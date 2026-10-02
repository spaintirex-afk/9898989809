# ---- Stage 1: build the frontend and install server dependencies ----
# Full toolchain image so better-sqlite3's native module compiles/links cleanly.
FROM node:20-bookworm AS build
WORKDIR /app

# Frontend deps + build
COPY package.json ./
COPY tsconfig.json ./
COPY vite.config.ts ./
COPY index.html ./
COPY src ./src
COPY public ./public
RUN npm install
RUN npm run build            # -> /app/dist

# Server deps (native better-sqlite3 built here for linux/glibc)
COPY server/package.json ./server/
RUN cd server && npm install --omit=dev

# ---- Stage 2: slim runtime ----
FROM node:20-bookworm-slim AS runtime
WORKDIR /app
ENV NODE_ENV=production \
    PORT=8080 \
    DATA_DIR=/app/server/data

# Built frontend + full server (code + node_modules)
COPY --from=build /app/dist ./dist
COPY --from=build /app/server ./server

# Persistent database lives in this volume (survives container restarts/redeploys)
RUN mkdir -p /app/server/data
VOLUME ["/app/server/data"]

EXPOSE 8080

# Simple healthcheck against the public state endpoint
HEALTHCHECK --interval=30s --timeout=5s --start-period=15s --retries=3 \
  CMD node -e "fetch('http://127.0.0.1:'+ (process.env.PORT||8080) +'/api/state').then(r=>process.exit(r.ok?0:1)).catch(()=>process.exit(1))"

CMD ["node", "server/index.js"]
