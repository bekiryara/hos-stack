param(
    [string]$BaseUrl = "https://turkiyeapi.dev/api/v1",
    [int]$PageSize = 1000,
    [string]$OutRoot = ""
)

$ErrorActionPreference = "Stop"

function Resolve-OutRoot {
    param([string]$raw)
    if ($raw -and $raw.Trim()) {
        return $raw.Trim()
    }
    if ($env:CATALOG_MANIFESTS_HOST_PATH -and $env:CATALOG_MANIFESTS_HOST_PATH.Trim()) {
        return $env:CATALOG_MANIFESTS_HOST_PATH.Trim()
    }
    return "D:\stack-data\catalog-dataset\out\manifests"
}

function Get-ApiItems {
    param(
        [string]$Endpoint,
        [int]$Limit = 1000
    )
    $all = @()
    $offset = 0
    for ($i = 0; $i -lt 1000; $i++) {
        $sep = "?"
        if ($Endpoint.Contains("?")) { $sep = "&" }
        $url = "{0}{1}limit={2}&offset={3}" -f $Endpoint, $sep, $Limit, $offset
        $resp = Invoke-RestMethod -Method Get -Uri $url -TimeoutSec 45
        $items = @()

        if ($resp -is [System.Array]) {
            $items = @($resp)
        } elseif ($resp -and $resp.PSObject.Properties['data']) {
            $items = @($resp.data)
        } elseif ($resp -and $resp.PSObject.Properties['items']) {
            $items = @($resp.items)
        } elseif ($resp -and $resp.PSObject.Properties['results']) {
            $items = @($resp.results)
        } else {
            $items = @()
        }

        if ($items.Count -eq 0) {
            break
        }

        $all += $items
        if ($items.Count -lt $Limit) {
            break
        }
        $offset += $Limit
    }
    return ,$all
}

function Pick-Field {
    param(
        $Obj,
        [string[]]$Names
    )
    foreach ($n in $Names) {
        if ($Obj -and $Obj.PSObject.Properties[$n]) {
            $v = [string]$Obj.$n
            if ($v -and $v.Trim()) { return $v.Trim() }
        }
    }
    return ""
}

function Add-UniqueToMapList {
    param(
        [hashtable]$Map,
        [string]$Key,
        [string]$Value
    )
    if (-not $Key -or -not $Value) { return }
    if (-not $Map.ContainsKey($Key)) {
        $Map[$Key] = New-Object System.Collections.Generic.List[string]
    }
    if (-not $Map[$Key].Contains($Value)) {
        $Map[$Key].Add($Value)
    }
}

$resolvedRoot = Resolve-OutRoot -raw $OutRoot
$optionsDir = Join-Path $resolvedRoot "options"
New-Item -ItemType Directory -Force -Path $optionsDir | Out-Null

$districtEndpoint = "{0}/districts" -f $BaseUrl.TrimEnd("/")
$neighborhoodEndpoint = "{0}/neighborhoods" -f $BaseUrl.TrimEnd("/")

Write-Host "Fetching districts from: $districtEndpoint" -ForegroundColor Cyan
$districtItems = Get-ApiItems -Endpoint $districtEndpoint -Limit $PageSize
Write-Host ("Fetched districts: {0}" -f $districtItems.Count) -ForegroundColor Gray

Write-Host "Fetching neighborhoods from: $neighborhoodEndpoint" -ForegroundColor Cyan
$neighborhoodItems = Get-ApiItems -Endpoint $neighborhoodEndpoint -Limit $PageSize
Write-Host ("Fetched neighborhoods: {0}" -f $neighborhoodItems.Count) -ForegroundColor Gray

$districtsByCity = @{}
foreach ($row in $districtItems) {
    $city = Pick-Field -Obj $row -Names @("province", "city", "provinceName", "province_name")
    $district = Pick-Field -Obj $row -Names @("name", "district", "districtName", "district_name")
    Add-UniqueToMapList -Map $districtsByCity -Key $city -Value $district
}

$neighborhoodsByCityDistrict = @{}
foreach ($row in $neighborhoodItems) {
    $city = Pick-Field -Obj $row -Names @("province", "city", "provinceName", "province_name")
    $district = Pick-Field -Obj $row -Names @("district", "districtName", "district_name")
    $neighborhood = Pick-Field -Obj $row -Names @("name", "neighborhood", "neighbourhood")
    if (-not $city -or -not $district -or -not $neighborhood) { continue }
    $key = "$city|$district"
    Add-UniqueToMapList -Map $neighborhoodsByCityDistrict -Key $key -Value $neighborhood
}

$orderedDistricts = [ordered]@{}
$districtKeys = @($districtsByCity.Keys | Sort-Object)
foreach ($city in $districtKeys) {
    $orderedDistricts[$city] = @($districtsByCity[$city] | Sort-Object)
}

$orderedNeighborhoods = [ordered]@{}
$neighborhoodKeys = @($neighborhoodsByCityDistrict.Keys | Sort-Object)
foreach ($k in $neighborhoodKeys) {
    $orderedNeighborhoods[$k] = @($neighborhoodsByCityDistrict[$k] | Sort-Object)
}

$districtsPath = Join-Path $optionsDir "districts.tr.json"
$neighborhoodsPath = Join-Path $optionsDir "neighborhoods.tr.json"

Set-Content -Path $districtsPath -Value ($orderedDistricts | ConvertTo-Json -Depth 6) -Encoding utf8
Set-Content -Path $neighborhoodsPath -Value ($orderedNeighborhoods | ConvertTo-Json -Depth 6) -Encoding utf8

Write-Host "Wrote: $districtsPath" -ForegroundColor Green
Write-Host "Wrote: $neighborhoodsPath" -ForegroundColor Green
Write-Host ("Cities in districts map: {0}" -f $orderedDistricts.Count) -ForegroundColor Gray
Write-Host ("City|District keys in neighborhoods map: {0}" -f $orderedNeighborhoods.Count) -ForegroundColor Gray
