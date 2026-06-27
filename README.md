# DotnetNuGetPublisherPs

`DotnetNuGetPublisherPs` is a PowerShell helper for publishing .NET NuGet packages with a repeatable local workflow.

The main script is:

```powershell
.\Tools\DotnetNuGetPublisherPs\NugetPublisher.ps1
```

Current version:

```powershell
.\Tools\DotnetNuGetPublisherPs\NugetPublisher.ps1 -Version
```

Returns:

```text
1.0.2
```

It uses [`Satancito/DevSecretsManagerPs`](https://github.com/Satancito/DevSecretsManagerPs) to store local values such as the NuGet API key, source feed, project path, build configuration, and symbol packaging option.

## Required Folder Layout

This tool is designed to be installed in a containing repository together with `DevSecretsManagerPs`.

Both tools should be added as Git submodules under `Tools`.

Expected layout:

```text
/ProjectFolder/Tools/DevSecretsManagerPs/SecretsManager.ps1
/ProjectFolder/Tools/DotnetNuGetPublisherPs/NugetPublisher.ps1
```

Example on Windows:

```text
C:\Users\you\source\repos\MyProject\Tools\DevSecretsManagerPs\SecretsManager.ps1
C:\Users\you\source\repos\MyProject\Tools\DotnetNuGetPublisherPs\NugetPublisher.ps1
```

`NugetPublisher.ps1` directly calls:

```powershell
..\DevSecretsManagerPs\SecretsManager.ps1
```

If that script is not present at that relative path, this tool cannot initialize, list, edit, set, or read secrets.

## Install As Submodules

From the containing repository root:

```powershell
git submodule add https://github.com/Satancito/DevSecretsManagerPs.git Tools/DevSecretsManagerPs
git submodule add https://github.com/Satancito/DotnetNuGetPublisherPs.git Tools/DotnetNuGetPublisherPs
```

Then synchronize, initialize, and update both submodules:

```powershell
git submodule sync --recursive Tools/DevSecretsManagerPs
git submodule update --init --recursive Tools/DevSecretsManagerPs
git submodule update --remote --recursive Tools/DevSecretsManagerPs

git submodule sync --recursive Tools/DotnetNuGetPublisherPs
git submodule update --init --recursive Tools/DotnetNuGetPublisherPs
git submodule update --remote --recursive Tools/DotnetNuGetPublisherPs
```

Apply the instructions from:

```text
Tools/DevSecretsManagerPs/SecretsManager-Agent.MD
```

Then copy this repository's agent guide to the containing repository root:

```text
Tools/DotnetNuGetPublisherPs/NugetPublisher-Agent.MD -> NugetPublisher-Agent.MD
```

## What This Tool Does

When configured, publishing runs this flow:

```text
dotnet build
dotnet pack
dotnet nuget push
```

The package is built using the configured `.csproj`, configuration, NuGet source, and API key.

Internally, these values are fixed in the script:

```text
SkipPack: False
SkipPush: False
NoRestore: False
```

That means `-Publish` always builds, packs, and pushes. It also allows restore during `dotnet build` and `dotnet pack`.

## First-Time Setup

Run:

```powershell
.\Tools\DotnetNuGetPublisherPs\NugetPublisher.ps1 -Init
```

This initializes `DevSecretsManagerPs` and creates the secrets required by this tool if they do not already exist.

Created secret names:

```text
NUGET_API_KEY
NUGET_SOURCE
NUGET_CSPROJ
NUGET_CONFIGURATION
NUGET_INCLUDE_SYMBOLS
```

Initial values are `null` unless they already exist.

## Recommended Secrets JSON

For publishing to NuGet.org, use this shape:

```json
{
  "NUGET_API_KEY": null,
  "NUGET_SOURCE": "https://api.nuget.org/v3/index.json",
  "NUGET_CSPROJ": null,
  "NUGET_CONFIGURATION": "Release",
  "NUGET_INCLUDE_SYMBOLS": "True"
}
```

Do not commit your real API key to a repository. It belongs only in the local secrets file managed by `DevSecretsManagerPs`.

## Configure Values

Use `-Set` to configure one or more values.

Set NuGet.org as the source:

```powershell
.\Tools\DotnetNuGetPublisherPs\NugetPublisher.ps1 -Set -Source "https://api.nuget.org/v3/index.json"
```

Set the package project:

```powershell
.\Tools\DotnetNuGetPublisherPs\NugetPublisher.ps1 -Set -Csproj "..\MyLibrary\MyLibrary.csproj"
```

Set Release mode:

```powershell
.\Tools\DotnetNuGetPublisherPs\NugetPublisher.ps1 -Set -Configuration Release
```

Set Debug mode:

```powershell
.\Tools\DotnetNuGetPublisherPs\NugetPublisher.ps1 -Set -Configuration Debug
```

Enable symbols and source packaging:

```powershell
.\Tools\DotnetNuGetPublisherPs\NugetPublisher.ps1 -Set -IncludeSymbols True
```

Disable symbols and source packaging:

```powershell
.\Tools\DotnetNuGetPublisherPs\NugetPublisher.ps1 -Set -IncludeSymbols False
```

Set the NuGet API key:

```powershell
.\Tools\DotnetNuGetPublisherPs\NugetPublisher.ps1 -Set -ApiKey "your-nuget-api-key"
```

You can set multiple values at once:

```powershell
.\Tools\DotnetNuGetPublisherPs\NugetPublisher.ps1 `
  -Set `
  -Source "https://api.nuget.org/v3/index.json" `
  -Csproj "..\MyLibrary\MyLibrary.csproj" `
  -Configuration Release `
  -IncludeSymbols True
```

`-Set` rules:

- Only explicitly provided values are updated.
- Values omitted after a `-Set` option are treated as `$null` and ignored.
- `$null` values are ignored.
- Empty strings are saved as empty secret values.
- `-Configuration` must be `Debug` or `Release`.
- `-IncludeSymbols` must be `True` or `False`.

Example that saves an empty value:

```powershell
.\Tools\DotnetNuGetPublisherPs\NugetPublisher.ps1 -Set -Source ""
```

## List Current Values

Run:

```powershell
.\Tools\DotnetNuGetPublisherPs\NugetPublisher.ps1 -List
```

Example output:

```text
Name                   Value
─────────────────────  ───────────────────────────────────
NUGET_API_KEY          null
NUGET_SOURCE           https://api.nuget.org/v3/index.json
NUGET_CSPROJ           ..\MyLibrary\MyLibrary.csproj
NUGET_CONFIGURATION    Release
NUGET_INCLUDE_SYMBOLS  True
```

The table only shows secrets used by `NugetPublisher.ps1`.

## Edit Secrets Directly

To open the underlying `DevSecretsManagerPs` secrets file:

```powershell
.\Tools\DotnetNuGetPublisherPs\NugetPublisher.ps1 -Edit
```

Use a specific editor:

```powershell
.\Tools\DotnetNuGetPublisherPs\NugetPublisher.ps1 -Edit -Editor code
```

This delegates to:

```powershell
..\DevSecretsManagerPs\SecretsManager.ps1 -Edit
```

or:

```powershell
..\DevSecretsManagerPs\SecretsManager.ps1 -Edit -Editor code
```

## Publish

After all required values are configured, run:

```powershell
.\Tools\DotnetNuGetPublisherPs\NugetPublisher.ps1 -Publish
```

`-Publish` is intentionally strict. Every required secret must exist and have a non-empty value:

```text
NUGET_API_KEY
NUGET_SOURCE
NUGET_CSPROJ
NUGET_CONFIGURATION
NUGET_INCLUDE_SYMBOLS
```

If any required value is missing, `null`, empty, or invalid, the script fails before running `dotnet build`, `dotnet pack`, or `dotnet nuget push`.

## Publish Flow Details

Given this configuration:

```json
{
  "NUGET_SOURCE": "https://api.nuget.org/v3/index.json",
  "NUGET_CSPROJ": "..\\MyLibrary\\MyLibrary.csproj",
  "NUGET_CONFIGURATION": "Release",
  "NUGET_INCLUDE_SYMBOLS": "True"
}
```

`-Publish` runs commands equivalent to:

```powershell
dotnet build ..\MyLibrary\MyLibrary.csproj --configuration Release
dotnet pack ..\MyLibrary\MyLibrary.csproj --configuration Release --no-build --include-symbols --include-source
dotnet nuget push <generated-package.nupkg> --api-key *** --source https://api.nuget.org/v3/index.json --skip-duplicate
```

The API key is masked in command logging.

`dotnet pack` uses the normal .NET output location. The script searches for generated `.nupkg` files under:

```text
<project-directory>\bin\<Configuration>
```

For example:

```text
..\MyLibrary\bin\Release
```

## Command Reference

Show help:

```powershell
.\Tools\DotnetNuGetPublisherPs\NugetPublisher.ps1
.\Tools\DotnetNuGetPublisherPs\NugetPublisher.ps1 -Help
.\Tools\DotnetNuGetPublisherPs\NugetPublisher.ps1 -h
.\Tools\DotnetNuGetPublisherPs\NugetPublisher.ps1 -help
.\Tools\DotnetNuGetPublisherPs\NugetPublisher.ps1 -usage
.\Tools\DotnetNuGetPublisherPs\NugetPublisher.ps1 -Usage
.\Tools\DotnetNuGetPublisherPs\NugetPublisher.ps1 -Version
.\Tools\DotnetNuGetPublisherPs\NugetPublisher.ps1 -version
.\Tools\DotnetNuGetPublisherPs\NugetPublisher.ps1 -v
```

Initialize secrets:

```powershell
.\Tools\DotnetNuGetPublisherPs\NugetPublisher.ps1 -Init
```

List configured values:

```powershell
.\Tools\DotnetNuGetPublisherPs\NugetPublisher.ps1 -List
```

Edit the secrets file:

```powershell
.\Tools\DotnetNuGetPublisherPs\NugetPublisher.ps1 -Edit
.\Tools\DotnetNuGetPublisherPs\NugetPublisher.ps1 -Edit -Editor code
```

Set values:

```powershell
.\Tools\DotnetNuGetPublisherPs\NugetPublisher.ps1 -Set -ApiKey "your-api-key"
.\Tools\DotnetNuGetPublisherPs\NugetPublisher.ps1 -Set -Source "https://api.nuget.org/v3/index.json"
.\Tools\DotnetNuGetPublisherPs\NugetPublisher.ps1 -Set -Csproj "..\MyLibrary\MyLibrary.csproj"
.\Tools\DotnetNuGetPublisherPs\NugetPublisher.ps1 -Set -Configuration Release
.\Tools\DotnetNuGetPublisherPs\NugetPublisher.ps1 -Set -IncludeSymbols True
.\Tools\DotnetNuGetPublisherPs\NugetPublisher.ps1 -Set -IncludeSymbols False
```

Publish:

```powershell
.\Tools\DotnetNuGetPublisherPs\NugetPublisher.ps1 -Publish
```

Show version:

```powershell
.\Tools\DotnetNuGetPublisherPs\NugetPublisher.ps1 -Version
.\Tools\DotnetNuGetPublisherPs\NugetPublisher.ps1 -version
.\Tools\DotnetNuGetPublisherPs\NugetPublisher.ps1 -v
```

## Option Details

### `NUGET_API_KEY`

The NuGet API key used by:

```powershell
dotnet nuget push
```

For NuGet.org, create this key from your NuGet.org account.

This value must not be committed to source control.

### `NUGET_SOURCE`

The NuGet feed URL.

For NuGet.org:

```text
https://api.nuget.org/v3/index.json
```

### `NUGET_CSPROJ`

Path to the `.csproj` that produces the package.

Example:

```text
..\MyLibrary\MyLibrary.csproj
```

The project file should contain normal NuGet package metadata, such as:

```xml
<PropertyGroup>
  <PackageId>MyLibrary</PackageId>
  <Version>1.0.0</Version>
  <Authors>YourName</Authors>
  <Description>Package description.</Description>
</PropertyGroup>
```

### `NUGET_CONFIGURATION`

Build configuration for `dotnet build` and `dotnet pack`.

Valid values:

```text
Debug
Release
```

Recommended for real packages:

```text
Release
```

### `NUGET_INCLUDE_SYMBOLS`

Controls whether the script adds:

```powershell
--include-symbols --include-source
```

to `dotnet pack`.

Recommended value for reusable packages:

```text
True
```

This helps package consumers debug into your library when symbols/source are available.

## Important Notes

NuGet.org does not allow overwriting an existing package version. Before publishing again, update the package version in the `.csproj`.

Example:

```xml
<Version>1.0.1</Version>
```

If the package already exists, the script uses:

```powershell
--skip-duplicate
```

so duplicate pushes are skipped instead of treated as a fatal publish failure by NuGet.

`NugetPublisher.ps1` does not create or edit your `.csproj` metadata. It only builds, packs, and pushes using the configured project.

