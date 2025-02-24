# Changelog
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Enhanced installation module with comprehensive error handling:
  - Network connectivity validation
  - Permission checks
  - Version conflict detection
  - Disk space verification
- Additional validation checks:
  - Certificate store access verification
  - Network port availability testing
  - Domain connectivity validation
- Improved progress reporting:
  - Detailed progress bars for each installation step
  - Time estimates and duration tracking
  - Success/failure summaries
- Comprehensive logging system:
  - Detailed installation logs
  - Error tracking and reporting
  - Installation audit trail
- Automated installation module with Install-PKIAudit function
- System requirements validation
- Automatic dependency installation
- Initial configuration setup
- Installation validation checks
- New Install-PKIAudit.bat script for fully automated installation without user input
- New installation validation system:
  - Test-PKIAuditInstallation for comprehensive installation verification
  - Test-PKIDependencies for dependency version validation
  - Restore-PKIAuditState for rollback functionality
  - New-PKIAuditBackupState for state preservation
- Installation state management:
  - Automatic backup before installation
  - Rollback on failure
  - Detailed status reporting
  - Component-level validation

### Changed
- Simplified installation process by removing uninstall functionality
- Improved dependency management with version validation
- Enhanced error handling with automatic rollback
- Consolidated logging using Write-PKILog

## [1.2.0] - 2024-02-24

### Added
- Event monitoring system for critical PKI events (4886, 4887, 4768)
- Comprehensive PKI health monitoring system
- OCSP responder monitoring and testing
- CRL validity checking
- Security protocol compliance testing
- System hardening verification
- Enhanced JSON export functionality with metadata
- Configurable logging system
- Customizable configuration management
- Progress reporting for long operations
- Detailed documentation for new features

### Enhanced
- Improved error handling across all functions
- Better progress reporting for long-running operations
- More comprehensive logging
- Configuration system now supports nested settings
- Added security baseline checks
- Added compliance monitoring

### Fixed
- Improved error handling in certificate request processing
- Better handling of large event logs
- Enhanced configuration validation
- More robust OCSP testing

* Fix manifest to include RootModule 
* Improved RequiredModules to include minimum version and ensure the correct dependencies are loaded
* Debundle PSPKI as latest version is available on github and newer version may include additional fixes

## [0.3.6] - 2021-09-21

* Fix for the -Requester flag in Get-CertRequest

## [0.3.5] - 2021-06-17

* Bundle PSPKI audit with the code. These will fix https://github.com/GhostPack/PSPKIAudit/issues/1 and some other issues.

## [0.3.4] - 2021-06-17

* Initial release
