#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  ./setup.sh --base-url URL --api-key KEY --model MODEL [options]

Required:
  --base-url URL        OpenAI-compatible base URL, e.g. https://ollama.com
  --api-key KEY         Provider API key
  --model MODEL         Chat model, e.g. deepseek-v4-flash

Options:
  --domain DOMAIN       Configure Caddy for DOMAIN
  --install-dir DIR     Default: /opt/agentmemory
  --data-dir DIR        AgentMemory home/data path. Default: INSTALL_DIR/agentmemory-home
  --iii-data-dir DIR    Rust iii-engine state path. Default: INSTALL_DIR/iii-data
  --project-name NAME   Default: agentmemory
  --image IMAGE         Default: local/agentmemory-worker:0.9.27
  --agentmemory-version VERSION  Default: 0.9.27
  --iii-version VERSION          Default: 0.11.2
  --embedding-provider NAME      Default: local
  --worker-memory LIMIT          Default: 2g
  --engine-memory LIMIT          Default: 512m
  --worker-cpus N                Default: 2
  --engine-cpus N                Default: 1
  --rest-port PORT               Default: 3111
  --stream-port PORT             Default: 3112
  --viewer-port PORT             Default: 3113
  --engine-port PORT             Default: 49134
  --metrics-port PORT            Default: 9464
  --no-caddy                     Skip Caddy config
  --no-start                     Write files only
EOF
}

BASE_URL=""
API_KEY=""
MODEL=""
DOMAIN=""
INSTALL_DIR="/opt/agentmemory"
DATA_DIR=""
III_DATA_DIR=""
PROJECT_NAME="agentmemory"
AGENTMEMORY_VERSION="0.9.27"
III_VERSION="0.11.2"
IMAGE="local/agentmemory-worker:0.9.27"
EMBEDDING_PROVIDER="local"
WORKER_MEMORY="2g"
ENGINE_MEMORY="512m"
WORKER_CPUS="2"
ENGINE_CPUS="1"
REST_PORT="3111"
STREAM_PORT="3112"
VIEWER_PORT="3113"
ENGINE_PORT="49134"
METRICS_PORT="9464"
CONFIGURE_CADDY="auto"
START_STACK="1"

while [ "$#" -gt 0 ]; do
  case "$1" in
    --base-url) BASE_URL="${2:?}"; shift 2 ;;
    --api-key) API_KEY="${2:?}"; shift 2 ;;
    --model) MODEL="${2:?}"; shift 2 ;;
    --domain) DOMAIN="${2:?}"; shift 2 ;;
    --install-dir) INSTALL_DIR="${2:?}"; shift 2 ;;
    --data-dir) DATA_DIR="${2:?}"; shift 2 ;;
    --iii-data-dir) III_DATA_DIR="${2:?}"; shift 2 ;;
    --project-name) PROJECT_NAME="${2:?}"; shift 2 ;;
    --image) IMAGE="${2:?}"; shift 2 ;;
    --agentmemory-version) AGENTMEMORY_VERSION="${2:?}"; IMAGE="local/agentmemory-worker:${2:?}"; shift 2 ;;
    --iii-version) III_VERSION="${2:?}"; shift 2 ;;
    --embedding-provider) EMBEDDING_PROVIDER="${2:?}"; shift 2 ;;
    --worker-memory) WORKER_MEMORY="${2:?}"; shift 2 ;;
    --engine-memory) ENGINE_MEMORY="${2:?}"; shift 2 ;;
    --worker-cpus) WORKER_CPUS="${2:?}"; shift 2 ;;
    --engine-cpus) ENGINE_CPUS="${2:?}"; shift 2 ;;
    --rest-port) REST_PORT="${2:?}"; shift 2 ;;
    --stream-port) STREAM_PORT="${2:?}"; shift 2 ;;
    --viewer-port) VIEWER_PORT="${2:?}"; shift 2 ;;
    --engine-port) ENGINE_PORT="${2:?}"; shift 2 ;;
    --metrics-port) METRICS_PORT="${2:?}"; shift 2 ;;
    --no-caddy) CONFIGURE_CADDY="0"; shift ;;
    --no-start) START_STACK="0"; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; usage; exit 2 ;;
  esac
done

[ -n "$BASE_URL" ] || { usage >&2; exit 2; }
[ -n "$API_KEY" ] || { usage >&2; exit 2; }
[ -n "$MODEL" ] || { usage >&2; exit 2; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DATA_DIR="${DATA_DIR:-$INSTALL_DIR/agentmemory-home}"
III_DATA_DIR="${III_DATA_DIR:-$INSTALL_DIR/iii-data}"

mkdir_owned() {
  if mkdir -p "$1" 2>/dev/null; then
    return
  fi
  sudo mkdir -p "$1"
  sudo chown -R "$(id -u):$(id -g)" "$1"
}

json_escape() {
  python3 -c 'import json,sys; print(json.dumps(sys.stdin.read().rstrip("\n"))[1:-1])'
}

mkdir_owned "$INSTALL_DIR"
mkdir_owned "$DATA_DIR/.agentmemory"
mkdir_owned "$III_DATA_DIR"

install -m 0644 "$SCRIPT_DIR/Dockerfile" "$INSTALL_DIR/Dockerfile"

umask 077
cat > "$INSTALL_DIR/.env" <<EOF
AGENTMEMORY_VERSION=$AGENTMEMORY_VERSION
AGENTMEMORY_III_VERSION=$III_VERSION
OPENAI_API_KEY=$API_KEY
EOF

cat > "$DATA_DIR/.agentmemory/.env" <<EOF
OPENAI_API_KEY=$API_KEY
OPENAI_BASE_URL=$BASE_URL
OPENAI_MODEL=$MODEL
OPENAI_REASONING_EFFORT=none
EMBEDDING_PROVIDER=$EMBEDDING_PROVIDER
AGENTMEMORY_AUTO_COMPRESS=true
AGENTMEMORY_SUPPRESS_COST_WARNING=1
AGENTMEMORY_URL=http://127.0.0.1:$REST_PORT
AGENTMEMORY_VIEWER_URL=${DOMAIN:+https://$DOMAIN}
III_ENGINE_URL=ws://127.0.0.1:$ENGINE_PORT
III_REST_PORT=$REST_PORT
III_STREAMS_PORT=$STREAM_PORT
III_VIEWER_PORT=$VIEWER_PORT
EOF

cat > "$DATA_DIR/.agentmemory/preferences.json" <<EOF
{
  "schemaVersion": 1,
  "lastAgent": null,
  "lastAgents": [],
  "lastProvider": "openai",
  "skipSplash": true,
  "skipNpxHint": true,
  "skipGlobalInstall": true,
  "skipConsoleInstall": true,
  "firstRunAt": "$(date -u +%Y-%m-%dT%H:%M:%S.000Z)"
}
EOF

cat > "$INSTALL_DIR/iii-config.docker.yaml" <<EOF
workers:
  - name: iii-http
    config:
      port: $REST_PORT
      host: 0.0.0.0
      default_timeout: 180000
      cors:
        allowed_origins: ["http://localhost:$REST_PORT", "http://localhost:$VIEWER_PORT", "http://127.0.0.1:$REST_PORT", "http://127.0.0.1:$VIEWER_PORT"]
        allowed_methods: [GET, POST, PUT, DELETE, OPTIONS]
  - name: iii-state
    config:
      adapter:
        name: kv
        config:
          store_method: file_based
          file_path: /data/state_store.db
  - name: iii-queue
    config:
      adapter:
        name: builtin
  - name: iii-pubsub
    config:
      adapter:
        name: local
  - name: iii-cron
    config:
      adapter:
        name: kv
  - name: iii-stream
    config:
      port: $STREAM_PORT
      host: 0.0.0.0
      adapter:
        name: kv
        config:
          store_method: file_based
          file_path: /data/stream_store
  - name: iii-observability
    config:
      enabled: true
      service_name: agentmemory
      exporter: memory
      sampling_ratio: 0.1
      metrics_enabled: true
      logs_enabled: true
      logs_console_output: false
  - name: iii-exec
    config:
      watch:
        - src/**/*.ts
      exec:
        - node dist/index.mjs
EOF

cat > "$INSTALL_DIR/docker-compose.yml" <<EOF
name: $PROJECT_NAME

services:
  iii-init:
    image: busybox:1.36
    user: "0:0"
    volumes:
      - "$III_DATA_DIR:/data"
    entrypoint: ["sh", "-c", "chown -R 65532:65532 /data && chmod 755 /data"]
    restart: "no"

  iii-engine:
    image: iiidev/iii:$III_VERSION
    user: "65532:65532"
    depends_on:
      iii-init:
        condition: service_completed_successfully
    ports:
      - "127.0.0.1:$ENGINE_PORT:49134"
      - "127.0.0.1:$REST_PORT:$REST_PORT"
      - "127.0.0.1:$STREAM_PORT:$STREAM_PORT"
      - "127.0.0.1:$METRICS_PORT:9464"
    volumes:
      - "$III_DATA_DIR:/data"
      - ./iii-config.docker.yaml:/app/config.yaml:ro
    restart: unless-stopped
    mem_limit: $ENGINE_MEMORY
    cpus: "$ENGINE_CPUS"
    logging:
      driver: json-file
      options:
        max-size: "10m"
        max-file: "3"

  agentmemory-worker:
    build:
      context: .
      args:
        AGENTMEMORY_VERSION: $AGENTMEMORY_VERSION
    image: $IMAGE
    network_mode: host
    depends_on:
      iii-engine:
        condition: service_started
    env_file:
      - ./.env
    environment:
      HOME: /data
      AGENTMEMORY_URL: http://127.0.0.1:$REST_PORT
      AGENTMEMORY_VIEWER_URL: ${DOMAIN:+https://$DOMAIN}
      III_ENGINE_URL: ws://127.0.0.1:$ENGINE_PORT
      III_REST_PORT: "$REST_PORT"
      III_STREAMS_PORT: "$STREAM_PORT"
      III_VIEWER_PORT: "$VIEWER_PORT"
      EMBEDDING_PROVIDER: $EMBEDDING_PROVIDER
      OPENAI_BASE_URL: $BASE_URL
      OPENAI_MODEL: $MODEL
      OPENAI_REASONING_EFFORT: none
      AGENTMEMORY_AUTO_COMPRESS: "true"
      AGENTMEMORY_SUPPRESS_COST_WARNING: "1"
    volumes:
      - "$DATA_DIR:/data"
    restart: unless-stopped
    mem_limit: $WORKER_MEMORY
    cpus: "$WORKER_CPUS"
    logging:
      driver: json-file
      options:
        max-size: "10m"
        max-file: "3"

EOF

chmod 600 "$INSTALL_DIR/.env" "$DATA_DIR/.agentmemory/.env"
chmod 644 "$INSTALL_DIR/Dockerfile" "$INSTALL_DIR/docker-compose.yml" "$INSTALL_DIR/iii-config.docker.yaml" "$DATA_DIR/.agentmemory/preferences.json"

if [ "$CONFIGURE_CADDY" != "0" ] && [ -n "$DOMAIN" ]; then
  if ! command -v caddy >/dev/null 2>&1; then
    echo "Caddy not found; skipped Caddy config." >&2
  else
    CADDY_PASS="$(openssl rand -base64 24 | tr -d '\n')"
    CADDY_HASH="$(caddy hash-password --plaintext "$CADDY_PASS")"
    cat > "$INSTALL_DIR/credentials.json" <<EOF
{
  "domain": "https://$(printf '%s' "$DOMAIN" | json_escape)",
  "username": "admin",
  "password": "$(printf '%s' "$CADDY_PASS" | json_escape)",
  "credential_path": "$INSTALL_DIR/credentials.json"
}
EOF
    chmod 600 "$INSTALL_DIR/credentials.json"

    TMP_AUTH="$(mktemp)"
    TMP_SITE="$(mktemp)"
    {
      printf 'basic_auth {\n'
      printf '\tadmin %s\n' "$CADDY_HASH"
      printf '}\n'
    } > "$TMP_AUTH"
    cat > "$TMP_SITE" <<EOF
$DOMAIN {
	import /etc/caddy/agentmemory-auth.caddy
	encode zstd gzip

	@agentmemory_api path /agentmemory/*
	reverse_proxy @agentmemory_api 127.0.0.1:$REST_PORT {
		header_up Host 127.0.0.1:$REST_PORT
		flush_interval -1
		transport http {
			read_timeout 24h
			response_header_timeout 30s
		}
	}

	@agentmemory_stream path /stream/*
	route @agentmemory_stream {
		rewrite * /
		reverse_proxy 127.0.0.1:$STREAM_PORT {
			header_up Host 127.0.0.1:$STREAM_PORT
			flush_interval -1
			transport http {
				read_timeout 24h
				response_header_timeout 30s
			}
		}
	}

	reverse_proxy 127.0.0.1:$VIEWER_PORT {
		header_up Host 127.0.0.1:$VIEWER_PORT
		flush_interval -1
		transport http {
			read_timeout 24h
			response_header_timeout 30s
		}
	}
}
EOF
    sudo install -m 0644 -o root -g root "$TMP_AUTH" /etc/caddy/agentmemory-auth.caddy
    sudo install -m 0644 -o root -g root "$TMP_SITE" /etc/caddy/agentmemory.caddy
    rm -f "$TMP_AUTH" "$TMP_SITE"
    if ! grep -q '^import /etc/caddy/agentmemory.caddy$' /etc/caddy/Caddyfile; then
      sudo cp /etc/caddy/Caddyfile "/etc/caddy/Caddyfile.backup-agentmemory-$(date -u +%Y%m%dT%H%M%SZ)"
      printf '\nimport /etc/caddy/agentmemory.caddy\n' | sudo tee -a /etc/caddy/Caddyfile >/dev/null
    fi
    sudo caddy validate --config /etc/caddy/Caddyfile >/dev/null
    sudo systemctl reload caddy
  fi
fi

if [ "$START_STACK" = "1" ]; then
  docker compose -f "$INSTALL_DIR/docker-compose.yml" up -d --build
fi

echo "Install dir: $INSTALL_DIR"
echo "AgentMemory data dir: $DATA_DIR"
echo "Rust iii-engine data dir: $III_DATA_DIR"
echo "Compose: docker compose -f $INSTALL_DIR/docker-compose.yml ps"
[ -z "$DOMAIN" ] || echo "URL: https://$DOMAIN"
