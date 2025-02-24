# PSPKIAudit Enhanced Features

## Table of Contents
- [Configuration Management](#configuration-management)
- [Logging System](#logging-system)
- [JSON Export](#json-export)
- [Progress Reporting](#progress-reporting)

## Configuration Management

### Overview
The configuration system allows customization of various aspects of the PKI audit toolkit through a JSON configuration file.

### Usage
```powershell
# Get current configuration
$config = Get-PKIConfig

# Update specific settings
Set-PKIConfig -Settings @{ 
    LogLevel = "Debug"
    EnableMetrics = $false 
}
```

### Available Settings

#### Logging Settings
| Setting | Type | Default | Description |
|---------|------|---------|-------------|
| LogPath | String | "PKIAudit.log" | Path to the log file |
| LogLevel | String | "Info" | Minimum log level (Debug, Info, Warning, Error) |
| EnableConsole | Boolean | true | Enable console output |
| EnableFile | Boolean | true | Enable file logging |

#### Export Settings
| Setting | Type | Default | Description |
|---------|------|---------|-------------|
| DefaultExportPath | String | "exports" | Default directory for exports |
| JsonIndentation | Number | 2 | JSON file indentation spaces |
| MaxJsonDepth | Number | 10 | Maximum depth for JSON serialization |

#### Performance Settings
| Setting | Type | Default | Description |
|---------|------|---------|-------------|
| PageSize | Number | 50000 | Number of records per page |
| MaxParallelism | Number | 4 | Maximum parallel operations |

#### Feature Flags
| Setting | Type | Default | Description |
|---------|------|---------|-------------|
| EnableVerboseProgress | Boolean | true | Show detailed progress |
| EnableMetrics | Boolean | true | Enable metrics collection |

#### Audit Settings
| Setting | Type | Default | Description |
|---------|------|---------|-------------|
| DefaultTemplateFilters | Array | ["UserAuthentication", ...] | Default certificate template filters |

## Logging System

### Overview
The logging system provides structured, configurable logging with multiple output options and log levels.

### Usage
```powershell
Write-PKILog -Message "Processing certificate" -Level Info -Component "CertRequest"
```

### Log Levels
- **Debug**: Detailed information for debugging
- **Info**: General operational information
- **Warning**: Non-critical issues or potential problems
- **Error**: Critical issues that need attention

### Components
Log messages are tagged with components for better organization:
- CertRequest
- PKIAudit
- Export
- Config

### Output Format
```
[2024-02-24 10:30:45] [Info] [CertRequest] Processing certificate request
```

## JSON Export

### Overview
Standardized JSON export functionality with metadata and error handling.

### Usage
```powershell
# Export certificate requests
Get-CertRequest -CAName "DC-CA" -ExportJson -JsonPath "cert-requests.json"
```

### Export Format
```json
{
  "metadata": {
    "type": "CertRequest",
    "timestamp": "2024-02-24T10:30:45.123Z",
    "version": "1.0"
  },
  "data": {
    // Exported data here
  }
}
```

### Export Types
- CertRequest: Certificate request data
- PKIAudit: Audit results
- Template: Certificate template information

## Progress Reporting

### Overview
Enhanced progress reporting for long-running operations.

### Features
- Overall progress tracking
- Sub-task progress reporting
- Estimated time remaining
- Operation counts

### Example Output
```
[Progress] Processing Certificate Authorities (2/5)
[Progress] > Processing Requests (1500/5000)
```

## Best Practices

1. **Configuration**
   - Keep the configuration file in version control
   - Document any custom settings
   - Use environment-specific settings files

2. **Logging**
   - Use appropriate log levels
   - Include relevant context in messages
   - Regularly rotate log files

3. **JSON Export**
   - Use descriptive file names
   - Include date/time in export paths
   - Validate exported data

4. **Performance**
   - Adjust PageSize based on server capacity
   - Monitor memory usage with large exports
   - Use appropriate MaxParallelism for your environment

## Troubleshooting

### Common Issues

1. **Configuration Issues**
   ```powershell
   # Verify configuration
   Get-PKIConfig | Format-List
   ```

2. **Logging Issues**
   - Check file permissions
   - Verify log path exists
   - Check available disk space

3. **Export Issues**
   - Verify export directory permissions
   - Check JSON file format
   - Validate data structure

### Getting Help
- Check the log file for detailed error messages
- Use -Verbose parameter for additional information
- Review configuration settings 