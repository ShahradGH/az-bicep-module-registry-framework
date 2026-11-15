# Semantic Versioning 2.0.0 & ACR OCI Registry Governance Specification

## 1. Supply-Chain Pinning Invariants

Platform modules distributed via Azure Container Registry (ACR) OCI artefacts and `PSResourceGet` repositories must never rely on mutable floating tags (`:latest`, `:main`, `:master`, `:v1`, `:2.x`). Every consumer reference is validated by `src/Test-BicepModuleSemVerPinning.ps1` against two hard invariants:

1. **Approved Registry Host**: References must target the private ACR instance (`acrsovereignmodules.azurecr.io`) reachable exclusively over Private Link.
2. **Strict Three-Part SemVer (`X.Y.Z`)**: Both OCI URIs (`oci://acrsovereignmodules.azurecr.io/platform/network/vnet:2.4.1`) and `Install-PSResource -Version '2.4.1'` commands must pin an exact `MAJOR.MINOR.PATCH` version.

## 2. AST-Verified Breaking Change Classification

Manual PR reviews routinely miss subtle breaking changes in PowerShell platform modules. `ai/Invoke-ModuleBreakingChangeReview.ps1` uses `[System.Management.Automation.Language.Parser]::ParseInput` to compare the `ParamBlockAst` of the baseline and candidate module scripts:

| AST Change Detected | Classification | Permitted SemVer Bump |
|---|---|---|
| Parameter removed from `ParamBlock` | Breaking | `MAJOR` (`X+1.0.0`) |
| Parameter static type changed (e.g. `string` to `int`) | Breaking | `MAJOR` (`X+1.0.0`) |
| Optional parameter became `[Parameter(Mandatory)]` without default | Breaking | `MAJOR` (`X+1.0.0`) |
| New `[Parameter(Mandatory)]` parameter added without default | Breaking | `MAJOR` (`X+1.0.0`) |
| Optional parameter added with default value | Non-Breaking | `MINOR` or `PATCH` |

If a breaking change is detected under a `PATCH` or `MINOR` bump, the gate emits `REJECT_BREAKING_CHANGE_REQUIRES_MAJOR_BUMP` and blocks publication.

## 3. Dual-Signature Major Release Escalation

When a `MAJOR` version bump is proposed:
1. `graph/Send-ModuleReleaseApproval.ps1` dispatches an Adaptive Card to the Platform Engineering Microsoft Teams channel via Microsoft Graph v2.x (`POST /v1.0/teams/{teamId}/channels/{channelId}/messages`) containing the AST diff and AI-generated migration notes.
2. `src/Publish-VerifiedBicepModule.ps1` enforces `HOLD_AWAITING_DUAL_SIGNATURE_APPROVAL` until two independent approver signatures (Platform Architect and Security Reviewer) are supplied.
3. Once approved, the OCI manifest is pushed to ACR via `PUT /v2/platform/{module}/manifests/{X.Y.Z}` with immutable tag locking and SHA-256 digest verification.
