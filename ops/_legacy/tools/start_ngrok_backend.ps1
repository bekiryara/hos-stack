# ngrok ile Backend'i Public'e Aç
# Kullanım: .\ops\_legacy\legacy.ps1 ngrok-backend

Write-Host "`n=== NGROK BACKEND TUNNEL ===" -ForegroundColor Cyan
Write-Host "`nBu script local backend'i (localhost:8080) public'e açar" -ForegroundColor Yellow
Write-Host "Böylece telefondan/başka bilgisayardan test edebilirsin" -ForegroundColor Yellow

# ngrok kontrolü
$ngrokPath = Get-Command ngrok -ErrorAction SilentlyContinue
if (-not $ngrokPath) {
    Write-Host "`n[FAIL] ngrok bulunamadi" -ForegroundColor Red
    Write-Host "`nYükleme:" -ForegroundColor Yellow
    Write-Host "  1. https://ngrok.com/download adresinden indir" -ForegroundColor White
    Write-Host "  2. PATH'e ekle veya bu klasöre kopyala" -ForegroundColor White
    Write-Host "  3. ngrok.com'da ücretsiz hesap oluştur" -ForegroundColor White
    Write-Host "  4. ngrok authtoken <token> komutu ile token'ı ayarla" -ForegroundColor White
    exit 1
}

Write-Host "`n[PASS] ngrok bulundu" -ForegroundColor Green

# Backend port kontrolü
$backendPort = 8080
Write-Host "`nBackend port: $backendPort" -ForegroundColor Cyan

# ngrok'u başlat
Write-Host "`nStarting ngrok tunnel..." -ForegroundColor Yellow
Write-Host "  (Ctrl+C ile durdurabilirsin)" -ForegroundColor Gray
Write-Host ""

# ngrok'u arka planda başlat ve URL'yi yakala
$ngrokProcess = Start-Process -FilePath "ngrok" -ArgumentList "http", $backendPort -PassThru -NoNewWindow

# ngrok API'den URL'yi al (birkaç saniye bekle)
Start-Sleep -Seconds 3

try {
    $ngrokApi = Invoke-RestMethod -Uri "http://localhost:4040/api/tunnels" -ErrorAction Stop
    $publicUrl = $ngrokApi.tunnels[0].public_url
    
    Write-Host "`n[PASS] BACKEND PUBLIC URL:" -ForegroundColor Green
    Write-Host "  $publicUrl" -ForegroundColor Cyan -BackgroundColor Black
    Write-Host "`nKULLANIM:" -ForegroundColor Yellow
    Write-Host "  1. Frontend'de VITE_API_BASE_URL=$publicUrl ayarla" -ForegroundColor White
    Write-Host "  2. Frontend'i yeniden build et" -ForegroundColor White
    Write-Host "  3. Telefondan/başka bilgisayardan test et" -ForegroundColor White
    Write-Host "`nNOT:" -ForegroundColor Red
    Write-Host "  - ngrok'u kapatırsan URL değişir" -ForegroundColor White
    Write-Host "  - Ücretsiz plan: 2 saat sonra timeout" -ForegroundColor White
    Write-Host "  - Bu sadece test için, production için backend deploy et" -ForegroundColor White
    Write-Host "`nDurdurmak icin: Ctrl+C" -ForegroundColor Yellow
    
    # Process'i bekle
    $ngrokProcess.WaitForExit()
} catch {
    Write-Host "`n[FAIL] ngrok API'ye baglanilamadi" -ForegroundColor Red
    Write-Host "  ngrok çalışıyor mu kontrol et" -ForegroundColor Yellow
    if ($ngrokProcess) {
        Stop-Process -Id $ngrokProcess.Id -Force -ErrorAction SilentlyContinue
    }
    exit 1
}

