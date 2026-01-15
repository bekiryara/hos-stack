# ops_env.ps1 - Environment Variable Initialization Helper
# Provides default values for observability and API URLs
# PowerShell 5.1 compatible

# Initialize environment variables with defaults (only if missing)
function Initialize-OpsEnv {
    if ([string]::IsNullOrEmpty($env:PAZAR_BASE_URL)) {
        $env:PAZAR_BASE_URL = "http://localhost:8080"
    }
    
    if ([string]::IsNullOrEmpty($env:HOS_BASE_URL)) {
        $env:HOS_BASE_URL = "http://localhost:3000"
    }
    
    if ([string]::IsNullOrEmpty($env:PROM_URL)) {
        $env:PROM_URL = "http://localhost:9090"
    }
    
    if ([string]::IsNullOrEmpty($env:ALERT_URL)) {
        $env:ALERT_URL = "http://localhost:9093"
    }
}

# Get Pazar base URL (with default)
function Get-PazarBaseUrl {
    Initialize-OpsEnv
    return $env:PAZAR_BASE_URL
}

# Get H-OS base URL (with default)
function Get-HosBaseUrl {
    Initialize-OpsEnv
    return $env:HOS_BASE_URL
}

# Get Prometheus URL (with default)
function Get-PrometheusUrl {
    Initialize-OpsEnv
    return $env:PROM_URL
}

# Get Alertmanager URL (with default)
function Get-AlertmanagerUrl {
    Initialize-OpsEnv
    return $env:ALERT_URL
}

