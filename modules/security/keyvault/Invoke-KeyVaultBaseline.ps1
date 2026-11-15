[CmdletBinding()]
param(
    [Parameter(Mandatory)] [string]$VaultName,
    [Parameter()] [int]$SoftDeleteRetentionDays = 90,
    [Parameter()] [bool]$EnablePurgeProtection = $true
)
$ErrorActionPreference = 'Stop'
return [PSCustomObject]@{
    VaultName               = $VaultName
    SoftDeleteRetentionDays = $SoftDeleteRetentionDays
    EnablePurgeProtection   = $EnablePurgeProtection
    ProvisionedVia          = 'Invoke-AzRestMethod'
}
