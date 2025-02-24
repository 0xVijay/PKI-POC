function Export-PKIJson {
    <#
    .SYNOPSIS
    Common function to export PKI audit data to JSON format with proper formatting and error handling.

    .PARAMETER Data
    The data object to export to JSON.

    .PARAMETER OutputPath
    The path where to save the JSON file.

    .PARAMETER Type
    The type of data being exported (e.g., 'CertRequest', 'PKIAudit', 'Template').

    .EXAMPLE
    Export-PKIJson -Data $certRequests -OutputPath "cert-requests.json" -Type "CertRequest"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [Object]
        $Data,

        [Parameter(Mandatory = $true)]
        [String]
        $OutputPath,

        [Parameter(Mandatory = $true)]
        [ValidateSet('CertRequest', 'PKIAudit', 'Template')]
        [String]
        $Type
    )

    try {
        # Create metadata wrapper
        $exportData = @{
            metadata = @{
                type = $Type
                timestamp = (Get-Date).ToString('o')
                version = "1.0"
            }
            data = $Data
        }

        # Convert to JSON with proper formatting
        $jsonContent = $exportData | ConvertTo-Json -Depth 10

        # Ensure directory exists
        $directory = Split-Path -Parent $OutputPath
        if (-not (Test-Path $directory)) {
            New-Item -ItemType Directory -Path $directory -Force | Out-Null
        }

        # Export to file
        $jsonContent | Out-File -FilePath $OutputPath -Encoding UTF8 -Force

        Write-Verbose "Successfully exported $Type data to $OutputPath"
        return $true
    }
    catch {
        Write-Error "Failed to export $Type data to JSON: $_"
        return $false
    }
} 