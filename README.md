# DotnetNuGetPublisherPs

`DotnetNuGetPublisherPs` is a PowerShell tool for preparing and publishing .NET packages to NuGet.org with the `dotnet` CLI.

The tool stores NuGet publishing configuration through `DevSecretsManagerPs`, reads the package project path from `Project.json`, resolves environment variable overrides for CI/CD scenarios, builds the configured `.csproj`, creates the NuGet package with `dotnet pack`, and publishes the generated `.nupkg` with `dotnet nuget push`.

## Script

```powershell
.\NugetPublisher.ps1
```

Current version:

```powershell
.\NugetPublisher.ps1 -Version
```

Returns:

```text
"1.0.6"
```

`-Version` and `-Help` do not initialize secrets, create files, build projects, pack packages, or publish artifacts.

This script expects `DevSecretsManagerPs` to exist in the sibling directory:

```text
../DevSecretsManagerPs/SecretsManager.ps1
```

Commands that read or mutate secrets delegate storage to `DevSecretsManagerPs`.

Commands with capturable results write JSON to stdout. Scalar values are emitted as valid JSON scalars: booleans as `true` or `false`, strings as `"value"`, null as `null`, and empty strings as `""`. Command failures write a JSON error object and exit with code `1`. `-Help` prints plain help text so it can be captured directly. `-Init` and `-Edit` print interactive progress only and do not produce a capturable result.

This tool reads stored secrets through the current `DevSecretsManagerPs` contract: `SecretsManager.ps1 -List` returns the raw secrets JSON.

## Install In A Consumer Project With ToolsManagerPs

Consumer projects can install this repository as a tool by using `ToolsManagerPs`.

Download `ProjectManager.ps1` in the consumer project root:

```powershell
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/Satancito/ToolsManagerPs/main/ProjectManager.ps1" -OutFile "ProjectManager.ps1" -UseBasicParsing
```

Initialize the consumer project configuration:

```powershell
.\ProjectManager.ps1 -Init
```

Install `DevSecretsManagerPs` first. `DotnetNuGetPublisherPs` depends on this tool and expects it to be available as a sibling tool:

```powershell
.\ProjectManager.ps1 -Tools Add -RepositoryName DevSecretsManagerPs -RepositoryUrl https://github.com/Satancito/DevSecretsManagerPs.git -Tag ""
```

Then install `DotnetNuGetPublisherPs`:

```powershell
.\ProjectManager.ps1 -Tools Add -RepositoryName DotnetNuGetPublisherPs -RepositoryUrl https://github.com/Satancito/DotnetNuGetPublisherPs.git -Tag ""
```

The expected consumer project layout is:

```text
Tools/DevSecretsManagerPs
Tools/DotnetNuGetPublisherPs
```

`-Tag ""` stores `Tag` as `null`. A `null` tag means the tool is updated to the latest remote commit when `-Tools Update` runs.

The `-Tag` value can be:

- `null`, by passing `-Tag ""`, to track the latest remote commit.
- A Git tag, to pin the tool to a released version.
- A Git commit SHA, to pin the tool to an exact commit.

## Files

### Repository Documentation

The following documentation files are part of this repository:

- `README.md`: main usage, installation, command, and behavior documentation in English.
- `README.es-ES.MD`: main usage, installation, command, and behavior documentation in Spanish.
- `CHANGELOG.md`: release history and unreleased changes.
- `Version.MD`: repository-local release workflow in English.
- `Version.es-ES.MD`: repository-local release workflow in Spanish.

`README.md` and `README.es-ES.MD` must stay aligned when usage, installation, commands, or behavior change.

`Version.MD` and `Version.es-ES.MD` are release workflow documents for this repository. They are not consumer-project setup files.

### Publishing Script

The reusable NuGet publishing script is:

```text
NugetPublisher.ps1
```

`-Init` initializes the sibling `DevSecretsManagerPs` tool and creates the missing NuGet publisher secrets. It does not copy files into the consumer project and does not stage or commit consumer files.

The consumer project root must contain `Project.json` with a `Project` property that points to the package `.csproj`:

```json
{
  "Project": ".\\src\\MyLibrary\\MyLibrary.csproj"
}
```

Relative `Project` values are resolved from the consumer project root, which is `../../` from the tool directory.

The selected `.csproj` should contain normal NuGet package metadata.

Example:

```xml
<PropertyGroup>
  <PackageId>MyLibrary</PackageId>
  <Version>1.0.0</Version>
  <Authors>YourName</Authors>
  <Description>Package description.</Description>
  <RepositoryUrl>https://github.com/Owner/Repo</RepositoryUrl>
  <PackageLicenseExpression>MIT</PackageLicenseExpression>
</PropertyGroup>
```

`NugetPublisher.ps1` does not create or edit `.csproj` package metadata. It only builds, packs, and pushes the configured project.

### Secrets

NuGet publisher values are stored through `DevSecretsManagerPs` using these secret names:

```text
NUGET_API_KEY
NUGET_SOURCE
NUGET_CONFIGURATION
NUGET_INCLUDE_SYMBOLS
```

When `-Init` creates missing values, it uses these defaults for publishing to NuGet.org:

```json
{
  "NUGET_API_KEY": null,
  "NUGET_SOURCE": "https://api.nuget.org/v3/index.json",
  "NUGET_CONFIGURATION": "Release",
  "NUGET_INCLUDE_SYMBOLS": true
}
```

Existing secrets are not overwritten by `-Init`.

Secret reference:

| Secret | What It Means | Expected Value |
| --- | --- | --- |
| `NUGET_API_KEY` | API key used by `dotnet nuget push`. | Required for publish. Create it from your NuGet.org account. Do not commit it. |
| `NUGET_SOURCE` | NuGet feed URL used by `dotnet nuget push`. | String value. `-Set` accepts null or empty values. Non-empty values must exist or `-Set` returns `false`. HTTP `401` and `403` responses count as valid existing endpoints. Publish requires a non-empty existing endpoint. For NuGet.org use `https://api.nuget.org/v3/index.json`. |
| `NUGET_CONFIGURATION` | Build configuration for `dotnet build` and `dotnet pack`. | Required for publish. `-Set` accepts `Debug`, `Release`, empty, or null. Any other value makes `-Set` return `false`. Publish requires exactly `Debug` or `Release` before build starts. `Release` is recommended for real packages. |
| `NUGET_INCLUDE_SYMBOLS` | Controls whether `dotnet pack` receives `--include-symbols --include-source`. | Required for publish. `-Set` accepts PowerShell boolean values such as `$true` or `$false`. The secret is stored and listed as a JSON boolean. `true` is recommended for reusable packages. |

These publish options are intentionally fixed in the script and are not stored as secrets:

```text
SkipPack: False
SkipPush: False
NoRestore: False
```

That means `-Publish` always builds, packs, and pushes. It also allows restore during `dotnet build` and `dotnet pack`.

## Validation

`-Init`, `-List`, `-Edit`, `-Set`, and `-Publish` initialize and validate access to the sibling `DevSecretsManagerPs` tool before running.

`-Publish` is intentionally strict. Every required value must resolve to a non-empty value:

```text
NUGET_API_KEY
NUGET_SOURCE
NUGET_CONFIGURATION
NUGET_INCLUDE_SYMBOLS
```

The consumer `Project.json` file must also contain a non-empty `Project` property that points to the package `.csproj`.

`NUGET_CONFIGURATION` is validated before any build starts. Publish fails unless it resolves to `Debug` or `Release`.

`NUGET_SOURCE` is validated before any build starts. Publish fails unless it resolves to a non-empty existing endpoint. HTTP `401` and `403` responses count as valid existing endpoints.

`NUGET_API_KEY` is validated before any push starts. Publish fails when it is null, empty, or whitespace.

Environment variables have priority over stored secrets when they exist and are not null, empty, or whitespace. If an environment variable is missing or empty, the value is read from `DevSecretsManagerPs`.

Example:

```powershell
$env:NUGET_API_KEY = "temporary-api-key"
.\NugetPublisher.ps1 -Publish
```

In that case, `NUGET_API_KEY` comes from the environment and the other values can still come from secrets. This is useful for GitHub Actions and other CI/CD systems where secrets are injected as environment variables.

If any required value cannot be resolved from either environment or secrets, or if a value is invalid, the script fails before running `dotnet build`, `dotnet pack`, or `dotnet nuget push`.

## Help

```powershell
.\NugetPublisher.ps1 -Help
.\NugetPublisher.ps1 -h
.\NugetPublisher.ps1 -help
.\NugetPublisher.ps1 -usage
.\NugetPublisher.ps1 -Usage
```

Prints command usage as plain capturable text.

Running the script without flags also prints usage:

```powershell
.\NugetPublisher.ps1
```

## Init

```powershell
.\NugetPublisher.ps1 -Init
```

Initializes `DevSecretsManagerPs` and creates missing NuGet publisher secrets.

Created secret names:

```text
NUGET_API_KEY
NUGET_SOURCE
NUGET_CONFIGURATION
NUGET_INCLUDE_SYMBOLS
```

Missing values are created with the NuGet.org defaults documented above. Existing values are not overwritten.

Prints only the final created/updated summary or an error. It does not produce a capturable result.

## List

```powershell
.\NugetPublisher.ps1 -List
```

Returns capturable JSON with only the NuGet publisher secret properties handled by this tool.

Example output:

```json
{
  "NUGET_API_KEY": null,
  "NUGET_SOURCE": "https://api.nuget.org/v3/index.json",
  "NUGET_CONFIGURATION": "Release",
  "NUGET_INCLUDE_SYMBOLS": true
}
```

This command reads local secrets. Do not run it in logs or shared terminals where secret values could be exposed.

`NUGET_API_KEY` is always masked in capturable output.

## Edit

```powershell
.\NugetPublisher.ps1 -Edit
.\NugetPublisher.ps1 -Edit -Editor <EditorName>
```

Opens the underlying `DevSecretsManagerPs` secrets file in an editor.

Prints which editor is launched using non-capturable output and returns no pipeline value.

## Set

```powershell
.\NugetPublisher.ps1 -Set -ApiKey "your-nuget-api-key"
.\NugetPublisher.ps1 -Set -Source "https://api.nuget.org/v3/index.json"
.\NugetPublisher.ps1 -Set -Configuration Release
.\NugetPublisher.ps1 -Set -Configuration Debug
.\NugetPublisher.ps1 -Set -IncludeSymbols $true
.\NugetPublisher.ps1 -Set -IncludeSymbols $false
```

Updates only the values explicitly passed.

Returns `true` when the provided values are stored. Returns `false` when only `$null` values were provided.

`-Set` also returns `false` when a non-empty `-Source` value does not appear to exist, or when `-Configuration` is not `Debug`, `Release`, empty, or null.

Supported flags:

```text
-ApiKey
-Source
-Configuration
-IncludeSymbols
```

`-Configuration` uses `ValidateSet` and accepts:

```text
Debug
Release
empty string
null
```

`-IncludeSymbols` accepts boolean values:

```text
$true
$false
1
0
null
```

`-Source` is a string parameter. Empty source values are stored as empty secret values. Null source values are ignored. Non-empty source values must exist before storage or `-Set` returns `false`; HTTP `401` and `403` responses are accepted as existing endpoints.

Null values are ignored. Empty strings are stored as empty secret values for text values and `-Configuration`. `-IncludeSymbols` must be a PowerShell boolean value when provided.

## Publish

```powershell
.\NugetPublisher.ps1 -Publish
```

Publishes a .NET package to NuGet.org through the configured `.csproj`, source feed, API key, configuration, and symbol setting.

During publish, the tool:

- Validates secrets and environment variables.
- Resolves environment variables before stored secrets when environment values are not null or empty.
- Reads the package `.csproj` from `Project.json` using the `Project` property.
- Builds the resolved `.csproj` with `dotnet build`.
- Packs the resolved `.csproj` with `dotnet pack --no-build`.
- Adds `--include-symbols --include-source` when `NUGET_INCLUDE_SYMBOLS` is `True`.
- Finds generated `.nupkg` and `.snupkg` files under `<project-directory>\bin\<Configuration>`.
- Excludes legacy `*.symbols.nupkg` packages.
- Pushes generated package files with `dotnet nuget push`, publishing normal `.nupkg` files before `.snupkg` symbol packages.

Commands run are equivalent to:

```powershell
dotnet build ..\MyLibrary\MyLibrary.csproj --configuration Release
dotnet pack ..\MyLibrary\MyLibrary.csproj --configuration Release --no-build --include-symbols --include-source
dotnet nuget push <generated-package.nupkg> --api-key *** --source https://api.nuget.org/v3/index.json --skip-duplicate
dotnet nuget push <generated-symbols.snupkg> --api-key *** --source https://api.nuget.org/v3/index.json --skip-duplicate
```

The API key is masked in command logging.

The API key is also masked from JSON output and error messages.

NuGet.org does not allow overwriting an existing package version. Before publishing again, update the package version in the `.csproj`.

If the package already exists, the script uses `--skip-duplicate` so duplicate pushes are skipped instead of treated as a fatal publish failure by NuGet.

The publish command returns a capturable JSON object. Agents should treat `Success = true`, `Published = true`, and successful process exit codes as a successful publish command execution.

The successful JSON includes `Success`, `Command`, `Stage`, `Published`, `ProjectPath`, `Configuration`, `Source`, `IncludeSymbols`, `Packages`, and `SymbolPackages`.

If publish fails, the command returns a JSON error object with `Success = false`, `Command = "Publish"`, the last completed or failing `Stage`, `Published = false`, and exits with code `1`.

## Version

```powershell
.\NugetPublisher.ps1 -Version
.\NugetPublisher.ps1 -version
.\NugetPublisher.ps1 -v
```

Returns the script version as a JSON string.

```text
"1.0.6"
```

## Recommended Workflow

Install the required tools in the consumer project:

```powershell
.\ProjectManager.ps1 -Tools Add -RepositoryName DevSecretsManagerPs -RepositoryUrl https://github.com/Satancito/DevSecretsManagerPs.git -Tag ""
.\ProjectManager.ps1 -Tools Add -RepositoryName DotnetNuGetPublisherPs -RepositoryUrl https://github.com/Satancito/DotnetNuGetPublisherPs.git -Tag ""
```

Initialize publisher secrets:

```powershell
.\Tools\DotnetNuGetPublisherPs\NugetPublisher.ps1 -Init
```

Configure secrets:

```powershell
.\Tools\DotnetNuGetPublisherPs\NugetPublisher.ps1 -Set -Source "https://api.nuget.org/v3/index.json"
.\Tools\DotnetNuGetPublisherPs\NugetPublisher.ps1 -Set -Configuration Release
.\Tools\DotnetNuGetPublisherPs\NugetPublisher.ps1 -Set -IncludeSymbols $true
.\Tools\DotnetNuGetPublisherPs\NugetPublisher.ps1 -Set -ApiKey "<nuget-api-key>"
```

Publish with the configured `.csproj`:

```powershell
.\Tools\DotnetNuGetPublisherPs\NugetPublisher.ps1 -Publish
```

## CI Environment Variables

For CI/CD, expose the same names used by this tool as environment variables before invoking `-Publish`.

Environment values are used only when they are not null, empty, or whitespace. Empty environment values fall back to local secrets.

NuGet.org example:

```yaml
env:
  NUGET_API_KEY: ${{ secrets.NUGET_API_KEY }}
  NUGET_SOURCE: https://api.nuget.org/v3/index.json
  NUGET_CONFIGURATION: Release
  NUGET_INCLUDE_SYMBOLS: "true"
```

Azure Artifacts project-scoped feed example:

```yaml
env:
  NUGET_API_KEY: ${{ secrets.AZURE_ARTIFACTS_PAT }}
  NUGET_SOURCE: https://pkgs.dev.azure.com/<organization>/<project>/_packaging/<feed>/nuget/v3/index.json
  NUGET_CONFIGURATION: Release
  NUGET_INCLUDE_SYMBOLS: "true"
```

Azure Artifacts organization-scoped feed example:

```yaml
env:
  NUGET_API_KEY: ${{ secrets.AZURE_ARTIFACTS_PAT }}
  NUGET_SOURCE: https://pkgs.dev.azure.com/<organization>/_packaging/<feed>/nuget/v3/index.json
  NUGET_CONFIGURATION: Release
  NUGET_INCLUDE_SYMBOLS: "true"
```

PowerShell equivalent:

```powershell
$env:NUGET_API_KEY = "<azure-artifacts-pat>"
$env:NUGET_SOURCE = "https://pkgs.dev.azure.com/<organization>/<project>/_packaging/<feed>/nuget/v3/index.json"
$env:NUGET_CONFIGURATION = "Release"
$env:NUGET_INCLUDE_SYMBOLS = "true"
```

For private Azure Artifacts feeds, authenticate NuGet before running `-Publish`. In Azure Pipelines, `NuGetAuthenticate@1` configures credential provider access for the job. Outside Azure Pipelines, configure the Azure Artifacts Credential Provider or add the source credentials to NuGet before invoking this script.

`NUGET_API_KEY` is sent only by `dotnet nuget push` through the `--api-key` option. Endpoint validation does not send the API key.

## Safety

Do not commit real secrets, API keys, local secret stores, NuGet package outputs, or generated build output.

Do not run `-List` in logs or shared terminals where secret values could be exposed.

Do not run `-Publish` unless you intentionally want to publish a package to the configured NuGet feed.
