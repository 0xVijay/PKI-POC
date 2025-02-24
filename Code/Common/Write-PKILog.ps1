function Write-PKILog {
    <#
    .SYNOPSIS
    Common logging function for PKI audit operations with configurable output.

    .PARAMETER Message
    The message to log.

    .PARAMETER Level
    The log level (Info, Warning, Error, Debug).

    .PARAMETER Component
    The component generating the log (e.g., 'CertRequest', 'PKIAudit', 'Export').

    .EXAMPLE
    Write-PKILog -Message "Processing certificate request" -Level Info -Component "CertRequest"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [String]
        $Message,

        [Parameter(Mandatory = $true)]
        [ValidateSet('Info', 'Warning', 'Error', 'Debug')]
        [String]
        $Level,

        [Parameter(Mandatory = $true)]
        [String]
        $Component
    )

    # Get configuration
    $config = Get-PKIConfig
    if (-not $config) {
        $config = @{
            LogPath = "PKIAudit.log"
            LogLevel = "Info"
            EnableConsole = $true
            EnableFile = $true
        }
    }

    # Only log if the level is appropriate
    $levelPriority = @{
        'Debug' = 0
        'Info' = 1
        'Warning' = 2
        'Error' = 3
    }

    if ($levelPriority[$Level] -ge $levelPriority[$config.LogLevel]) {
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        $logMessage = "[$timestamp] [$Level] [$Component] $Message"

        # Console output
        if ($config.EnableConsole) {
            switch ($Level) {
                'Error' { Write-Error $logMessage }
                'Warning' { Write-Warning $logMessage }
                'Info' { Write-Host $logMessage }
                'Debug' { Write-Verbose $logMessage }
            }
        }

        # File output
        if ($config.EnableFile) {
            try {
                $logMessage | Out-File -FilePath $config.LogPath -Append -Encoding UTF8
            }
            catch {
                Write-Error "Failed to write to log file: $_"
            }
        }
    }
} 