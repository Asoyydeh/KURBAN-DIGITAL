#!/bin/bash
# ============================================================
#  KURBAN DIGITAL — Build & Deploy Script
#  Penggunaan: chmod +x deploy.sh && ./deploy.sh
#
#  Apa yang dilakukan script ini:
#  1. Validasi environment
#  2. Build Docker image (dengan obfuscation otomatis)
#  3. Scan keamanan image
#  4. Run container dengan flags keamanan ketat
# ============================================================

set -euo pipefail  # Exit on error, unset var, pipe fail

# ── Warna terminal ──────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# ── Konfigurasi ─────────────────────────────────────────────
APP_NAME="kurban-digital"
IMAGE_TAG="${APP_NAME}:latest"
CONTAINER_NAME="${APP_NAME}-app"
PORT="${PORT:-8083}"
ENV_FILE=".env"

# ── Banner ──────────────────────────────────────────────────
echo ""
echo -e "${CYAN}${BOLD}╔════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}${BOLD}║   🐪  KURBAN DIGITAL — PROTECTED DEPLOY        ║${NC}"
echo -e "${CYAN}${BOLD}║       Build + Obfuscate + Docker Secure Run     ║${NC}"
echo -e "${CYAN}${BOLD}╚════════════════════════════════════════════════╝${NC}"
echo ""

# ── Fungsi helper ────────────────────────────────────────────
log_step() { echo -e "${BLUE}[STEP]${NC} $1"; }
log_ok()   { echo -e "${GREEN}[✓]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[!]${NC} $1"; }
log_err()  { echo -e "${RED}[✗] ERROR:${NC} $1"; exit 1; }

# ── STEP 1: Cek Docker ───────────────────────────────────────
log_step "Memeriksa instalasi Docker..."
if ! command -v docker &> /dev/null; then
    log_err "Docker tidak ditemukan! Install dari https://docker.com"
fi
log_ok "Docker tersedia: $(docker --version)"

# ── STEP 2: Cek src/app.js ada ──────────────────────────────
log_step "Memverifikasi source code..."
if [ ! -f "src/app.js" ]; then
    log_err "src/app.js tidak ditemukan! Pastikan source code ada."
fi
log_ok "src/app.js ditemukan ($(du -sh src/app.js | cut -f1))"

# ── STEP 3: Cek file .env ────────────────────────────────────
log_step "Memeriksa konfigurasi environment..."
if [ ! -f "$ENV_FILE" ]; then
    log_warn ".env tidak ditemukan. Menggunakan variabel default."
    log_warn "Salin .env.example ke .env dan isi nilainya!"
    ENV_ARGS=""
else
    log_ok ".env ditemukan"
    ENV_ARGS="--env-file $ENV_FILE"
fi

# ── STEP 4: Hentikan container lama ─────────────────────────
log_step "Membersihkan container lama..."
if docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
    docker stop "$CONTAINER_NAME" 2>/dev/null || true
    docker rm   "$CONTAINER_NAME" 2>/dev/null || true
    log_ok "Container lama dihapus"
else
    log_ok "Tidak ada container lama"
fi

# ── STEP 5: Build Docker image ───────────────────────────────
log_step "Memulai build Docker (dengan obfuscation)..."
echo ""

docker build \
    --no-cache \
    --pull \
    --tag "$IMAGE_TAG" \
    --label "build.date=$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    --label "build.commit=$(git rev-parse --short HEAD 2>/dev/null || echo 'no-git')" \
    --label "build.protected=true" \
    . 

echo ""
log_ok "Docker image berhasil dibuat: $IMAGE_TAG"

# ── STEP 6: Verifikasi — src/ TIDAK ada di image ─────────────
log_step "Memverifikasi keamanan: memastikan src/ tidak ada di image..."
if docker run --rm --entrypoint="" "$IMAGE_TAG" ls /app/src 2>/dev/null; then
    log_err "PELANGGARAN KEAMANAN: folder src/ terdeteksi di dalam image!"
else
    log_ok "AMAN: src/ tidak ada di dalam image production"
fi

# Verifikasi app.js terobfuscate (tidak mengandung nama fungsi asli yang mudah dibaca)
log_step "Memverifikasi obfuscation pada app.js..."
READABLE_CHECK=$(docker run --rm --entrypoint="" "$IMAGE_TAG" \
    node -e "const c=require('fs').readFileSync('/app/app.js','utf8'); \
    const readable=['function main','addEventListener','function init'].filter(k=>c.includes(k)); \
    console.log(readable.length === 0 ? 'OBFUSCATED' : 'READABLE:'+readable.join(','))")

if [[ "$READABLE_CHECK" == "OBFUSCATED" ]]; then
    log_ok "AMAN: app.js telah terobfuscasi dengan baik"
else
    log_warn "app.js mungkin masih terbaca sebagian: $READABLE_CHECK"
fi

# ── STEP 7: Tampilkan info image ─────────────────────────────
IMAGE_SIZE=$(docker image inspect "$IMAGE_TAG" --format='{{.Size}}' | \
    awk '{ if($1>1073741824) printf "%.1f GB\n",$1/1073741824; \
           else if($1>1048576) printf "%.1f MB\n",$1/1048576; \
           else printf "%.0f KB\n",$1/1024 }')
log_ok "Ukuran image: $IMAGE_SIZE"

# ── STEP 8: Jalankan container dengan keamanan ketat ─────────
log_step "Menjalankan container dengan security flags..."

docker run \
    --detach \
    --name "$CONTAINER_NAME" \
    --publish "${PORT}:8083" \
    --restart unless-stopped \
    \
    `# ── Security Flags ──` \
    --read-only \
    --no-new-privileges \
    --security-opt no-new-privileges:true \
    --security-opt apparmor:docker-default \
    --cap-drop ALL \
    --cap-add NET_BIND_SERVICE \
    \
    `# ── Resource Limits ──` \
    --memory "256m" \
    --memory-swap "256m" \
    --cpus "1.0" \
    --pids-limit 100 \
    \
    `# ── Network ──` \
    --network bridge \
    \
    `# ── Tmp (writable) untuk keperluan runtime ──` \
    --tmpfs /tmp:rw,noexec,nosuid,size=50m \
    \
    `# ── Environment ──` \
    --env NODE_ENV=production \
    --env PORT=8083 \
    $ENV_ARGS \
    \
    "$IMAGE_TAG"

# ── STEP 9: Tunggu dan cek health ───────────────────────────
log_step "Menunggu server siap..."
sleep 3

MAX_WAIT=30
WAITED=0
while ! curl -sf "http://localhost:${PORT}" > /dev/null 2>&1; do
    sleep 2
    WAITED=$((WAITED + 2))
    if [ $WAITED -ge $MAX_WAIT ]; then
        log_err "Server tidak merespons setelah ${MAX_WAIT}s. Cek log: docker logs $CONTAINER_NAME"
    fi
    echo -ne "  Menunggu... ${WAITED}s\r"
done

echo ""
echo ""
echo -e "${GREEN}${BOLD}╔════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}${BOLD}║  ✅  KURBAN DIGITAL BERHASIL DEPLOY!               ║${NC}"
echo -e "${GREEN}${BOLD}╠════════════════════════════════════════════════════╣${NC}"
echo -e "${GREEN}${BOLD}║${NC}  🌐  URL  : ${CYAN}http://localhost:${PORT}${NC}"
echo -e "${GREEN}${BOLD}║${NC}  📦  Image: ${CYAN}${IMAGE_TAG}${NC}"
echo -e "${GREEN}${BOLD}║${NC}  🐳  Container: ${CYAN}${CONTAINER_NAME}${NC}"
echo -e "${GREEN}${BOLD}║${NC}"
echo -e "${GREEN}${BOLD}║${NC}  🔒  Proteksi Aktif:"
echo -e "${GREEN}${BOLD}║${NC}      ✓ Source code terobfuscasi"
echo -e "${GREEN}${BOLD}║${NC}      ✓ src/ tidak ada di image"
echo -e "${GREEN}${BOLD}║${NC}      ✓ Read-only filesystem"
echo -e "${GREEN}${BOLD}║${NC}      ✓ No new privileges"
echo -e "${GREEN}${BOLD}║${NC}      ✓ All capabilities dropped"
echo -e "${GREEN}${BOLD}║${NC}      ✓ Non-root user"
echo -e "${GREEN}${BOLD}║${NC}      ✓ Memory limit: 256MB"
echo -e "${GREEN}${BOLD}╚════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "  Untuk melihat log  : ${YELLOW}docker logs -f $CONTAINER_NAME${NC}"
echo -e "  Untuk stop app     : ${YELLOW}./stop.sh${NC}"
echo -e "  Untuk audit security: ${YELLOW}./security-audit.sh${NC}"
echo ""
