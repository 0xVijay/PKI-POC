@{

# Script module or binary module file associated with this manifest.
RootModule = 'PSPKIAudit.psm1'

# Version number of this module.
ModuleVersion = '1.2.0'

# ID used to uniquely identify this module
GUID = '6BAE79BD-4BCD-45AC-AA23-533FAEC0DACA'

# Author of this module
Author = 'SpecterOps'

# Company or vendor of this module
CompanyName = 'SpecterOps'

# Copyright statement for this module
Copyright = '(c) 2024 SpecterOps. All rights reserved.'

# Description of the functionality provided by this module
Description = 'PowerShell toolkit for auditing Active Directory Certificate Services (AD CS) with enhanced logging and configuration'

# Minimum version of the Windows PowerShell engine required by this module
PowerShellVersion = '5.1'

# Modules that must be imported into the global environment prior to importing this module
RequiredModules = @('PSPKI', 'ActiveDirectory')

# Functions to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no functions to export.
FunctionsToExport = @(
    'Get-CertRequest',
    'Invoke-PKIAudit',
    'Get-AuditCertificateAuthority',
    'Get-AuditCertificateTemplate',
    'Get-AuditPKIADObjectControllers',
    'Format-PKIAdObjectControllers',
    'Export-PKIJson',
    'Write-PKILog',
    'Get-PKIConfig',
    'Set-PKIConfig',
    'Install-PKIAudit',
    'Test-PKIAuditInstallation',
    'Test-PKIDependencies',
    'Restore-PKIAuditState',
    'New-PKIAuditBackupState'
)

# Private data to pass to the module specified in RootModule/ModuleToProcess. This may also contain a PSData hashtable with additional module metadata used by PowerShell.
PrivateData = @{
    PSData = @{
        # Tags applied to this module. These help with module discovery in online galleries.
        Tags = @('Security', 'PKI', 'Audit', 'ActiveDirectory', 'Certificates', 'Logging', 'Configuration')

        # A URL to the license for this module.
        LicenseUri = 'https://github.com/GhostPack/PSPKIAudit/blob/main/License.md'

        # A URL to the main website for this project.
        ProjectUri = 'https://github.com/GhostPack/PSPKIAudit'

        # Release notes for this version
        ReleaseNotes = @'
- Added JSON export functionality with metadata
- Added configurable logging system
- Added customizable configuration management
- Improved progress reporting
- Enhanced error handling
'@
    }
}
}