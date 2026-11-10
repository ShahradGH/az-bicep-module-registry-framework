# Test-BicepModuleSemVerPinning.ps1
[CmdletBinding()]
param(
    [Parameter(Mandatory)] [string]$BicepContent,
    [Parameter()] [string]$ApprovedRegistryHost = 'acrsovereignmodules.azurecr.io'
)

$ErrorActionPreference = 'Stop'
$violations = [System.Collections.Generic.List[string]]::new()

$moduleMatches = [regex]::Matches($BicepContent, "module\s+\w+\s+'([^']+)'")
foreach ($m in $moduleMatches) {
    $ref = $m.Groups[1].Value

    # 1. Reject floating tags (:latest, :main, :v1, :2.x)
    if ($ref -match ':(?:latest|main|master|v?\d+(?:\.x)?)$') {
        $violations.Add("FLOATING_TAG_BANNED: Module reference '$ref' uses a mutable floating tag.")
        continue
    }

    # 2. Enforce approved private ACR OCI registry and full 3-part SemVer (X.Y.Z)
    $expectedPattern = "^br:$([regex]::Escape($ApprovedRegistryHost))/bicep/[a-z0-9-]+/[a-z0-9-]+:v?\d+\.\d+\.\d+$"
    if ($ref.StartsWith('br:') -and $ref -notmatch $expectedPattern) {
        $violations.Add("UNAPPROVED_REGISTRY_OR_SEMVER: Module '$ref' must target '$ApprovedRegistryHost' with strict X.Y.Z SemVer.")
    }
}

return [PSCustomObject]@{
    TotalModules   = $moduleMatches.Count
    Passed         = ($violations.Count -eq 0)
    Verdict        = if ($violations.Count -eq 0) { 'PERMIT_PINNED_OCI_MODULES' } else { 'VETO_UNPINNED_MODULE_REFERENCE' }
    Violations     = @($violations)
}