# Shared helpers for ops scripts (PowerShell 5.1 compatible)

$ErrorActionPreference = "Stop"

function Get-DockerCmd {
  $cmd = Get-Command docker -ErrorAction SilentlyContinue
  if ($cmd) { return "docker" }

  $fallback = "C:\Program Files\Docker\Docker\resources\bin\docker.exe"
  if (Test-Path $fallback) { return $fallback }

  throw "docker komutu bulunamadı. Docker Desktop açık mı ve PATH düzgün mü?"
}

function Load-EnvFile {
  param([string]$Path)
  if (-not (Test-Path $Path)) { return }
  Get-Content $Path | ForEach-Object {
    if ($_ -match '^\s*$' -or $_ -match '^\s*#') { return }
    $pair = $_.Split('=', 2)
    if ($pair.Length -ne 2) { return }
    $key = $pair[0].Trim()
    $val = $pair[1]
    if ($key -and -not [Environment]::GetEnvironmentVariable($key)) {
      [Environment]::SetEnvironmentVariable($key, $val)
    }
  }
}

function Read-TextFile {
  param([string]$Path)
  if (-not (Test-Path $Path)) { return $null }
  return (Get-Content $Path -Raw).Trim()
}


