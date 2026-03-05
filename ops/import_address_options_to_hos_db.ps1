param(
    [string]$HostManifestsPath = "D:\stack-data\catalog-dataset\out\manifests",
    [switch]$DryRun
)

$ErrorActionPreference = "Stop"

function Normalize-Tr([string]$Raw) {
    if ([string]::IsNullOrWhiteSpace($Raw)) { return "" }
    $s = $Raw.Trim()
    $s = $s.Replace("i̇", "i").Replace("İ", "i")
    $s = $s.ToLowerInvariant()
    $s = $s.Replace("i̇", "i").Replace("İ", "i")
    $s = $s.Replace("ı","i").Replace("ş","s").Replace("ğ","g").Replace("ü","u").Replace("ö","o").Replace("ç","c")
    return ([regex]::Replace($s, "\s+", " ")).Trim()
}

function SqlQuote([string]$s) {
    if ($null -eq $s) { return "NULL" }
    return "'" + $s.Replace("'", "''") + "'"
}

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
Push-Location $repoRoot
try {
    Write-Host "=== HOS ADDRESS IMPORT (DB) ===" -ForegroundColor Cyan
    Write-Host "Repo: $repoRoot" -ForegroundColor Gray
    Write-Host "Host manifests: $HostManifestsPath" -ForegroundColor Gray

    $districtPath = Join-Path $HostManifestsPath "options\districts.tr.json"
    $neighborhoodPath = Join-Path $HostManifestsPath "options\neighborhoods.tr.json"
    if (-not (Test-Path $districtPath)) { throw "Missing: $districtPath" }
    if (-not (Test-Path $neighborhoodPath)) { throw "Missing: $neighborhoodPath" }

    $districtObj = Get-Content -Path $districtPath -Raw | ConvertFrom-Json
    $neighborhoodObj = Get-Content -Path $neighborhoodPath -Raw | ConvertFrom-Json

    $citiesByNorm = @{}
    $districtByKey = @{}
    $neighByKey = @{}

    foreach ($cp in $districtObj.PSObject.Properties) {
        $city = [string]$cp.Name
        $cityNorm = Normalize-Tr $city
        if (-not $cityNorm) { continue }
        if (-not $citiesByNorm.ContainsKey($cityNorm)) { $citiesByNorm[$cityNorm] = $city.Trim() }
        foreach ($d in @($cp.Value)) {
            $district = [string]$d
            if ([string]::IsNullOrWhiteSpace($district)) { continue }
            $district = $district.Trim()
            $districtNorm = Normalize-Tr $district
            if (-not $districtNorm) { continue }
            $dk = "$cityNorm|$districtNorm"
            if (-not $districtByKey.ContainsKey($dk)) {
                $districtByKey[$dk] = @{
                    city_norm = $cityNorm
                    name = $district
                    norm_name = $districtNorm
                }
            }
        }
    }

    foreach ($np in $neighborhoodObj.PSObject.Properties) {
        $compound = [string]$np.Name
        $parts = $compound.Split("|", 2)
        if ($parts.Count -ne 2) { continue }
        $cityNorm = Normalize-Tr $parts[0]
        $districtNorm = Normalize-Tr $parts[1]
        if (-not $cityNorm -or -not $districtNorm) { continue }
        $dk = "$cityNorm|$districtNorm"
        if (-not $districtByKey.ContainsKey($dk)) { continue }

        foreach ($n in @($np.Value)) {
            $name = [string]$n
            if ([string]::IsNullOrWhiteSpace($name)) { continue }
            $name = $name.Trim()
            $nn = Normalize-Tr $name
            if (-not $nn) { continue }
            $nk = "$cityNorm|$districtNorm|$nn"
            if (-not $neighByKey.ContainsKey($nk)) {
                $neighByKey[$nk] = @{
                    city_norm = $cityNorm
                    district_norm = $districtNorm
                    name = $name
                    norm_name = $nn
                }
            }
        }
    }

    Write-Host ("Cities: " + $citiesByNorm.Count) -ForegroundColor Gray
    Write-Host ("Districts: " + $districtByKey.Count) -ForegroundColor Gray
    Write-Host ("Neighborhoods: " + $neighByKey.Count) -ForegroundColor Gray

    if ($DryRun) {
        Write-Host "Dry-run only. No DB changes applied." -ForegroundColor Yellow
        return
    }

    $checksumA = (Get-FileHash -Path $districtPath -Algorithm SHA256).Hash.ToLowerInvariant()
    $checksumB = (Get-FileHash -Path $neighborhoodPath -Algorithm SHA256).Hash.ToLowerInvariant()
    $checksum = "$checksumA|$checksumB"

    $sqlLines = New-Object System.Collections.Generic.List[string]
    $sqlLines.Add("\set ON_ERROR_STOP on")
    $sqlLines.Add("begin;")
    $sqlLines.Add("truncate table address_neighborhoods, address_districts, address_cities restart identity cascade;")
    $sqlLines.Add("create temp table tmp_city(name text, norm_name text);")
    $sqlLines.Add("create temp table tmp_district(city_norm text, name text, norm_name text);")
    $sqlLines.Add("create temp table tmp_neighborhood(city_norm text, district_norm text, name text, norm_name text);")

    $cityVals = New-Object System.Collections.Generic.List[string]
    foreach ($k in ($citiesByNorm.Keys | Sort-Object)) {
        $cityVals.Add("(" + (SqlQuote $citiesByNorm[$k]) + "," + (SqlQuote $k) + ")")
    }
    for ($i = 0; $i -lt $cityVals.Count; $i += 500) {
        $end = [Math]::Min($i + 499, $cityVals.Count - 1)
        $chunk = $cityVals[$i..$end] -join ","
        $sqlLines.Add("insert into tmp_city(name,norm_name) values $chunk;")
    }

    $districtVals = New-Object System.Collections.Generic.List[string]
    foreach ($k in ($districtByKey.Keys | Sort-Object)) {
        $r = $districtByKey[$k]
        $districtVals.Add("(" + (SqlQuote $r.city_norm) + "," + (SqlQuote $r.name) + "," + (SqlQuote $r.norm_name) + ")")
    }
    for ($i = 0; $i -lt $districtVals.Count; $i += 500) {
        $end = [Math]::Min($i + 499, $districtVals.Count - 1)
        $chunk = $districtVals[$i..$end] -join ","
        $sqlLines.Add("insert into tmp_district(city_norm,name,norm_name) values $chunk;")
    }

    $neighVals = New-Object System.Collections.Generic.List[string]
    foreach ($k in ($neighByKey.Keys | Sort-Object)) {
        $r = $neighByKey[$k]
        $neighVals.Add("(" + (SqlQuote $r.city_norm) + "," + (SqlQuote $r.district_norm) + "," + (SqlQuote $r.name) + "," + (SqlQuote $r.norm_name) + ")")
    }
    for ($i = 0; $i -lt $neighVals.Count; $i += 1000) {
        $end = [Math]::Min($i + 999, $neighVals.Count - 1)
        $chunk = $neighVals[$i..$end] -join ","
        $sqlLines.Add("insert into tmp_neighborhood(city_norm,district_norm,name,norm_name) values $chunk;")
    }

    $sqlLines.Add("insert into address_cities(name,norm_name,created_at,updated_at) select name,norm_name,now(),now() from tmp_city order by name;")
    $sqlLines.Add("insert into address_districts(city_id,name,norm_name,created_at,updated_at) select c.id,d.name,d.norm_name,now(),now() from tmp_district d join address_cities c on c.norm_name=d.city_norm order by c.id,d.name;")
    $sqlLines.Add("insert into address_neighborhoods(district_id,name,norm_name,created_at,updated_at) select distinct on (d.id,n.norm_name) d.id,n.name,n.norm_name,now(),now() from tmp_neighborhood n join address_cities c on c.norm_name=n.city_norm join address_districts d on d.city_id=c.id and d.norm_name=n.district_norm order by d.id,n.norm_name,n.name;")
    $hostPathEscaped = $HostManifestsPath.Replace("'", "''")
    $checksumEscaped = $checksum.Replace("'", "''")
    $sqlLines.Add("insert into address_manifest_versions(source,manifests_path,checksum_sha256,counts_json,loaded_at,created_at,updated_at) values ('stack-data','$hostPathEscaped','$checksumEscaped', jsonb_build_object('cities',(select count(*) from address_cities),'districts',(select count(*) from address_districts),'neighborhoods',(select count(*) from address_neighborhoods)), now(), now(), now());")
    $sqlLines.Add("commit;")

    $sql = $sqlLines -join "`n"

    $tmp = Join-Path $env:TEMP ("hos_address_import_" + [guid]::NewGuid().ToString("N") + ".sql")
    Set-Content -Path $tmp -Value $sql -Encoding utf8
    try {
        Get-Content -Path $tmp -Raw | docker compose exec -T hos-db psql -U hos -d hos -f -
        if ($LASTEXITCODE -ne 0) { throw "psql import failed (exit=$LASTEXITCODE)" }
    } finally {
        Remove-Item -Path $tmp -Force -ErrorAction SilentlyContinue
    }

    Write-Host "PASS: HOS address dictionary imported." -ForegroundColor Green
} finally {
    Pop-Location
}
