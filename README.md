# agentmemory-setup

Docker setup for AgentMemory with Rust `iii-engine` (`iiidev/iii`), OpenAI-compatible LLM config, local embeddings, persistent storage, and CPU/RAM limits.

## Quick Start

```bash
./setup.sh \
  --base-url https://ollama.com \
  --api-key "$OLLAMA_API_KEY" \
  --model deepseek-v4-flash \
  --domain agent-mem.randomcodespace.dev
```

Defaults:

- AgentMemory worker: `2g`, `2` CPUs
- Rust iii-engine: `512m`, `1` CPU
- Persistent Rust iii-engine state: `/opt/agentmemory/iii-data`
- Persistent AgentMemory home: `/opt/agentmemory/agentmemory-home`
- Caddy auth username: `admin`
- Caddy auth password path: `/opt/agentmemory/credentials.json`

## Options

```bash
./setup.sh --help
```

Useful overrides:

```bash
./setup.sh \
  --base-url https://ollama.com \
  --api-key "$OLLAMA_API_KEY" \
  --model deepseek-v4-flash \
  --worker-memory 2g \
  --engine-memory 512m \
  --worker-cpus 2 \
  --engine-cpus 1 \
  --data-dir /srv/agentmemory/home \
  --iii-data-dir /srv/agentmemory/iii
```

## Verify

```bash
docker compose -f /opt/agentmemory/docker-compose.yml ps
curl http://127.0.0.1:3111/agentmemory/livez
```

With Caddy:

```bash
jq -r .password /opt/agentmemory/credentials.json
```

Then open the configured domain and sign in as `admin`.
