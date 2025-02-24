function Get-PKIEvent {
    <#
    .SYNOPSIS
    Monitors and analyzes critical PKI-related event IDs.

    .DESCRIPTION
    Collects and analyzes PKI-related events from Windows Event logs, focusing on certificate
    operations and Kerberos ticket requests.

    .PARAMETER StartTime
    The start time for event collection. Defaults to 24 hours ago.

    .PARAMETER EndTime
    The end time for event collection. Defaults to current time.

    .PARAMETER EventIDs
    Array of event IDs to monitor. Defaults to @(4886, 4887, 4768).

    .PARAMETER ExportJson
    Switch to export results to JSON.

    .PARAMETER JsonPath
    Path for JSON export. Defaults to "pki-events.json".

    .EXAMPLE
    Get-PKIEvent -StartTime (Get-Date).AddDays(-1) -ExportJson
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [DateTime]
        $StartTime = (Get-Date).AddDays(-1),

        [Parameter()]
        [DateTime]
        $EndTime = (Get-Date),

        [Parameter()]
        [int[]]
        $EventIDs = @(4886, 4887, 4768),

        [Switch]
        $ExportJson,

        [String]
        $JsonPath = "pki-events.json"
    )

    try {
        Write-PKILog -Message "Starting PKI event collection" -Level Info -Component "EventMonitor"

        # Initialize results collection
        $events = @{
            CertificateRequests = @()
            CertificatesIssued = @()
            KerberosRequests = @()
            Anomalies = @()
        }

        # Get configuration
        $config = Get-PKIConfig
        
        # Create filter XPath query
        $filterXPath = "Event[System[TimeCreated[@SystemTime>='{0}' and @SystemTime<='{1}']] and System[EventID='4886' or EventID='4887' or EventID='4768']]" -f $StartTime.ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss.000Z"), $EndTime.ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss.000Z")

        Write-PKILog -Message "Collecting events from $StartTime to $EndTime" -Level Info -Component "EventMonitor"

        # Get events from Security log
        $securityEvents = Get-WinEvent -LogName Security -FilterXPath $filterXPath -ErrorAction SilentlyContinue

        foreach ($event in $securityEvents) {
            $eventData = @{
                TimeCreated = $event.TimeCreated
                EventID = $event.Id
                MachineName = $event.MachineName
                UserId = $event.UserId
                Message = $event.Message
                Properties = $event.Properties | ForEach-Object { $_.Value }
            }

            # Categorize events
            switch ($event.Id) {
                4886 {
                    $events.CertificateRequests += @{
                        TimeStamp = $eventData.TimeCreated
                        Requester = $eventData.Properties[1]
                        Template = $eventData.Properties[4]
                        Status = $eventData.Properties[6]
                    }
                }
                4887 {
                    $events.CertificatesIssued += @{
                        TimeStamp = $eventData.TimeCreated
                        Requester = $eventData.Properties[1]
                        Template = $eventData.Properties[4]
                        SerialNumber = $eventData.Properties[8]
                    }
                }
                4768 {
                    $events.KerberosRequests += @{
                        TimeStamp = $eventData.TimeCreated
                        User = $eventData.Properties[0]
                        Domain = $eventData.Properties[1]
                        TicketOptions = $eventData.Properties[3]
                        Status = $eventData.Properties[5]
                    }
                }
            }
        }

        # Analyze for anomalies
        $events.Anomalies = Find-PKIEventAnomaly -Events $events

        # Export to JSON if requested
        if ($ExportJson) {
            $exportResult = Export-PKIJson -Data $events -OutputPath $JsonPath -Type "PKIEvent"
            if ($exportResult) {
                Write-PKILog -Message "Events exported to $JsonPath" -Level Info -Component "EventMonitor"
            }
        }

        return $events
    }
    catch {
        Write-PKILog -Message "Error collecting PKI events: $_" -Level Error -Component "EventMonitor"
        throw $_
    }
}

function Find-PKIEventAnomaly {
    <#
    .SYNOPSIS
    Analyzes PKI events for potential anomalies and security incidents.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]
        $Events
    )

    $anomalies = @()
    
    # Get configuration for thresholds
    $config = Get-PKIConfig
    $thresholds = $config.EventAnalysis

    # Check for rapid certificate requests
    $timeGroups = $Events.CertificateRequests | 
        Group-Object -Property { $_.TimeStamp.ToString("yyyy-MM-dd-HH") }

    foreach ($group in $timeGroups) {
        if ($group.Count -gt $thresholds.MaxCertRequestsPerHour) {
            $anomalies += @{
                Type = "HighVolumeRequests"
                Time = $group.Name
                Count = $group.Count
                Details = "Unusually high number of certificate requests"
            }
        }
    }

    # Check for failed Kerberos requests
    $failedKerberos = $Events.KerberosRequests | 
        Where-Object { $_.Status -ne 0 } |
        Group-Object -Property User

    foreach ($failure in $failedKerberos) {
        if ($failure.Count -gt $thresholds.MaxFailedKerberosPerUser) {
            $anomalies += @{
                Type = "KerberosFailure"
                User = $failure.Name
                Count = $failure.Count
                Details = "Multiple failed Kerberos authentication attempts"
            }
        }
    }

    # Check for certificate requests outside business hours
    $outsideHours = $Events.CertificateRequests | 
        Where-Object { 
            $hour = $_.TimeStamp.Hour
            $hour -lt $thresholds.BusinessHoursStart -or 
            $hour -gt $thresholds.BusinessHoursEnd
        }

    if ($outsideHours.Count -gt 0) {
        $anomalies += @{
            Type = "OutOfHoursActivity"
            Count = $outsideHours.Count
            Details = "Certificate requests outside business hours"
            Requests = $outsideHours
        }
    }

    return $anomalies
} 