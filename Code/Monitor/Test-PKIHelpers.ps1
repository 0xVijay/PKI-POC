function Get-OCSPResponders {
    <#
    .SYNOPSIS
    Gets OCSP responders from the PKI infrastructure.
    #>
    [CmdletBinding()]
    param()

    try {
        Write-PKILog -Message "Getting OCSP responders" -Level Info -Component "HealthCheck"
        
        $responders = @()
        $cas = Get-CertificationAuthority

        foreach ($ca in $cas) {
            $config = $ca.GetOCSPConfiguration()
            if ($config) {
                foreach ($url in $config.URLs) {
                    $responders += @{
                        Name = $ca.Name
                        URL = $url
                        CAName = $ca.Name
                    }
                }
            }
        }

        return $responders
    }
    catch {
        Write-PKILog -Message "Error getting OCSP responders: $_" -Level Error -Component "HealthCheck"
        return @()
    }
}

function Test-OCSPResponder {
    <#
    .SYNOPSIS
    Tests OCSP responder availability and response time.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [PSObject]
        $Responder
    )

    try {
        Write-PKILog -Message "Testing OCSP responder: $($Responder.Name)" -Level Info -Component "HealthCheck"
        
        $result = @{
            Available = $false
            ResponseTime = 0
            LastResponse = $null
            Error = $null
        }

        # Test OCSP response
        $startTime = Get-Date
        $response = Invoke-WebRequest -Uri $Responder.URL -Method Head -UseBasicParsing -ErrorAction Stop
        $endTime = Get-Date

        $result.Available = $response.StatusCode -eq 200
        $result.ResponseTime = ($endTime - $startTime).TotalMilliseconds
        $result.LastResponse = Get-Date

        return $result
    }
    catch {
        Write-PKILog -Message "Error testing OCSP responder: $_" -Level Error -Component "HealthCheck"
        $result.Error = $_.Exception.Message
        return $result
    }
}

function Test-CRLValidity {
    <#
    .SYNOPSIS
    Tests CRL validity and expiration.
    #>
    [CmdletBinding()]
    param()

    try {
        Write-PKILog -Message "Testing CRL validity" -Level Info -Component "HealthCheck"
        
        $config = Get-PKIConfig
        $warningThreshold = $config.HealthCheck.Thresholds.CRLExpirationWarning
        $result = @{
            Valid = $true
            ExpiringCRLs = @()
            ExpiredCRLs = @()
            NextUpdate = $null
        }

        $cas = Get-CertificationAuthority
        foreach ($ca in $cas) {
            $crl = $ca.GetCRL()
            $timeToExpiry = ($crl.NextUpdate - (Get-Date)).TotalHours

            if ($timeToExpiry -lt 0) {
                $result.Valid = $false
                $result.ExpiredCRLs += @{
                    CA = $ca.Name
                    ExpiredSince = $crl.NextUpdate
                }
            }
            elseif ($timeToExpiry -lt $warningThreshold) {
                $result.ExpiringCRLs += @{
                    CA = $ca.Name
                    ExpiresIn = $timeToExpiry
                    NextUpdate = $crl.NextUpdate
                }
            }

            if (-not $result.NextUpdate -or $crl.NextUpdate -lt $result.NextUpdate) {
                $result.NextUpdate = $crl.NextUpdate
            }
        }

        return $result
    }
    catch {
        Write-PKILog -Message "Error testing CRL validity: $_" -Level Error -Component "HealthCheck"
        return @{ Valid = $false; Error = $_.Exception.Message }
    }
}

function Test-SecurityProtocol {
    <#
    .SYNOPSIS
    Tests security protocol configuration and compliance.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Protocol
    )

    try {
        Write-PKILog -Message "Testing security protocol: $Protocol" -Level Info -Component "HealthCheck"
        
        $result = @{
            Protocol = $Protocol
            Enabled = $false
            Compliant = $false
            CipherSuites = @()
            Recommendations = @()
        }

        # Get registry settings
        $protocolKey = "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\$Protocol\Server"
        if (Test-Path $protocolKey) {
            $enabled = (Get-ItemProperty -Path $protocolKey -Name "Enabled" -ErrorAction SilentlyContinue).Enabled
            $result.Enabled = $enabled -eq 1

            # Get cipher suites
            $cipherSuites = Get-TlsCipherSuite | Where-Object { $_.TlsVersion -eq $Protocol }
            $result.CipherSuites = $cipherSuites | ForEach-Object { $_.Name }

            # Check compliance
            $config = Get-PKIConfig
            $requiredCiphers = $config.HealthCheck.SecurityBaseline.RequiredCipherSuites
            $missingCiphers = $requiredCiphers | Where-Object { $_ -notin $result.CipherSuites }

            $result.Compliant = $result.Enabled -and (-not $missingCiphers)
            
            if (-not $result.Enabled) {
                $result.Recommendations += "Enable $Protocol"
            }
            foreach ($cipher in $missingCiphers) {
                $result.Recommendations += "Add cipher suite: $cipher"
            }
        }
        else {
            $result.Recommendations += "$Protocol configuration not found"
        }

        return $result
    }
    catch {
        Write-PKILog -Message "Error testing security protocol: $_" -Level Error -Component "HealthCheck"
        return @{ Protocol = $Protocol; Error = $_.Exception.Message }
    }
}

function Test-SystemHardening {
    <#
    .SYNOPSIS
    Tests system hardening configuration and security settings.
    #>
    [CmdletBinding()]
    param()

    try {
        Write-PKILog -Message "Testing system hardening" -Level Info -Component "HealthCheck"
        
        $result = @{
            Compliant = $true
            Checks = @{}
            Recommendations = @()
        }

        # Check security policies
        $securityPolicies = @{
            "PasswordComplexity" = @{
                Path = "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa"
                Name = "PasswordComplexity"
                Expected = 1
            }
            "AuditLogonEvents" = @{
                Path = "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa"
                Name = "AuditLogonEvents"
                Expected = 1
            }
        }

        foreach ($policy in $securityPolicies.GetEnumerator()) {
            $actual = (Get-ItemProperty -Path $policy.Value.Path -Name $policy.Value.Name -ErrorAction SilentlyContinue).$($policy.Value.Name)
            $compliant = $actual -eq $policy.Value.Expected
            $result.Checks[$policy.Key] = $compliant
            
            if (-not $compliant) {
                $result.Compliant = $false
                $result.Recommendations += "Set $($policy.Key) to $($policy.Value.Expected)"
            }
        }

        # Check services
        $services = @{
            "RemoteRegistry" = "Disabled"
            "LanmanServer" = "Automatic"
        }

        foreach ($svc in $services.GetEnumerator()) {
            $service = Get-Service -Name $svc.Key -ErrorAction SilentlyContinue
            $compliant = $service.StartType -eq $svc.Value
            $result.Checks["Service_$($svc.Key)"] = $compliant
            
            if (-not $compliant) {
                $result.Compliant = $false
                $result.Recommendations += "Set service $($svc.Key) to $($svc.Value)"
            }
        }

        # Check firewall
        $firewallEnabled = (Get-NetFirewallProfile -All).Enabled
        $result.Checks["Firewall"] = $firewallEnabled -notcontains $false
        
        if ($firewallEnabled -contains $false) {
            $result.Compliant = $false
            $result.Recommendations += "Enable firewall for all profiles"
        }

        return $result
    }
    catch {
        Write-PKILog -Message "Error testing system hardening: $_" -Level Error -Component "HealthCheck"
        return @{ Compliant = $false; Error = $_.Exception.Message }
    }
} 