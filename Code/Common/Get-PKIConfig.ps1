function Get-PKIConfig {
    <#
    .SYNOPSIS
    Retrieves or creates PKI audit configuration settings.

    .DESCRIPTION
    Manages configuration settings for the PKI audit toolkit. Settings are stored in a JSON file
    and can be customized by the user.

    .EXAMPLE
    $config = Get-PKIConfig
    #>
    [CmdletBinding()]
    param()

    $configPath = Join-Path $PSScriptRoot "../../config/settings.json"
    
    # Default configuration
    $defaultConfig = @{
        # Logging settings
        LogPath = "PKIAudit.log"
        LogLevel = "Info"  # Debug, Info, Warning, Error
        EnableConsole = $true
        EnableFile = $true

        # Export settings
        DefaultExportPath = "exports"
        JsonIndentation = 2
        MaxJsonDepth = 10
        
        # Performance settings
        PageSize = 50000
        MaxParallelism = 4
        
        # Feature flags
        EnableVerboseProgress = $true
        EnableMetrics = $true
        
        # Audit settings
        DefaultTemplateFilters = @(
            "UserAuthentication",
            "ClientAuthentication",
            "SmartcardLogon"
        )

        # Event monitoring settings
        EventAnalysis = @{
            MaxCertRequestsPerHour = 100
            MaxFailedKerberosPerUser = 5
            BusinessHoursStart = 8  # 8 AM
            BusinessHoursEnd = 18   # 6 PM
            AlertThresholds = @{
                CertRequests = 50
                FailedAuth = 3
                OutOfHours = 10
            }
        }

        # Health check settings
        HealthCheck = @{
            CheckIntervals = @{
                Infrastructure = 300  # 5 minutes
                Compliance = 3600     # 1 hour
                Security = 1800       # 30 minutes
            }
            Thresholds = @{
                CRLExpirationWarning = 168   # 7 days
                CertExpirationWarning = 720  # 30 days
                MaxExpiredCerts = 5
                MinKeyLength = 2048
            }
            SecurityBaseline = @{
                RequiredTLSVersion = "1.2"
                RequiredCipherSuites = @(
                    "TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384",
                    "TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256"
                )
                RequiredAuditCategories = @(
                    "Security",
                    "System",
                    "Application"
                )
            }
            ComplianceRules = @{
                RequireCAApproval = $true
                RequireStrongCrypto = $true
                EnforceTemplateACLs = $true
                RequireSecureRenewal = $true
            }
        }
    }

    try {
        # Create config directory if it doesn't exist
        $configDir = Split-Path $configPath -Parent
        if (-not (Test-Path $configDir)) {
            New-Item -ItemType Directory -Path $configDir -Force | Out-Null
        }

        # Load existing config or create new one
        if (Test-Path $configPath) {
            $config = Get-Content $configPath -Raw | ConvertFrom-Json
            
            # Merge with defaults to ensure all properties exist
            $mergedConfig = @{}
            foreach ($key in $defaultConfig.Keys) {
                $mergedConfig[$key] = if ($config.PSObject.Properties.Name -contains $key) {
                    $config.$key
                } else {
                    $defaultConfig[$key]
                }
            }
            
            return $mergedConfig
        } else {
            # Save default config
            $defaultConfig | ConvertTo-Json -Depth 10 | Out-File $configPath -Encoding UTF8
            return $defaultConfig
        }
    }
    catch {
        Write-Warning "Failed to load/create config, using defaults: $_"
        return $defaultConfig
    }
}

function Set-PKIConfig {
    <#
    .SYNOPSIS
    Updates PKI audit configuration settings.

    .PARAMETER Settings
    Hashtable of settings to update.

    .EXAMPLE
    Set-PKIConfig -Settings @{ 
        LogLevel = "Debug"
        EventAnalysis = @{
            MaxCertRequestsPerHour = 200
        }
    }
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [Hashtable]
        $Settings
    )

    try {
        $config = Get-PKIConfig
        
        # Recursively update settings
        function Update-ConfigValue {
            param($Target, $Source)
            
            foreach ($key in $Source.Keys) {
                if ($Source[$key] -is [Hashtable] -and $Target.ContainsKey($key)) {
                    Update-ConfigValue -Target $Target[$key] -Source $Source[$key]
                }
                else {
                    $Target[$key] = $Source[$key]
                }
            }
        }

        Update-ConfigValue -Target $config -Source $Settings

        $configPath = Join-Path $PSScriptRoot "../../config/settings.json"
        $config | ConvertTo-Json -Depth 10 | Out-File $configPath -Encoding UTF8
        Write-PKILog -Message "Configuration updated successfully" -Level Info -Component "Config"
        return $true
    }
    catch {
        Write-PKILog -Message "Failed to update configuration: $_" -Level Error -Component "Config"
        return $false
    }
} 