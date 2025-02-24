function Test-PKIDependencies {
    <#
    .SYNOPSIS
    Validates required dependencies and their versions for PSPKIAudit.

    .DESCRIPTION
    Checks for the presence and version compatibility of required dependencies:
    - PowerShell version
    - Required modules (PSPKI, ActiveDirectory)
    - Windows features
    - System requirements

    .PARAMETER Detailed
    Switch to enable detailed validation output.

    .EXAMPLE
    Test-PKIDependencies -Detailed
    #>
    [CmdletBinding()]
    param(
        [switch]$Detailed
    )

    try {
        Write-PKILog -Message "Starting dependency validation" -Level Info -Component "Install"

        $results = @{
            Success = $true
            Dependencies = @{}
            Details = @{}
            Recommendations = @()
        }

        # Define required dependencies
        $dependencies = @{
            PowerShell = @{
                MinVersion = "5.1"
                Current = $PSVersionTable.PSVersion.ToString()
            }
            Modules = @{
                PSPKI = @{
                    MinVersion = "3.7.2"
                    Required = $true
                }
                ActiveDirectory = @{
                    MinVersion = "1.0.0"
                    Required = $true
                }
            }
            Features = @{
                "Rsat.CertificateServices.Tools" = $true
                "Rsat.ActiveDirectory.DS-LDS.Tools" = $true
            }
            SystemRequirements = @{
                MinimumRAM = 4GB
                MinimumDiskSpace = 1GB
                OSVersion = "Windows 10/Windows Server 2016"
            }
        }

        # Check PowerShell version
        $results.Dependencies["PowerShell"] = ($PSVersionTable.PSVersion -ge [Version]$dependencies.PowerShell.MinVersion)
        $results.Details["PowerShell"] = "Required: $($dependencies.PowerShell.MinVersion), Current: $($dependencies.PowerShell.Current)"

        # Check required modules
        foreach ($module in $dependencies.Modules.GetEnumerator()) {
            $installed = Get-Module -Name $module.Key -ListAvailable
            if ($installed) {
                $currentVersion = $installed.Version
                $minVersion = [Version]$module.Value.MinVersion
                $isValid = $currentVersion -ge $minVersion

                $results.Dependencies[$module.Key] = $isValid
                $results.Details[$module.Key] = "Required: $minVersion, Current: $currentVersion"

                if (-not $isValid) {
                    $results.Recommendations += "Update $($module.Key) to version $minVersion or higher"
                }
            }
            else {
                $results.Dependencies[$module.Key] = $false
                $results.Details[$module.Key] = "Module not installed"
                if ($module.Value.Required) {
                    $results.Recommendations += "Install $($module.Key) module version $($module.Value.MinVersion) or higher"
                }
            }
        }

        # Check Windows features
        foreach ($feature in $dependencies.Features.GetEnumerator()) {
            $installed = Get-WindowsCapability -Online -Name $feature.Key -ErrorAction SilentlyContinue
            $isValid = $installed.State -eq "Installed"

            $results.Dependencies[$feature.Key] = $isValid
            $results.Details[$feature.Key] = if ($isValid) { "Installed" } else { "Not installed" }

            if (-not $isValid -and $feature.Value) {
                $results.Recommendations += "Install Windows feature: $($feature.Key)"
            }
        }

        # Check system requirements
        $systemChecks = @{
            RAM = (Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory -ge $dependencies.SystemRequirements.MinimumRAM
            DiskSpace = (Get-PSDrive $env:SystemDrive[0]).Free -ge $dependencies.SystemRequirements.MinimumDiskSpace
            OS = [Environment]::OSVersion.Version -ge [Version]"10.0"
        }

        foreach ($check in $systemChecks.GetEnumerator()) {
            $results.Dependencies[$check.Key] = $check.Value
            $results.Details[$check.Key] = if ($check.Value) { "Sufficient" } else { "Insufficient" }
            
            if (-not $check.Value) {
                $results.Recommendations += "Upgrade $($check.Key) to meet minimum requirements"
            }
        }

        # Calculate overall success
        $results.Success = -not ($results.Dependencies.Values -contains $false)

        if ($Detailed) {
            return $results
        }
        else {
            return $results.Success
        }
    }
    catch {
        Write-PKILog -Message "Dependency validation failed: $_" -Level Error -Component "Install"
        return $false
    }
}

# Export function
Export-ModuleMember -Function Test-PKIDependencies 