.$PSScriptRoot\\_lib.ps1
$docker = Get-DockerCmd

Write-Host "Stopping stack..."
# Include obs/logs profile services as well; otherwise the project network may stay "in use".
& $docker compose --profile obs --profile logs down --remove-orphans
Write-Host "OK."



