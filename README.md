# Platform Engineering: Scaling Private Bicep Module Registries with Semantic Versioning

[![Pester Verification](https://img.shields.io/badge/pester-16%2F16%20passing-brightgreen)](tests/BicepSemVer.Tests.ps1)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Architecture Deep-Dive](https://img.shields.io/badge/blog-alerasoul.net-0a1128)](https://alerasoul.net/bicep-module-registry-semantic-governance/)

> **Primary Governance Artefact:** Private Bicep OCI Registry CI/CD Pipeline & Versioning Matrix  
> **Accountable Service Owner:** Platform Engineering Practice Lead & Principal DevSecOps Architect  
> **Full Architectural Deep-Dive:** [https://alerasoul.net/bicep-module-registry-semantic-governance/](https://alerasoul.net/bicep-module-registry-semantic-governance/)

---

## Repository Layout (16 Files)

```text
├── .github/workflows/module-release.yml
├── .gitignore
├── LICENSE
├── README.md
├── bicepconfig.json
├── docs/MODULE-AUTHORING-GUIDE.md
├── docs/SEMVER-GOVERNANCE-SPEC.md
├── fixtures/semver-breaking-diff.json
├── modules/network/vnet/main.bicep
├── modules/network/vnet/version.json
├── modules/security/keyvault/main.bicep
├── modules/security/keyvault/version.json
├── queries/Acr-ModulePull-Telemetry.kql
├── src/Publish-VerifiedBicepModule.ps1
├── src/Test-BicepModuleSemVerPinning.ps1
└── tests/BicepSemVer.Tests.ps1
```

## Quickstart & Offline Verification

```powershell
# 1. Execute the primary PowerShell 7 evaluator
pwsh -NoProfile -File ./src/Test-BicepModuleSemVerPinning.ps1

# 2. Run the 16-test Pester verification contract
Invoke-Pester -Path ./tests/BicepSemVer.Tests.ps1 -Output Detailed
```

## License

Released under the [MIT License](LICENSE). Authored by **Shahrad Alerasoul** ([alerasoul.net](https://alerasoul.net)).
