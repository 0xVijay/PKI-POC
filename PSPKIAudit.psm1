# if($(Get-WindowsCapability -Name "Rsat.CertificateServices.Tools*" -Online).State -eq 'NotPresent') {
#     # Note: try this if there are errors on installation https://www.wincert.net/microsoft-windows/windows-10/cannot-install-rsat-tools-on-windows-10-1809-error0x80244022/
#     Write-Warning "Please install RSAT tools with 'Get-WindowsCapability -Name `"Rsat*`" -Online | Add-WindowsCapability -Online'"
#     exit(1)
# }

# Check for required modules
$requiredModules = @('PSPKI', 'ActiveDirectory')
foreach ($module in $requiredModules) {
    if (-not (Get-Module -Name $module -ListAvailable)) {
        Write-Warning "Required module '$module' is not installed. Please install it first."
        return
    }
}

# Import required modules
try {
    Import-Module PSPKI -Force -ErrorAction Stop
    Import-Module ActiveDirectory -Force -ErrorAction Stop
}
catch {
    Write-Warning "Failed to import required modules: $_"
    return
}

# Load all PowerShell scripts from Code directory and its subdirectories
$scriptPaths = @(
    "$PSScriptRoot\Code\Common",
    "$PSScriptRoot\Code"
)

foreach ($path in $scriptPaths) {
    if (Test-Path $path) {
        Get-ChildItem -Path $path -Recurse -Include *.ps1 | ForEach-Object {
            try {
                Write-Verbose "Loading script: $($_.FullName)"
                . $_.FullName
            }
            catch {
                Write-Warning "Failed to load script $($_.FullName): $_"
            }
        }
    }
}
