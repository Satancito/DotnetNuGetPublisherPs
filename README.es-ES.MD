# DotnetNuGetPublisherPs

`DotnetNuGetPublisherPs` es una herramienta PowerShell para preparar y publicar paquetes .NET en NuGet.org usando el CLI `dotnet`.

La herramienta guarda configuracion de publicacion NuGet mediante `DevSecretsManagerPs`, lee el path del proyecto de paquete desde `Project.json`, resuelve overrides desde variables de entorno para escenarios CI/CD, compila el `.csproj` configurado, crea el paquete NuGet con `dotnet pack`, y publica el `.nupkg` generado con `dotnet nuget push`.

## Script

```powershell
.\NugetPublisher.ps1
```

Version actual:

```powershell
.\NugetPublisher.ps1 -Version
```

Retorna:

```text
"2.0.0"
```

`-Version` y `-Help` no inicializan secretos, no crean archivos, no compilan proyectos, no empaquetan y no publican artefactos.

Este script espera que `DevSecretsManagerPs` exista en el directorio hermano:

```text
../DevSecretsManagerPs/SecretsManager.ps1
```

Los comandos que leen o mutan secretos delegan el almacenamiento a `DevSecretsManagerPs`.

Los comandos con resultados capturables escriben JSON en stdout. Los valores escalares se emiten como escalares JSON validos: booleanos como `true` o `false`, strings como `"value"`, null como `null`, y strings vacios como `""`. Los fallos escriben un objeto JSON de error y salen con codigo `1`. `-Help` imprime ayuda como texto plano para que se pueda capturar directamente. `-Init` y `-Edit` imprimen solo progreso interactivo y no producen un resultado capturable.

Esta herramienta lee los secretos guardados usando el contrato actual de `DevSecretsManagerPs`: `SecretsManager.ps1 -List` retorna el JSON crudo de secrets.

## Instalar En Un Proyecto Consumidor Con ToolsManagerPs

Los proyectos consumidores pueden instalar este repositorio como herramienta usando `ToolsManagerPs`.

Descargar `ProjectManager.ps1` en la raiz del proyecto consumidor:

```powershell
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/Satancito/ToolsManagerPs/main/ProjectManager.ps1" -OutFile "ProjectManager.ps1" -UseBasicParsing
```

Inicializar la configuracion del proyecto consumidor:

```powershell
.\ProjectManager.ps1 -Init
```

Instalar primero `DevSecretsManagerPs`. `DotnetNuGetPublisherPs` depende de esta herramienta y espera que este disponible como herramienta hermana:

```powershell
.\ProjectManager.ps1 -Tools Add -RepositoryName DevSecretsManagerPs -RepositoryUrl https://github.com/Satancito/DevSecretsManagerPs.git -Tag ""
```

Luego instalar `DotnetNuGetPublisherPs`:

```powershell
.\ProjectManager.ps1 -Tools Add -RepositoryName DotnetNuGetPublisherPs -RepositoryUrl https://github.com/Satancito/DotnetNuGetPublisherPs.git -Tag ""
```

El layout esperado del proyecto consumidor es:

```text
Tools/DevSecretsManagerPs
Tools/DotnetNuGetPublisherPs
```

`-Tag ""` guarda `Tag` como `null`. Un tag `null` significa que la herramienta se actualiza al ultimo commit remoto cuando se ejecuta `-Tools Update`.

El valor de `-Tag` puede ser:

- `null`, pasando `-Tag ""`, para seguir el ultimo commit remoto.
- Un Git tag, para fijar la herramienta a una version publicada.
- Un SHA de commit Git, para fijar la herramienta a un commit exacto.

## Archivos

### Documentacion Del Repositorio

Los siguientes archivos de documentacion son parte de este repositorio:

- `README.md`: documentacion principal de uso, instalacion, comandos y comportamiento en ingles.
- `README.es-ES.MD`: documentacion principal de uso, instalacion, comandos y comportamiento en espanol.
- `CHANGELOG.md`: historial de releases y cambios no publicados.
- `Version.MD`: flujo de release local del repositorio en ingles.
- `Version.es-ES.MD`: flujo de release local del repositorio en espanol.

`README.md` y `README.es-ES.MD` deben mantenerse alineados cuando cambie el uso, instalacion, comandos o comportamiento.

`Version.MD` y `Version.es-ES.MD` son documentos de flujo de release para este repositorio. No son archivos de configuracion de proyectos consumidores.

### Script De Publicacion

El script reusable de publicacion NuGet es:

```text
NugetPublisher.ps1
```

`-Init` inicializa la herramienta hermana `DevSecretsManagerPs` y crea los secretos faltantes del publicador NuGet. No copia archivos al proyecto consumidor y no stagea ni commitea archivos del consumidor.

La raiz del proyecto consumidor debe contener `Project.json` con una propiedad `Project` que apunte al `.csproj` del paquete:

```json
{
  "Project": ".\\src\\MyLibrary\\MyLibrary.csproj"
}
```

Los valores relativos de `Project` se resuelven desde la raiz del proyecto consumidor, que es `../../` desde el directorio de la herramienta.

El `.csproj` seleccionado debe contener metadata normal de paquete NuGet.

Ejemplo:

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

`NugetPublisher.ps1` no crea ni edita metadata de paquete en el `.csproj`. Solo compila, empaqueta y publica el proyecto configurado.

### Secretos

Los valores del publicador NuGet se guardan mediante `DevSecretsManagerPs` usando estos nombres de secretos:

```text
NUGET_API_KEY
NUGET_SOURCE
NUGET_CONFIGURATION
NUGET_INCLUDE_SYMBOLS
```

Cuando `-Init` crea valores faltantes, usa estos defaults para publicar en NuGet.org:

```json
{
  "NUGET_API_KEY": null,
  "NUGET_SOURCE": "https://api.nuget.org/v3/index.json",
  "NUGET_CONFIGURATION": "Release",
  "NUGET_INCLUDE_SYMBOLS": true
}
```

Los secretos existentes no se sobrescriben con `-Init`.

Referencia de secretos:

| Secreto | Que significa | Valor esperado |
| --- | --- | --- |
| `NUGET_API_KEY` | API key usado por `dotnet nuget push`. | Requerido para publish. Crealo desde tu cuenta de NuGet.org. No lo commitees. |
| `NUGET_SOURCE` | URL del feed NuGet usado por `dotnet nuget push`. | Valor string. `-Set` acepta valores null o vacios. Los valores no vacios deben existir o `-Set` retorna `false`. Las respuestas HTTP `401` y `403` cuentan como endpoints existentes validos. Publish requiere un endpoint existente y no vacio. Para NuGet.org usa `https://api.nuget.org/v3/index.json`. |
| `NUGET_CONFIGURATION` | Configuracion de build para `dotnet build` y `dotnet pack`. | Requerido para publish. `-Set` acepta `Debug`, `Release`, vacio o null. Cualquier otro valor hace que `-Set` retorne `false`. Publish requiere exactamente `Debug` o `Release` antes de iniciar build. `Release` es recomendado para paquetes reales. |
| `NUGET_INCLUDE_SYMBOLS` | Controla si `dotnet pack` recibe `--include-symbols --include-source`. | Requerido para publish. `-Set` acepta valores booleanos de PowerShell como `$true` o `$false`. El secreto se guarda y lista como boolean JSON. `true` es recomendado para paquetes reutilizables. |

Estas opciones de publish estan fijas intencionalmente en el script y no se guardan como secretos:

```text
SkipPack: False
SkipPush: False
NoRestore: False
```

Eso significa que `-Publish` siempre compila, empaqueta y publica. Tambien permite restore durante `dotnet build` y `dotnet pack`.

## Validacion

`-Init`, `-List`, `-Edit`, `-Set`, y `-Publish` inicializan y validan acceso a la herramienta hermana `DevSecretsManagerPs` antes de ejecutarse.

`-Publish` es intencionalmente estricto. Cada valor requerido debe resolverse a un valor no vacio:

```text
NUGET_API_KEY
NUGET_SOURCE
NUGET_CONFIGURATION
NUGET_INCLUDE_SYMBOLS
```

El archivo consumidor `Project.json` tambien debe contener una propiedad `Project` no vacia que apunte al `.csproj` del paquete.

`NUGET_CONFIGURATION` se valida antes de iniciar cualquier build. Publish falla salvo que resuelva a `Debug` o `Release`.

`NUGET_SOURCE` se valida antes de iniciar cualquier build. Publish falla salvo que resuelva a un endpoint existente y no vacio. Las respuestas HTTP `401` y `403` cuentan como endpoints existentes validos.

`NUGET_API_KEY` se valida antes de iniciar cualquier push. Publish falla cuando es null, vacio o whitespace.

Las variables de entorno tienen prioridad sobre los secretos guardados cuando existen y no son null, vacias ni whitespace. Si una variable de entorno no existe o esta vacia, el valor se lee desde `DevSecretsManagerPs`.

Ejemplo:

```powershell
$env:NUGET_API_KEY = "temporary-api-key"
.\NugetPublisher.ps1 -Publish
```

En ese caso, `NUGET_API_KEY` viene del environment y los otros valores pueden seguir viniendo de secrets. Esto sirve para GitHub Actions y otros sistemas CI/CD donde los secretos se inyectan como variables de entorno.

Si algun valor requerido no se puede resolver desde environment ni secrets, o si un valor es invalido, el script falla antes de ejecutar `dotnet build`, `dotnet pack` o `dotnet nuget push`.

## Help

```powershell
.\NugetPublisher.ps1 -Help
.\NugetPublisher.ps1 -h
.\NugetPublisher.ps1 -help
.\NugetPublisher.ps1 -usage
.\NugetPublisher.ps1 -Usage
```

Imprime el uso de comandos como texto plano capturable.

Ejecutar el script sin flags tambien imprime el uso:

```powershell
.\NugetPublisher.ps1
```

## Init

```powershell
.\NugetPublisher.ps1 -Init
```

Inicializa `DevSecretsManagerPs` y crea los secretos faltantes del publicador NuGet.

Secretos creados:

```text
NUGET_API_KEY
NUGET_SOURCE
NUGET_CONFIGURATION
NUGET_INCLUDE_SYMBOLS
```

Los valores faltantes se crean con los defaults de NuGet.org documentados arriba. Los valores existentes no se sobrescriben.

Imprime solo el resumen final de creados/actualizados o un error. No produce un resultado capturable.

## List

```powershell
.\NugetPublisher.ps1 -List
```

Retorna JSON capturable solo con las propiedades de secrets del publicador NuGet que maneja esta herramienta.

Ejemplo de salida:

```json
{
  "NUGET_API_KEY": null,
  "NUGET_SOURCE": "https://api.nuget.org/v3/index.json",
  "NUGET_CONFIGURATION": "Release",
  "NUGET_INCLUDE_SYMBOLS": true
}
```

Este comando lee secretos locales. No lo ejecutes en logs o terminales compartidas donde los valores puedan exponerse.

`NUGET_API_KEY` siempre se enmascara en la salida capturable.

## Edit

```powershell
.\NugetPublisher.ps1 -Edit
.\NugetPublisher.ps1 -Edit -Editor <EditorName>
```

Abre el archivo de secretos de `DevSecretsManagerPs` en un editor.

Imprime que editor se lanza usando salida no capturable y no retorna un valor por pipeline.

## Set

```powershell
.\NugetPublisher.ps1 -Set -ApiKey "your-nuget-api-key"
.\NugetPublisher.ps1 -Set -Source "https://api.nuget.org/v3/index.json"
.\NugetPublisher.ps1 -Set -Configuration Release
.\NugetPublisher.ps1 -Set -Configuration Debug
.\NugetPublisher.ps1 -Set -IncludeSymbols $true
.\NugetPublisher.ps1 -Set -IncludeSymbols $false
```

Actualiza solo los valores pasados explicitamente.

Retorna `true` cuando los valores proporcionados se guardan. Retorna `false` cuando solo se enviaron valores `$null`.

`-Set` tambien retorna `false` cuando un valor no vacio de `-Source` no parece existir, o cuando `-Configuration` no es `Debug`, `Release`, vacio o null.

Flags soportados:

```text
-ApiKey
-Source
-Configuration
-IncludeSymbols
```

`-Configuration` usa `ValidateSet` y acepta:

```text
Debug
Release
empty string
null
```

`-IncludeSymbols` acepta valores booleanos:

```text
$true
$false
1
0
null
```

`-Source` es un parametro string. Los valores source vacios se guardan como valores secretos vacios. Los valores source null se ignoran. Los valores source no vacios deben existir antes de guardarse o `-Set` retorna `false`; las respuestas HTTP `401` y `403` se aceptan como endpoints existentes.

Los valores null se ignoran. Los strings vacios se guardan como valores secretos vacios para valores de texto y `-Configuration`. `-IncludeSymbols` debe ser un valor booleano de PowerShell cuando se proporciona.

## Publish

```powershell
.\NugetPublisher.ps1 -Publish
```

Publica un paquete .NET en NuGet.org mediante el `.csproj`, feed source, API key, configuracion y opcion de simbolos configurados.

Durante publish, la herramienta:

- Valida secretos y variables de entorno.
- Resuelve variables de entorno antes que secretos guardados cuando los valores de entorno no son null ni vacios.
- Lee el `.csproj` del paquete desde `Project.json` usando la propiedad `Project`.
- Compila el `.csproj` resuelto con `dotnet build`.
- Empaqueta el `.csproj` resuelto con `dotnet pack --no-build`.
- Agrega `--include-symbols --include-source` cuando `NUGET_INCLUDE_SYMBOLS` es `True`.
- Busca archivos `.nupkg` y `.snupkg` generados debajo de `<project-directory>\bin\<Configuration>`.
- Excluye paquetes legacy `*.symbols.nupkg`.
- Publica los archivos de paquete generados con `dotnet nuget push`, publicando los `.nupkg` normales antes que los paquetes de simbolos `.snupkg`.

Los comandos ejecutados son equivalentes a:

```powershell
dotnet build ..\MyLibrary\MyLibrary.csproj --configuration Release
dotnet pack ..\MyLibrary\MyLibrary.csproj --configuration Release --no-build --include-symbols --include-source
dotnet nuget push <generated-package.nupkg> --api-key *** --source https://api.nuget.org/v3/index.json --skip-duplicate
dotnet nuget push <generated-symbols.snupkg> --api-key *** --source https://api.nuget.org/v3/index.json --skip-duplicate
```

El API key se enmascara en el log de comandos.

El API key tambien se enmascara en la salida JSON y mensajes de error.

NuGet.org no permite sobrescribir una version existente de un paquete. Antes de publicar otra vez, actualiza la version del paquete en el `.csproj`.

Si el paquete ya existe, el script usa `--skip-duplicate` para que los pushes duplicados se omitan en lugar de tratarse como un fallo fatal de publicacion por NuGet.

El comando publish retorna un objeto JSON capturable. Los agentes deben tratar `Success = true`, `Published = true`, y exit codes exitosos de procesos como una ejecucion exitosa del comando publish.

El JSON exitoso incluye `Success`, `Command`, `Stage`, `Published`, `ProjectPath`, `Configuration`, `Source`, `IncludeSymbols`, `Packages`, y `SymbolPackages`.

Si publish falla, el comando retorna un objeto JSON de error con `Success = false`, `Command = "Publish"`, el ultimo `Stage` completado o fallido, `Published = false`, y sale con codigo `1`.

## Version

```powershell
.\NugetPublisher.ps1 -Version
.\NugetPublisher.ps1 -version
.\NugetPublisher.ps1 -v
```

Retorna la version del script como string JSON.

```text
"2.0.0"
```

## Flujo Recomendado

Instalar las herramientas requeridas en el proyecto consumidor:

```powershell
.\ProjectManager.ps1 -Tools Add -RepositoryName DevSecretsManagerPs -RepositoryUrl https://github.com/Satancito/DevSecretsManagerPs.git -Tag ""
.\ProjectManager.ps1 -Tools Add -RepositoryName DotnetNuGetPublisherPs -RepositoryUrl https://github.com/Satancito/DotnetNuGetPublisherPs.git -Tag ""
```

Inicializar secretos del publicador:

```powershell
.\Tools\DotnetNuGetPublisherPs\NugetPublisher.ps1 -Init
```

Configurar secretos:

```powershell
.\Tools\DotnetNuGetPublisherPs\NugetPublisher.ps1 -Set -Source "https://api.nuget.org/v3/index.json"
.\Tools\DotnetNuGetPublisherPs\NugetPublisher.ps1 -Set -Configuration Release
.\Tools\DotnetNuGetPublisherPs\NugetPublisher.ps1 -Set -IncludeSymbols $true
.\Tools\DotnetNuGetPublisherPs\NugetPublisher.ps1 -Set -ApiKey "<nuget-api-key>"
```

Publicar con el `.csproj` configurado:

```powershell
.\Tools\DotnetNuGetPublisherPs\NugetPublisher.ps1 -Publish
```

## Variables De Entorno CI

Para CI/CD, expone los mismos nombres usados por esta herramienta como variables de entorno antes de invocar `-Publish`.

Los valores de environment se usan solo cuando no son null, vacios ni whitespace. Los valores de environment vacios hacen fallback a los secrets locales.

Ejemplo para NuGet.org:

```yaml
env:
  NUGET_API_KEY: ${{ secrets.NUGET_API_KEY }}
  NUGET_SOURCE: https://api.nuget.org/v3/index.json
  NUGET_CONFIGURATION: Release
  NUGET_INCLUDE_SYMBOLS: "true"
```

Ejemplo para Azure Artifacts con feed de proyecto:

```yaml
env:
  NUGET_API_KEY: ${{ secrets.AZURE_ARTIFACTS_PAT }}
  NUGET_SOURCE: https://pkgs.dev.azure.com/<organization>/<project>/_packaging/<feed>/nuget/v3/index.json
  NUGET_CONFIGURATION: Release
  NUGET_INCLUDE_SYMBOLS: "true"
```

Ejemplo para Azure Artifacts con feed de organizacion:

```yaml
env:
  NUGET_API_KEY: ${{ secrets.AZURE_ARTIFACTS_PAT }}
  NUGET_SOURCE: https://pkgs.dev.azure.com/<organization>/_packaging/<feed>/nuget/v3/index.json
  NUGET_CONFIGURATION: Release
  NUGET_INCLUDE_SYMBOLS: "true"
```

Equivalente en PowerShell:

```powershell
$env:NUGET_API_KEY = "<azure-artifacts-pat>"
$env:NUGET_SOURCE = "https://pkgs.dev.azure.com/<organization>/<project>/_packaging/<feed>/nuget/v3/index.json"
$env:NUGET_CONFIGURATION = "Release"
$env:NUGET_INCLUDE_SYMBOLS = "true"
```

Para feeds privados de Azure Artifacts, autentica NuGet antes de ejecutar `-Publish`. En Azure Pipelines, `NuGetAuthenticate@1` configura el credential provider para el job. Fuera de Azure Pipelines, configura Azure Artifacts Credential Provider o agrega las credenciales del source a NuGet antes de invocar este script.

`NUGET_API_KEY` se envia solo por `dotnet nuget push` mediante la opcion `--api-key`. La validacion del endpoint no envia el API key.

## Seguridad

No commitear secretos reales, API keys, stores locales de secretos, paquetes NuGet generados, ni output de build generado.

No ejecutar `-List` en logs o terminales compartidas donde los valores secretos puedan exponerse.

No ejecutar `-Publish` salvo que intencionalmente quieras publicar un paquete en el feed NuGet configurado.
