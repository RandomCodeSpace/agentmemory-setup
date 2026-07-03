FROM node:22-bookworm-slim

ARG AGENTMEMORY_VERSION=0.9.27

LABEL org.opencontainers.image.source="https://github.com/RandomCodeSpace/agentmemory-setup"
LABEL org.opencontainers.image.description="AgentMemory worker for Rust iii-engine Docker setup"

RUN npm install -g "@agentmemory/agentmemory@${AGENTMEMORY_VERSION}" \
  && npm cache clean --force \
  && printf '%s\n' \
    '#!/bin/sh' \
    'set -eu' \
    'node -e "const base=(process.env.AGENTMEMORY_URL||\"http://127.0.0.1:3111\").replace(/\\/$/, \"\"); const wait=ms=>new Promise(r=>setTimeout(r,ms)); (async()=>{for(let i=0;i<120;i++){try{const r=await fetch(base+\"/\",{signal:AbortSignal.timeout(2000)}); if(r.status<500) process.exit(0)}catch{} await wait(1000)} console.error(\"iii-engine did not become ready at \"+base); process.exit(1)})()"' \
    'exec agentmemory --no-engine' \
    > /usr/local/bin/agentmemory-entrypoint \
  && chmod +x /usr/local/bin/agentmemory-entrypoint

ENV NODE_ENV=production

CMD ["agentmemory-entrypoint"]
