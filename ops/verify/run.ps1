param(
    [ValidateSet('Prototype','Full')]
    [string]$Profile = 'Prototype'
)
 
# Verification entrypoint (V1)
# Delegates to canonical script: ops/ops_run.ps1
 
& "$PSScriptRoot\..\ops_run.ps1" -Profile $Profile
exit $LASTEXITCODE

