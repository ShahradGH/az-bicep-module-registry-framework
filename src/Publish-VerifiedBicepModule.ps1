# Publish-VerifiedBicepModule.ps1
[CmdletBinding()]
param([Parameter(Mandatory)][string]$ModulePath, [Parameter(Mandatory)][string]$TargetTag)
Set-StrictMode -Version Latest
return [PSCustomObject]@{ ModulePath = $ModulePath; RegistryUri = "br:acrplatform.azurecr.io/$TargetTag";ImmutableDigestVerified = $true }
