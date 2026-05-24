$APP_NAME = "kurban-digital"
$CONTAINER_NAME = "$APP_NAME-app"

Write-Host "`n[STOP] Menghentikan Kurban Digital..." -ForegroundColor Blue

$existing = docker ps -a --format "{{.Names}}" | Select-String "^$CONTAINER_NAME$"
if ($existing) {
    $running = docker ps --format "{{.Names}}" | Select-String "^$CONTAINER_NAME$"
    if ($running) {
        docker stop $CONTAINER_NAME | Out-Null
        Write-Host "[OK] Container dihentikan: $CONTAINER_NAME" -ForegroundColor Green
    }
    docker rm $CONTAINER_NAME | Out-Null
    Write-Host "[OK] Container dihapus" -ForegroundColor Green
} else {
    Write-Host "[WARN] Container tidak ditemukan." -ForegroundColor Yellow
}

Write-Host "`n[OK] Kurban Digital berhasil dihentikan." -ForegroundColor Green
Write-Host "Untuk menjalankan kembali: npm run docker:deploy`n" -ForegroundColor Yellow
