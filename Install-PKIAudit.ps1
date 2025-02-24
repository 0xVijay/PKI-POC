#Requires -Version 5.1
[CmdletBinding()]
param()

function Test-AdminPrivileges {
    if ($IsWindows) {
        $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
        $principal = New-Object Security.Principal.WindowsPrincipal($identity)
        return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    }
    else {
        # For Unix systems, check if running as root
        return (id -u) -eq 0
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
            throw "This script requires administrative privileges"
        }

        # Create temp directory
        $tempDir = Join-Path ([System.IO.Path]::GetTempPath()) "PKIAudit_Install"
        if (-not (Test-Path $tempDir)) {
            New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
        }

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
        
        $modules = @('PSPKI', 'ActiveDirectory')
        foreach ($module in $modules) {
            if (-not (Get-Module -Name $module -ListAvailable)) {
                Write-Host "Installing $module module..." -ForegroundColor Yellow
                Install-Module -Name $module -Force -AllowClobber -Scope CurrentUser
            }
        }
    }
    catch {
        Write-Error "Failed to install required modules: $_"
        throw
    }
}

function Install-PKIAuditModule {
    param(
        [string]$TempDir
    )
    
    try {
        Write-Host "Installing PKIAudit module..." -ForegroundColor Cyan
        
        # Download module
        $url = "https://github.com/GhostPack/PSPKIAudit/archive/main.zip"
        $zipFile = Join-Path $TempDir "PSPKIAudit.zip"
        
        Write-Host "Downloading PKIAudit..." -ForegroundColor Yellow
        Invoke-WebRequest -Uri $url -OutFile $zipFile
        
        # Extract module
        Write-Host "Extracting files..." -ForegroundColor Yellow
        Expand-Archive -Path $zipFile -DestinationPath $TempDir -Force
        
        # Import and install
        Write-Host "Installing module..." -ForegroundColor Yellow
        Import-Module (Join-Path $TempDir "PSPKIAudit-main\PSPKIAudit.psd1") -Force
        Install-PKIAudit -Force
        
        Write-Host "PKIAudit module installed successfully!" -ForegroundColor Green
    }
    catch {
        Write-Error "Failed to install PKIAudit module: $_"
        throw
    }
}

try {
    Write-Host "=== PSPKIAudit Installation ===" -ForegroundColor Cyan
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
}
catch {
    Write-Host
    Write-Host "Installation failed: $_" -ForegroundColor Red
    Write-Host "Please check the error message above and try again." -ForegroundColor Yellow
    exit 1
} 