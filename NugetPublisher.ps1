[CmdletBinding(DefaultParameterSetName = "Help")]
param(
    [Parameter(Mandatory = $true, ParameterSetName = "Init")]
    [switch]$Init,

    [Parameter(Mandatory = $true, ParameterSetName = "List")]
    [switch]$List,

    [Parameter(Mandatory = $true, ParameterSetName = "Edit")]
    [switch]$Edit,

    [Parameter(ParameterSetName = "Edit")]
    [ValidateNotNullOrEmpty()]
    [string]$Editor,

    [Parameter(Mandatory = $true, ParameterSetName = "Set")]
    [switch]$Set,

    [Parameter(Mandatory = $true, ParameterSetName = "Publish")]
    [switch]$Publish,

    [Parameter(ParameterSetName = "Help")]
    [Alias("h", "usage")]
    [switch]$Help,

    [Parameter(ParameterSetName = "Version")]
    [Alias("v")]
    [switch]$Version,

    [Parameter(ParameterSetName = "Set", ValueFromRemainingArguments = $true)]
    [string[]]$RemainingArguments
)

$ErrorActionPreference = "Stop"
$ScriptVersion = "1.0.0"
$ProvidedParameterNames = @($PSBoundParameters.Keys)
$IgnoredSetArguments = $false
$ScriptInvocationStatement = $MyInvocation.Statement

$RequiredSecretNames = @(
    "NUGET_API_KEY",
    "NUGET_SOURCE",
    "NUGET_CSPROJ",
    "NUGET_CONFIGURATION",
    "NUGET_INCLUDE_SYMBOLS"
)

$DefaultSkipPack = $false
$DefaultSkipPush = $false
$DefaultNoRestore = $false

function Show-Usage {
    $usage = @"
NuGet Publisher

Usage:
  .\NugetPublisher.ps1 -Init
  .\NugetPublisher.ps1 -List
  .\NugetPublisher.ps1 -Edit [-Editor <editor>]
  .\NugetPublisher.ps1 -Set [-ApiKey <value>] [-Source <value>] [-Csproj <value>] [-Configuration <Debug|Release>] [options]
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
    Initializes DevSecretsManagerPs and creates these secrets with null when missing:
      NUGET_API_KEY
      NUGET_SOURCE
      NUGET_CSPROJ
      NUGET_CONFIGURATION
      NUGET_INCLUDE_SYMBOLS

  -List
    Lists only the NuGet publisher secrets in table format.

  -Edit
    Opens the DevSecretsManagerPs secrets file in an editor.
    Uses the default editor from SecretsManager.ps1 unless -Editor is provided.

    Examples:
      .\NugetPublisher.ps1 -Edit
      .\NugetPublisher.ps1 -Edit -Editor code

  -Set
    Updates only the values explicitly provided.
    Null values are ignored.
    Empty strings are saved as empty secret values.
    -Configuration stores NUGET_CONFIGURATION as Debug or Release.

    Examples:
      .\NugetPublisher.ps1 -Set -ApiKey "<nuget-api-key>"
      .\NugetPublisher.ps1 -Set -Source "https://api.nuget.org/v3/index.json"
      .\NugetPublisher.ps1 -Set -Csproj "..\MyPackage\MyPackage.csproj"
      .\NugetPublisher.ps1 -Set -Configuration Debug
      .\NugetPublisher.ps1 -Set -Configuration Release
      .\NugetPublisher.ps1 -Set -IncludeSymbols True
      .\NugetPublisher.ps1 -Set -IncludeSymbols False
      .\NugetPublisher.ps1 -Set -Source ""

  -Publish
    Builds, packs, and pushes a NuGet package using only configured secrets.
    Every NuGet publisher secret must exist and have a non-empty value:
      NUGET_API_KEY
      NUGET_SOURCE
      NUGET_CSPROJ
      NUGET_CONFIGURATION
      NUGET_INCLUDE_SYMBOLS
    Internal defaults:
      SkipPack: False
      SkipPush: False
      NoRestore: False

    Examples:
      .\NugetPublisher.ps1 -Publish

  -Version
    Prints the script version.

Options:
  -Configuration <value>
    Build configuration for dotnet build and dotnet pack. Valid values: Debug, Release.
    For -Publish, NUGET_CONFIGURATION must be configured in secrets.

  -IncludeSymbols
    Passes --include-symbols and --include-source to dotnet pack.
    For -Publish, NUGET_INCLUDE_SYMBOLS must be configured as True or False.
"@

    Write-Host $usage
}

function Show-Version {
    Write-Output $ScriptVersion
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
        [string]$Path
    )

    $resolved = Resolve-Path -LiteralPath $Path -ErrorAction SilentlyContinue

    if ($resolved) {
        return $resolved.Path
    }

    return [System.IO.Path]::GetFullPath((Join-Path (Get-Location) $Path))
}

function Resolve-SecretsManagerPath {
    $resolvedPath = Resolve-FullPath -Path "..\DevSecretsManagerPs\SecretsManager.ps1"

    if (-not (Test-Path -LiteralPath $resolvedPath -PathType Leaf)) {
        throw "SecretsManager.ps1 was not found: $resolvedPath"
    }

    return $resolvedPath
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

function Initialize-NuGetSecrets {
    Invoke-SecretsManager -Parameters @{ Init = $true } | Out-Null
    $secretStates = [ordered]@{}

    foreach ($secretName in $RequiredSecretNames) {
        $created = Invoke-SecretsManager -Parameters @{ Add = $secretName }
        $secretStates[$secretName] = if ($created) { "Created" } else { "Existing" }
    }

    Write-Host "NuGet publisher secrets initialized:"
    foreach ($secretName in $RequiredSecretNames) {
        Write-Host "  $secretName [$($secretStates[$secretName])]"
    }
}

function Convert-SecretValueToText {
    param(
        [object]$Value
    )

    if ($null -eq $Value) {
        return "null"
    }

    if ([string]::Empty -eq [string]$Value) {
        return "empty"
    }

    return [string]$Value
}

function Write-NuGetSecretsTable {
    param(
        [Parameter(Mandatory = $true)]
        [object[]]$Rows
    )

    $nameHeader = "Name"
    $valueHeader = "Value"
    $nameWidth = $nameHeader.Length
    $valueWidth = $valueHeader.Length

    foreach ($row in $Rows) {
        $nameWidth = [Math]::Max($nameWidth, ([string]$row.Name).Length)
        $valueWidth = [Math]::Max($valueWidth, (Convert-SecretValueToText -Value $row.Value).Length)
    }

    Write-Host $nameHeader.PadRight($nameWidth) -ForegroundColor Magenta -NoNewline
    Write-Host "  " -NoNewline
    Write-Host $valueHeader.PadRight($valueWidth) -ForegroundColor Magenta
    Write-Host ("─" * $nameWidth) -NoNewline
    Write-Host "  " -NoNewline
    Write-Host ("─" * $valueWidth)

    foreach ($row in $Rows) {
        $valueText = Convert-SecretValueToText -Value $row.Value
        Write-Host ([string]$row.Name).PadRight($nameWidth) -ForegroundColor Blue -NoNewline
        Write-Host "  " -NoNewline

        if ($null -eq $row.Value -or [string]::Empty -eq [string]$row.Value) {
            Write-Host $valueText.PadRight($valueWidth) -ForegroundColor Cyan
        }
        else {
            Write-Host $valueText.PadRight($valueWidth)
        }
    }
}

function Get-ConfiguredSecret {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name
    )

    $value = Invoke-SecretsManager -Parameters @{ Get = $Name }

    if ($null -eq $value) {
        return $null
    }

    return [string]$value
}

function Get-RequiredConfiguredSecret {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name
    )

    $value = Get-ConfiguredSecret -Name $Name

    if ([string]::IsNullOrWhiteSpace($value)) {
        throw "Required secret '$Name' is missing, null, or empty. Configure it before running -Publish."
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

function Get-RequiredConfiguredBoolean {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name
    )

    $value = Get-RequiredConfiguredSecret -Name $Name
    $parsed = $false

    if (-not [bool]::TryParse($value, [ref]$parsed)) {
        throw "$Name must be True or False. Current value: $value"
    }

    return $parsed
}

function Show-NuGetSecrets {
    $rows = foreach ($secretName in $RequiredSecretNames) {
        [PSCustomObject]@{
            Name = $secretName
            Value = Get-ConfiguredSecret -Name $secretName
        }
    }

    Write-NuGetSecretsTable -Rows @($rows)
}

function Set-ConfiguredSecret {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name,

        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$Value
    )

    Invoke-SecretsManager -Parameters @{
        Add = $Name
        Value = $Value
        Force = $true
    } | Out-Null
}

function Add-ProvidedParameterName {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name
    )

    if ($script:ProvidedParameterNames -notcontains $Name) {
        $script:ProvidedParameterNames += $Name
    }
}

function Remove-ProvidedParameterName {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name
    )

    $script:ProvidedParameterNames = @($script:ProvidedParameterNames | Where-Object { $_ -ne $Name })
}

function Get-SetCommandTokens {
    $errors = $null
    $source = if (-not [string]::IsNullOrWhiteSpace($ScriptInvocationStatement)) {
        $ScriptInvocationStatement
    }
    else {
        [Environment]::CommandLine
    }

    $tokens = [System.Management.Automation.PSParser]::Tokenize($source, [ref]$errors)

    if ($errors -and $errors.Count -gt 0) {
        return @()
    }

    $scriptTokenIndex = -1

    for ($i = 0; $i -lt $tokens.Count; $i++) {
        if ($tokens[$i].Content -like "*NugetPublisher.ps1" -or $tokens[$i].Content -like "*NugetPublisherPs.ps1") {
            $scriptTokenIndex = $i
            break
        }
    }

    if ($scriptTokenIndex -lt 0 -or $scriptTokenIndex -ge ($tokens.Count - 1)) {
        return @()
    }

    return @($tokens | Select-Object -Skip ($scriptTokenIndex + 1))
}

function Read-OptionalRemainingValue {
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string[]]$Arguments,

        [Parameter(Mandatory = $true)]
        [ref]$Index
    )

    $nextIndex = $Index.Value + 1

    if ($nextIndex -ge $Arguments.Count) {
        $script:IgnoredSetArguments = $true
        return $null
    }

    $nextValue = $Arguments[$nextIndex]

    if ($nextValue -like "-*") {
        $script:IgnoredSetArguments = $true
        return $null
    }

    $Index.Value = $nextIndex
    return $nextValue
}

function Read-OptionalTokenValue {
    param(
        [Parameter(Mandatory = $true)]
        [object[]]$Tokens,

        [Parameter(Mandatory = $true)]
        [ref]$Index
    )

    $nextIndex = $Index.Value + 1

    if ($nextIndex -ge $Tokens.Count) {
        $script:IgnoredSetArguments = $true
        return $null
    }

    $nextToken = $Tokens[$nextIndex]

    if ($nextToken.Type -eq "CommandParameter") {
        $script:IgnoredSetArguments = $true
        return $null
    }

    $Index.Value = $nextIndex
    return $nextToken.Content
}

function Read-SetRemainingArguments {
    $tokens = Get-SetCommandTokens

    if ($tokens.Count -gt 0) {
        for ($i = 0; $i -lt $tokens.Count; $i++) {
            $token = $tokens[$i]

            if ($token.Type -ne "CommandParameter") {
                continue
            }

            $name = $token.Content.TrimStart("-")
            $inlineValue = $null

            if ($name.Contains(":")) {
                $parts = $name.Split(":", 2)
                $name = $parts[0]
                $inlineValue = $parts[1]
            }

            switch ($name.ToLowerInvariant()) {
                "set" { }
                "apikey" {
                    $value = if ($null -ne $inlineValue) { $inlineValue } else { Read-OptionalTokenValue -Tokens $tokens -Index ([ref]$i) }

                    if ($null -eq $value) {
                        Remove-ProvidedParameterName -Name "ApiKey"
                    }
                    else {
                        $script:ApiKey = $value
                        Add-ProvidedParameterName -Name "ApiKey"
                    }
                }
                "source" {
                    $value = if ($null -ne $inlineValue) { $inlineValue } else { Read-OptionalTokenValue -Tokens $tokens -Index ([ref]$i) }

                    if ($null -eq $value) {
                        Remove-ProvidedParameterName -Name "Source"
                    }
                    else {
                        $script:Source = $value
                        Add-ProvidedParameterName -Name "Source"
                    }
                }
                "csproj" {
                    $value = if ($null -ne $inlineValue) { $inlineValue } else { Read-OptionalTokenValue -Tokens $tokens -Index ([ref]$i) }

                    if ($null -eq $value) {
                        Remove-ProvidedParameterName -Name "Csproj"
                    }
                    else {
                        $script:Csproj = $value
                        Add-ProvidedParameterName -Name "Csproj"
                    }
                }
                "configuration" {
                    $value = if ($null -ne $inlineValue) { $inlineValue } else { Read-OptionalTokenValue -Tokens $tokens -Index ([ref]$i) }

                    if ($null -eq $value) {
                        Remove-ProvidedParameterName -Name "Configuration"
                    }
                    else {
                        $script:Configuration = $value
                        Add-ProvidedParameterName -Name "Configuration"
                    }
                }
                "includesymbols" {
                    $value = if ($null -ne $inlineValue) { $inlineValue } else { Read-OptionalTokenValue -Tokens $tokens -Index ([ref]$i) }

                    if ($null -eq $value) {
                        Remove-ProvidedParameterName -Name "IncludeSymbols"
                    }
                    else {
                        $script:IncludeSymbols = $value
                        Add-ProvidedParameterName -Name "IncludeSymbols"
                    }
                }
                default {
                    throw "Unknown -Set argument: -$name"
                }
            }
        }

        return
    }

    if (-not $RemainingArguments -or $RemainingArguments.Count -eq 0) {
        foreach ($name in @("ApiKey", "Source", "Csproj", "Configuration", "IncludeSymbols")) {
            if ($ProvidedParameterNames -contains $name) {
                Remove-ProvidedParameterName -Name $name
                $script:IgnoredSetArguments = $true
            }
        }

        return
    }

    for ($i = 0; $i -lt $RemainingArguments.Count; $i++) {
        $argument = $RemainingArguments[$i]

        if ($argument -notlike "-*") {
            throw "Unexpected argument for -Set: $argument"
        }

        $name = $argument.TrimStart("-")
        $inlineValue = $null

        if ($name.Contains(":")) {
            $parts = $name.Split(":", 2)
            $name = $parts[0]
            $inlineValue = $parts[1]
        }

        switch ($name.ToLowerInvariant()) {
            "apikey" {
                $value = if ($null -ne $inlineValue) { $inlineValue } else { Read-OptionalRemainingValue -Arguments $RemainingArguments -Index ([ref]$i) }

                if ($null -ne $value) {
                    $script:ApiKey = $value
                    Add-ProvidedParameterName -Name "ApiKey"
                }
            }
            "source" {
                $value = if ($null -ne $inlineValue) { $inlineValue } else { Read-OptionalRemainingValue -Arguments $RemainingArguments -Index ([ref]$i) }

                if ($null -ne $value) {
                    $script:Source = $value
                    Add-ProvidedParameterName -Name "Source"
                }
            }
            "csproj" {
                $value = if ($null -ne $inlineValue) { $inlineValue } else { Read-OptionalRemainingValue -Arguments $RemainingArguments -Index ([ref]$i) }

                if ($null -ne $value) {
                    $script:Csproj = $value
                    Add-ProvidedParameterName -Name "Csproj"
                }
            }
            "configuration" {
                $value = if ($null -ne $inlineValue) { $inlineValue } else { Read-OptionalRemainingValue -Arguments $RemainingArguments -Index ([ref]$i) }

                if ($null -ne $value) {
                    $script:Configuration = $value
                    Add-ProvidedParameterName -Name "Configuration"
                }
            }
            "includesymbols" {
                $value = if ($null -ne $inlineValue) { $inlineValue } else { Read-OptionalRemainingValue -Arguments $RemainingArguments -Index ([ref]$i) }

                if ($null -ne $value) {
                    $script:IncludeSymbols = $value
                    Add-ProvidedParameterName -Name "IncludeSymbols"
                }
            }
            default {
                throw "Unknown -Set argument: -$name"
            }
        }
    }
}

function Set-NuGetSecrets {
    $updates = [ordered]@{}
    $invalidParameters = @()
    $setParameterNames = @(
        "ApiKey",
        "Source",
        "Csproj",
        "Configuration",
        "IncludeSymbols"
    ) |
        Where-Object { $ProvidedParameterNames -contains $_ }

    if ($ProvidedParameterNames -contains "Debug") {
        throw "Use -Set -Configuration Debug instead of -Set -Debug."
    }

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
            $updates["NUGET_SOURCE"] = [string]$Source
        }
    }

    if ($ProvidedParameterNames -contains "Csproj") {
        if ($null -eq $Csproj) {
            # Null means "leave this secret unchanged".
        }
        else {
            $updates["NUGET_CSPROJ"] = [string]$Csproj
        }
    }

    if ($ProvidedParameterNames -contains "Configuration") {
        if ($null -eq $Configuration) {
            # Null means "leave this secret unchanged".
        }
        elseif (-not [string]::IsNullOrEmpty([string]$Configuration) -and [string]$Configuration -notin @("Debug", "Release")) {
            throw "Configuration must be Debug or Release."
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
            $parsedIncludeSymbols = $false

            if (-not [bool]::TryParse([string]$IncludeSymbols, [ref]$parsedIncludeSymbols)) {
                throw "IncludeSymbols must be True or False."
            }

            $updates["NUGET_INCLUDE_SYMBOLS"] = [string]$parsedIncludeSymbols
        }
    }

    if ($invalidParameters.Count -gt 0) {
        throw "These -Set values cannot be null or empty: $($invalidParameters -join ', ')."
    }

    if ($setParameterNames.Count -eq 0) {
        if ($IgnoredSetArguments) {
            Write-Host "No NuGet publisher secrets updated."
            return
        }

        throw "Use -Set with at least one value: -ApiKey, -Source, -Csproj, -Configuration, or -IncludeSymbols."
    }

    if ($updates.Count -eq 0) {
        Write-Host "No NuGet publisher secrets updated."
        return
    }

    foreach ($entry in $updates.GetEnumerator()) {
        Set-ConfiguredSecret -Name $entry.Key -Value $entry.Value
    }

    Write-Host "NuGet publisher secrets updated:"
    foreach ($secretName in $updates.Keys) {
        Write-Host "  $secretName"
    }
}

if ($PSBoundParameters.Count -eq 0 -or $PSCmdlet.ParameterSetName -eq "Help" -or $Help) {
    Show-Usage
    return
}

if ($PSCmdlet.ParameterSetName -eq "Version" -or $Version) {
    Show-Version
    return
}

if ($Init) {
    Initialize-NuGetSecrets
    return
}

if ($List) {
    Show-NuGetSecrets
    return
}

if ($Edit) {
    $editParameters = @{ Edit = $true }

    if (-not [string]::IsNullOrWhiteSpace($Editor)) {
        $editParameters["Editor"] = $Editor
    }

    Invoke-SecretsManager -Parameters $editParameters | Out-Null
    return
}

if ($Set) {
    Read-SetRemainingArguments
    Set-NuGetSecrets
    return
}

$ApiKey = Get-RequiredConfiguredSecret -Name "NUGET_API_KEY"
$Source = Get-RequiredConfiguredSecret -Name "NUGET_SOURCE"
$ProjectPath = Get-RequiredConfiguredSecret -Name "NUGET_CSPROJ"
$Configuration = Get-RequiredConfiguredSecret -Name "NUGET_CONFIGURATION"

if ($Configuration -notin @("Debug", "Release")) {
    throw "NUGET_CONFIGURATION must be Debug or Release. Current value: $Configuration"
}

$SkipPack = $DefaultSkipPack
$SkipPush = $DefaultSkipPush
$IncludeSymbols = Get-RequiredConfiguredBoolean -Name "NUGET_INCLUDE_SYMBOLS"
$NoRestore = $DefaultNoRestore

if ([string]::IsNullOrWhiteSpace($ProjectPath)) {
    throw "Project path is required. Configure NUGET_CSPROJ before running -Publish."
}

if (-not (Get-Command dotnet -ErrorAction SilentlyContinue)) {
    throw "The dotnet CLI was not found on PATH."
}

$projectFullPath = Resolve-FullPath -Path $ProjectPath

if (-not (Test-Path -LiteralPath $projectFullPath)) {
    throw "Project path does not exist: $projectFullPath"
}

$projectDirectory = Split-Path -Parent $projectFullPath
$packageSearchDirectory = Join-Path $projectDirectory (Join-Path "bin" $Configuration)
$publishStartedAtUtc = [DateTime]::UtcNow.AddSeconds(-5)

if (-not $SkipPack) {
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

$packages = if (Test-Path -LiteralPath $packageSearchDirectory -PathType Container) {
    Get-ChildItem -LiteralPath $packageSearchDirectory -Filter "*.nupkg" -File -Recurse
}
else {
    @()
}

$packages = $packages |
    Where-Object { $_.Name -notlike "*.symbols.nupkg" } |
    Where-Object { $SkipPack -or $_.LastWriteTimeUtc -ge $publishStartedAtUtc } |
    Sort-Object LastWriteTimeUtc -Descending

if (-not $packages) {
    throw "No .nupkg files were found in $packageSearchDirectory."
}

if ($SkipPush) {
    Write-Host "Packages created:"
    $packages | ForEach-Object { Write-Host "  $($_.FullName)" }
    return
}

if ([string]::IsNullOrWhiteSpace($ApiKey)) {
    throw "NuGet API key is required. Pass -ApiKey or set the NUGET_API_KEY environment variable."
}

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

Write-Host "NuGet publish completed."
