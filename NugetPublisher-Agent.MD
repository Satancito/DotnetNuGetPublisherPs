# NuGet Publisher Agent Guide

This file defines the required workflow for installing `DotnetNuGetPublisherPs` inside a consuming repository.

The consuming repository must install two tools as Git submodules:

```text
Tools/DevSecretsManagerPs
Tools/DotnetNugetPublisher
```

`NugetPublisher.ps1` depends on `DevSecretsManagerPs` by relative path:

```powershell
..\DevSecretsManagerPs\SecretsManager.ps1
```

That path works because both submodules live under `Tools`.

## Step 1: Add Or Update DevSecretsManagerPs

From the root of the consuming repository, ensure `DevSecretsManagerPs` exists as a submodule at:

```text
Tools/DevSecretsManagerPs
```

If it does not exist, add it:

```powershell
git submodule add https://github.com/Satancito/DevSecretsManagerPs.git Tools/DevSecretsManagerPs
```

If it already exists as a submodule in that directory, synchronize, initialize, and update it:

```powershell
git submodule sync --recursive Tools/DevSecretsManagerPs
git submodule update --init --recursive Tools/DevSecretsManagerPs
git submodule update --remote --recursive Tools/DevSecretsManagerPs
```

## Step 2: Add Or Update DotnetNugetPublisher

From the root of the consuming repository, ensure this project exists as a submodule at:

```text
Tools/DotnetNugetPublisher
```

If it does not exist, add it:

```powershell
git submodule add https://github.com/Satancito/DotnetNuGetPublisherPs.git Tools/DotnetNugetPublisher
```

If it already exists as a submodule in that directory, synchronize, initialize, and update it:

```powershell
git submodule sync --recursive Tools/DotnetNugetPublisher
git submodule update --init --recursive Tools/DotnetNugetPublisher
git submodule update --remote --recursive Tools/DotnetNugetPublisher
```

## Step 3: Apply DevSecretsManagerPs Instructions

After `Tools/DevSecretsManagerPs` exists, apply the instructions from:

```text
Tools/DevSecretsManagerPs/SecretsManager-Agent.MD
```

Do this before configuring or running `NugetPublisher.ps1`.

## Step 4: Copy This Agent File

Copy this file from the publisher submodule into the root of the consuming repository:

```text
Tools/DotnetNugetPublisher/NugetPublisher-Agent.MD -> NugetPublisher-Agent.MD
```

The root copy gives future agents a predictable instruction file without searching inside the submodule.

## Step 5: Stage Only Publisher Changes

Stage only the publisher submodule and the copied publisher agent file when something actually changed.

Do not stage `Tools/DevSecretsManagerPs` or `SecretsManager-Agent.MD` from this guide. The `SecretsManager-Agent.MD` workflow is responsible for its own stage and commit operations.

There are changes when:

- The `Tools/DotnetNugetPublisher` submodule was added.
- The `Tools/DotnetNugetPublisher` submodule revision changed after synchronize, initialize, or update.
- The copied `NugetPublisher-Agent.MD` changed.

Typical first publisher install:

```powershell
git add .gitmodules Tools/DotnetNugetPublisher NugetPublisher-Agent.MD
```

Typical publisher update:

```powershell
git add Tools/DotnetNugetPublisher NugetPublisher-Agent.MD
```

If only one publisher path changed, stage only that changed path.

Never stage real secrets, API keys, machine-local secret files, or generated package artifacts.

## Step 6: Commit

Commit the staged installation or update changes with a clear message.

First install example:

```powershell
git commit -m "Add NuGet publisher and secrets manager submodules"
```

Update example:

```powershell
git commit -m "Update NuGet publisher and secrets manager submodules"
```

## Step 7: Read The README

Read the publisher README to learn how to use the tool:

```text
Tools/DotnetNugetPublisher/README.md
```

The README is the source of truth for `NugetPublisher.ps1` commands, flags, required secrets, examples, and publishing behavior.

## Required Publish Workflow

Publishing must be explicit:

```powershell
.\Tools\DotnetNugetPublisher\NugetPublisher.ps1 -Publish
```

Running the script with no flags must only show usage/help:

```powershell
.\Tools\DotnetNugetPublisher\NugetPublisher.ps1
```

Before publishing, every required secret must exist and have a non-empty value. If any required value is missing, null, empty, or invalid, `-Publish` must fail before running `dotnet build`, `dotnet pack`, or `dotnet nuget push`.

The publisher uses only these secrets:

```text
NUGET_API_KEY
NUGET_SOURCE
NUGET_CSPROJ
NUGET_CONFIGURATION
NUGET_INCLUDE_SYMBOLS
```

Secret values are stored by `DevSecretsManagerPs` in the user's home directory. They are local to each machine and must never be committed.

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
- Treat `Tools/DotnetNugetPublisher` as the required NuGet publisher submodule path.
- Use `git submodule add` only when the submodule does not already exist.
- If a submodule already exists in the required path, synchronize, initialize, and update it.
- Apply `Tools/DevSecretsManagerPs/SecretsManager-Agent.MD` before using the publisher.
- Keep updated copies of `SecretsManager-Agent.MD` and `NugetPublisher-Agent.MD` in the consuming repository root when their source files changed.
- Do not introduce a `NUGET_SECRETS_MANAGER_PATH` secret.
- Do not introduce output directory, skip pack, skip push, or no-restore secrets.
- Keep the active publisher secret list limited to the five required NuGet publisher secrets.
- Use `.\Tools\DotnetNugetPublisher\NugetPublisher.ps1 -Init` before other publisher secret operations in a new environment.
- Use `.\Tools\DotnetNugetPublisher\NugetPublisher.ps1 -Set ...` to update publisher secrets instead of editing JSON manually.
- Use `.\Tools\DotnetNugetPublisher\NugetPublisher.ps1 -Edit` only when the user explicitly wants to edit the underlying secrets file.
- Do not clear, overwrite, stage, commit, or publish actual API keys or secret values.
- Keep `Tools/DotnetNugetPublisher/README.md` updated when command behavior, flags, required secrets, or publish flow changes.
- Keep this guide focused on installation, dependency layout, and agent workflow.
- Verify `.\Tools\DotnetNugetPublisher\NugetPublisher.ps1 -Version` after version changes.

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
