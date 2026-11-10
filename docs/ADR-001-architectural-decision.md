# ADR-001: Platform Engineering: Scaling Private Bicep Module Registries with Semantic Versioning

## Status
Accepted

## Service Owner & Sign-Off Authority
Platform Engineering Practice Lead & Principal DevSecOps Architect

## Dominant Artefact
Private Bicep OCI Registry CI/CD Pipeline & Versioning Matrix

## Decision & Refusal Boundary
All production state mutations must pass deterministic pre-flight policy evaluation in `src/Test-BicepModuleSemVerPinning.ps1` and satisfy the 16-test Pester verification contract in `tests/Boundary-Verification.Tests.ps1` before execution.
