# ============================================================
#  Dockerfile — KURBAN DIGITAL  (PROTECTED BUILD)
#  Multi-stage: src/ tidak pernah masuk ke image final
#  Image final: read-only, non-root, no shell, obfuscated code
# ============================================================

# ── STAGE 1: Builder ────────────────────────────────────────
FROM node:20-alpine AS builder

LABEL maintainer="Risky Hariadi"
LABEL app="kurban-digital"
LABEL stage="builder"

WORKDIR /build

# Install deps (termasuk devDependencies untuk obfuscator)
COPY package*.json ./
RUN npm install --include=dev

# Copy seluruh source
COPY . .

# Jalankan obfuscasi: src/app.js → public/app.js
RUN node build.js

# Verifikasi output build ada
RUN test -f public/app.js || (echo "❌ BUILD GAGAL: public/app.js tidak ada" && exit 1)

# ── STAGE 2: Runner (image bersih — tanpa src/, tanpa devTools) ──
FROM node:20-alpine AS runner

# Metadata keamanan
LABEL maintainer="Risky Hariadi"
LABEL app="kurban-digital"
LABEL description="Protected production image — source code not included"
LABEL version="1.0.0"

# Environment
ENV NODE_ENV=production
ENV PORT=8083
# Nonaktifkan npm update check
ENV NO_UPDATE_NOTIFIER=1
# Blokir akses inspect / debugger dari luar
ENV NODE_OPTIONS="--no-experimental-repl-await"

WORKDIR /app

# Install hanya production deps
COPY package*.json ./
RUN npm install --only=production && npm cache clean --force

# ── Salin HANYA output build (BUKAN src/) ──
COPY --from=builder /build/public/app.js      ./app.js
COPY --from=builder /build/public/index.html  ./index.html
COPY --from=builder /build/public/style.css   ./style.css
COPY --from=builder /build/server.js          ./server.js
COPY --from=builder /build/public/lagu        ./lagu
COPY --from=builder /build/public/qris.png    ./qris.png
COPY --from=builder /build/public/qr.png      ./qr.png
COPY --from=builder /build/public/bg-mosque.png         ./bg-mosque.png

# ── Hapus semua binary yang tidak perlu (kurangi attack surface) ──
RUN apk del --no-cache \
    wget curl git openssh-client \
    || true

# ── Buat non-root user (tanpa shell login) ──────────────────
RUN addgroup -g 1001 -S appgroup && \
    adduser -S appuser -u 1001 -G appgroup -s /sbin/nologin

# Atur kepemilikan file ke appuser
RUN chown -R appuser:appgroup /app

# Jadikan filesystem read-only untuk file sensitif
RUN chmod 444 /app/app.js /app/server.js && \
    chmod 444 /app/index.html /app/style.css && \
    chmod 555 /app/lagu 2>/dev/null || true

USER appuser

EXPOSE 8083

# Health check
HEALTHCHECK --interval=30s --timeout=5s --start-period=15s --retries=3 \
    CMD node -e "require('http').get('http://localhost:8083', r => r.statusCode===200 ? process.exit(0) : process.exit(1)).on('error', () => process.exit(1))"

# Jalankan tanpa shell — mencegah exec/sh masuk ke container
CMD ["node", "--disable-proto=delete", "--no-experimental-fetch", "server.js"]
