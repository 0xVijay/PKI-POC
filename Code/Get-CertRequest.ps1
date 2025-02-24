function Get-CertRequest {
    <#
    .SYNOPSIS

    Returns issued certificate requests with augmented security information.

    License: Ms-PL
    Required Dependencies: PSPKI

    .PARAMETER CAComputerName

    The name of the Certificate Authority computer to enumerate requests for.

    .PARAMETER CAName

    The name of the Certificate Authority to enumerate requests for.

    .PARAMETER HasSAN

    Switch. Only return issued certificates that has a Subject Alternative Name specified in the request.

    .PARAMETER Requester

    'DOMAIN\user' format. Only return issued certificate requests for the requester.

    .PARAMETER Template

    Only return return issued certificate requests for the specified template name.

    .PARAMETER Filter

    Custom filter to search for issued certificates.

    .PARAMETER ExportJson

    Switch. Export the results to JSON file.

    .PARAMETER JsonPath

    Path where to save the JSON file. Defaults to "cert-requests.json" in current directory.

    .EXAMPLE

    Get-CertRequest -CAName "theshire-DC-CA" -HasSAN -ExportJson

    Return requests with SANs for the "theshire-DC-CA" and export to JSON.

    .EXAMPLE

    Get-CertRequest -CAComputerName dc.theshire.local -Requester THESHIRE\cody

    Return requests issue by THESHIRE\cody from the dc.theshire.local CA.

    .EXAMPLE

    Get-CertRequest -Template "VulnTemplate"

    Return requests for the "VulnTemplate" certificate template.
    #>
    [CmdletBinding()]
    Param(
        [Parameter()]
        [String]
        $CAComputerName,

        [Parameter()]
        [String]
        $CAName,

        [Switch]
        $HasSAN,

        [String]
        $Requester,

        [String]
        [Alias('TemplateName', 'CertificateTemplate')]
        $Template,

        [String]
        $Filter,

        [Switch]
        $ExportJson,

        [String]
        $JsonPath = "cert-requests.json"
    )

    # Progress tracking variables
    $progressId = Get-Random
    $activity = "Processing Certificate Requests"
    $totalCAs = 0
    $currentCA = 0

    if($Requester -and (-not $Requester.Contains("\"))) {
        Write-Warning "-Requester must be of form 'DOMAIN\user'"
        return
    }

    $Filter = $Null
    if($Requester) {
        $Filter = "Request.RequesterName -eq $Requester"
    }

    $CAs = @()

    if($CAComputerName) {
        $CAs = Get-CertificationAuthority -ComputerName $CAComputerName
    }
    elseif($CAName) {
        $CAs = Get-CertificationAuthority -Name $CAName
    }
    else {
        $CAs = Get-CertificationAuthority
    }
    
    $totalCAs = $CAs.Count
    $results = @()

    foreach($CA in $CAs) {
        $currentCA++
        Write-Progress -Id $progressId -Activity $activity -Status "Processing CA $currentCA of $totalCAs" -PercentComplete (($currentCA / $totalCAs) * 100)

        if($Filter) {
            Write-Verbose "Filter: $Filter"
            $caResults = $CA | Get-IssuedRequest -Filter "$Filter" -Property @('Request.RequesterName', 'Request.SubmittedWhen', 'CertificateTemplateOid', 'RequestID', 'ConfigString', 'Request.RawRequest') | ForEach-Object {
                    $IssuedRequest = $_ | Add-CertRequestInformation
                    $IssuedRequest | Select-Object -Property `
                    @{N='CA'; E={$_.ConfigString}}, `
                    @{N='RequestID'; E={$_.RequestID}}, `
                    @{N='RequesterName'; E={$_.'Request.RequesterName'}}, `
                    @{N='RequesterMachineName'; E={$_.MachineName}}, `
                    @{N='RequesterProcessName'; E={$_.ProcessName}}, `
                    @{N='SubjectAltNamesExtension'; E={$_.SubjectAltNamesExtension}}, `
                    @{N='SubjectAltNamesAttrib'; E={$_.SubjectAltNamesAttrib}}, `
                    @{N='SerialNumber'; E={$_.SerialNumber}}, `
                    @{N='CertificateTemplate'; E={$_.CertificateTemplateOid}}, `
                    @{N='RequestDate'; E={$_.'Request.SubmittedWhen'}}, `
                    @{N='StartDate'; E={$_.NotBefore}}, `
                    @{N='EndDate'; E={$_.NotAfter}}
            }
            $results += $caResults
        }
        else {
            # from https://github.com/PKISolutions/PSPKI/issues/144
            $PageSize = 50000
            $LastID = 0
            $totalProcessed = 0

            do {
                $ReadRows = 0
                $pageResults = @()
                
                $CA | Get-IssuedRequest -Filter "$($Filter)RequestID -gt $LastID" -Page 1 -PageSize $PageSize -Property @('Request.RequesterName', 'Request.SubmittedWhen', 'CertificateTemplateOid', 'RequestID', 'ConfigString', 'Request.RawRequest') | ForEach-Object {
                    $ReadRows++
                    $totalProcessed++
                    $LastID = $_.Properties["RequestID"]

                    Write-Progress -Id ($progressId + 1) -ParentId $progressId -Activity "Processing Requests" -Status "Processed $totalProcessed requests" -PercentComplete -1

                    $IssuedRequest = $_ | Add-CertRequestInformation
                    $pageResults += $IssuedRequest | Select-Object -Property `
                    @{N='CA'; E={$_.ConfigString}}, `
                    @{N='RequestID'; E={$_.RequestID}}, `
                    @{N='RequesterName'; E={$_.'Request.RequesterName'}}, `
                    @{N='RequesterMachineName'; E={$_.MachineName}}, `
                    @{N='RequesterProcessName'; E={$_.ProcessName}}, `
                    @{N='SubjectAltNamesExtension'; E={$_.SubjectAltNamesExtension}}, `
                    @{N='SubjectAltNamesAttrib'; E={$_.SubjectAltNamesAttrib}}, `
                    @{N='SerialNumber'; E={$_.SerialNumber}}, `
                    @{N='CertificateTemplate'; E={$_.CertificateTemplateOid}}, `
                    @{N='RequestDate'; E={$_.'Request.SubmittedWhen'}}, `
                    @{N='StartDate'; E={$_.NotBefore}}, `
                    @{N='EndDate'; E={$_.NotAfter}}
                }

                # Filter results based on SAN and Template parameters
                $filteredResults = $pageResults | Where-Object {
                    $include = $true
                    if($HasSAN) {
                        $include = $include -and ($_.SubjectAltNamesExtension -or $_.SubjectAltNamesAttrib)
                    }
                    if($Template) {
                        $include = $include -and ($_.CertificateTemplate -match $Template)
                    }
                    $include
                }

                $results += $filteredResults

            } while ($ReadRows -eq $PageSize)
        }
    }

    Write-Progress -Id $progressId -Activity $activity -Completed
    Write-Progress -Id ($progressId + 1) -Activity "Processing Requests" -Completed

    # Export to JSON if requested
    if($ExportJson) {
        $exportResult = Export-PKIJson -Data $results -OutputPath $JsonPath -Type "CertRequest"
        if($exportResult) {
            Write-Host "Results exported to $JsonPath"
        }
    }

    return $results
}



function Add-CertRequestInformation {
    <#
    .SYNOPSIS
    
    Adds SAN and REQUEST_CLIENT_INFO parsing to a raw AdcsDbRow.

    License: Ms-PL
    Required Dependencies: None
    #>
    [CmdletBinding()]
    Param(
        [Parameter(Position = 0, Mandatory = $True, ValueFromPipeline = $True)]
        [SysadminsLV.PKI.Management.CertificateServices.Database.AdcsDbRow]
        $Request
    )

    $MachineName = ""
    $UserName = ""
    $ProcessName = ""
    $AltNameExtensions = @()
    $AltNameValuePairs = @()

    try {
        $RawRequestBytes = [Convert]::FromBase64String($Request.'Request.RawRequest')

        if($RawRequestBytes.Length -gt 0) {
            try {
                $CertRequest = New-Object SysadminsLV.PKI.Cryptography.X509Certificates.X509CertificateRequest (,$RawRequestBytes)
            }
            catch {
                Write-Verbose "Error parsing RequestID: $($Request.RequestID): $_"
                return
            }

            # scenario 1 for SAN specification -> using the explicit X509SubjectAlternativeNamesExtension
            #   this occurs with the EnrolleeSuppliesSubject scenario
            $Alt = $CertRequest.Extensions | Where-Object {$_.GetType().Name -eq "X509SubjectAlternativeNamesExtension"}
            $AltNameExtensions += $Alt.AlternativeNames.Value

            $CertRequest.Attributes | ForEach-Object {
                if($_.Oid.Value -eq "1.3.6.1.4.1.311.21.20") {
                    # format - https://docs.microsoft.com/en-us/openspecs/windows_protocols/ms-wcce/64e5ff6d-c6dd-4578-92f7-b3d895f9b9c7
                    $ASN = New-Object SysadminsLV.Asn1Parser.Asn1Reader @(,$_.RawData)
                    if(($ASN.Tag -eq 48) -and $ASN.MoveNext() -and ($ASN.Tag -eq 2) -and $ASN.MoveNext() -and ($ASN.Tag -eq 12)) {
                        $Bytes = $ASN.GetPayload()
                        $Encoding = [System.Text.UnicodeEncoding]::ASCII
                        if($Bytes -cmatch '[^\x20-\x7F]') {
                            $Encoding = [System.Text.UnicodeEncoding]::Unicode
                        }
                        $MachineName = $Encoding.GetString($asn.GetPayload())
                        $Null = $ASN.MoveNext()
                        $UserName = $Encoding.GetString($asn.GetPayload())
                        $Null = $ASN.MoveNext()
                        $ProcessName = $Encoding.GetString($asn.GetPayload())
                    }
                }
                if($_.Oid.Value -eq "1.3.6.1.4.1.311.13.2.1") {
                    # "Enrollment Name Value Pair"
                    $Index = 0
                    $Len = $_.RawData.Length
                    while($Index -lt $Len) {
                        $ASN = New-Object SysadminsLV.Asn1Parser.Asn1Reader @(,$_.RawData[$index..$Len])
                        $TagLen = $ASN.TagLength

                        if($ASN.Tag -eq 48) {
                            while($ASN.MoveNext()) {
                                $Name = [System.Text.UnicodeEncoding]::BigEndianUnicode.GetString($ASN.GetPayload())
                                $Null = $ASN.MoveNext()
                                if($Name -eq "SAN") {
                                    # scenario 2 for SAN specification -> attrib/name value pairs
                                    #   this occurs with the EDITF_ATTRIBUTESUBJECTALTNAME2 scenario
                                    $Value = [System.Text.UnicodeEncoding]::BigEndianUnicode.GetString($ASN.GetPayload())
                                    $AltNameValuePairs += $Value.Split("=")[-1]
                                }
                            }
                        }
                        $Index += $TagLen
                    }
                }
            }
        }
    }
    catch {
        Write-Error $_
    }

    $SubjectAltNamesExtension = $($AltNameExtensions | Sort-Object -Unique) -join "|"
    $SubjectAltNamesAttrib = $($AltNameValuePairs | Sort-Object -Unique) -join "|"
    $Request | Add-Member NoteProperty 'MachineName' $MachineName
    $Request | Add-Member NoteProperty 'UserName' $UserName
    $Request | Add-Member NoteProperty 'ProcessName' $ProcessName
    $Request | Add-Member NoteProperty 'SubjectAltNamesExtension' $SubjectAltNamesExtension
    $Request | Add-Member NoteProperty 'SubjectAltNamesAttrib' $SubjectAltNamesAttrib
    $Request
}