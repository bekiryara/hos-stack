# worlds_config.ps1 - Canonical Worlds Config Parser
# Parses work/pazar/config/worlds.php without requiring PHP execution
# PowerShell 5.1 compatible, multiline-safe

function Get-WorldsConfig {
    <#
    .SYNOPSIS
    Parses worlds.php config file and returns enabled/disabled world arrays.
    
    .DESCRIPTION
    Extracts enabled and disabled world arrays from PHP config file without
    requiring PHP execution. Handles multiline arrays, comments, trailing commas,
    and whitespace variations.
    
    .PARAMETER WorldsConfigPath
    Path to worlds.php config file (default: work/pazar/config/worlds.php)
    
    .OUTPUTS
    Hashtable with Enabled (string[]) and Disabled (string[]) arrays
    
    .EXAMPLE
    $worlds = Get-WorldsConfig
    $worlds.Enabled  # @('commerce', 'food', 'rentals')
    $worlds.Disabled # @('services', 'real_estate', 'vehicle')
    #>
    param(
        [string]$WorldsConfigPath = "work\pazar\config\worlds.php"
    )
    
    if (-not (Test-Path $WorldsConfigPath)) {
        Write-Error "Worlds config file not found: $WorldsConfigPath"
        return @{
            Enabled = @()
            Disabled = @()
        }
    }
    
    $content = Get-Content $WorldsConfigPath -Raw
    
    # Remove single-line comments (// ...)
    $content = $content -replace '//.*?(\r?\n|$)', ''
    
    # Remove multi-line comments (/* ... */)
    $content = $content -replace '/\*.*?\*/', ''
    
    # Extract enabled array
    $enabled = @()
    if ($content -match "'enabled'\s*=>\s*\[(.*?)\]") {
        $enabledContent = $matches[1]
        # Extract quoted strings (single or double quotes)
        $enabledMatches = [regex]::Matches($enabledContent, "['""]([a-z0-9_]+)['""]")
        foreach ($match in $enabledMatches) {
            $worldId = $match.Groups[1].Value
            if ($worldId) {
                $enabled += $worldId
            }
        }
    }
    
    # Extract disabled array
    $disabled = @()
    if ($content -match "'disabled'\s*=>\s*\[(.*?)\]") {
        $disabledContent = $matches[1]
        # Extract quoted strings (single or double quotes)
        $disabledMatches = [regex]::Matches($disabledContent, "['""]([a-z0-9_]+)['""]")
        foreach ($match in $disabledMatches) {
            $worldId = $match.Groups[1].Value
            if ($worldId) {
                $disabled += $worldId
            }
        }
    }
    
    return @{
        Enabled = $enabled | Sort-Object
        Disabled = $disabled | Sort-Object
    }
}























