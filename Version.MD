# Release Version Guide

This file defines the required workflow for publishing changes from this repository to the remote Git repository.

## Release Flow

Before committing or tagging a release, clear any local secrets created while validating this repository.

`DotnetNuGetPublisherPs` stores its values through the sibling `DevSecretsManagerPs` tool. From this repository root, the expected development layout is:

```text
..\DevSecretsManagerPs\SecretsManager.ps1
.\NugetPublisher.ps1
```

If local publisher secrets were initialized during validation, clear them with:

```powershell
..\DevSecretsManagerPs\SecretsManager.ps1 -Clear -Force
```

Update the script version in:

```text
NugetPublisher.ps1
```

Choose the next version based on the changes made before editing the version value.

Example version:

```text
1.0.1
```

Use semantic versioning to decide which part of the version must be increased:

- Increase **Major** for breaking changes, removed commands, renamed flags, incompatible output changes, incompatible file format changes, or any change that requires consumers to update their usage.
- Increase **Minor** for new commands, new flags, new behavior, new documentation workflows, or backward-compatible features.
- Increase **Patch** for bug fixes, help text fixes, README fixes, release guide fixes, small internal improvements, or any change that does not alter public behavior.

Examples:

```text
1.0.1 -> 1.0.2  Patch
1.0.1 -> 1.1.0  Minor
1.0.1 -> 2.0.0  Major
```

Also update any documentation that shows the current version, such as:

```text
README.md
NugetPublisher-Agent.MD
```

## Update Help And Documentation

Always update the command help exposed by:

```powershell
.\NugetPublisher.ps1 -Help
```

The `-Help` output must describe the current commands, flags, behavior, return values, and important safety rules.

Also update repository documentation when the change affects usage, installation, release flow, or agent instructions:

```text
README.md
NugetPublisher-Agent.MD
Version.MD
```

Keep the README as the source of truth for tool usage and available commands. Keep `NugetPublisher-Agent.MD` focused on installation, dependency layout, and agent workflow only.

## Validate Before Commit

Validate the PowerShell script before staging:

```powershell
$tokens = $null
$errors = $null
[System.Management.Automation.Language.Parser]::ParseFile((Resolve-Path .\NugetPublisher.ps1), [ref]$tokens, [ref]$errors) | Out-Null
if ($errors.Count -gt 0) {
    $errors | ForEach-Object { $_.Message }
    exit 1
}
```

Confirm the script returns the expected version:

```powershell
.\NugetPublisher.ps1 -Version
```

Confirm usage/help still renders:

```powershell
.\NugetPublisher.ps1
.\NugetPublisher.ps1 -Help
```

If publish-related behavior changed, validate the public commands that do not require pushing a package:

```powershell
.\NugetPublisher.ps1 -List
.\NugetPublisher.ps1 -Set -IncludeSymbols True
.\NugetPublisher.ps1 -Set -IncludeSymbols False
```

## Stage Changes

Stage only the files required for the release.

Do not stage local project environment files or secret files unless the release explicitly requires them.

In normal releases, do not stage:

```text
env.json
.devsecretsmanager
```

Example:

```powershell
git add NugetPublisher.ps1 README.md NugetPublisher-Agent.MD Version.MD
```

Adjust the staged file list to match the actual changes.

## Commit

Create a commit with a message that describes the changes made.

Example:

```powershell
git commit -m "Release 1.0.1"
```

For feature releases, the commit message may include the main change:

```powershell
git commit -m "Release 1.0.1 with updated publisher guidance"
```

## Tag

Create an annotated tag using only the release version.

Example:

```powershell
git tag -a 1.0.1 -m "Release 1.0.1"
```

## Push

Push the branch:

```powershell
git push origin main
```

Push the release tag:

```powershell
git push origin 1.0.1
```

## Final Check

Confirm the working tree is clean or only contains intentionally untracked local files:

```powershell
git status --short
```

Confirm the tag points at the release commit:

```powershell
git tag --points-at HEAD
```
