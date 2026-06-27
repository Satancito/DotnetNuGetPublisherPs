# Release Version Guide

This file defines the required workflow for publishing changes from this repository to the remote Git repository.

## Release Flow

Do not clear, reset, overwrite, stage, or commit local secrets as part of a release.

Secrets are machine-local values managed by `DevSecretsManagerPs`. They are not release artifacts, they are not part of the Git working tree, and they can vary per developer or build machine.

Only validate that tracked files do not contain real API keys or secret values.

Update the script version in:

```text
NugetPublisher.ps1
```

Choose the next version based on the changes made before editing the version value.

Example version:

```text
1.0.5
```

Use semantic versioning to decide which part of the version must be increased:

- Increase **Major** for breaking changes, removed commands, renamed flags, incompatible output changes, incompatible file format changes, or any change that requires consumers to update their usage.
- Increase **Minor** for new commands, new flags, new behavior, new documentation workflows, or backward-compatible features.
- Increase **Patch** for bug fixes, help text fixes, README fixes, release guide fixes, small internal improvements, or any change that does not alter public behavior.

Examples:

```text
1.0.5 -> 1.0.6  Patch
1.0.5 -> 1.1.0  Minor
1.0.5 -> 2.0.0  Major
```

Also update any documentation that shows the current version, such as:

```text
README.md
Agent-DotnetNuGetPublisherPs.MD
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
Agent-DotnetNuGetPublisherPs.MD
CHANGELOG.md
Version.MD
```

Keep the README as the source of truth for tool usage and available commands. Keep `Agent-DotnetNuGetPublisherPs.MD` focused on installation, dependency layout, and agent workflow only.

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
git add NugetPublisher.ps1 README.md Agent-DotnetNuGetPublisherPs.MD Version.MD CHANGELOG.md
```

Adjust the staged file list to match the actual changes.

## Commit

Create a commit with a message that describes the changes made.

Example:

```powershell
git commit -m "Release 1.0.5"
```

For feature releases, the commit message may include the main change:

```powershell
git commit -m "Release 1.0.5 with updated publisher guidance"
```

## Tag

Create an annotated tag using only the release version.

Example:

```powershell
git tag -a 1.0.5 -m "Release 1.0.5"
```

## Push

Push the branch:

```powershell
git push origin main
```

Push the release tag:

```powershell
git push origin 1.0.5
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
