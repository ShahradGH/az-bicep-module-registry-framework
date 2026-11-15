BeforeAll {
    $script:RepoRoot = Split-Path -Parent $PSScriptRoot
    $script:PinningPath = Join-Path $script:RepoRoot 'src/Test-BicepModuleSemVerPinning.ps1'
    $script:PublishPath = Join-Path $script:RepoRoot 'src/Publish-VerifiedBicepModule.ps1'
    $script:AiPath = Join-Path $script:RepoRoot 'ai/Invoke-ModuleBreakingChangeReview.ps1'
    $script:GraphPath = Join-Path $script:RepoRoot 'graph/Send-ModuleReleaseApproval.ps1'
    $script:VnetModPath = Join-Path $script:RepoRoot 'modules/network/vnet/Invoke-VnetBaseline.ps1'
    $script:KqlPath = Join-Path $script:RepoRoot 'queries/Acr-ModulePull-Telemetry.kql'
}

Describe 'PowerShell & ACR OCI Module Registry Governance - Verification Matrix' {
    Context 'Positive Path: AST Parsing, SemVer Pinning, OCI Publish & Graph Approval' {
        It 'P-01: All PowerShell scripts parse cleanly with zero AST syntax errors' {
            foreach ($path in @($script:PinningPath, $script:PublishPath, $script:AiPath, $script:GraphPath, $script:VnetModPath)) {
                Test-Path $path | Should -BeTrue
                $errors = $null
                [System.Management.Automation.Language.Parser]::ParseFile($path, [ref]$null, [ref]$errors)
                $errors.Count | Should -Be 0
            }
        }

        It 'P-02: Test-BicepModuleSemVerPinning permits pinned ACR OCI and PSResourceGet X.Y.Z references' {
            $content = @"
oci://acrsovereignmodules.azurecr.io/platform/network/vnet:2.5.0
Install-PSResource -Name Contoso.Platform.Vnet -Repository PlatformACR -Version '2.5.0'
"@
            $res = & $script:PinningPath -ManifestContent $content
            $res.Passed | Should -BeTrue
            $res.Verdict | Should -Be 'PERMIT_PINNED_OCI_MODULES'
        }

        It 'P-03: Invoke-ModuleBreakingChangeReview permits optional parameter addition under MINOR bump' {
            $base = Get-Content $script:VnetModPath -Raw
            $cand = $base -replace '\[Parameter\(\)\] \[bool\]\$EnableDdosProtection = \$false', "[Parameter()] [bool]`$EnableDdosProtection = `$false,`n    [Parameter()] [string]`$DnsServerIp = '172.16.1.4'"
            $res = & $script:AiPath -ModuleName 'network/vnet' -PreviousVersion '2.4.1' -CandidateVersion '2.5.0' -BaselineScriptContent $base -CandidateScriptContent $cand
            $res.Verdict | Should -Be 'PERMIT_NON_BREAKING_RELEASE'
            $res.RequiresMajorBump | Should -BeFalse
        }

        It 'P-04: Invoke-ModuleBreakingChangeReview requires dual-signature approval for MAJOR breaking bump' {
            $base = Get-Content $script:VnetModPath -Raw
            $cand = $base -replace ',?\s*\[Parameter\(\)\] \[bool\]\$EnableDdosProtection = \$false', ''
            $res = & $script:AiPath -ModuleName 'network/vnet' -PreviousVersion '2.4.1' -CandidateVersion '3.0.0' -BaselineScriptContent $base -CandidateScriptContent $cand
            $res.Verdict | Should -Be 'REQUIRE_DUAL_SIGNATURE_MAJOR_APPROVAL'
            $res.RequiresMajorBump | Should -BeTrue
            $res.MigrationNotes.Count | Should -BeGreaterThan 0
        }

        It 'P-05: Publish-VerifiedBicepModule publishes OCI manifest when dual signatures are supplied' {
            $astRes = [PSCustomObject]@{ Verdict = 'REQUIRE_DUAL_SIGNATURE_MAJOR_APPROVAL'; BreakingChanges = @('REMOVED_PARAMETER') }
            $mockRest = { param($m, $u, $b) return [PSCustomObject]@{ digest = 'sha256:abcdef123456' } }
            $res = & $script:PublishPath -ModuleName 'vnet' -TargetVersion '3.0.0' -RegistryHost 'acrsovereignmodules.azurecr.io' -AstReviewResult $astRes -ApproverSignatures @('arch@contoso.com', 'sec@contoso.com') -RestInvoker $mockRest
            $res.Published | Should -BeTrue
            $res.Status | Should -Be 'PUBLISHED_IMMUTABLE_OCI_ARTIFACT'
            $res.ImmutableDigestVerified | Should -BeTrue
        }

        It 'P-06: Send-ModuleReleaseApproval posts Teams Adaptive Card and SharePoint item via Graph v2.x' {
            $mockGraph = { param($m, $u, $b) return [PSCustomObject]@{ id = 'msg-9988' } }
            $astRes = [PSCustomObject]@{
                ModuleName       = 'network/vnet'
                PreviousVersion  = '2.4.1'
                CandidateVersion = '3.0.0'
                Verdict          = 'REQUIRE_DUAL_SIGNATURE_MAJOR_APPROVAL'
                Confidence       = 0.98
                BreakingChanges  = @('REMOVED_PARAMETER: EnableDdosProtection')
                MigrationNotes   = @('Remove -EnableDdosProtection from caller scripts.')
            }
            $res = & $script:GraphPath -AstReviewResult $astRes -TeamId 't1' -ChannelId 'c1' -ReleaseAuditSiteId 's1' -ReleaseAuditListId 'l1' -GraphInvoker $mockGraph
            $res.ApprovalCardSent | Should -BeTrue
            $res.SharePointLogged | Should -BeTrue
        }

        It 'P-07: KQL, docs, README, and diagrams meet minimum engineering standards' {
            (Get-Content $script:KqlPath -Raw) | Should -Match 'where|summarize|project'
            (Get-Item (Join-Path $script:RepoRoot 'docs/SEMVER-GOVERNANCE-SPEC.md')).Length | Should -BeGreaterThan 2000
            (Get-Item (Join-Path $script:RepoRoot 'README.md')).Length | Should -BeGreaterThan 4000
            Test-Path (Join-Path $script:RepoRoot 'diagrams/azure-stencil-registry-topology.png') | Should -BeTrue
        }
    }

    Context 'Negative Path: Floating Tags, Breaking Minor Bumps, Missing Signatures & Zero-Leak' {
        It 'N-01: Test-BicepModuleSemVerPinning vetoes floating :latest and unpinned PSResource' {
            $content = @"
oci://acrsovereignmodules.azurecr.io/platform/network/vnet:latest
Install-PSResource -Name Contoso.Platform.Vnet -Repository PlatformACR
"@
            $res = & $script:PinningPath -ManifestContent $content
            $res.Passed | Should -BeFalse
            $res.Verdict | Should -Be 'VETO_UNPINNED_MODULE_REFERENCE'
            $res.Violations.Count | Should -Be 2
        }

        It 'N-02: Invoke-ModuleBreakingChangeReview rejects removed parameter under PATCH bump' {
            $base = Get-Content $script:VnetModPath -Raw
            $cand = $base -replace ',?\s*\[Parameter\(\)\] \[bool\]\$EnableDdosProtection = \$false', ''
            $res = & $script:AiPath -ModuleName 'network/vnet' -PreviousVersion '2.4.1' -CandidateVersion '2.4.2' -BaselineScriptContent $base -CandidateScriptContent $cand
            $res.Verdict | Should -Be 'REJECT_BREAKING_CHANGE_REQUIRES_MAJOR_BUMP'
        }

        It 'N-03: Invoke-ModuleBreakingChangeReview rejects newly added Mandatory parameter under MINOR bump' {
            $base = Get-Content $script:VnetModPath -Raw
            $cand = $base -replace '\[Parameter\(\)\] \[bool\]\$EnableDdosProtection = \$false', "[Parameter()] [bool]`$EnableDdosProtection = `$false,`n    [Parameter(Mandatory)] [string]`$DdosPlanId"
            $res = & $script:AiPath -ModuleName 'network/vnet' -PreviousVersion '2.4.1' -CandidateVersion '2.5.0' -BaselineScriptContent $base -CandidateScriptContent $cand
            $res.Verdict | Should -Be 'REJECT_BREAKING_CHANGE_REQUIRES_MAJOR_BUMP'
        }

        It 'N-04: Publish-VerifiedBicepModule holds MAJOR release when fewer than 2 signatures provided' {
            $astRes = [PSCustomObject]@{ Verdict = 'REQUIRE_DUAL_SIGNATURE_MAJOR_APPROVAL'; BreakingChanges = @('REMOVED_PARAMETER') }
            $res = & $script:PublishPath -ModuleName 'vnet' -TargetVersion '3.0.0' -RegistryHost 'acrsovereignmodules.azurecr.io' -AstReviewResult $astRes -ApproverSignatures @('arch@contoso.com')
            $res.Published | Should -BeFalse
            $res.Status | Should -Be 'HOLD_AWAITING_DUAL_SIGNATURE_APPROVAL'
        }

        It 'N-05: Send-ModuleReleaseApproval skips Teams card for non-breaking release' {
            $astRes = [PSCustomObject]@{ Verdict = 'PERMIT_NON_BREAKING_RELEASE' }
            $res = & $script:GraphPath -AstReviewResult $astRes -TeamId 't1' -ChannelId 'c1'
            $res.ApprovalCardSent | Should -BeFalse
        }

        It 'N-06: Zero Bicep or Terraform files remain in repository' {
            $iac = @(Get-ChildItem -Path $script:RepoRoot -Recurse -File | Where-Object { $_.Extension -in @('.bicep', '.tf') })
            $iac.Count | Should -Be 0
        }

        It 'N-07: Zero secrets, internal IPs, or internal sequence numbers in repo' {
            $files = Get-ChildItem -Path $script:RepoRoot -Recurse -File | Where-Object { $_.FullName -notmatch '[\\/]\.git[\\/]|[\\/]tests[\\/]' -and $_.Extension -in @('.ps1', '.md', '.json', '.kql') }
            foreach ($f in $files) {
                $raw = Get-Content $f.FullName -Raw
                $raw | Should -Not -Match 'AccountKey=|SharedAccessSignature=|192\.142\.41\.43|mvpfoundry\.alerasoul\.net|Decision Pack 0'
            }
        }

        It 'N-08: MIT LICENSE present and AGENTS.md excluded' {
            Test-Path (Join-Path $script:RepoRoot 'LICENSE') | Should -BeTrue
            Test-Path (Join-Path $script:RepoRoot 'AGENTS.md') | Should -BeFalse
        }
    }
}
