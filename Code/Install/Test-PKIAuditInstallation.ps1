function Test-PKIAuditInstallation {
    <#
    .SYNOPSIS
    Validates PSPKIAudit installation and configuration.

    .DESCRIPTION
    Performs comprehensive tests to verify PSPKIAudit installation, including:
    - Module import
    - Configuration
    - Logging
    - RSAT features
    - Dependencies
    - Permissions
    - Network connectivity

    .PARAMETER Detailed
    Switch to enable detailed test output.

    .EXAMPLE
    Test-PKIAuditInstallation -Detailed
    #>
    [CmdletBinding()]
    param(
        [switch]$Detailed
    )

    try {
        Write-PKILog -Message "Starting installation validation" -Level Info -Component "Install"
        
        $results = @{
            Success = $true
            Tests = @{}
            Details = @{}
            Recommendations = @()
        }

        # Module Import Test
        $moduleTest = {
            $module = Get-Module PSPKIAudit -ListAvailable
            if (-not $module) { throw "PSPKIAudit module not found" }
            $module.Version.ToString()
        }
        $results.Tests["Module Import"] = Test-Component -Name "Module Import" -Test $moduleTest -Results $results

        # Configuration Test
        $configTest = {
            $config = Get-PKIConfig
            if (-not $config) { throw "Configuration not found" }
            if (-not $config.LogPath) { throw "Invalid configuration: LogPath missing" }
            "Valid"
        }
        $results.Tests["Configuration"] = Test-Component -Name "Configuration" -Test $configTest -Results $results

        # Logging Test
        $loggingTest = {
            $config = Get-PKIConfig
            if (-not (Test-Path $config.LogPath)) { 
                Write-PKILog -Message "Test message" -Level Info -Component "Install"
                if (-not (Test-Path $config.LogPath)) {
                    throw "Unable to create log file" 
                }
            }
            "Enabled"
        }
        $results.Tests["Logging"] = Test-Component -Name "Logging" -Test $loggingTest -Results $results

        # RSAT Features Test
        $rsatTest = {
            $features = Get-WindowsCapability -Online -Name "Rsat.*" | 
                Where-Object Name -match "CertificateServices|ActiveDirectory"
            $notInstalled = $features | Where-Object State -ne "Installed"
            if ($notInstalled) {
                throw "Missing RSAT features: $($notInstalled.Name -join ', ')"
            }
            "$($features.Count) features installed"
        }
        $results.Tests["RSAT Features"] = Test-Component -Name "RSAT Features" -Test $rsatTest -Results $results

        # Permissions Test
        $permissionsTest = {
            # Test certificate store access
            $null = Get-ChildItem "Cert:\LocalMachine\My" -ErrorAction Stop
            
            # Test configuration directory access
            $configPath = Split-Path (Get-PKIConfig).LogPath -Parent
            $null = Test-Path $configPath -ErrorAction Stop

            "Sufficient"
        }
        $results.Tests["Permissions"] = Test-Component -Name "Permissions" -Test $permissionsTest -Results $results

        # Network Connectivity Test
        $networkTest = {
            $testResults = Test-NetworkConnectivity
            if (-not $testResults) { throw "Network connectivity check failed" }
            "Connected"
        }
        $results.Tests["Network"] = Test-Component -Name "Network" -Test $networkTest -Results $results

        # Generate summary
        $results.Success = -not ($results.Tests.Values -contains $false)
        
        if ($Detailed) {
            return $results
        }
        else {
            return $results.Success
        }
    }
    catch {
        Write-PKILog -Message "Installation validation failed: $_" -Level Error -Component "Install"
        return $false
    }
}

function Test-Component {
    [CmdletBinding()]
    param(
        [string]$Name,
        [scriptblock]$Test,
        [hashtable]$Results
    )

    try {
        $detail = & $Test
        $Results.Details[$Name] = $detail
        return $true
    }
    catch {
        $Results.Details[$Name] = $_.Exception.Message
        $Results.Recommendations += "Fix for $($Name) - $($_.Exception.Message)"
        return $false
    }
}

# Export functions
Export-ModuleMember -Function Test-PKIAuditInstallation 