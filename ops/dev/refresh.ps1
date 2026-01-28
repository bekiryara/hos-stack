param(
    [switch]$FrontendOnly,
    [switch]$All
)
 
# Dev refresh entrypoint (V1)
# Delegates to canonical script: ops/dev_refresh.ps1
 
& "$PSScriptRoot\..\dev_refresh.ps1" @PSBoundParameters
exit $LASTEXITCODE

