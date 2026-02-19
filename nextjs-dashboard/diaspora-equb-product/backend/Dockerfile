# ── Build stage ───────────────────────────────────────
FROM node:20-alpine AS builder

WORKDIR /app

COPY package.json package-lock.json* ./
RUN npm ci

COPY tsconfig.json nest-cli.json ./
COPY src/ src/

RUN npm run build

# ── Production stage ──────────────────────────────────
FROM node:20-alpine AS production

RUN addgroup -g 1001 -S appgroup && \
    adduser -S appuser -u 1001 -G appgroup

WORKDIR /app

COPY package.json package-lock.json* ./
RUN npm ci --omit=dev && npm cache clean --force

COPY --from=builder /app/dist ./dist

# wget is built into alpine — no extra apk install needed
USER appuser

EXPOSE 3001

HEALTHCHECK --interval=30s --timeout=10s --retries=3 --start-period=15s \
  CMD wget -q --spider http://localhost:3001/api/health || exit 1

CMD ["node", "dist/main.js"]
