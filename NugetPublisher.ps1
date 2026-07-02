[CmdletBinding(DefaultParameterSetName = "Help")]
param(
    [Parameter(Mandatory = $true, ParameterSetName = "Init")]
    [switch]$Init,

    [Parameter(Mandatory = $true, ParameterSetName = "List")]
    [switch]$List,

    [Parameter(Mandatory = $true, ParameterSetName = "Edit")]
    [switch]$Edit,

    [Parameter(ParameterSetName = "Edit")]
    [AllowNull()]
    [AllowEmptyString()]
    [string]$Editor,

    [Parameter(Mandatory = $true, ParameterSetName = "Set")]
    [switch]$Set,

    [Parameter(Mandatory = $true, ParameterSetName = "Publish")]
    [switch]$Publish,

    [Parameter(ParameterSetName = "Set")]
    [AllowNull()]
    [AllowEmptyString()]
    [object]$ApiKey,

    [Parameter(ParameterSetName = "Set")]
    [AllowNull()]
    [AllowEmptyString()]
    [object]$Source,

    [Parameter(ParameterSetName = "Set")]
    [AllowNull()]
    [AllowEmptyString()]
    [object]$Configuration,

    [Parameter(ParameterSetName = "Set")]
    [AllowNull()]
    [System.Nullable[bool]]$IncludeSymbols,

    [Parameter(ParameterSetName = "Help")]
    [Alias("h", "usage")]
    [switch]$Help,

    [Parameter(ParameterSetName = "Version")]
    [Alias("v")]
    [switch]$Version
)

$ErrorActionPreference = "Stop"
$ScriptVersion = "1.0.6"
$ProvidedParameterNames = @()
$ScriptInvocationStatement = if (-not [string]::IsNullOrWhiteSpace($MyInvocation.Line)) { $MyInvocation.Line } else { $MyInvocation.Statement }

$RequiredSecretNames = @(
    "NUGET_API_KEY",
    "NUGET_SOURCE",
    "NUGET_CONFIGURATION",
    "NUGET_INCLUDE_SYMBOLS"
)

$DefaultSecretValues = [ordered]@{
    NUGET_API_KEY = $null
    NUGET_SOURCE = "https://api.nuget.org/v3/index.json"
    NUGET_CONFIGURATION = "Release"
    NUGET_INCLUDE_SYMBOLS = $true
}

$DefaultSkipPack = $false
$DefaultSkipPush = $false
$DefaultNoRestore = $false

function Get-ProvidedParameterNames {
    $boundNames = [System.Collections.Generic.List[string]]::new()

    foreach ($entry in $PSBoundParameters.GetEnumerator()) {
        if ($entry.Value -is [System.Management.Automation.SwitchParameter]) {
            if ($entry.Value.IsPresent) {
                $boundNames.Add($entry.Key)
            }

            continue
        }

        if ($null -ne $entry.Value) {
            $boundNames.Add($entry.Key)
        }
    }

    $source = if (-not [string]::IsNullOrWhiteSpace($ScriptInvocationStatement)) {
        $ScriptInvocationStatement
    }
    else {
        [Environment]::CommandLine
    }

    $errors = $null
    $tokens = [System.Management.Automation.PSParser]::Tokenize($source, [ref]$errors)

    if ($errors -and $errors.Count -gt 0) {
        return @($boundNames | Select-Object -Unique)
    }

    $names = [System.Collections.Generic.List[string]]::new()

    foreach ($boundName in $boundNames) {
        $names.Add($boundName)
    }

    foreach ($token in $tokens) {
        if ($token.Type -ne "CommandParameter") {
            continue
        }

        $name = $token.Content.TrimStart("-")
        if ($name.Contains(":")) {
            $name = $name.Split(":", 2)[0]
        }

        switch ($name.ToLowerInvariant()) {
            "h" { $names.Add("Help") }
            "help" { $names.Add("Help") }
            "usage" { $names.Add("Help") }
            "v" { $names.Add("Version") }
            "version" { $names.Add("Version") }
            "init" { $names.Add("Init") }
            "list" { $names.Add("List") }
            "edit" { $names.Add("Edit") }
            "editor" { $names.Add("Editor") }
            "set" { $names.Add("Set") }
            "apikey" { $names.Add("ApiKey") }
            "source" { $names.Add("Source") }
            "configuration" { $names.Add("Configuration") }
            "includesymbols" { $names.Add("IncludeSymbols") }
            "publish" { $names.Add("Publish") }
        }
    }

    return @($names | Select-Object -Unique)
}

function Show-Usage {
    $usage = @"
NuGet Publisher

Usage:
  .\NugetPublisher.ps1 -Init
  .\NugetPublisher.ps1 -List
  .\NugetPublisher.ps1 -Edit [-Editor <editor>]
  .\NugetPublisher.ps1 -Set [-ApiKey <value>] [-Source <value>] [-Configuration <Debug|Release>] [options]
  .\NugetPublisher.ps1 -Publish
  .\NugetPublisher.ps1 -Help
  .\NugetPublisher.ps1 -h
  .\NugetPublisher.ps1 -help
  .\NugetPublisher.ps1 -usage
  .\NugetPublisher.ps1 -Usage
  .\NugetPublisher.ps1 -Version
  .\NugetPublisher.ps1 -version
  .\NugetPublisher.ps1 -v

Modes:
  -Init
    Initializes DevSecretsManagerPs and creates these secrets when missing:
      NUGET_API_KEY: null
      NUGET_SOURCE: https://api.nuget.org/v3/index.json
      NUGET_CONFIGURATION: Release
      NUGET_INCLUDE_SYMBOLS: true

  -List
    Returns JSON with only the NuGet publisher secrets handled by this tool.

  -Edit
    Opens the DevSecretsManagerPs secrets file in an editor.
    Uses the default editor from SecretsManager.ps1 unless -Editor is provided.

    Examples:
      .\NugetPublisher.ps1 -Edit
      .\NugetPublisher.ps1 -Edit -Editor code

  -Set
    Updates only the values explicitly provided.
    Null values are ignored.
    Empty strings are saved as empty secret values for string parameters.
    Non-empty -Source values must exist. HTTP 401/403 responses count as valid existing endpoints.
    -Configuration stores NUGET_CONFIGURATION as Debug or Release.
    Invalid -Configuration values return false.
    -IncludeSymbols accepts PowerShell boolean values and is stored as a JSON boolean.

    Examples:
      .\NugetPublisher.ps1 -Set -ApiKey "<nuget-api-key>"
      .\NugetPublisher.ps1 -Set -Source "https://api.nuget.org/v3/index.json"
      .\NugetPublisher.ps1 -Set -Configuration Debug
      .\NugetPublisher.ps1 -Set -Configuration Release
      .\NugetPublisher.ps1 -Set -IncludeSymbols `$true
      .\NugetPublisher.ps1 -Set -IncludeSymbols `$false
      .\NugetPublisher.ps1 -Set -Source ""

  -Publish
    Builds, packs, and pushes a NuGet package using configured values.
    Environment variables have priority over secrets when they are not null or empty.
    Every NuGet publisher value must resolve to a non-empty value:
      NUGET_API_KEY
      NUGET_SOURCE
      NUGET_CONFIGURATION
      NUGET_INCLUDE_SYMBOLS
    Project.json in the consumer project root must contain a non-empty Project value pointing to the package .csproj.
    Internal defaults:
      SkipPack: False
      SkipPush: False
      NoRestore: False
    Returns capturable JSON with Success, Command, Stage, Published, ProjectPath, Configuration, Source, IncludeSymbols, Packages, and SymbolPackages.

    Examples:
      .\NugetPublisher.ps1 -Publish

  -Version
    Returns the script version as a JSON string.

Options:
  -Configuration <value>
    Build configuration for dotnet build and dotnet pack. Valid values: Debug, Release.
    For -Publish, NUGET_CONFIGURATION must resolve from environment or secrets.

  -IncludeSymbols
    Passes --include-symbols and --include-source to dotnet pack.
    For -Publish, NUGET_INCLUDE_SYMBOLS must resolve as a boolean from environment or secrets.

  -Source
    NuGet source endpoint. Null and empty values are allowed by -Set. Non-empty values must exist before storing.
"@

    return $usage
}

function Show-Version {
    return $ScriptVersion
}

function Get-SensitiveValues {
    $values = [System.Collections.Generic.List[string]]::new()

    $environmentApiKey = Get-EnvironmentConfiguredValue -Name "NUGET_API_KEY"
    if (-not [string]::IsNullOrWhiteSpace($environmentApiKey)) {
        $values.Add($environmentApiKey)
    }

    try {
        $secretApiKey = Get-ConfiguredSecret -Name "NUGET_API_KEY"
        if ($null -ne $secretApiKey -and -not [string]::IsNullOrWhiteSpace([string]$secretApiKey)) {
            $values.Add([string]$secretApiKey)
        }
    }
    catch {
        # Masking is best-effort before secrets are initialized.
    }

    return @($values | Select-Object -Unique)
}

function Mask-SensitiveText {
    param(
        [AllowNull()]
        [string]$Text
    )

    if ($null -eq $Text) {
        return $null
    }

    $masked = $Text
    foreach ($sensitiveValue in Get-SensitiveValues) {
        if ([string]::IsNullOrWhiteSpace($sensitiveValue)) {
            continue
        }

        $masked = $masked.Replace($sensitiveValue, "***")
    }

    return $masked
}

function Protect-OutputValue {
    param(
        [AllowNull()]
        [object]$Value,

        [string]$PropertyName = ""
    )

    if ($null -eq $Value) {
        return $null
    }

    if ($PropertyName -eq "NUGET_API_KEY" -or $PropertyName -eq "ApiKey") {
        return "***"
    }

    if ($Value -is [string]) {
        return Mask-SensitiveText -Text $Value
    }

    if ($Value -is [bool] -or $Value -is [int] -or $Value -is [long] -or $Value -is [double] -or $Value -is [decimal]) {
        return $Value
    }

    if ($Value -is [System.Collections.IDictionary]) {
        $protected = [ordered]@{}
        foreach ($key in $Value.Keys) {
            $protected[[string]$key] = Protect-OutputValue -Value $Value[$key] -PropertyName ([string]$key)
        }
        return $protected
    }

    if ($Value -is [System.Collections.IEnumerable] -and $Value -isnot [string]) {
        return @($Value | ForEach-Object { Protect-OutputValue -Value $_ })
    }

    if ($Value -is [PSCustomObject]) {
        $protected = [ordered]@{}
        foreach ($property in $Value.PSObject.Properties) {
            $protected[$property.Name] = Protect-OutputValue -Value $property.Value -PropertyName $property.Name
        }
        return [PSCustomObject]$protected
    }

    return $Value
}

function Write-JsonOutput {
    param(
        [AllowNull()]
        [object]$Value
    )

    if ($null -eq $Value) {
        Write-Output "null"
        return
    }

    Write-Output ((Protect-OutputValue -Value $Value) | ConvertTo-Json -Depth 100)
}

function Invoke-LoggedCommand {
    param(
        [Parameter(Mandatory = $true)]
        [string]$FilePath,

        [Parameter(Mandatory = $true)]
        [string[]]$Arguments,

        [string[]]$DisplayArguments = $Arguments
    )

    Write-Host "> $FilePath $($DisplayArguments -join ' ')"
    & $FilePath @Arguments

    if ($LASTEXITCODE -ne 0) {
        throw "Command failed with exit code $LASTEXITCODE."
    }
}

function Resolve-FullPath {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,

        [string]$BasePath = (Get-Location).Path
    )

    if ([System.IO.Path]::IsPathRooted($Path)) {
        $candidatePath = $Path
    }
    else {
        $candidatePath = Join-Path $BasePath $Path
    }

    $resolved = Resolve-Path -LiteralPath $candidatePath -ErrorAction SilentlyContinue

    if ($resolved) {
        return $resolved.Path
    }

    return [System.IO.Path]::GetFullPath($candidatePath)
}

function Resolve-SecretsManagerPath {
    $resolvedPath = Resolve-FullPath -Path "..\DevSecretsManagerPs\SecretsManager.ps1" -BasePath $PSScriptRoot

    if (-not (Test-Path -LiteralPath $resolvedPath -PathType Leaf)) {
        throw "SecretsManager.ps1 was not found: $resolvedPath"
    }

    return $resolvedPath
}

function Resolve-ConsumerProjectRoot {
    return Resolve-FullPath -Path "..\.." -BasePath $PSScriptRoot
}

function Get-ProjectJsonProjectPath {
    $consumerProjectRoot = Resolve-ConsumerProjectRoot
    $projectJsonPath = Join-Path $consumerProjectRoot "Project.json"

    if (-not (Test-Path -LiteralPath $projectJsonPath -PathType Leaf)) {
        throw "Project.json was not found in the consumer project root: $projectJsonPath"
    }

    try {
        $projectJson = Get-Content -LiteralPath $projectJsonPath -Raw | ConvertFrom-Json
    }
    catch {
        throw "Project.json could not be parsed as JSON: $projectJsonPath"
    }

    if (-not ($projectJson.PSObject.Properties.Name -contains "Project")) {
        throw "Project.json must contain a Project property pointing to the package .csproj."
    }

    $projectPath = [string]$projectJson.Project

    if ([string]::IsNullOrWhiteSpace($projectPath)) {
        throw "Project.json Project value is required and must point to the package .csproj."
    }

    return Resolve-FullPath -Path $projectPath -BasePath $consumerProjectRoot
}

function Invoke-SecretsManager {
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Parameters
    )

    $managerPath = Resolve-SecretsManagerPath
    & $managerPath @Parameters 6>$null

    if (-not $?) {
        throw "SecretsManager.ps1 failed."
    }
}

function Get-SecretsFilePath {
    $managerPath = Resolve-SecretsManagerPath
    $managerDirectory = Split-Path -Parent $managerPath
    $envFilePath = Join-Path $managerDirectory "env.json"

    if (-not (Test-Path -LiteralPath $envFilePath -PathType Leaf)) {
        throw "DevSecretsManagerPs env.json was not found: $envFilePath"
    }

    try {
        $envJson = Get-Content -LiteralPath $envFilePath -Raw | ConvertFrom-Json
    }
    catch {
        throw "DevSecretsManagerPs env.json could not be parsed as JSON: $envFilePath"
    }

    $environmentId = [string]$envJson.Id
    if ([string]::IsNullOrWhiteSpace($environmentId)) {
        throw "DevSecretsManagerPs env.json must contain an Id value."
    }

    $homeDirectory = [Environment]::GetFolderPath([Environment+SpecialFolder]::UserProfile)
    if ([string]::IsNullOrWhiteSpace($homeDirectory)) {
        $homeDirectory = [Environment]::GetEnvironmentVariable("HOME")
    }
    if ([string]::IsNullOrWhiteSpace($homeDirectory)) {
        throw "Unable to resolve the user home directory for DevSecretsManagerPs secrets."
    }

    return Join-Path (Join-Path $homeDirectory ".devsecretsmanager") "$environmentId.json"
}

function Read-SecretsMap {
    $secretsFilePath = Get-SecretsFilePath

    if (-not (Test-Path -LiteralPath $secretsFilePath -PathType Leaf)) {
        return [ordered]@{}
    }

    $raw = Get-Content -LiteralPath $secretsFilePath -Raw
    if ([string]::IsNullOrWhiteSpace($raw)) {
        return [ordered]@{}
    }

    try {
        $json = $raw | ConvertFrom-Json
    }
    catch {
        throw "Secrets file could not be parsed as JSON: $secretsFilePath"
    }

    $secrets = [ordered]@{}
    foreach ($property in $json.PSObject.Properties) {
        $secrets[$property.Name] = $property.Value
    }

    return $secrets
}

function Write-SecretsMap {
    param(
        [Parameter(Mandatory = $true)]
        [System.Collections.IDictionary]$Secrets
    )

    $secretsFilePath = Get-SecretsFilePath
    $secretsDirectory = Split-Path -Parent $secretsFilePath

    if (-not (Test-Path -LiteralPath $secretsDirectory -PathType Container)) {
        New-Item -ItemType Directory -Path $secretsDirectory | Out-Null
    }

    $Secrets | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $secretsFilePath -Encoding UTF8
}

function Initialize-NuGetSecrets {
    Invoke-SecretsManager -Parameters @{ Init = $true } | Out-Null
    $secretStates = [ordered]@{}
    $secrets = Read-SecretsMap

    foreach ($secretName in $RequiredSecretNames) {
        if ($secrets.Contains($secretName)) {
            $secretStates[$secretName] = "Existing"
            continue
        }

        $secrets[$secretName] = $DefaultSecretValues[$secretName]
        $secretStates[$secretName] = "Created"
    }

    Write-SecretsMap -Secrets $secrets

    Write-Host "NuGet publisher secrets initialized:"
    foreach ($secretName in $RequiredSecretNames) {
        $defaultValue = $DefaultSecretValues[$secretName]
        $displayValue = if ($null -eq $defaultValue) {
            "null"
        }
        elseif ($defaultValue -is [bool]) {
            $defaultValue.ToString().ToLowerInvariant()
        }
        else {
            [string]$defaultValue
        }
        Write-Host "  $secretName [$($secretStates[$secretName])] Default: $displayValue"
    }
}

function Get-ConfiguredSecret {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name
    )

    $secrets = Read-SecretsMap

    if (-not $secrets.Contains($Name)) {
        return $null
    }

    return $secrets[$Name]
}

function Get-EnvironmentConfiguredValue {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name
    )

    $value = [Environment]::GetEnvironmentVariable($Name, "Process")

    if ([string]::IsNullOrWhiteSpace($value)) {
        return $null
    }

    return [string]$value
}

function Get-ResolvedConfiguredValue {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name
    )

    $environmentValue = Get-EnvironmentConfiguredValue -Name $Name

    if (-not [string]::IsNullOrWhiteSpace($environmentValue)) {
        return $environmentValue
    }

    return Get-ConfiguredSecret -Name $Name
}

function Get-RequiredResolvedConfiguredValue {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name
    )

    $value = Get-ResolvedConfiguredValue -Name $Name

    if ($null -eq $value -or [string]::IsNullOrWhiteSpace([string]$value)) {
        throw "Required value '$Name' is missing, null, or empty. Configure it in an environment variable or secret before running -Publish."
    }

    return $value
}

function Get-ConfiguredBoolean {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name,

        [bool]$Default = $false
    )

    $value = Get-ConfiguredSecret -Name $Name

    if ([string]::IsNullOrWhiteSpace($value)) {
        return $Default
    }

    $parsed = $false
    if (-not [bool]::TryParse($value, [ref]$parsed)) {
        throw "$Name must be True or False. Current value: $value"
    }

    return $parsed
}

function Get-RequiredResolvedConfiguredBoolean {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name
    )

    $value = Get-RequiredResolvedConfiguredValue -Name $Name

    if ($value -is [bool]) {
        return [bool]$value
    }

    $parsed = $false

    if (-not [bool]::TryParse($value, [ref]$parsed)) {
        throw "$Name must be True or False. Current value: $value"
    }

    return $parsed
}

function Assert-NuGetSourceEndpoint {
    param(
        [AllowNull()]
        [AllowEmptyString()]
        [string]$Source
    )

    if ([string]::IsNullOrWhiteSpace($Source)) {
        return
    }

    $sourceUri = $null
    if (-not [System.Uri]::TryCreate($Source, [System.UriKind]::Absolute, [ref]$sourceUri)) {
        throw "NUGET_SOURCE must be an absolute HTTP/HTTPS URL. Current value: $Source"
    }

    if ($sourceUri.Scheme -notin @("http", "https")) {
        throw "NUGET_SOURCE must use HTTP or HTTPS. Current value: $Source"
    }

    try {
        Invoke-WebRequest -Uri $sourceUri -Method Head -UseBasicParsing -TimeoutSec 20 | Out-Null
        return
    }
    catch {
        if ($_.Exception.Response -and $_.Exception.Response.StatusCode -in @(
                [System.Net.HttpStatusCode]::Unauthorized,
                [System.Net.HttpStatusCode]::Forbidden
            )) {
            return
        }

        try {
            Invoke-WebRequest -Uri $sourceUri -Method Get -UseBasicParsing -TimeoutSec 20 | Out-Null
            return
        }
        catch {
            if ($_.Exception.Response -and $_.Exception.Response.StatusCode -in @(
                    [System.Net.HttpStatusCode]::Unauthorized,
                    [System.Net.HttpStatusCode]::Forbidden
                )) {
                return
            }

            throw "NUGET_SOURCE endpoint does not exist or is not reachable: $Source"
        }
    }
}

function Convert-NuGetSecretForOutput {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name,

        [AllowNull()]
        [object]$Value
    )

    if ($Name -ne "NUGET_INCLUDE_SYMBOLS" -or $null -eq $Value) {
        return $Value
    }

    if ([string]::IsNullOrWhiteSpace([string]$Value)) {
        return $Value
    }

    $parsed = $false
    if ([bool]::TryParse([string]$Value, [ref]$parsed)) {
        return $parsed
    }

    return $Value
}

function Show-NuGetSecrets {
    $values = [ordered]@{}

    foreach ($secretName in $RequiredSecretNames) {
        $values[$secretName] = Convert-NuGetSecretForOutput -Name $secretName -Value (Get-ConfiguredSecret -Name $secretName)
    }

    return $values
}

function Set-ConfiguredSecret {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name,

        [AllowNull()]
        [AllowEmptyString()]
        [object]$Value
    )

    $secrets = Read-SecretsMap
    $secrets[$Name] = $Value
    Write-SecretsMap -Secrets $secrets
}

function Set-NuGetSecrets {
    $updates = [ordered]@{}
    $setParameterNames = @(
        "ApiKey",
        "Source",
        "Configuration",
        "IncludeSymbols"
    ) |
        Where-Object { $ProvidedParameterNames -contains $_ }

    if ($ProvidedParameterNames -contains "ApiKey") {
        if ($null -eq $ApiKey) {
            # Null means "leave this secret unchanged".
        }
        else {
            $updates["NUGET_API_KEY"] = [string]$ApiKey
        }
    }

    if ($ProvidedParameterNames -contains "Source") {
        if ($null -eq $Source) {
            # Null means "leave this secret unchanged".
        }
        else {
            if (-not [string]::IsNullOrWhiteSpace([string]$Source)) {
                try {
                    Assert-NuGetSourceEndpoint -Source ([string]$Source)
                }
                catch {
                    Write-Host "NUGET_SOURCE is not valid: $($_.Exception.Message)"
                    return $false
                }
            }

            $updates["NUGET_SOURCE"] = [string]$Source
        }
    }

    if ($ProvidedParameterNames -contains "Configuration") {
        if ($null -eq $Configuration) {
            # Null means "leave this secret unchanged".
        }
        elseif (-not [string]::IsNullOrEmpty([string]$Configuration) -and [string]$Configuration -notin @("Debug", "Release")) {
            Write-Host "NUGET_CONFIGURATION is not valid. Use Debug, Release, empty, or null."
            return $false
        }
        else {
            $updates["NUGET_CONFIGURATION"] = [string]$Configuration
        }
    }

    if ($ProvidedParameterNames -contains "IncludeSymbols") {
        if ($null -eq $IncludeSymbols) {
            # Null means "leave this secret unchanged".
        }
        else {
            $updates["NUGET_INCLUDE_SYMBOLS"] = [bool]$IncludeSymbols
        }
    }

    if ($setParameterNames.Count -eq 0) {
        throw "Use -Set with at least one value: -ApiKey, -Source, -Configuration, or -IncludeSymbols."
    }

    if ($updates.Count -eq 0) {
        return $false
    }

    foreach ($entry in $updates.GetEnumerator()) {
        Set-ConfiguredSecret -Name $entry.Key -Value $entry.Value
    }

    return $true
}

function Invoke-NuGetPublish {
    $publishStage = "ResolveConfiguration"
    $projectFullPath = $null
    $packageSearchDirectory = $null
    $packages = @()

    try {
        $ApiKey = Get-RequiredResolvedConfiguredValue -Name "NUGET_API_KEY"
        $Source = Get-RequiredResolvedConfiguredValue -Name "NUGET_SOURCE"
        $Configuration = Get-RequiredResolvedConfiguredValue -Name "NUGET_CONFIGURATION"

        if ($Configuration -notin @("Debug", "Release")) {
            throw "NUGET_CONFIGURATION must be Debug or Release. Current value: $Configuration"
        }

        Assert-NuGetSourceEndpoint -Source $Source

        $SkipPack = $DefaultSkipPack
        $SkipPush = $DefaultSkipPush
        $IncludeSymbols = Get-RequiredResolvedConfiguredBoolean -Name "NUGET_INCLUDE_SYMBOLS"
        $NoRestore = $DefaultNoRestore

        if (-not (Get-Command dotnet -ErrorAction SilentlyContinue)) {
            throw "The dotnet CLI was not found on PATH."
        }

        $projectFullPath = Get-ProjectJsonProjectPath

        if (-not (Test-Path -LiteralPath $projectFullPath)) {
            throw "Project path does not exist: $projectFullPath"
        }

        $projectDirectory = Split-Path -Parent $projectFullPath
        $packageSearchDirectory = Join-Path $projectDirectory (Join-Path "bin" $Configuration)
        $publishStartedAtUtc = [DateTime]::UtcNow.AddSeconds(-5)

        if (-not $SkipPack) {
            $publishStage = "Build"
            $buildArgs = @(
                "build",
                $projectFullPath,
                "--configuration",
                $Configuration
            )

            if ($NoRestore) {
                $buildArgs += "--no-restore"
            }

            Invoke-LoggedCommand -FilePath "dotnet" -Arguments $buildArgs

            $publishStage = "Pack"
            $packArgs = @(
                "pack",
                $projectFullPath,
                "--configuration",
                $Configuration,
                "--no-build"
            )

            if ($NoRestore) {
                $packArgs += "--no-restore"
            }

            if ($IncludeSymbols) {
                $packArgs += @("--include-symbols", "--include-source")
            }

            Invoke-LoggedCommand -FilePath "dotnet" -Arguments $packArgs
        }

        $publishStage = "FindPackages"
        $packages = if (Test-Path -LiteralPath $packageSearchDirectory -PathType Container) {
            @(
                Get-ChildItem -LiteralPath $packageSearchDirectory -Filter "*.nupkg" -File -Recurse
                Get-ChildItem -LiteralPath $packageSearchDirectory -Filter "*.snupkg" -File -Recurse
            )
        }
        else {
            @()
        }

        $packages = @($packages |
            Where-Object { $_.Name -notlike "*.symbols.nupkg" } |
            Where-Object { $SkipPack -or $_.LastWriteTimeUtc -ge $publishStartedAtUtc } |
            Sort-Object `
                @{ Expression = { if ($_.Extension -eq ".snupkg") { 1 } else { 0 } }; Ascending = $true },
                @{ Expression = "LastWriteTimeUtc"; Descending = $true })

        if (-not $packages) {
            throw "No .nupkg or .snupkg files were found in $packageSearchDirectory."
        }

        $symbolPackages = @($packages | Where-Object { $_.Extension -eq ".snupkg" })

        if ($SkipPush) {
            return [PSCustomObject]@{
                Success = $true
                Command = "Publish"
                Stage = "Completed"
                Published = $false
                Message = "Packages created."
                ProjectPath = $projectFullPath
                Configuration = $Configuration
                Source = $Source
                IncludeSymbols = $IncludeSymbols
                Packages = @($packages | ForEach-Object { $_.FullName })
                SymbolPackages = @($symbolPackages | ForEach-Object { $_.FullName })
            }
        }

        if ([string]::IsNullOrWhiteSpace($ApiKey)) {
            throw "NuGet API key is required. Configure NUGET_API_KEY in an environment variable or secret."
        }

        $publishStage = "Push"
        foreach ($package in $packages) {
            $pushArgs = @(
                "nuget",
                "push",
                $package.FullName,
                "--api-key",
                $ApiKey,
                "--source",
                $Source,
                "--skip-duplicate"
            )

            $pushDisplayArgs = @(
                "nuget",
                "push",
                $package.FullName,
                "--api-key",
                "***",
                "--source",
                $Source,
                "--skip-duplicate"
            )

            Invoke-LoggedCommand -FilePath "dotnet" -Arguments $pushArgs -DisplayArguments $pushDisplayArgs
        }

        return [PSCustomObject]@{
            Success = $true
            Command = "Publish"
            Stage = "Completed"
            Published = $true
            Message = "NuGet publish completed."
            ProjectPath = $projectFullPath
            Configuration = $Configuration
            Source = $Source
            IncludeSymbols = $IncludeSymbols
            Packages = @($packages | ForEach-Object { $_.FullName })
            SymbolPackages = @($symbolPackages | ForEach-Object { $_.FullName })
        }
    }
    catch {
        $_.Exception.Data["Command"] = "Publish"
        $_.Exception.Data["Stage"] = $publishStage
        $_.Exception.Data["Published"] = $false
        if (-not [string]::IsNullOrWhiteSpace($projectFullPath)) {
            $_.Exception.Data["ProjectPath"] = $projectFullPath
        }
        if (-not [string]::IsNullOrWhiteSpace($packageSearchDirectory)) {
            $_.Exception.Data["PackageSearchDirectory"] = $packageSearchDirectory
        }
        throw
    }
}

function Invoke-Main {
    if ($ProvidedParameterNames.Count -eq 0 -or $ProvidedParameterNames -contains "Help") {
        return Show-Usage
    }

    if ($ProvidedParameterNames -contains "Version") {
        return Show-Version
    }

    if ($ProvidedParameterNames -contains "Init") {
        Initialize-NuGetSecrets
        return
    }

    if ($ProvidedParameterNames -contains "List") {
        return Show-NuGetSecrets
    }

    if ($ProvidedParameterNames -contains "Edit") {
        $editParameters = @{ Edit = $true }

        if (-not [string]::IsNullOrWhiteSpace($Editor)) {
            $editParameters["Editor"] = $Editor
            Write-Host "Launching editor: $Editor"
        }
        else {
            Write-Host "Launching default editor from DevSecretsManagerPs."
        }

        Invoke-SecretsManager -Parameters $editParameters | Out-Null
        return
    }

    if ($ProvidedParameterNames -contains "Set") {
        return Set-NuGetSecrets
    }

    if ($ProvidedParameterNames -contains "Publish") {
        return Invoke-NuGetPublish
    }

    return Show-Usage
}

try {
    $ProvidedParameterNames = Get-ProvidedParameterNames
    $result = Invoke-Main

    if ($ProvidedParameterNames.Count -eq 0 -or $ProvidedParameterNames -contains "Help") {
        Write-Output $result
        return
    }

    if ($ProvidedParameterNames -contains "Init" -or $ProvidedParameterNames -contains "Edit") {
        return
    }

    Write-JsonOutput -Value $result
}
catch {
    $errorResult = [ordered]@{
        Success = $false
        Error = $_.Exception.Message
    }

    if ($_.Exception.Data.Contains("Command")) {
        $errorResult["Command"] = $_.Exception.Data["Command"]
    }

    if ($_.Exception.Data.Contains("Stage")) {
        $errorResult["Stage"] = $_.Exception.Data["Stage"]
    }

    if ($_.Exception.Data.Contains("Published")) {
        $errorResult["Published"] = $_.Exception.Data["Published"]
    }

    if ($_.Exception.Data.Contains("ProjectPath")) {
        $errorResult["ProjectPath"] = $_.Exception.Data["ProjectPath"]
    }

    if ($_.Exception.Data.Contains("PackageSearchDirectory")) {
        $errorResult["PackageSearchDirectory"] = $_.Exception.Data["PackageSearchDirectory"]
    }

    Write-JsonOutput -Value $errorResult
    exit 1
}
