$ErrorActionPreference = "Stop"

# Warna Terminal
$Host.UI.RawUI.ForegroundColor = "Cyan"
Write-Host "`n=================================================="
Write-Host "    KURBAN DIGITAL - PROTECTED DEPLOY        "
Write-Host "    Build + Obfuscate + Docker Secure Run    "
Write-Host "==================================================`n"
$Host.UI.RawUI.ForegroundColor = "White"

$APP_NAME = "kurban-digital"
$IMAGE_TAG = "$APP_NAME`:latest"
$CONTAINER_NAME = "$APP_NAME-app"
$PORT = 8083
if ($env:PORT) { $PORT = $env:PORT }

function Log-Step([string]$msg) { Write-Host "[STEP] $msg" -ForegroundColor Blue }
function Log-Ok([string]$msg)   { Write-Host "[OK] $msg" -ForegroundColor Green }
function Log-Warn([string]$msg) { Write-Host "[WARN] $msg" -ForegroundColor Yellow }
function Log-Err([string]$msg)  { Write-Host "[ERROR] $msg" -ForegroundColor Red; exit 1 }

# 1. Cek Docker
Log-Step "Memeriksa instalasi Docker..."
if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
    Log-Err "Docker tidak ditemukan! Pastikan Docker Desktop berjalan."
}
$dockerVersion = (docker --version)
Log-Ok "Docker tersedia: $dockerVersion"

# 2. Cek source code
Log-Step "Memverifikasi source code..."
if (-not (Test-Path "src/app.js")) {
    Log-Err "src/app.js tidak ditemukan! Pastikan source code ada."
}
Log-Ok "src/app.js ditemukan"

# 3. Cek .env
Log-Step "Memeriksa konfigurasi environment..."
$ENV_ARGS = @()
if (Test-Path ".env") {
    Log-Ok ".env ditemukan"
    $ENV_ARGS = @("--env-file", ".env")
} else {
    Log-Warn ".env tidak ditemukan. Menggunakan variabel default."
}

# 4. Cleanup old container
Log-Step "Membersihkan container lama..."
$existing = docker ps -a --format "{{.Names}}" | Select-String "^$CONTAINER_NAME$"
if ($existing) {
    docker stop $CONTAINER_NAME | Out-Null
    docker rm $CONTAINER_NAME | Out-Null
    Log-Ok "Container lama dihapus"
} else {
    Log-Ok "Tidak ada container lama"
}

# 5. Build Docker Image
Log-Step "Memulai build Docker (dengan obfuscation)...`n"
$dateStr = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
docker build --no-cache --pull --tag $IMAGE_TAG --label "build.date=$dateStr" --label "build.protected=true" .
if ($LASTEXITCODE -ne 0) {
    Log-Err "Docker build gagal! Silakan cek log di atas."
}
Write-Host ""
Log-Ok "Docker image berhasil dibuat: $IMAGE_TAG"

# 6. Verifikasi Keamanan
Log-Step "Memverifikasi keamanan: memastikan src/ tidak ada di image..."
$srcCheck = docker run --rm --entrypoint="" $IMAGE_TAG sh -c "ls /app/src 2>/dev/null || echo NOT_FOUND"
if ($srcCheck -match "NOT_FOUND") {
    Log-Ok "AMAN: src/ tidak ada di dalam image production"
} else {
    Log-Err "PELANGGARAN KEAMANAN: folder src/ terdeteksi di dalam image!"
}

# 7. Run Container
Log-Step "Menjalankan container dengan security flags..."
$runCmd = @(
    "run", "--detach", "--name", $CONTAINER_NAME, "--publish", "$PORT`:8083", "--restart", "unless-stopped",
    "--read-only", "--security-opt", "no-new-privileges:true", "--cap-drop", "ALL", "--cap-add", "NET_BIND_SERVICE",
    "--memory", "256m", "--cpus", "1.0",
    "--tmpfs", "/tmp:rw,noexec,nosuid,size=50m",
    "--env", "NODE_ENV=production", "--env", "PORT=8083"
)
$runCmd += $ENV_ARGS
$runCmd += $IMAGE_TAG

docker @runCmd

# 8. Wait & Check
Log-Step "Menunggu server siap..."
Start-Sleep -Seconds 5

$Host.UI.RawUI.ForegroundColor = "Green"
Write-Host "`n======================================================"
Write-Host "  [OK] KURBAN DIGITAL BERHASIL DEPLOY!               "
Write-Host "======================================================"
Write-Host "  URL  : http://localhost:$PORT"
Write-Host "  Image: $IMAGE_TAG"
Write-Host "  Container: $CONTAINER_NAME"
Write-Host ""
Write-Host "  Proteksi Aktif:"
Write-Host "      - Source code terobfuscasi"
Write-Host "      - src/ tidak ada di image"
Write-Host "      - Read-only filesystem"
Write-Host "      - No new privileges"
Write-Host "      - All capabilities dropped"
Write-Host "      - Non-root user"
Write-Host "      - Memory limit: 256MB"
Write-Host "======================================================`n"
$Host.UI.RawUI.ForegroundColor = "White"

Write-Host "Untuk melihat log  : docker logs -f $CONTAINER_NAME" -ForegroundColor Yellow
Write-Host "Untuk stop app     : npm run docker:stop" -ForegroundColor Yellow
Write-Host "Untuk audit security: npm run docker:audit" -ForegroundColor Yellow
Write-Host ""
