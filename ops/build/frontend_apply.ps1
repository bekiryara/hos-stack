param(
    [switch]$Build
)
 
# Frontend apply entrypoint (V1)
# Delegates to canonical script: ops/frontend_refresh.ps1
 
& "$PSScriptRoot\..\frontend_refresh.ps1" @PSBoundParameters
exit $LASTEXITCODE

