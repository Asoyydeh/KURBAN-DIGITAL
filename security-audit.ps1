$ErrorActionPreference = "Continue"

$Host.UI.RawUI.ForegroundColor = "Cyan"
Write-Host "`n=================================================="
Write-Host "    KURBAN DIGITAL - SECURITY AUDIT REPORT        "
Write-Host "==================================================`n"
$Host.UI.RawUI.ForegroundColor = "White"

$APP_NAME = "kurban-digital"
$IMAGE_TAG = "$APP_NAME`:latest"
$CONTAINER_NAME = "$APP_NAME-app"

$PASS = 0; $FAIL = 0; $WARN = 0

function Check-Pass([string]$msg) { Write-Host "  [PASS] $msg" -ForegroundColor Green; $script:PASS++ }
function Check-Fail([string]$msg) { Write-Host "  [FAIL] $msg" -ForegroundColor Red; $script:FAIL++ }
function Check-Warn([string]$msg) { Write-Host "  [WARN] $msg" -ForegroundColor Yellow; $script:WARN++ }
function Section([string]$msg)    { Write-Host "`n▶ $msg" -ForegroundColor Cyan }

Section "A. IMAGE DOCKER"
$imageExists = docker image inspect $IMAGE_TAG 2>$null
if ($LASTEXITCODE -eq 0) {
    Check-Pass "Image $IMAGE_TAG ditemukan"
} else {
    Check-Fail "Image $IMAGE_TAG tidak ditemukan! Jalankan npm run docker:deploy"
    exit 1
}

Section "B. SOURCE CODE PROTECTION (dalam image)"
$srcCheck = docker run --rm --entrypoint="" $IMAGE_TAG sh -c "ls /app/src 2>/dev/null || echo NOT_FOUND"
if ($srcCheck -match "NOT_FOUND") {
    Check-Pass "folder src/ TIDAK ada di image production ✓"
} else {
    Check-Fail "BAHAYA: folder src/ TERDETEKSI di dalam image!"
}

$envCheck = docker run --rm --entrypoint="" $IMAGE_TAG sh -c "ls /app/.env 2>/dev/null || echo NOT_FOUND"
if ($envCheck -match "NOT_FOUND") {
    Check-Pass ".env tidak ada di image ✓"
} else {
    Check-Fail "BAHAYA: file .env ada di dalam image!"
}

Section "C. CONTAINER RUNTIME SECURITY"
$running = docker ps --format "{{.Names}}" | Select-String "^$CONTAINER_NAME$"
if ($running) {
    $uid = docker exec $CONTAINER_NAME id -u
    if ($uid -ne "0" -and $uid -ne "") {
        Check-Pass "Berjalan sebagai non-root (UID: $uid) ✓"
    } else {
        Check-Fail "Container berjalan sebagai root! Ini berbahaya."
    }

    $ro = docker inspect $CONTAINER_NAME --format="{{.HostConfig.ReadonlyRootfs}}"
    if ($ro -eq "true") {
        Check-Pass "Filesystem read-only aktif ✓"
    } else {
        Check-Warn "Filesystem tidak dalam mode read-only"
    }
} else {
    Check-Warn "Container $CONTAINER_NAME tidak berjalan, tidak bisa cek runtime."
}

Write-Host "`n==================================================" -ForegroundColor Cyan
$TOTAL = $PASS + $FAIL + $WARN
Write-Host "  HASIL AUDIT: $TOTAL checks"
Write-Host "  [PASS] : $PASS" -ForegroundColor Green
Write-Host "  [WARN] : $WARN" -ForegroundColor Yellow
Write-Host "  [FAIL] : $FAIL" -ForegroundColor Red
Write-Host ""
if ($FAIL -eq 0) {
    Write-Host "  [OK] STATUS: AMAN - Tidak ada masalah kritis!" -ForegroundColor Green
} else {
    Write-Host "  [ALERT] STATUS: BERBAHAYA - Ada $FAIL masalah kritis!" -ForegroundColor Red
}
Write-Host "==================================================`n" -ForegroundColor Cyan
