# env_preflight.ps1 - Ortam on kontrolu (node, npm, docker, docker compose)
# Her biri icin PASS/FAIL + net aksiyon mesaji; herhangi biri FAIL ise exit 1.

$ErrorActionPreference = "Stop"
$allPass = $true

Write-Host "=== ENV PREFLIGHT ===" -ForegroundColor Cyan

# 1) node --version
Write-Host "`n[1] node --version" -ForegroundColor Yellow
try {
    $nodeVer = node --version 2>&1
    if ($LASTEXITCODE -ne 0) { throw "node exited non-zero" }
    Write-Host "PASS: node $nodeVer" -ForegroundColor Green
} catch {
    Write-Host "FAIL: node bulunamadi veya calismadi" -ForegroundColor Red
    Write-Host "Aksiyon: Node.js yukleyin (https://nodejs.org/) veya PATH'e ekleyin." -ForegroundColor Red
    $allPass = $false
}

# 2) npm --version
Write-Host "`n[2] npm --version" -ForegroundColor Yellow
try {
    $npmVer = npm --version 2>&1
    if ($LASTEXITCODE -ne 0) { throw "npm exited non-zero" }
    Write-Host "PASS: npm $npmVer" -ForegroundColor Green
} catch {
    Write-Host "FAIL: npm bulunamadi veya calismadi" -ForegroundColor Red
    Write-Host "Aksiyon: Node.js ile birlikte gelen npm kullanin veya 'npm install -g npm' ile guncelleyin." -ForegroundColor Red
    $allPass = $false
}

# 3) docker version
Write-Host "`n[3] docker version" -ForegroundColor Yellow
try {
    $dockerOut = docker version 2>&1
    if ($LASTEXITCODE -ne 0) { throw "docker exited non-zero" }
    Write-Host "PASS: docker version calisti" -ForegroundColor Green
} catch {
    Write-Host "FAIL: docker bulunamadi veya calismadi (pipe erisim engelli olabilir)" -ForegroundColor Red
    Write-Host "Aksiyon: Docker Desktop yukleyin ve calistirin (https://www.docker.com/products/docker-desktop/)." -ForegroundColor Red
    $allPass = $false
}

# 4) docker compose version
Write-Host "`n[4] docker compose version" -ForegroundColor Yellow
try {
    $composeOut = docker compose version 2>&1
    if ($LASTEXITCODE -ne 0) { throw "docker compose exited non-zero" }
    Write-Host "PASS: docker compose calisti" -ForegroundColor Green
} catch {
    Write-Host "FAIL: docker compose bulunamadi veya calismadi" -ForegroundColor Red
    Write-Host "Aksiyon: Docker Desktop guncel sürümünde 'docker compose' (v2) dahildir; Docker Desktop'i yeniden baslatin." -ForegroundColor Red
    $allPass = $false
}

Write-Host ""
if ($allPass) {
    Write-Host "=== ENV PREFLIGHT: PASS ===" -ForegroundColor Green
    exit 0
} else {
    Write-Host "=== ENV PREFLIGHT: FAIL ===" -ForegroundColor Red
    exit 1
}

