# NuGet Publisher Agent Guide

This file defines the required workflow for installing `DotnetNuGetPublisherPs` inside a containing repository.

## Required Location

The containing repository must have these two tool directories:

```text
Tools/DevSecretsManagerPs
Tools/DotnetNuGetPublisherPs
```

Both directories must be Git submodules.

Required paths:

```text
Tools/DevSecretsManagerPs/SecretsManager.ps1
Tools/DotnetNuGetPublisherPs/NugetPublisher.ps1
```

Do not install either tool in another folder. `NugetPublisher.ps1` directly calls:

```powershell
..\DevSecretsManagerPs\SecretsManager.ps1
```

That relative path works because both tools live under `Tools`.

## Add Or Update The Submodules

From the root of the containing repository, first check whether both submodules already exist:

```text
Tools/DevSecretsManagerPs
Tools/DotnetNuGetPublisherPs
```

If `DevSecretsManagerPs` does not exist, add it with:

```powershell
git submodule add https://github.com/Satancito/DevSecretsManagerPs.git Tools/DevSecretsManagerPs
```

If `DotnetNuGetPublisherPs` does not exist, add it with:

```powershell
git submodule add https://github.com/Satancito/DotnetNuGetPublisherPs.git Tools/DotnetNuGetPublisherPs
```

After adding either submodule, or when either submodule already exists, always synchronize, initialize, and update both:

```powershell
git submodule sync --recursive Tools/DevSecretsManagerPs
git submodule update --init --recursive Tools/DevSecretsManagerPs
git submodule update --remote --recursive Tools/DevSecretsManagerPs

git submodule sync --recursive Tools/DotnetNuGetPublisherPs
git submodule update --init --recursive Tools/DotnetNuGetPublisherPs
git submodule update --remote --recursive Tools/DotnetNuGetPublisherPs
```

## Apply DevSecretsManagerPs Instructions First

After `Tools/DevSecretsManagerPs` exists, follow the instructions in:

```text
Tools/DevSecretsManagerPs/SecretsManager-Agent.MD
```

That guide controls how the secrets manager is installed, updated, copied to the containing repository root, initialized, and validated.

Do not skip that workflow. `NugetPublisher.ps1` depends on `SecretsManager.ps1`.

## Copy This Guide

This file must exist in the root of the containing repository where the publisher is installed.

Recommended target path in the containing repository:

```text
NugetPublisher-Agent.MD
```

Copy it from the publisher submodule:

```text
Tools/DotnetNuGetPublisherPs/NugetPublisher-Agent.MD -> NugetPublisher-Agent.MD
```

The copied file should stay updated in the containing repository root so agents can invoke a predictable repository-local instruction file without searching inside the submodule.

During updates, copy this guide to the containing repository root only when the `Tools/DotnetNuGetPublisherPs` submodule revision changed. This avoids unnecessary file copies and commits.

## Stage And Commit

When either submodule was added for the first time, stage the submodule references, `.gitmodules`, and copied guides:

```powershell
git add .gitmodules Tools/DevSecretsManagerPs Tools/DotnetNuGetPublisherPs SecretsManager-Agent.MD NugetPublisher-Agent.MD
git commit -m "Add NuGet publisher and secrets manager submodules"
```

When updating existing submodules, only stage and commit when a submodule revision actually changes.

If `Tools/DevSecretsManagerPs` changes, also copy and stage:

```text
SecretsManager-Agent.MD
```

If `Tools/DotnetNuGetPublisherPs` changes, also copy and stage:

```text
NugetPublisher-Agent.MD
```

Example update commit:

```powershell
git add Tools/DevSecretsManagerPs Tools/DotnetNuGetPublisherPs SecretsManager-Agent.MD NugetPublisher-Agent.MD
git commit -m "Update NuGet publisher and secrets manager submodules"
```

If only one submodule changed, stage only that submodule and its copied guide.

## Tool Documentation

Tool usage, behavior, and available commands are documented in:

```text
Tools/DotnetNuGetPublisherPs/README.md
```

Do not duplicate full command usage in this agent guide. Treat the publisher README as the source of truth for `NugetPublisher.ps1` commands, flags, required secrets, and examples.

## Before Running The Tool

Before running the publisher from a containing repository, synchronize, initialize, and update both submodules from the containing repository root:

```powershell
git submodule sync --recursive Tools/DevSecretsManagerPs
git submodule update --init --recursive Tools/DevSecretsManagerPs
git submodule update --remote --recursive Tools/DevSecretsManagerPs

git submodule sync --recursive Tools/DotnetNuGetPublisherPs
git submodule update --init --recursive Tools/DotnetNuGetPublisherPs
git submodule update --remote --recursive Tools/DotnetNuGetPublisherPs
```

Then initialize the publisher secrets:

```powershell
.\Tools\DotnetNuGetPublisherPs\NugetPublisher.ps1 -Init
```

List configured values:

```powershell
.\Tools\DotnetNuGetPublisherPs\NugetPublisher.ps1 -List
```

The publisher uses only these secrets:

```text
NUGET_API_KEY
NUGET_SOURCE
NUGET_CSPROJ
NUGET_CONFIGURATION
NUGET_INCLUDE_SYMBOLS
```

Secret values are stored by `DevSecretsManagerPs` in the user's home directory, not in the containing repository.

## Required Publish Workflow

Publishing must be explicit:

```powershell
.\Tools\DotnetNuGetPublisherPs\NugetPublisher.ps1 -Publish
```

Running the script with no flags must only show usage/help:

```powershell
.\Tools\DotnetNuGetPublisherPs\NugetPublisher.ps1
```

Before publishing, every required secret must exist and have a non-empty value. If any required value is missing, null, empty, or invalid, `-Publish` must fail before running `dotnet build`, `dotnet pack`, or `dotnet nuget push`.

The publish flow is:

```text
dotnet build
dotnet pack
dotnet nuget push
```

Internal defaults:

```text
SkipPack: False
SkipPush: False
NoRestore: False
```

These defaults are not stored in secrets.

## Agent Rules

When working in a repository that uses this tool:

- Treat `Tools/DevSecretsManagerPs` as the required secrets manager submodule path.
- Treat `Tools/DotnetNuGetPublisherPs` as the required NuGet publisher submodule path.
- Use submodule commands to install or update both tools.
- Apply `Tools/DevSecretsManagerPs/SecretsManager-Agent.MD` first.
- Keep updated copies of `SecretsManager-Agent.MD` and `NugetPublisher-Agent.MD` in the containing repository root.
- Copy `NugetPublisher-Agent.MD` to the containing repository root only when the publisher submodule revision changed.
- Do not introduce a `NUGET_SECRETS_MANAGER_PATH` secret.
- Do not introduce output directory, skip pack, skip push, or no-restore secrets.
- Keep the active publisher secret list limited to the five required NuGet publisher secrets.
- Use `.\Tools\DotnetNuGetPublisherPs\NugetPublisher.ps1 -Init` before other publisher secret operations in a new environment.
- Use `.\Tools\DotnetNuGetPublisherPs\NugetPublisher.ps1 -Set ...` to update publisher secrets instead of editing JSON manually.
- Use `.\Tools\DotnetNuGetPublisherPs\NugetPublisher.ps1 -Edit` only when the user explicitly wants to edit the underlying secrets file.
- Do not store actual API keys or secret values in tracked files.
- Keep `Tools/DotnetNuGetPublisherPs/README.md` updated when command behavior, flags, required secrets, or publish flow changes.
- Keep this guide focused on installation, dependency layout, and agent workflow.
- Validate `NugetPublisher.ps1` with the PowerShell parser before finishing code changes.
- Verify `.\Tools\DotnetNuGetPublisherPs\NugetPublisher.ps1 -Version` after version changes.

## Validation Commands

Validate syntax:

```powershell
$tokens = $null
$errors = $null
[System.Management.Automation.Language.Parser]::ParseFile((Resolve-Path .\Tools\DotnetNuGetPublisherPs\NugetPublisher.ps1), [ref]$tokens, [ref]$errors) | Out-Null
if ($errors.Count -gt 0) {
    $errors | ForEach-Object { $_.Message }
    exit 1
}
```

Check version:

```powershell
.\Tools\DotnetNuGetPublisherPs\NugetPublisher.ps1 -Version
```

Check help:

```powershell
.\Tools\DotnetNuGetPublisherPs\NugetPublisher.ps1 -Help
```

Check configured values:

```powershell
.\Tools\DotnetNuGetPublisherPs\NugetPublisher.ps1 -List
```

## Versioning

Use semantic versioning for `NugetPublisher.ps1`.

Increase:

- Major for breaking command behavior, removed commands, renamed flags, incompatible output changes, or changed required layout.
- Minor for new commands, new flags, new supported workflows, or backward-compatible features.
- Patch for bug fixes, help text fixes, README updates, agent guide updates, or internal cleanup.

When changing the version, update:

```text
NugetPublisher.ps1
README.md
NugetPublisher-Agent.MD
```
