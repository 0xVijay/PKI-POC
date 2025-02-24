#Requires -Version 5.1
[CmdletBinding()]
param()

# Get the script path
$scriptPath = $MyInvocation.MyCommand.Path
$scriptDir = Split-Path -Parent $scriptPath
Write-Host "Script running from: $scriptDir" -ForegroundColor Cyan

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
        
        # Register PSGallery if not registered
        if (-not (Get-PSRepository -Name "PSGallery" -ErrorAction SilentlyContinue)) {
            Write-Host "Registering PSGallery..." -ForegroundColor Yellow
            Register-PSRepository -Default
        }

        # Set PSGallery as trusted
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
    catch {
        Write-Error "Failed to install required modules: $_"
        Write-Host "Troubleshooting tips:" -ForegroundColor Yellow
        Write-Host "1. Check your internet connection" -ForegroundColor Yellow
        Write-Host "2. Try running 'Install-PackageProvider -Name NuGet -Force' first" -ForegroundColor Yellow
        Write-Host "3. Make sure you have access to PowerShell Gallery" -ForegroundColor Yellow
        throw
    }
}

function Install-PKIAuditModule {
    param(
        [string]$TempDir
    )
    
    try {
        Write-Host "Installing PKIAudit module..." -ForegroundColor Cyan
        
        # Check if module files exist locally
        $localPsd1 = Join-Path $scriptDir "PSPKIAudit.psd1"
        if (Test-Path $localPsd1) {
            Write-Host "Installing from local files..." -ForegroundColor Yellow
            Import-Module $localPsd1 -Force
            Install-PKIAudit -Force
        } else {
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
        Write-Host "3. Check your internet connection if downloading from GitHub" -ForegroundColor Yellow
        throw
    }
}

try {
    Write-Host "=== PSPKIAudit Installation ===" -ForegroundColor Cyan
    Write-Host "PowerShell Version: $($PSVersionTable.PSVersion)" -ForegroundColor Yellow
    Write-Host "OS: $([System.Environment]::OSVersion.VersionString)" -ForegroundColor Yellow
    Write-Host

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
    Write-Host "For support, please visit: https://github.com/yourusername/PSPKIAudit/issues" -ForegroundColor Yellow
    exit 1
} 