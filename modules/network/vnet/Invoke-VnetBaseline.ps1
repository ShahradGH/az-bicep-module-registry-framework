[CmdletBinding()]
param(
    [Parameter(Mandatory)] [string]$VnetName,
    [Parameter(Mandatory)] [string]$AddressPrefix,
    [Parameter()] [bool]$EnableDdosProtection = $false
)
$ErrorActionPreference = 'Stop'
return [PSCustomObject]@{
    VnetName             = $VnetName
    AddressPrefix        = $AddressPrefix
    EnableDdosProtection = $EnableDdosProtection
    ProvisionedVia       = 'Invoke-AzRestMethod'
}
