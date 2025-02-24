@echo off
echo === PSPKIAudit Automated Installation ===
echo.

:: Check for administrative privileges
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo Error: This script requires administrative privileges.
    echo Please run as administrator.
    pause
    exit /b 1
)

:: Set up PowerShell execution policy
powershell -Command "Set-ExecutionPolicy Bypass -Scope Process -Force"

:: Create temporary directory
set "TEMP_DIR=%TEMP%\PKIAudit_Install"
if not exist "%TEMP_DIR%" mkdir "%TEMP_DIR%"

echo Downloading PSPKIAudit...
powershell -Command "& {
    $ProgressPreference = 'SilentlyContinue'
    Invoke-WebRequest -Uri 'https://github.com/GhostPack/PSPKIAudit/archive/main.zip' -OutFile '%TEMP_DIR%\PSPKIAudit.zip'
}"

echo Extracting files...
powershell -Command "& {
    Expand-Archive -Path '%TEMP_DIR%\PKIAudit.zip' -DestinationPath '%TEMP_DIR%' -Force
}"

:: Run the PowerShell installation script
echo Running installation...
powershell -NoProfile -ExecutionPolicy Bypass -Command "& {
    $ErrorActionPreference = 'Stop'
    try {
        # Import module
        Import-Module '%TEMP_DIR%\PSPKIAudit-main\PSPKIAudit.psd1' -Force

        # Run installer with all defaults
        Install-PKIAudit -Force

        Write-Host 'Installation completed successfully.' -ForegroundColor Green
    }
    catch {
        Write-Host 'Error during installation: ' -ForegroundColor Red -NoNewline
        Write-Host $_.Exception.Message
        exit 1
    }
}"

:: Check if installation was successful
if %errorLevel% equ 0 (
    echo.
    echo Installation completed successfully!
    echo You can now use PSPKIAudit commands in PowerShell.
) else (
    echo.
    echo Installation failed. Please check the logs for details.
)

:: Cleanup
echo Cleaning up temporary files...
rd /s /q "%TEMP_DIR%" 2>nul

echo.
echo Press any key to exit...
pause >nul 