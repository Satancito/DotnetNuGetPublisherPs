# Changelog

## Unreleased

- Added failed process details to publish error JSON, including the displayed command, exit code, and captured stdout/stderr output.

## 2.0.2

- Changed publish package discovery to resolve MSBuild `PackageId` and `PackageVersion` and select `<PackageId>.<PackageVersion>.nupkg` plus the matching `.snupkg` before using timestamp or latest-package fallback.

## 2.0.1

- Fixed package discovery fallback after `dotnet pack` so publish can use the latest existing `.nupkg` and matching `.snupkg` when no package timestamp is newer than the publish start time.

## 2.0.0

- Aligned NuGet publisher command behavior with the shared publisher CLI style while keeping NuGet-specific parameters.
- Added formal `-Set` parameters for `-ApiKey`, `-Source`, `-Configuration`, and `-IncludeSymbols`.
- Changed package project resolution to read the consumer `Project.json` `Project` property instead of storing `NUGET_CSPROJ` as a secret.
- Changed `-Init` to create missing NuGet publisher secrets with NuGet.org-ready defaults.
- Added NuGet source endpoint validation for non-empty `-Set -Source` values and before publish while allowing stored string values to be null or empty.
- Changed NuGet source validation to treat HTTP `401` and `403` responses as valid existing endpoints.
- Tightened publish-time validation for `NUGET_API_KEY`, `NUGET_CONFIGURATION`, and `NUGET_INCLUDE_SYMBOLS` before build or push steps run.
- Changed `NUGET_INCLUDE_SYMBOLS` handling to accept PowerShell boolean values and store the secret as a JSON boolean.
- Changed invalid `-Set -Configuration` and invalid non-empty `-Set -Source` inputs to return `false` instead of throwing.
- Added Azure Artifacts CI environment variable examples.
- Added `.snupkg` symbol package discovery and push support alongside normal `.nupkg` packages.
- Added API key masking for capturable output, command logs, and error JSON.
- Changed capturable commands to return JSON for `-List`, `-Set`, `-Publish`, `-Version`, and errors.
- Removed the repository-local reusable agent guide support.
- Reworked consumer installation documentation to use `ToolsManagerPs`, `ProjectManager.ps1`, and `Project.json`-managed tool dependencies.
- Added Spanish README documentation aligned with the English README.
- Added Spanish release workflow documentation aligned with the English `Version.MD`.
- Restructured the English and Spanish README files to follow the shared publisher documentation format.

## 1.0.6

- Added `-Publish` support for non-empty environment variables to override matching NuGet publisher secrets.

## 1.0.5

- Updated documentation references for the renamed DevSecretsManagerPs agent file: `Agent-DevSecretsManagerPs.MD`.

## 1.0.4

- Renamed the reusable agent instruction file from `NugetPublisher-Agent.MD` to `Agent-DotnetNuGetPublisherPs.MD`.
- Updated operational references in README, release guide, and agent instructions to use `Agent-DotnetNuGetPublisherPs.MD`.
