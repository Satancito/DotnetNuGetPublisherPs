# Flujo De Release De Version

Este archivo describe el flujo de release que los agentes deben seguir cuando el usuario pide publicar una nueva version de `NugetPublisher.ps1`.

Estas instrucciones aplican solo al repositorio `DotnetNuGetPublisherPs`. No son instrucciones para repositorios consumidores que instalan este repositorio como herramienta.

Este repositorio incluye ambos documentos de flujo de release:

- `Version.MD`: flujo de release en ingles.
- `Version.es-ES.MD`: flujo de release en espanol.

Ambos archivos son parte de este repositorio y deben mantenerse alineados cuando cambie el flujo de release.

Este repositorio tambien incluye ambos archivos README:

- `README.md`: documentacion de uso en ingles.
- `README.es-ES.MD`: documentacion de uso en espanol.

Ambos README son parte de este repositorio y deben mantenerse alineados cuando cambie el uso, instalacion, comandos o comportamiento.

## Fuente De Version

La version del script esta almacenada en `NugetPublisher.ps1`:

```powershell
$ScriptVersion = "2.0.0"
```

El comando de version debe retornar este valor:

```powershell
.\NugetPublisher.ps1 -Version
```

Forma esperada de salida:

```text
"2.0.0"
```

## Decidir La Siguiente Version

Cuando el usuario pida publicar una nueva version, inspeccionar el historial desde el ultimo tag:

```powershell
git tag --sort=-creatordate
git log --oneline <last-tag>..HEAD
```

Si no existe un tag anterior, inspeccionar el historial relevante del repositorio:

```powershell
git log --oneline
```

Elegir la siguiente version usando SemVer:

- `MAJOR`: comportamiento incompatible de comandos, rupturas del contrato de salida, flags renombrados o eliminados, nombres de secretos incompatibles, requisitos incompatibles de `Project.json`, cambios incompatibles del layout de archivos, cambios destructivos de comportamiento, o requisitos de migracion.
- `MINOR`: comandos nuevos, parametros nuevos, nuevos flujos de publicacion soportados, nuevo comportamiento de publicacion NuGet, o funcionalidades significativas compatibles hacia atras.
- `PATCH`: correcciones de bugs, correcciones de documentacion, tests, actualizaciones del texto de ayuda, correcciones de la guia de release, o refactors internos que no cambian el comportamiento publico.

Si el tipo de incremento es ambiguo, explicar las opciones y recomendar una antes de continuar.

## Orden Del Release

Seguir este orden para cada release:

- Revisar `git status --short` e identificar cambios no relacionados del usuario.
- No revertir cambios no relacionados.
- No limpiar, resetear, sobrescribir, stagear ni commitear secretos locales.
- Validar que los archivos trackeados no contengan API keys reales de NuGet, PATs de Azure Artifacts, tokens de feeds privados u otros valores secretos.
- Determinar que cambios estan incluidos en el release.
- Elegir la siguiente version `X.Y.Z` usando SemVer.
- Crear uno o mas commits tecnicos con Conventional Commits para los cambios reales, stageando solo los archivos que pertenecen a cada commit.
- Preparar el bump final de version actualizando cada archivo que deba mencionar `X.Y.Z`, incluyendo `NugetPublisher.ps1`, `CHANGELOG.md`, `README.md`, `README.es-ES.MD`, y cualquier otra documentacion afectada.
- Stagear solo los archivos del bump final de version.
- Crear el commit final de release con `chore(release): bump DotnetNuGetPublisherPs to X.Y.Z`.
- Confirmar que no existan cambios trackeados pendientes despues del commit final de release.
- Crear el tag `X.Y.Z`.
- Hacer push del branch.
- Hacer push del tag `X.Y.Z`.
- Ejecutar las verificaciones finales.

El tag debe apuntar al commit final de release, y el commit final de release debe dejar el repositorio sin cambios trackeados pendientes.

## Preparar El Release

Antes de crear commits:

- Actualizar la documentacion de comandos cuando cambia el comportamiento.
- Mantener en `README.md` la seccion que explica como instalar esta herramienta en un proyecto consumidor con `ToolsManagerPs`.
- Mantener en `README.es-ES.MD` la seccion que explica como instalar esta herramienta en un proyecto consumidor con `ToolsManagerPs`.
- Actualizar `Version.MD` y `Version.es-ES.MD` si cambio el flujo de release.
- Ejecutar validacion del parser de PowerShell para `NugetPublisher.ps1`.
- Ejecutar smoke checks relevantes para comandos que no modifican secretos, crean paquetes ni publican artefactos.

Los secretos son valores locales de la maquina gestionados por `DevSecretsManagerPs` o inyectados mediante variables de entorno en sistemas CI/CD. No son artefactos de release, no son parte del working tree de Git, y pueden variar por desarrollador o maquina de build.

## Requisitos De Documentacion

Para cada release:

- `README.md` y `README.es-ES.MD` deben mostrar comandos validos.
- `README.md` y `README.es-ES.MD` deben documentar flags, parametros requeridos, comportamiento, valores de retorno y reglas de seguridad.
- `README.md` y `README.es-ES.MD` deben mantener el flujo de instalacion en proyectos consumidores que usa `ToolsManagerPs`.
- `README.md` y `README.es-ES.MD` deben mostrar la version actual si referencian una version.
- `CHANGELOG.md` debe contener una seccion para la version publicada usando el formato del repositorio `## X.Y.Z`, sin sufijo de fecha.
- `Version.MD` y `Version.es-ES.MD` deben seguir siendo locales al repositorio y deben describir el flujo actual de release.

Mantener `README.md` y `README.es-ES.MD` como fuente de verdad para el uso de la herramienta, instalacion y comandos disponibles.

## Validar Antes Del Commit

Validar el script de PowerShell antes de stagear:

```powershell
$tokens = $null
$errors = $null
[System.Management.Automation.Language.Parser]::ParseFile((Resolve-Path .\NugetPublisher.ps1), [ref]$tokens, [ref]$errors) | Out-Null
if ($errors.Count -gt 0) {
    $errors | ForEach-Object { $_.Message }
    exit 1
}
```

Confirmar que el script retorna la version esperada:

```powershell
.\NugetPublisher.ps1 -Version
```

Confirmar que uso/ayuda todavia renderizan:

```powershell
.\NugetPublisher.ps1
.\NugetPublisher.ps1 -Help
```

No ejecutar `-List`, `-Set`, `-Edit`, o `-Publish` como parte de una validacion normal de release, salvo que el release explicitamente requiera leer o cambiar secretos locales o hacer una publicacion real en NuGet.

Si cambio el comportamiento relacionado con listados, validar `-List` solo en un entorno controlado con secretos dummy.

Si cambio la validacion relacionada con set, preferir checks que no escriban secretos reales. Por ejemplo, valores invalidos pueden validar el comportamiento de rechazo:

```powershell
.\NugetPublisher.ps1 -Set -Configuration Invalid
```

No ejecutar `-Publish` durante validacion de release salvo que el usuario pida explicitamente una publicacion real de paquete.

## Conventional Commits

Crear commits usando Conventional Commits. Usar un subject corto y un body detallado cuando el cambio necesite contexto para futura generacion de changelog.

Ejemplo:

```powershell
git commit -m "docs(release): update release guide" -m "Update the internal release guide for DotnetNuGetPublisherPs with the current validation, documentation, staging, tagging, and push workflow. This change does not alter script behavior."
```

Usar tipos de commit segun el impacto del release:

- `feat` para funcionalidades compatibles hacia atras.
- `fix` o `perf` para cambios runtime de nivel patch.
- `docs` para cambios solo de documentacion.
- `test` para cambios solo de tests.
- `chore`, `refactor`, `style`, `build`, o `ci` para mantenimiento que no afecta comportamiento runtime.
- Agregar `!` o `BREAKING CHANGE:` solo para cambios breaking.

No incluir datos personales, secretos, credenciales, tokens, certificados, URLs privadas o connection strings en mensajes de commit.

Usar uno o mas commits tecnicos convencionales antes del commit final de release. Stagear solo los archivos que pertenecen a cada commit.

No incluir el bump final de version en un commit tecnico salvo que todo el release consista solo en el bump de version. El bump de version pertenece al commit final de release.

Ejemplos para este repositorio:

```powershell
git status --short
git add NugetPublisher.ps1
git commit -m "fix(publisher): mask api key in push logs"
git add README.md
git commit -m "docs(readme): document ToolsManagerPs installation"
git add README.es-ES.MD
git commit -m "docs(readme): add Spanish usage documentation"
git add Version.MD
git commit -m "docs(release): align release workflow"
git add Version.es-ES.MD
git commit -m "docs(release): add Spanish release workflow"
```

Los mensajes de commit deben ser suficientemente detallados para entender que cambio desde el historial de Git.

## Commit Final De Release

Despues de completar commits de features, fixes, tests y documentacion, crear un commit final de release:

```text
chore(release): bump DotnetNuGetPublisherPs to X.Y.Z
```

Antes de este commit:

- Asegurar que `NugetPublisher.ps1` tenga `$ScriptVersion = "X.Y.Z"`.
- Asegurar que `README.md` y `README.es-ES.MD` referencien `X.Y.Z` donde corresponda.
- Asegurar que `CHANGELOG.md` haya movido los items publicados desde `Unreleased` hacia `## X.Y.Z`.
- Asegurar que no esten stageados output generado de NuGet, archivos de secretos, estado de proyectos consumidores o archivos locales de entorno.

Stagear solo los archivos del bump final:

```powershell
git add NugetPublisher.ps1 README.md README.es-ES.MD CHANGELOG.md Version.MD Version.es-ES.MD
```

Crear el commit final de release:

```powershell
git commit -m "chore(release): bump DotnetNuGetPublisherPs to X.Y.Z"
```

Despues de este commit, no deben quedar cambios trackeados pendientes. Si queda algo pendiente, corregirlo con otro commit apropiado antes de crear el tag.

En releases normales, no stagear:

```text
env.json
.devsecretsmanager
bin
obj
artifacts
*.nupkg
*.snupkg
```

## Tag

Crear un tag Git usando solo la version SemVer del release.

```powershell
git tag X.Y.Z
```

Ejemplo:

```powershell
git tag 1.0.7
```

No prefijar el tag con `v`.

Usar un tag anotado solo si el usuario o la politica del repositorio lo pide. El nombre del tag tampoco debe usar `v`:

```powershell
git tag -a X.Y.Z -m "Release X.Y.Z"
```

## Push

Hacer push del branch:

```powershell
git push origin main
```

Hacer push del tag de release:

```powershell
git push origin X.Y.Z
```

Si el branch no es `main`, verificar el branch destino con el usuario o con la politica del repositorio antes de hacer push.

## Verificacion Final

Confirmar que el working tree este limpio o que solo contenga archivos locales intencionalmente untracked:

```powershell
git status --short
```

Confirmar que el tag apunta al commit de release:

```powershell
git tag --points-at HEAD
```

Confirmar que el tag existe en el remoto:

```powershell
git ls-remote --tags origin X.Y.Z
```

## Notas De Seguridad

- No stagear archivos locales de entorno del proyecto, archivos de secretos, output generado de NuGet o artefactos de paquetes.
- No stagear `.gitmodules`, `Tools/` u output de build generados por consumidores salvo que el usuario lo pida explicitamente para ese estado del repositorio.
- No ejecutar limpieza destructiva salvo que se pida explicitamente.
- No crear tags antes de que exista el commit final de release.
- Si tests o validaciones requieren acceso de red, escrituras reales de secretos o una publicacion real en NuGet, pedir aprobacion antes de ejecutarlos.
- No imprimir API keys reales, PATs o tokens de feeds privados. `NugetPublisher.ps1` debe mantener `NUGET_API_KEY` enmascarado en salida capturable y logs de comandos.

## Mejora Futura

Un flujo de release mas automatizado podria luego:

- Leer el ultimo tag.
- Calcular la siguiente version SemVer desde conventional commits.
- Actualizar `NugetPublisher.ps1`, `README.md`, `README.es-ES.MD` y `CHANGELOG.md`.
- Ejecutar validaciones seguras.
- Crear el commit de release y el tag.

Hasta que eso exista, los agentes deben seguir este flujo manual de release.
