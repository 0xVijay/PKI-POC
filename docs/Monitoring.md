# PKI Monitoring and Health Checks

## Overview
This document describes the monitoring and health check capabilities added to the PSPKIAudit toolkit.

## Table of Contents
- [Event Monitoring](#event-monitoring)
- [Health Checks](#health-checks)
- [Helper Functions](#helper-functions)
- [Configuration Options](#configuration-options)
- [Best Practices](#best-practices)
- [Troubleshooting](#troubleshooting)

## Event Monitoring

### Critical Event IDs
The module monitors the following critical event IDs:
- **4886**: Certificate Request
- **4887**: Certificate Issued
- **4768**: Kerberos Ticket Request (TGT)

### Usage
```powershell
# Monitor last 24 hours of events
Get-PKIEvent -ExportJson

# Monitor specific time range
Get-PKIEvent -StartTime (Get-Date).AddDays(-7) -EndTime (Get-Date)
```

### Anomaly Detection
The module automatically detects:
- High volume certificate requests
- Failed Kerberos authentication attempts
- Out-of-hours activity

## Health Checks

### Infrastructure Health
Monitors core PKI infrastructure components:
- Root CA status
- Sub CA status
- CRL validity
- OCSP responder availability
- Certificate stores
- PKI services

### Compliance Status
Verifies compliance with security policies:
- Policy settings
- Role configurations
- Security protocols
- Audit settings

### Security Status
Checks for:
- Known vulnerabilities (ESC1-ESC8)
- Security measures
- Network security
- System hardening

### Usage
```powershell
# Run all health checks
Get-PKIHealth -CheckType All -ExportJson

# Run specific check type
Get-PKIHealth -CheckType Infrastructure
```

## Helper Functions

### OCSP Functions
#### Get-OCSPResponders
Retrieves OCSP responders from the PKI infrastructure.
```powershell
$responders = Get-OCSPResponders
```

#### Test-OCSPResponder
Tests OCSP responder availability and response time.
```powershell
$status = Test-OCSPResponder -Responder $responder
```

### CRL Functions
#### Test-CRLValidity
Verifies CRL validity and expiration status.
```powershell
$crlStatus = Test-CRLValidity
```

### Security Functions
#### Test-SecurityProtocol
Tests security protocol configuration and compliance.
```powershell
$tlsStatus = Test-SecurityProtocol -Protocol "TLS 1.2"
```

#### Test-SystemHardening
Verifies system security settings and hardening.
```powershell
$hardeningStatus = Test-SystemHardening
```

## Configuration Options

### Event Monitoring Settings
```powershell
EventAnalysis = @{
    MaxCertRequestsPerHour = 100
    MaxFailedKerberosPerUser = 5
    BusinessHoursStart = 8
    BusinessHoursEnd = 18
    AlertThresholds = @{
        CertRequests = 50
        FailedAuth = 3
        OutOfHours = 10
    }
}
```

### Health Check Settings
```powershell
HealthCheck = @{
    CheckIntervals = @{
        Infrastructure = 300  # 5 minutes
        Compliance = 3600     # 1 hour
        Security = 1800       # 30 minutes
    }
    Thresholds = @{
        CRLExpirationWarning = 168   # 7 days
        CertExpirationWarning = 720  # 30 days
        MaxExpiredCerts = 5
        MinKeyLength = 2048
    }
}
```

## Best Practices

### Event Monitoring
1. **Regular Monitoring**
   - Monitor events at least daily
   - Review anomalies promptly
   - Maintain audit logs

2. **Alert Configuration**
   - Set appropriate thresholds
   - Configure business hours
   - Enable notifications for critical events

3. **Log Management**
   - Rotate logs regularly
   - Archive historical data
   - Maintain sufficient disk space

### Health Checks
1. **Check Frequency**
   - Run infrastructure checks frequently (5-15 minutes)
   - Run compliance checks daily
   - Run security checks hourly

2. **Response Times**
   - Address critical issues immediately
   - Review warnings within 24 hours
   - Maintain response procedures

3. **Maintenance**
   - Update security baselines regularly
   - Review and adjust thresholds
   - Document changes and findings

## Troubleshooting

### Common Issues

1. **Event Collection Failures**
   - Verify event log access
   - Check event log size
   - Validate time ranges

2. **Health Check Errors**
   - Verify service accounts
   - Check network connectivity
   - Validate permissions

3. **Performance Issues**
   - Adjust check intervals
   - Optimize event queries
   - Monitor resource usage

### Logging
All monitoring functions use the common logging system:
```powershell
Write-PKILog -Message "Message" -Level Info -Component "Component"
```

### Error Resolution
1. Check the log file for detailed error messages
2. Verify configuration settings
3. Test network connectivity
4. Validate permissions
5. Review event log settings 