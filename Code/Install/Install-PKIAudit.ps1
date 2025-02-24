function Install-PKIAudit {
    <#
    .SYNOPSIS
    Installs and configures PSPKIAudit with all required dependencies.

    .DESCRIPTION
    Automated installation script that:
    1. Checks system requirements
    2. Installs required Windows features
    3. Installs PowerShell modules
    4. Configures initial settings
    5. Validates the installation

    .PARAMETER Force
    Switch to force reinstallation of components.

    .PARAMETER LogPath
    Path to the installation log file. Defaults to "PKIAudit_Install.log".

    .EXAMPLE
    Install-PKIAudit

    .NOTES
    Common Issues and Solutions:
    1. Administrative Privileges:
       - Error: "Access denied" or "Insufficient privileges"
       - Solution: Run PowerShell as Administrator
    
    2. Network Issues:
       - Error: "Unable to download required modules"
       - Solution: Check internet connectivity, proxy settings
       - Alternative: Use -Offline parameter for offline installation
    
    3. RSAT Features:
       - Error: "Failed to install RSAT features"
       - Solution: Run Windows Update, then retry
       - Alternative: Install manually through Windows Features
    
    4. Module Conflicts:
       - Error: "Module 'PSPKI' version conflict"
       - Solution: Use -Force to reinstall modules
       - Alternative: Manually remove old versions first
    
    5. Certificate Store Access:
       - Error: "Unable to access certificate store"
       - Solution: Check certificate store permissions
       - Alternative: Grant explicit permissions to the store
    #>
    [CmdletBinding()]
    param(
        [switch]$Force,
        [string]$LogPath = "PKIAudit_Install.log"
    )

    try {
        Write-PKILog "=== Starting PSPKIAudit Installation ===" -Level Info -Component "Install"
        $startTime = Get-Date

        # Initialize progress tracking
        $totalSteps = 7
        $currentStep = 0

        # Step 1: Create backup state
        Write-Progress -Activity "Installing PSPKIAudit" -Status "Creating backup" -PercentComplete (($currentStep++/$totalSteps) * 100)
        $backupState = New-PKIAuditBackupState
        Write-PKILog "Created backup state" -Level Info -Component "Install"

        # Step 2: Check dependencies
        Write-Progress -Activity "Installing PSPKIAudit" -Status "Checking dependencies" -PercentComplete (($currentStep++/$totalSteps) * 100)
        $dependencyCheck = Test-PKIDependencies -Detailed
        if (-not $dependencyCheck.Success) {
            $errorMessage = "Dependency check failed. Please address the following issues:`n"
            foreach ($rec in $dependencyCheck.Recommendations) {
                $errorMessage += "- $rec`n"
            }
            $errorMessage += "`nTroubleshooting Tips:`n"
            $errorMessage += "1. Ensure you have administrative privileges`n"
            $errorMessage += "2. Check your internet connection`n"
            $errorMessage += "3. Run Windows Update to get latest RSAT features`n"
            $errorMessage += "4. Clear PowerShell module cache if needed: Remove-Item -Path `$env:USERPROFILE\Documents\WindowsPowerShell\Modules\* -Recurse -Force`n"
            throw $errorMessage
        }
        Write-PKILog "Dependency check passed" -Level Info -Component "Install"

        # Step 3: Install Required Windows Features
        Write-Progress -Activity "Installing PSPKIAudit" -Status "Installing Windows features" -PercentComplete (($currentStep++/$totalSteps) * 100)
        Write-PKILog "Installing required Windows features..." -Level Info -Component "Install"
        
        $rsatFeatures = Get-WindowsCapability -Online -Name "Rsat.*" | Where-Object Name -match "CertificateServices|ActiveDirectory"
        foreach ($feature in $rsatFeatures) {
            if ($feature.State -ne "Installed" -or $Force) {
                try {
                    Write-PKILog "Installing feature: $($feature.Name)" -Level Info -Component "Install"
                    $result = Add-WindowsCapability -Online -Name $feature.Name
                    if ($result.RestartNeeded) {
                        Write-PKILog "System restart required after installing $($feature.Name)" -Level Warning -Component "Install"
                    }
                }
                catch {
                    $errorMessage = "Failed to install RSAT feature $($feature.Name). Error: $_`n`n"
                    $errorMessage += "Troubleshooting Steps:`n"
                    $errorMessage += "1. Run 'sfc /scannow' to check system files`n"
                    $errorMessage += "2. Run Windows Update and retry`n"
                    $errorMessage += "3. Try installing through 'Optional Features' in Windows Settings`n"
                    $errorMessage += "4. Check CBS logs in C:\Windows\Logs\CBS\CBS.log for detailed errors`n"
                    throw $errorMessage
                }
            }
        }

        # Step 4: Install Required PowerShell Modules
        Write-Progress -Activity "Installing PSPKIAudit" -Status "Installing PowerShell modules" -PercentComplete (($currentStep++/$totalSteps) * 100)
        Write-PKILog "Installing required PowerShell modules..." -Level Info -Component "Install"
        
        foreach ($module in $dependencyCheck.Dependencies.GetEnumerator()) {
            if ($module.Key -in @('PSPKI', 'ActiveDirectory')) {
                try {
                    if (-not $module.Value -or $Force) {
                        $minVersion = $dependencyCheck.Details[$module.Key] -replace 'Required: ([0-9.]+).*', '$1'
                        Write-PKILog "Installing module: $($module.Key) v$minVersion" -Level Info -Component "Install"
                        Install-Module -Name $module.Key -MinimumVersion $minVersion -Force -AllowClobber
                    }
                }
                catch {
                    $errorMessage = "Failed to install/update module $($module.Key). Error: $_`n`n"
                    $errorMessage += "Troubleshooting Steps:`n"
                    $errorMessage += "1. Check internet connectivity and proxy settings`n"
                    $errorMessage += "2. Run 'Register-PSRepository -Default' to reset PSGallery`n"
                    $errorMessage += "3. Clear NuGet cache: Remove-Item `$env:LOCALAPPDATA\NuGet\Cache\* -Force`n"
                    $errorMessage += "4. Try manual installation: Save-Module -Name $($module.Key) -Path <path>`n"
                    throw $errorMessage
                }
            }
        }

        # Step 5: Configure Initial Settings
        Write-Progress -Activity "Installing PSPKIAudit" -Status "Configuring settings" -PercentComplete (($currentStep++/$totalSteps) * 100)
        Write-PKILog "Configuring initial settings..." -Level Info -Component "Install"
        
        try {
            $config = @{
                LogPath = "PKIAudit.log"
                LogLevel = "Info"
                EnableConsole = $true
                EnableFile = $true
                DefaultExportPath = "exports"
                Monitoring = @{
                    EventLogRetentionDays = 30
                    HealthCheckInterval = 3600
                    AlertThresholds = @{
                        CertificateExpirationWarningDays = 30
                        DiskSpaceWarningThreshold = 10
                    }
                }
            }
            
            Set-PKIConfig -Settings $config
            Write-PKILog "Initial configuration completed" -Level Info -Component "Install"
        }
        catch {
            $errorMessage = "Failed to configure settings. Error: $_`n`n"
            $errorMessage += "Troubleshooting Steps:`n"
            $errorMessage += "1. Check file system permissions for config directory`n"
            $errorMessage += "2. Verify JSON configuration format`n"
            $errorMessage += "3. Try running with -Force to reset configuration`n"
            throw $errorMessage
        }

        # Step 6: Validate Installation
        Write-Progress -Activity "Installing PSPKIAudit" -Status "Validating installation" -PercentComplete (($currentStep++/$totalSteps) * 100)
        Write-PKILog "Validating installation..." -Level Info -Component "Install"
        
        $validationResult = Test-PKIAuditInstallation -Detailed
        if (-not $validationResult.Success) {
            $errorMessage = "Installation validation failed. Please check the following:`n"
            foreach ($rec in $validationResult.Recommendations) {
                $errorMessage += "- $rec`n"
            }
            $errorMessage += "`nTroubleshooting Steps:`n"
            $errorMessage += "1. Review the installation log at $LogPath`n"
            $errorMessage += "2. Verify all components are properly installed`n"
            $errorMessage += "3. Check system event logs for errors`n"
            $errorMessage += "4. Try running with -Force to reinstall components`n"
            throw $errorMessage
        }
        Write-PKILog "Installation validation completed" -Level Info -Component "Install"

        # Step 7: Final Status
        Write-Progress -Activity "Installing PSPKIAudit" -Status "Completing installation" -PercentComplete 100
        $endTime = Get-Date
        $duration = $endTime - $startTime
        
        Write-PKILog "=== Installation Completed Successfully ===" -Level Info -Component "Install"
        Write-PKILog "Installation duration: $($duration.Minutes) minutes $($duration.Seconds) seconds" -Level Info -Component "Install"
        Write-PKILog "You can now use PSPKIAudit commands. Type 'Get-Command -Module PSPKIAudit' to see available commands." -Level Info -Component "Install"

        return $true
    }
    catch {
        Write-PKILog "Installation failed: $_" -Level Error -Component "Install"
        Write-PKILog "Attempting to restore previous state..." -Level Warning -Component "Install"

        try {
            $restoreResult = Restore-PKIAuditState -BackupState $backupState -Force
            if ($restoreResult.Success) {
                Write-PKILog "Successfully restored previous state" -Level Info -Component "Install"
            }
            else {
                Write-PKILog "Failed to fully restore previous state. Manual cleanup may be required." -Level Warning -Component "Install"
                foreach ($warning in $restoreResult.Warnings) {
                    Write-PKILog $warning -Level Warning -Component "Install"
                }
            }
        }
        catch {
            Write-PKILog "Failed to restore previous state: $_" -Level Error -Component "Install"
        }

        Write-PKILog "Please check the log file at $LogPath for details" -Level Error -Component "Install"
        Write-PKILog "For troubleshooting assistance, visit: https://github.com/GhostPack/PSPKIAudit/wiki/Troubleshooting" -Level Info -Component "Install"
        return $false
    }
    finally {
        Write-Progress -Activity "Installing PSPKIAudit" -Completed
    }
}

# Export function
Export-ModuleMember -Function Install-PKIAudit 