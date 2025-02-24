#Requires -Version 5.1
[CmdletBinding()]
param(
    [switch]$Offline,
    [switch]$DownloadDependencies
)

# Get the script path
$scriptPath = $MyInvocation.MyCommand.Path
$scriptDir = Split-Path -Parent $scriptPath
Write-Host "Script running from: $scriptDir" -ForegroundColor Cyan

# Constants
$GITHUB_URL = "https://github.com/0xVijay/PKI-POC"
$GITHUB_RAW_URL = "https://raw.githubusercontent.com/0xVijay/PKI-POC/master"

function Test-AdminPrivileges {
    try {
        # Check if running on Windows
        if ($PSVersionTable.PSVersion.Major -ge 6 -and -not $IsWindows) {
            # For PowerShell Core on Unix-like systems
            if ($PSVersionTable.Platform -eq 'Unix') {
                $user = & whoami
                return $user -eq 'root'
            }
            return $false
        } else {
            # For Windows PowerShell or PowerShell Core on Windows
            $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
            $principal = New-Object Security.Principal.WindowsPrincipal($identity)
            return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
        }
    }
    catch {
        Write-Warning "Failed to check admin privileges: $_"
        return $false
    }
}

function Test-RequiredFiles {
    param(
        [string]$Path
    )
    
    $requiredFiles = @(
        'PSPKIAudit.psd1',
        'PSPKIAudit.psm1',
        'Code/Common/Export-PKIJson.ps1',
        'Code/Common/Get-PKIConfig.ps1',
        'Code/Common/Write-PKILog.ps1',
        'Code/Install/Install-PKIAudit.ps1',
        'Code/Install/Test-PKIAuditInstallation.ps1',
        'Code/Install/Test-PKIDependencies.ps1',
        'Code/Install/Restore-PKIAuditState.ps1'
    )

    $missingFiles = @()
    foreach ($file in $requiredFiles) {
        $filePath = Join-Path $Path $file
        if (-not (Test-Path $filePath)) {
            $missingFiles += $file
        }
    }

    return $missingFiles
}

function Install-Prerequisites {
    try {
        Write-Host "Checking prerequisites..." -ForegroundColor Cyan
        
        # Check PowerShell version
        if ($PSVersionTable.PSVersion.Major -lt 5) {
            throw "PowerShell 5.1 or higher is required"
        }

        # Check if running as admin/root
        if (-not (Test-AdminPrivileges)) {
            throw "This script requires administrative privileges. Please run as administrator/root."
        }

        # Check for required files if in offline mode
        if ($Offline) {
            $missingFiles = Test-RequiredFiles -Path $scriptDir
            if ($missingFiles.Count -gt 0) {
                throw "Missing required files for offline installation:`n$($missingFiles -join "`n")"
            }
        }

        # Create temp directory
        $tempDir = Join-Path ([System.IO.Path]::GetTempPath()) "PKIAudit_Install"
        if (Test-Path $tempDir) {
            Remove-Item -Path $tempDir -Recurse -Force
        }
        New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
        Write-Host "Created temporary directory: $tempDir" -ForegroundColor Yellow

        return $tempDir
    }
    catch {
        Write-Error "Failed to check prerequisites: $_"
        throw
    }
}

function Install-RequiredModules {
    param(
        [string]$ModulePath
    )
    
    try {
        Write-Host "Installing required modules..." -ForegroundColor Cyan
        
        if ($Offline) {
            # Install NuGet provider from local files if needed
            $nugetProvider = Get-PackageProvider -Name NuGet -ErrorAction SilentlyContinue
            if (-not $nugetProvider) {
                Write-Host "Installing NuGet provider from local files..." -ForegroundColor Yellow
                $nugetPath = Join-Path $scriptDir "Providers/NuGet"
                if (Test-Path $nugetPath) {
                    Copy-Item -Path "$nugetPath/*" -Destination "C:\Program Files\PackageManagement\ProviderAssemblies" -Recurse -Force
                } else {
                    throw "NuGet provider files not found in Providers/NuGet directory"
                }
            }

            # Check for modules directory
            $modulesDir = Join-Path $scriptDir "Modules"
            if (-not (Test-Path $modulesDir)) {
                throw "Modules directory not found. For offline installation, please create a 'Modules' directory with PSPKI and ActiveDirectory modules"
            }

            # Install modules from local path
            $modules = @('PSPKI', 'ActiveDirectory')
            foreach ($module in $modules) {
                Write-Host "Checking $module module..." -ForegroundColor Yellow
                $moduleDir = Join-Path $modulesDir $module
                if (-not (Test-Path $moduleDir)) {
                    throw "Module $module not found in Modules directory. Please copy the module to $moduleDir"
                }

                # Copy module to PowerShell modules directory
                $destPath = Join-Path ([Environment]::GetFolderPath('MyDocuments')) "WindowsPowerShell\Modules\$module"
                if (-not (Test-Path $destPath)) {
                    Copy-Item -Path $moduleDir -Destination $destPath -Recurse -Force
                    Write-Host "$module module installed successfully from local files" -ForegroundColor Green
                } else {
                    Write-Host "$module module is already installed" -ForegroundColor Green
                }
            }
        } else {
            # Online installation
            if (-not (Get-PSRepository -Name "PSGallery" -ErrorAction SilentlyContinue)) {
                Write-Host "Registering PSGallery..." -ForegroundColor Yellow
                Register-PSRepository -Default
            }

            Set-PSRepository -Name "PSGallery" -InstallationPolicy Trusted
            
            $modules = @('PSPKI', 'ActiveDirectory')
            foreach ($module in $modules) {
                Write-Host "Checking $module module..." -ForegroundColor Yellow
                if (-not (Get-Module -Name $module -ListAvailable)) {
                    Write-Host "Installing $module module..." -ForegroundColor Yellow
                    Install-Module -Name $module -Force -AllowClobber -Scope CurrentUser -Repository PSGallery
                    Write-Host "$module module installed successfully" -ForegroundColor Green
                } else {
                    Write-Host "$module module is already installed" -ForegroundColor Green
                }
            }
        }
    }
    catch {
        Write-Error "Failed to install required modules: $_"
        if ($Offline) {
            Write-Host "For offline installation, please ensure:" -ForegroundColor Yellow
            Write-Host "1. Create a 'Modules' directory in the same location as this script" -ForegroundColor Yellow
            Write-Host "2. Copy the PSPKI and ActiveDirectory modules to the Modules directory" -ForegroundColor Yellow
            Write-Host "3. Copy the NuGet provider to the Providers/NuGet directory" -ForegroundColor Yellow
            Write-Host "4. Directory structure should be:" -ForegroundColor Yellow
            Write-Host "   ├── Modules/" -ForegroundColor Yellow
            Write-Host "   │   ├── PSPKI/" -ForegroundColor Yellow
            Write-Host "   │   └── ActiveDirectory/" -ForegroundColor Yellow
            Write-Host "   └── Providers/" -ForegroundColor Yellow
            Write-Host "       └── NuGet/" -ForegroundColor Yellow
        } else {
            Write-Host "Troubleshooting tips:" -ForegroundColor Yellow
            Write-Host "1. Check your internet connection" -ForegroundColor Yellow
            Write-Host "2. Try running with -Offline switch if you have all required files" -ForegroundColor Yellow
        }
        throw
    }
}

function Install-PKIAuditModule {
    param(
        [string]$TempDir
    )
    
    try {
        Write-Host "Installing PKIAudit module..." -ForegroundColor Cyan
        
        # Always try local files first
        $localPsd1 = Join-Path $scriptDir "PSPKIAudit.psd1"
        if (Test-Path $localPsd1) {
            Write-Host "Installing from local files..." -ForegroundColor Yellow
            Import-Module $localPsd1 -Force
            Install-PKIAudit -Force
        } else {
            if ($Offline) {
                throw "PSPKIAudit.psd1 not found. For offline installation, all files must be present locally."
            }
            
            # Download from GitHub
            Write-Host "Local files not found, downloading from GitHub..." -ForegroundColor Yellow
            $url = "https://github.com/GhostPack/PSPKIAudit/archive/main.zip"
            $zipFile = Join-Path $TempDir "PSPKIAudit.zip"
            
            Write-Host "Downloading PKIAudit..." -ForegroundColor Yellow
            [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
            Invoke-WebRequest -Uri $url -OutFile $zipFile
            
            Write-Host "Extracting files..." -ForegroundColor Yellow
            Expand-Archive -Path $zipFile -DestinationPath $TempDir -Force
            
            Write-Host "Installing module..." -ForegroundColor Yellow
            Import-Module (Join-Path $TempDir "PSPKIAudit-main\PSPKIAudit.psd1") -Force
            Install-PKIAudit -Force
        }
        
        Write-Host "PKIAudit module installed successfully!" -ForegroundColor Green
    }
    catch {
        Write-Error "Failed to install PKIAudit module: $_"
        Write-Host "Troubleshooting tips:" -ForegroundColor Yellow
        Write-Host "1. Check if you have write access to PowerShell modules directory" -ForegroundColor Yellow
        Write-Host "2. Try running the script with administrative privileges" -ForegroundColor Yellow
        if (-not $Offline) {
            Write-Host "3. Check your internet connection if downloading from GitHub" -ForegroundColor Yellow
            Write-Host "4. Try running with -Offline switch if you have all required files" -ForegroundColor Yellow
        }
        throw
    }
}

function Download-Dependencies {
    param(
        [string]$DestinationPath
    )
    try {
        Write-Host "Downloading dependencies..." -ForegroundColor Cyan
        
        # Create directory structure
        $dirs = @(
            "Modules",
            "Providers/NuGet",
            "Code/Common",
            "Code/Install",
            "Code/Monitor"
        )
        foreach ($dir in $dirs) {
            $path = Join-Path $DestinationPath $dir
            if (-not (Test-Path $path)) {
                New-Item -ItemType Directory -Path $path -Force | Out-Null
            }
        }

        # Download NuGet Provider directly from PowerShell Gallery
        Write-Host "Downloading NuGet provider..." -ForegroundColor Yellow
        $nugetDir = Join-Path $DestinationPath "Providers/NuGet"
        
        # Download NuGet Provider package
        $nugetVersion = "2.8.5.208"
        $nugetUrl = "https://www.powershellgallery.com/api/v2/package/PackageManagement.NuGet.PowerShellGet/$nugetVersion"
        $nugetZip = Join-Path $nugetDir "NuGet.zip"
        
        try {
            Invoke-WebRequest -Uri $nugetUrl -OutFile $nugetZip -UseBasicParsing
            
            # Extract the NuGet provider files
            if (Test-Path $nugetZip) {
                Expand-Archive -Path $nugetZip -DestinationPath $nugetDir -Force
                Remove-Item -Path $nugetZip -Force
                
                # Move files from nested directory if needed
                $nestedDir = Get-ChildItem -Path $nugetDir -Directory | Select-Object -First 1
                if ($nestedDir) {
                    Get-ChildItem -Path $nestedDir.FullName | Move-Item -Destination $nugetDir -Force
                    Remove-Item -Path $nestedDir.FullName -Force
                }
                
                Write-Host "NuGet provider downloaded successfully" -ForegroundColor Green
            }
        }
        catch {
            Write-Warning "Failed to download NuGet provider from PowerShell Gallery. Trying alternative source..."
            
            # Alternative: Download from NuGet.org
            $nugetUrl = "https://dist.nuget.org/win-x86-commandline/latest/nuget.exe"
            Invoke-WebRequest -Uri $nugetUrl -OutFile (Join-Path $nugetDir "nuget.exe") -UseBasicParsing
            
            Write-Host "NuGet provider downloaded from alternative source" -ForegroundColor Green
        }

        # Download required PowerShell modules with specific versions
        $modulesDir = Join-Path $DestinationPath "Modules"
        $modules = @{
            'PSPKI' = '3.7.2'
            'ActiveDirectory' = '1.0.0'
        }

        foreach ($module in $modules.GetEnumerator()) {
            Write-Host "Downloading $($module.Key) module v$($module.Value)..." -ForegroundColor Yellow
            $moduleDir = Join-Path $modulesDir $module.Key
            
            try {
                # Try downloading from PowerShell Gallery first
                Save-Module -Name $module.Key -Path $modulesDir -RequiredVersion $module.Value -Repository PSGallery -ErrorAction Stop
                Write-Host "$($module.Key) module downloaded from PSGallery" -ForegroundColor Green
            }
            catch {
                Write-Warning "Failed to download $($module.Key) from PSGallery. Trying alternative source..."
                
                if ($module.Key -eq 'PSPKI') {
                    # Download PSPKI from GitHub
                    $pspkiZip = Join-Path $DestinationPath "pspki.zip"
                    Invoke-WebRequest -Uri "$GITHUB_URL/archive/refs/heads/master.zip" -OutFile $pspkiZip -UseBasicParsing
                    
                    if (Test-Path $pspkiZip) {
                        Expand-Archive -Path $pspkiZip -DestinationPath $modulesDir -Force
                        Move-Item -Path (Join-Path $modulesDir "PKI-POC-master/PSPKI") -Destination $moduleDir -Force
                        Remove-Item -Path $pspkiZip -Force
                        Write-Host "PSPKI module downloaded from GitHub" -ForegroundColor Green
                    }
                }
            }
        }

        # Download required files from GitHub
        $files = @{
            "PSPKIAudit.psd1" = "PSPKIAudit.psd1"
            "PSPKIAudit.psm1" = "PSPKIAudit.psm1"
            "Code/Common/Export-PKIJson.ps1" = "Code/Common/Export-PKIJson.ps1"
            "Code/Common/Get-PKIConfig.ps1" = "Code/Common/Get-PKIConfig.ps1"
            "Code/Common/Write-PKILog.ps1" = "Code/Common/Write-PKILog.ps1"
            "Code/Install/Install-PKIAudit.ps1" = "Code/Install/Install-PKIAudit.ps1"
            "Code/Install/Test-PKIAuditInstallation.ps1" = "Code/Install/Test-PKIAuditInstallation.ps1"
            "Code/Install/Test-PKIDependencies.ps1" = "Code/Install/Test-PKIDependencies.ps1"
            "Code/Install/Restore-PKIAuditState.ps1" = "Code/Install/Restore-PKIAuditState.ps1"
            "Code/Monitor/Get-PKIEvent.ps1" = "Code/Monitor/Get-PKIEvent.ps1"
            "Code/Monitor/Get-PKIHealth.ps1" = "Code/Monitor/Get-PKIHealth.ps1"
            "Code/Monitor/Test-PKIHelpers.ps1" = "Code/Monitor/Test-PKIHelpers.ps1"
        }

        foreach ($file in $files.GetEnumerator()) {
            $destFile = Join-Path $DestinationPath $file.Key
            Write-Host "Downloading $($file.Key)..." -ForegroundColor Yellow
            $content = Invoke-WebRequest -Uri "$GITHUB_RAW_URL/$($file.Value)" -UseBasicParsing
            Set-Content -Path $destFile -Value $content.Content -Force
        }

        # Create verification file with checksums
        $verificationPath = Join-Path $DestinationPath "verification.json"
        $verification = @{
            CreatedDate = (Get-Date).ToString('o')
            NuGetVersion = $nugetVersion
            Modules = $modules
            FileHashes = @{}
        }

        # Calculate hashes for all downloaded files
        Get-ChildItem -Path $DestinationPath -Recurse -File | ForEach-Object {
            $relativePath = $_.FullName.Replace($DestinationPath, '').TrimStart('\')
            $verification.FileHashes[$relativePath] = (Get-FileHash -Path $_.FullName).Hash
        }

        $verification | ConvertTo-Json -Depth 10 | Set-Content -Path $verificationPath

        # Create offline installation instructions
        $readmePath = Join-Path $DestinationPath "README.md"
        $readmeContent = @"
# PKIAudit Offline Installation Package

This package contains all required files and dependencies for offline installation of PKIAudit.

## Package Contents
- NuGet Provider v$nugetVersion
- PowerShell Modules:
$(($modules.GetEnumerator() | ForEach-Object { "  - $($_.Key) v$($_.Value)" }) -join "`n")
- PKIAudit source code and scripts

## Installation Instructions

1. Copy the entire folder to the target machine
2. Open PowerShell as Administrator
3. Navigate to the package directory
4. Run the following commands:

```powershell
# Install NuGet provider
Copy-Item -Path "Providers/NuGet/*" -Destination "C:\Program Files\PackageManagement\ProviderAssemblies" -Recurse -Force

# Install required modules
Copy-Item -Path "Modules/*" -Destination "$env:ProgramFiles\WindowsPowerShell\Modules" -Recurse -Force

# Install PKIAudit
.\Install-PKIAudit.ps1 -Offline
```

## Verification
The verification.json file contains checksums for all files in this package.
You can verify the integrity of the files using:

```powershell
Get-Content verification.json | ConvertFrom-Json | Select-Object CreatedDate, NuGetVersion, Modules
```
"@
        Set-Content -Path $readmePath -Value $readmeContent

        Write-Host "Dependencies downloaded successfully!" -ForegroundColor Green
        Write-Host "Package created at: $DestinationPath" -ForegroundColor Green
        Write-Host "You can now transfer this folder to the target machine for offline installation." -ForegroundColor Yellow
        return $true
    }
    catch {
        Write-Error "Failed to download dependencies: $_"
        return $false
    }
}

try {
    Write-Host "=== PSPKIAudit Installation ===" -ForegroundColor Cyan
    Write-Host "Mode: $($Offline ? 'Offline' : 'Online')" -ForegroundColor Yellow
    Write-Host "PowerShell Version: $($PSVersionTable.PSVersion)" -ForegroundColor Yellow
    Write-Host "OS: $([System.Environment]::OSVersion.VersionString)" -ForegroundColor Yellow
    Write-Host

    if ($DownloadDependencies) {
        Write-Host "Downloading all required files..." -ForegroundColor Cyan
        $downloadPath = Join-Path $scriptDir "PKIAudit_Files"
        if (-not (Download-Dependencies -DestinationPath $downloadPath)) {
            throw "Failed to download required files"
        }
        Write-Host "All files downloaded to: $downloadPath" -ForegroundColor Green
        Write-Host "You can now run the installation in offline mode using:" -ForegroundColor Yellow
        Write-Host "    .\Install-PKIAudit.ps1 -Offline" -ForegroundColor Yellow
        exit 0
    }

    # Check and install prerequisites
    $tempDir = Install-Prerequisites
    
    # Install required modules
    Install-RequiredModules
    
    # Install PKIAudit
    Install-PKIAuditModule -TempDir $tempDir
    
    # Cleanup
    Write-Host "Cleaning up..." -ForegroundColor Yellow
    Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue
    
    Write-Host
    Write-Host "Installation completed successfully!" -ForegroundColor Green
    Write-Host "You can now use PSPKIAudit commands in PowerShell." -ForegroundColor Cyan
    Write-Host "Try 'Get-Command -Module PSPKIAudit' to see available commands." -ForegroundColor Cyan
}
catch {
    Write-Host
    Write-Host "Installation failed: $_" -ForegroundColor Red
    Write-Host "Please check the error messages above and try again." -ForegroundColor Yellow
    Write-Host
    Write-Host "For support, please visit: $GITHUB_URL/issues" -ForegroundColor Yellow
    exit 1
} 