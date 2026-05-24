#!/bin/bash
# ============================================================
#  KURBAN DIGITAL — Security Audit Script
#  Memeriksa semua lapisan proteksi kode
#  Penggunaan: ./security-audit.sh
# ============================================================

set -uo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

APP_NAME="kurban-digital"
IMAGE_TAG="${APP_NAME}:latest"
CONTAINER_NAME="${APP_NAME}-app"

PASS=0
FAIL=0
WARN=0

check_pass() { echo -e "  ${GREEN}[PASS]${NC} $1"; PASS=$((PASS+1)); }
check_fail() { echo -e "  ${RED}[FAIL]${NC} $1"; FAIL=$((FAIL+1)); }
check_warn() { echo -e "  ${YELLOW}[WARN]${NC} $1"; WARN=$((WARN+1)); }
section()    { echo ""; echo -e "${CYAN}${BOLD}▶ $1${NC}"; }

echo ""
echo -e "${CYAN}${BOLD}╔══════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}${BOLD}║  🔍  KURBAN DIGITAL — SECURITY AUDIT REPORT      ║${NC}"
echo -e "${CYAN}${BOLD}╚══════════════════════════════════════════════════╝${NC}"

# ── A. CEK IMAGE ADA ─────────────────────────────────────────
section "A. IMAGE DOCKER"

if docker image inspect "$IMAGE_TAG" &>/dev/null; then
    check_pass "Image $IMAGE_TAG ditemukan"
    IMAGE_SIZE=$(docker image inspect "$IMAGE_TAG" --format='{{.Size}}' | \
        awk '{ printf "%.1f MB\n",$1/1048576 }')
    echo -e "     Ukuran: $IMAGE_SIZE"
else
    check_fail "Image $IMAGE_TAG tidak ditemukan! Jalankan ./deploy.sh terlebih dahulu"
    echo ""
    echo -e "${YELLOW}Audit tidak dapat dilanjutkan. Build image dulu dengan ./deploy.sh${NC}"
    exit 1
fi

# ── B. CEK KEAMANAN FILESYSTEM IMAGE ─────────────────────────
section "B. SOURCE CODE PROTECTION (dalam image)"

# Cek src/ tidak ada
if docker run --rm --entrypoint="" "$IMAGE_TAG" \
    sh -c "ls /app/src 2>/dev/null && echo FOUND || echo NOT_FOUND" 2>/dev/null | grep -q "NOT_FOUND"; then
    check_pass "folder src/ TIDAK ada di image production ✓"
else
    check_fail "BAHAYA: folder src/ TERDETEKSI di dalam image!"
fi

# Cek build.js tidak ada
if docker run --rm --entrypoint="" "$IMAGE_TAG" \
    sh -c "ls /app/build.js 2>/dev/null && echo FOUND || echo NOT_FOUND" 2>/dev/null | grep -q "NOT_FOUND"; then
    check_pass "build.js tidak ada di image ✓"
else
    check_warn "build.js masih ada di image (tidak kritis, tapi sebaiknya dihapus)"
fi

# Cek .env tidak ada di image
if docker run --rm --entrypoint="" "$IMAGE_TAG" \
    sh -c "ls /app/.env 2>/dev/null && echo FOUND || echo NOT_FOUND" 2>/dev/null | grep -q "NOT_FOUND"; then
    check_pass ".env tidak ada di image ✓"
else
    check_fail "BAHAYA: file .env ada di dalam image!"
fi

# Cek app.js terobfuscasi
section "C. OBFUSCATION QUALITY"

APP_JS_SIZE=$(docker run --rm --entrypoint="" "$IMAGE_TAG" \
    node -e "const s=require('fs').statSync('/app/app.js').size; \
    console.log(Math.round(s/1024)+'KB')" 2>/dev/null || echo "?")
echo -e "     Ukuran app.js: $APP_JS_SIZE"

# Cek apakah ada string hex identifier (_0x)
HEX_COUNT=$(docker run --rm --entrypoint="" "$IMAGE_TAG" \
    node -e "const c=require('fs').readFileSync('/app/app.js','utf8'); \
    const m=c.match(/_0x[a-f0-9]+/g); \
    console.log(m?m.length:0)" 2>/dev/null || echo "0")

if [ "$HEX_COUNT" -gt "100" ] 2>/dev/null; then
    check_pass "app.js terobfuscasi (${HEX_COUNT} hex identifiers) ✓"
elif [ "$HEX_COUNT" -gt "0" ] 2>/dev/null; then
    check_warn "app.js sedikit terobfuscasi (${HEX_COUNT} hex identifiers) — pertimbangkan level lebih tinggi"
else
    check_fail "app.js TIDAK terobfuscasi atau gagal dibaca!"
fi

# Cek tidak ada comment /** atau nama fungsi jelas
READABLE_STRINGS=$(docker run --rm --entrypoint="" "$IMAGE_TAG" \
    node -e "const c=require('fs').readFileSync('/app/app.js','utf8'); \
    const patterns=['/** @','function main(','addEventListener(','// TODO','// FIXME']; \
    const found=patterns.filter(p=>c.includes(p)); \
    console.log(found.length)" 2>/dev/null || echo "?")

if [ "$READABLE_STRINGS" = "0" ]; then
    check_pass "Tidak ada komentar/pola kode yang mudah dibaca ✓"
else
    check_warn "Ditemukan ${READABLE_STRINGS} pola kode yang masih terbaca"
fi

# ── D. CEK KONFIGURASI CONTAINER ─────────────────────────────
section "D. CONTAINER RUNTIME SECURITY"

if docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then

    # Cek user bukan root
    USER_ID=$(docker exec "$CONTAINER_NAME" id -u 2>/dev/null || echo "?")
    if [ "$USER_ID" != "0" ] && [ "$USER_ID" != "?" ]; then
        check_pass "Berjalan sebagai non-root (UID: $USER_ID) ✓"
    else
        check_fail "Container berjalan sebagai root! Ini berbahaya."
    fi

    # Cek read-only filesystem
    RO_CHECK=$(docker inspect "$CONTAINER_NAME" \
        --format='{{.HostConfig.ReadonlyRootfs}}' 2>/dev/null || echo "false")
    if [ "$RO_CHECK" = "true" ]; then
        check_pass "Filesystem read-only aktif ✓"
    else
        check_warn "Filesystem tidak dalam mode read-only"
    fi

    # Cek no-new-privileges
    NNP=$(docker inspect "$CONTAINER_NAME" \
        --format='{{.HostConfig.SecurityOpt}}' 2>/dev/null || echo "[]")
    if echo "$NNP" | grep -q "no-new-privileges"; then
        check_pass "no-new-privileges aktif ✓"
    else
        check_warn "no-new-privileges tidak terdeteksi"
    fi

    # Cek memory limit
    MEM_LIMIT=$(docker inspect "$CONTAINER_NAME" \
        --format='{{.HostConfig.Memory}}' 2>/dev/null || echo "0")
    if [ "$MEM_LIMIT" != "0" ] && [ "$MEM_LIMIT" != "" ]; then
        MEM_MB=$((MEM_LIMIT / 1048576))
        check_pass "Memory limit: ${MEM_MB}MB ✓"
    else
        check_warn "Memory limit tidak disetel"
    fi

    # Cek capabilities
    CAPS=$(docker inspect "$CONTAINER_NAME" \
        --format='{{.HostConfig.CapDrop}}' 2>/dev/null || echo "[]")
    if echo "$CAPS" | grep -q "ALL"; then
        check_pass "Semua capabilities di-drop (--cap-drop ALL) ✓"
    else
        check_warn "Capabilities tidak sepenuhnya di-drop"
    fi

    # Cek apakah bisa exec shell
    echo -ne "     Menguji akses shell ke container..."
    if docker exec "$CONTAINER_NAME" sh -c "echo pwned" 2>/dev/null | grep -q "pwned"; then
        check_warn "Shell /bin/sh masih bisa dieksekusi — pertimbangkan --no-new-privileges"
    else
        check_pass "Shell tidak bisa dieksekusi dari luar ✓"
    fi

else
    check_warn "Container $CONTAINER_NAME tidak berjalan — lewati cek runtime"
    echo -e "     Jalankan container dulu dengan: ${YELLOW}./deploy.sh${NC}"
fi

# ── E. CEK FILE SENSITIF DI HOST ─────────────────────────────
section "E. FILE SENSITIF DI HOST"

if [ -f ".env" ]; then
    check_warn ".env ada di folder proyek — pastikan sudah ada di .gitignore"
    # Cek .gitignore
    if grep -q "^\.env$" .gitignore 2>/dev/null; then
        check_pass ".env sudah ada di .gitignore ✓"
    else
        check_fail ".env TIDAK ada di .gitignore — BAHAYA jika push ke GitHub!"
    fi
else
    check_warn ".env tidak ditemukan — pastikan environment variable sudah disetel"
fi

if [ -f "src/app.js" ]; then
    check_warn "src/app.js ada di host (normal untuk development)"
    # Cek apakah src/ ada di gitignore
    if grep -q "src/" .gitignore 2>/dev/null || grep -q "^src$" .gitignore 2>/dev/null; then
        check_warn "src/ ada di .gitignore — pastikan ini sengaja (tidak bisa push source)"
    else
        echo -e "     ${BLUE}INFO${NC}: src/ tidak di-ignore di git (source akan di-push ke repo)"
    fi
fi

# ── RINGKASAN ─────────────────────────────────────────────────
echo ""
echo -e "${CYAN}${BOLD}══════════════════════════════════════════════════${NC}"
TOTAL=$((PASS + FAIL + WARN))
echo -e "${BOLD}  HASIL AUDIT: ${TOTAL} checks${NC}"
echo -e "  ${GREEN}✓ PASS : ${PASS}${NC}"
echo -e "  ${YELLOW}! WARN : ${WARN}${NC}"
echo -e "  ${RED}✗ FAIL : ${FAIL}${NC}"

echo ""
if [ "$FAIL" -eq 0 ]; then
    echo -e "${GREEN}${BOLD}  🔒 STATUS: AMAN — Tidak ada masalah kritis!${NC}"
elif [ "$FAIL" -le 2 ]; then
    echo -e "${YELLOW}${BOLD}  ⚠️  STATUS: PERLU PERHATIAN — Ada ${FAIL} masalah!${NC}"
else
    echo -e "${RED}${BOLD}  🚨 STATUS: BERBAHAYA — Ada ${FAIL} masalah kritis!${NC}"
fi
echo -e "${CYAN}${BOLD}══════════════════════════════════════════════════${NC}"
echo ""
