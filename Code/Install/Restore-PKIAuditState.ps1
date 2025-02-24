function Restore-PKIAuditState {
    <#
    .SYNOPSIS
    Restores PSPKIAudit to a previous state after a failed installation.

    .DESCRIPTION
    Provides rollback functionality for failed installations by:
    - Restoring previous configuration
    - Removing installed components
    - Cleaning up temporary files
    - Restoring system settings

    .PARAMETER BackupState
    Hashtable containing the backup state information.

    .PARAMETER Force
    Switch to force restoration even if some steps fail.

    .EXAMPLE
    Restore-PKIAuditState -BackupState $backupState
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]
        $BackupState,

        [switch]
        $Force
    )

    try {
        Write-PKILog -Message "Starting PKIAudit state restoration" -Level Info -Component "Install"

        $results = @{
            Success = $true
            RestoredItems = @()
            FailedItems = @()
            Warnings = @()
        }

        # Restore configuration if it exists
        if ($BackupState.Configuration) {
            try {
                $configPath = Join-Path $PSScriptRoot "../../config/settings.json"
                if (Test-Path $configPath) {
                    Remove-Item $configPath -Force
                }
                if ($BackupState.Configuration.Exists) {
                    $BackupState.Configuration.Content | ConvertTo-Json -Depth 10 | 
                        Out-File $configPath -Encoding UTF8
                    $results.RestoredItems += "Configuration"
                }
            }
            catch {
                $results.FailedItems += "Configuration"
                $results.Warnings += "Failed to restore configuration: $_"
                if (-not $Force) { throw $_ }
            }
        }

        # Remove installed modules if they were installed during setup
        if ($BackupState.InstalledModules) {
            foreach ($module in $BackupState.InstalledModules) {
                try {
                    if (Get-Module $module.Name -ListAvailable) {
                        if ($module.WasInstalled) {
                            Uninstall-Module $module.Name -Force -AllVersions
                        }
                        elseif ($module.Version) {
                            # Restore previous version if it exists
                            Uninstall-Module $module.Name -Force -AllVersions
                            Install-Module $module.Name -RequiredVersion $module.Version -Force
                        }
                        $results.RestoredItems += "Module: $($module.Name)"
                    }
                }
                catch {
                    $results.FailedItems += "Module: $($module.Name)"
                    $results.Warnings += "Failed to restore module $($module.Name): $_"
                    if (-not $Force) { throw $_ }
                }
            }
        }

        # Restore Windows features if they were modified
        if ($BackupState.WindowsFeatures) {
            foreach ($feature in $BackupState.WindowsFeatures) {
                try {
                    if ($feature.WasInstalled -eq $false) {
                        Remove-WindowsCapability -Online -Name $feature.Name -ErrorAction Stop
                        $results.RestoredItems += "Feature: $($feature.Name)"
                    }
                }
                catch {
                    $results.FailedItems += "Feature: $($feature.Name)"
                    $results.Warnings += "Failed to restore feature $($feature.Name): $_"
                    if (-not $Force) { throw $_ }
                }
            }
        }

        # Clean up temporary files
        if ($BackupState.TempFiles) {
            foreach ($file in $BackupState.TempFiles) {
                try {
                    if (Test-Path $file) {
                        Remove-Item $file -Force -Recurse
                        $results.RestoredItems += "TempFile: $file"
                    }
                }
                catch {
                    $results.FailedItems += "TempFile: $file"
                    $results.Warnings += "Failed to remove temporary file $file: $_"
                    if (-not $Force) { throw $_ }
                }
            }
        }

        # Restore system settings if they were modified
        if ($BackupState.SystemSettings) {
            foreach ($setting in $BackupState.SystemSettings.GetEnumerator()) {
                try {
                    Set-ItemProperty -Path $setting.Key -Name $setting.Value.Name -Value $setting.Value.Value
                    $results.RestoredItems += "Setting: $($setting.Key)\$($setting.Value.Name)"
                }
                catch {
                    $results.FailedItems += "Setting: $($setting.Key)\$($setting.Value.Name)"
                    $results.Warnings += "Failed to restore setting $($setting.Key)\$($setting.Value.Name): $_"
                    if (-not $Force) { throw $_ }
                }
            }
        }

        # Update results
        $results.Success = ($results.FailedItems.Count -eq 0) -or $Force

        Write-PKILog -Message "State restoration completed. Success: $($results.Success)" -Level Info -Component "Install"
        if ($results.Warnings.Count -gt 0) {
            foreach ($warning in $results.Warnings) {
                Write-PKILog -Message $warning -Level Warning -Component "Install"
            }
        }

        return $results
    }
    catch {
        Write-PKILog -Message "State restoration failed: $_" -Level Error -Component "Install"
        throw $_
    }
}

function New-PKIAuditBackupState {
    <#
    .SYNOPSIS
    Creates a backup of the current PKIAudit state before installation.

    .DESCRIPTION
    Captures the current state of:
    - Configuration
    - Installed modules
    - Windows features
    - System settings
    - Temporary files

    .EXAMPLE
    $backupState = New-PKIAuditBackupState
    #>
    [CmdletBinding()]
    param()

    try {
        Write-PKILog -Message "Creating PKIAudit state backup" -Level Info -Component "Install"

        $backupState = @{
            Timestamp = Get-Date
            Configuration = @{}
            InstalledModules = @()
            WindowsFeatures = @()
            SystemSettings = @{}
            TempFiles = @()
        }

        # Backup configuration
        $configPath = Join-Path $PSScriptRoot "../../config/settings.json"
        if (Test-Path $configPath) {
            $backupState.Configuration = @{
                Exists = $true
                Content = Get-Content $configPath -Raw | ConvertFrom-Json
            }
        }

        # Backup module state
        $requiredModules = @('PSPKI', 'ActiveDirectory')
        foreach ($moduleName in $requiredModules) {
            $module = Get-Module $moduleName -ListAvailable
            if ($module) {
                $backupState.InstalledModules += @{
                    Name = $moduleName
                    Version = $module.Version
                    WasInstalled = $true
                }
            }
            else {
                $backupState.InstalledModules += @{
                    Name = $moduleName
                    WasInstalled = $false
                }
            }
        }

        # Backup Windows features state
        $features = Get-WindowsCapability -Online -Name "Rsat.*" | 
            Where-Object Name -match "CertificateServices|ActiveDirectory"
        foreach ($feature in $features) {
            $backupState.WindowsFeatures += @{
                Name = $feature.Name
                WasInstalled = $feature.State -eq "Installed"
            }
        }

        # Backup relevant system settings
        $settingsToBackup = @{
            "HKLM:\SOFTWARE\Microsoft\PowerShell\1\ShellIds\Microsoft.PowerShell" = @{
                Name = "ExecutionPolicy"
                Value = (Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\PowerShell\1\ShellIds\Microsoft.PowerShell").ExecutionPolicy
            }
        }
        $backupState.SystemSettings = $settingsToBackup

        Write-PKILog -Message "State backup completed successfully" -Level Info -Component "Install"
        return $backupState
    }
    catch {
        Write-PKILog -Message "Failed to create state backup: $_" -Level Error -Component "Install"
        throw $_
    }
}

# Export functions
Export-ModuleMember -Function Restore-PKIAuditState, New-PKIAuditBackupState 