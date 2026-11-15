# Test-BicepModuleSemVerPinning.ps1
# Validates PowerShell PSResourceGet / ACR OCI module references for strict 3-part SemVer pinning.
[CmdletBinding()]
param(
    [Parameter(Mandatory)] [string]$ManifestContent,
    [Parameter()] [string]$ApprovedRegistryHost = 'acrsovereignmodules.azurecr.io'
)

$ErrorActionPreference = 'Stop'
$violations = [System.Collections.Generic.List[string]]::new()

# Match OCI / PSResource / container module references (oci://host/repo:tag or br:host/repo:tag or RequiredVersion = 'X.Y.Z')
$ociMatches = [regex]::Matches($ManifestContent, "(?:oci://|br:)([^\s'\""]+)")
foreach ($m in $ociMatches) {
    $ref = $m.Groups[0].Value
    $pathPart = $m.Groups[1].Value

    # 1. Reject floating tags (:latest, :main, :v1, :2.x)
    if ($pathPart -match ':(?:latest|main|master|v?\d+(?:\.x)?)$') {
        $violations.Add("FLOATING_TAG_BANNED: Module reference '$ref' uses a mutable floating tag.")
        continue
    }

    # 2. Enforce approved private ACR OCI registry and full 3-part SemVer (X.Y.Z)
    $expectedPattern = "^(?:oci://|br:)$([regex]::Escape($ApprovedRegistryHost))/[a-z0-9-]+/[a-z0-9-]+/[a-z0-9-]+:v?\d+\.\d+\.\d+$"
    if ($ref -notmatch $expectedPattern) {
        $violations.Add("UNAPPROVED_REGISTRY_OR_SEMVER: Module '$ref' must target '$ApprovedRegistryHost' with strict X.Y.Z SemVer.")
    }
}

# Also validate PSResourceGet RequiredVersion pinning if present
$psResourceMatches = [regex]::Matches($ManifestContent, "Install-PSResource[^\r\n]+")
foreach ($pm in $psResourceMatches) {
    if ($pm.Value -notmatch "-Version\s+['""]?\d+\.\d+\.\d+['""]?") {
        $violations.Add("UNPINNED_PSRESOURCE: '$($pm.Value.Trim())' must pin an exact 3-part -Version X.Y.Z.")
    }
}

return [PSCustomObject]@{
    TotalReferences = ($ociMatches.Count + $psResourceMatches.Count)
    Passed          = ($violations.Count -eq 0)
    Verdict         = if ($violations.Count -eq 0) { 'PERMIT_PINNED_OCI_MODULES' } else { 'VETO_UNPINNED_MODULE_REFERENCE' }
    Violations      = @($violations)
}
