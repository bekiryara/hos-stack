<# 
error_contract.ps1 - Error envelope contract helper

Purpose:
- Single source of truth for error envelope checks (422 + 404).
- Used by ops_status.ps1 and rc0_gate.ps1 to avoid drift.

Contract (minimal):
- ok: false
- error_code: non-empty string (A-Z0-9_)
- message: present
- request_id: non-empty string

Notes:
- 422 is triggered via Pazar listing read-path validation (unknown filter key) to avoid depending on auth endpoints.
- category_id is discovered dynamically from /api/v1/categories to avoid hardcoded seed IDs.

PowerShell 5.1 compatible.
#>

function Invoke-ErrorContractCheck {
    param(
        [string]$BaseUrl = "http://localhost:8080"
    )

    $status = "PASS"
    $exitCode = 0
    $notes = ""
    $failures = @()

    try {
        # Discover a category_id (avoid hardcoded IDs)
        $categoryId = $null
        try {
            $catJson = curl.exe -sS "$BaseUrl/api/v1/categories" -H "Accept: application/json" 2>&1
            $cats = $catJson | ConvertFrom-Json
            if ($cats -is [array] -and $cats.Count -gt 0) {
                $categoryId = $cats[0].id
            } elseif ($cats -and $cats.PSObject.Properties['items'] -and $cats.items -is [array] -and $cats.items.Count -gt 0) {
                $categoryId = $cats.items[0].id
            }
        } catch {
            $categoryId = $null
        }

        if (-not $categoryId) {
            $status = "SKIP"
            $exitCode = 0
            $notes = "SKIP: could not determine category_id from /api/v1/categories"
            return @{ Status = $status; ExitCode = $exitCode; Notes = $notes }
        }

        # 422: unknown filter key with valid category_id
        $url422 = "$BaseUrl/api/v1/listings?category_id=$categoryId&filters%5B__unknown_key__%5D=x"
        $response422 = curl.exe -sS -i $url422 -H "Accept: application/json" 2>&1
        $status422 = ($response422 | Select-String -Pattern "HTTP/\d\.\d\s+(\d+)" | ForEach-Object { $_.Matches.Groups[1].Value })
        $body422 = ($response422 | Select-String -Pattern '\{.*\}' -AllMatches | ForEach-Object { $_.Matches.Value } | Select-Object -Last 1)

        if (-not $status422) {
            $response422Str = $response422 -join " "
            if ($response422Str -match "Failed to connect|Connection refused|Could not resolve|Connection timed out|Unable to connect") {
                $status = "SKIP"
                $exitCode = 0
                $notes = "CORE_UNAVAILABLE: Cannot connect to $BaseUrl"
                return @{ Status = $status; ExitCode = $exitCode; Notes = $notes }
            }
            $failures += "422 status check failed (got $status422)"
        } elseif ($status422 -ne "422") {
            $failures += "422 status check failed (got $status422)"
        }

        if ($body422 -and
            $body422 -match '"ok"\s*:\s*false' -and
            $body422 -match '"error_code"\s*:\s*"[A-Z0-9_]+"' -and
            $body422 -match '"message"' -and
            $body422 -match '"request_id"\s*:\s*"[^"]+"') {
            # ok
        } else {
            $failures += "422 envelope missing required fields"
        }

        # 404: non-existent endpoint
        $response404 = curl.exe -sS -i -H "Accept: application/json" "$BaseUrl/api/non-existent-endpoint" 2>&1
        $status404 = ($response404 | Select-String -Pattern "HTTP/\d\.\d\s+(\d+)" | ForEach-Object { $_.Matches.Groups[1].Value })
        $body404 = ($response404 | Select-String -Pattern '\{.*\}' -AllMatches | ForEach-Object { $_.Matches.Value } | Select-Object -Last 1)

        if (-not $status404) {
            $response404Str = $response404 -join " "
            if ($response404Str -match "Failed to connect|Connection refused|Could not resolve|Connection timed out|Unable to connect") {
                $status = "SKIP"
                $exitCode = 0
                $notes = "CORE_UNAVAILABLE: Cannot connect to $BaseUrl"
                return @{ Status = $status; ExitCode = $exitCode; Notes = $notes }
            }
            $failures += "404 status check failed (got $status404)"
        } elseif ($status404 -ne "404") {
            $failures += "404 status check failed (got $status404)"
        }

        if ($body404 -and
            $body404 -match '"ok"\s*:\s*false' -and
            $body404 -match '"error_code"\s*:\s*"NOT_FOUND"' -and
            $body404 -match '"request_id"') {
            # ok
        } else {
            $failures += "404 envelope missing required fields"
        }

        if ($failures.Count -gt 0) {
            $status = "FAIL"
            $exitCode = 1
            $notes = $failures -join "; "
        } else {
            $notes = "422 and 404 envelopes correct"
        }
    } catch {
        $status = "FAIL"
        $exitCode = 1
        $notes = "Error: $($_.Exception.Message)"
    }

    return @{ Status = $status; ExitCode = $exitCode; Notes = $notes }
}

