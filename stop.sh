#!/bin/bash
# ============================================================
#  KURBAN DIGITAL — Stop & Cleanup Script
#  Penggunaan: ./stop.sh
# ============================================================

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

APP_NAME="kurban-digital"
CONTAINER_NAME="${APP_NAME}-app"

echo ""
echo -e "${BLUE}[STOP]${NC} Menghentikan Kurban Digital..."

if docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
    docker stop "$CONTAINER_NAME"
    echo -e "${GREEN}[✓]${NC} Container dihentikan: $CONTAINER_NAME"
else
    echo -e "${YELLOW}[!]${NC} Container tidak sedang berjalan"
fi

if docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
    docker rm "$CONTAINER_NAME"
    echo -e "${GREEN}[✓]${NC} Container dihapus"
fi

echo ""
echo -e "${GREEN}✅ Kurban Digital berhasil dihentikan.${NC}"
echo ""
echo -e "Untuk menjalankan kembali: ${YELLOW}./deploy.sh${NC}"
echo ""
