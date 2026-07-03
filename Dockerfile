ARG III_VERSION=0.11.2
FROM iiidev/iii:${III_VERSION} AS iii

FROM node:22-bookworm-slim

ARG AGENTMEMORY_VERSION=0.9.27

LABEL org.opencontainers.image.source="https://github.com/RandomCodeSpace/agentmemory-setup"
LABEL org.opencontainers.image.description="AgentMemory plus Rust iii-engine in one Docker image"

RUN apt-get update \
  && apt-get install -y --no-install-recommends socat \
  && rm -rf /var/lib/apt/lists/* \
  && npm install -g "@agentmemory/agentmemory@${AGENTMEMORY_VERSION}" \
  && npm install --prefix /usr/local/lib/node_modules/@agentmemory/agentmemory/node_modules/onnx-proto --omit=dev protobufjs@7.6.1 \
  && npm cache clean --force \
  && rm -rf /usr/local/lib/node_modules/npm /usr/local/bin/npm /usr/local/bin/npx \
  && rm -rf /usr/local/lib/node_modules/@agentmemory/agentmemory/node_modules/onnx-proto/node_modules/protobufjs/cli

COPY --from=iii /app/iii /usr/local/bin/iii

RUN printf '%s\n' \
    '#!/usr/bin/env bash' \
    'set -euo pipefail' \
    'pids=()' \
    'cleanup() {' \
    '  for pid in "${pids[@]:-}"; do kill "$pid" 2>/dev/null || true; done' \
    '}' \
    'trap cleanup EXIT INT TERM' \
    'iii --config "${III_CONFIG_PATH:-/app/config.yaml}" &' \
    'pids+=("$!")' \
    'if [ -n "${VIEWER_PROXY_PORT:-}" ] && [ "${VIEWER_PROXY_PORT}" != "${III_VIEWER_PORT:-3113}" ]; then' \
    '  socat "TCP-LISTEN:${VIEWER_PROXY_PORT},fork,reuseaddr" "TCP:127.0.0.1:${III_VIEWER_PORT:-3113}" &' \
    '  pids+=("$!")' \
    'fi' \
    'node -e "const base=(process.env.AGENTMEMORY_URL||\"http://127.0.0.1:3111\").replace(/\\/$/, \"\"); const wait=ms=>new Promise(r=>setTimeout(r,ms)); (async()=>{for(let i=0;i<120;i++){try{const r=await fetch(base+\"/\",{signal:AbortSignal.timeout(2000)}); if(r.status<500) process.exit(0)}catch{} await wait(1000)} console.error(\"iii-engine did not become ready at \"+base); process.exit(1)})()"' \
    'agentmemory --no-engine &' \
    'am_pid="$!"' \
    'pids+=("$am_pid")' \
    'wait "$am_pid"' \
    > /usr/local/bin/agentmemory-entrypoint \
  && chmod +x /usr/local/bin/agentmemory-entrypoint

ENV NODE_ENV=production
ENV HOME=/data/home
ENV III_ENGINE_URL=ws://127.0.0.1:49134

CMD ["agentmemory-entrypoint"]
