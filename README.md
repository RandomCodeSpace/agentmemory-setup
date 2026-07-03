# agentmemory-setup

Single-image Docker setup for AgentMemory plus Rust `iii-engine` (`iiidev/iii`), OpenAI-compatible LLM config, local embeddings, persistent storage, and CPU/RAM limits.

## Quick Start

```bash
./setup.sh \
  --base-url https://ollama.com/v1 \
  --api-key "$OLLAMA_API_KEY" \
  --model deepseek-v4-flash \
  --domain agent-mem.randomcodespace.dev
```

Defaults:

- Pulls `ghcr.io/randomcodespace/agentmemory-setup-public:latest` by default; version tag: `ghcr.io/randomcodespace/agentmemory-setup-public:0.9.27`
- One container image contains AgentMemory and Rust `iii-engine`
- Container limit: `3g`, `2.5` CPUs
- Rust `iii-engine` is internal only; only AgentMemory REST/stream/viewer ports bind to host loopback
- Persistent Rust `iii-engine` state: `/opt/agentmemory/iii-data`
- Persistent AgentMemory home: `/opt/agentmemory/agentmemory-home`
- Public web UI: `https://DOMAIN`
- Public MCP/REST base URL: `https://DOMAIN`
- Auth: AgentMemory bearer secret in `/opt/agentmemory/credentials.json`

## Options

```bash
./setup.sh --help
```

Useful overrides:

```bash
./setup.sh \
  --base-url https://ollama.com/v1 \
  --api-key "$OLLAMA_API_KEY" \
  --model deepseek-v4-flash \
  --memory 3g \
  --cpus 2.5 \
  --data-dir /srv/agentmemory/home \
  --iii-data-dir /srv/agentmemory/iii
```

Use `--build-local` only when changing the Dockerfile or AgentMemory/iii versions.

## Verify

```bash
docker compose -f /opt/agentmemory/docker-compose.yml ps
curl http://127.0.0.1:3111/agentmemory/livez
```

With Caddy/domain:

```bash
jq -r .agentmemory_secret /opt/agentmemory/credentials.json
```

Open the domain for the web UI. Use the same value as `AGENTMEMORY_SECRET` for MCP:

```bash
AGENTMEMORY_URL=https://agent-mem.randomcodespace.dev \
AGENTMEMORY_SECRET="$(jq -r .agentmemory_secret /opt/agentmemory/credentials.json)" \
npx -y @agentmemory/mcp
```
