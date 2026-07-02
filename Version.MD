# Version Release Workflow

This file describes the release flow agents must follow when the user asks to release a new `NugetPublisher.ps1` version.

These instructions apply only to the `DotnetNuGetPublisherPs` repository itself. They are not instructions for consuming repositories that install this repository as a tool.

This repository includes both release workflow documents:

- `Version.MD`: English release workflow.
- `Version.es-ES.MD`: Spanish release workflow.

Both files are part of this repository and must stay aligned when the release workflow changes.

This repository also includes both README files:

- `README.md`: English usage documentation.
- `README.es-ES.MD`: Spanish usage documentation.

Both README files are part of this repository and must stay aligned when usage, installation, commands, or behavior change.

## Version Source

The script version is stored in `NugetPublisher.ps1`:

```powershell
$ScriptVersion = "2.0.3"
```

The version command must return this value:

```powershell
.\NugetPublisher.ps1 -Version
```

Expected output shape:

```text
"2.0.3"
```

## Decide The Next Version

When the user asks to release a new version, inspect the history since the latest tag:

```powershell
git tag --sort=-creatordate
git log --oneline <last-tag>..HEAD
```

If there is no previous tag, inspect the relevant repository history:

```powershell
git log --oneline
```

Choose the next version using SemVer:

- `MAJOR`: incompatible command behavior, output contract breaks, renamed or removed flags, incompatible secret names, incompatible `Project.json` requirements, incompatible file layout changes, destructive behavior changes, or migration requirements.
- `MINOR`: new commands, new parameters, new supported publishing workflows, new NuGet publishing behavior, or meaningful backward-compatible feature additions.
- `PATCH`: bug fixes, documentation corrections, tests, help text updates, release guide fixes, or internal refactors that do not change public behavior.

If the right bump is ambiguous, explain the options and recommend one before proceeding.

## Release Order

Follow this order for every release:

- Check `git status --short` and identify unrelated user changes.
- Do not revert unrelated changes.
- Do not clear, reset, overwrite, stage, or commit local secrets.
- Validate that tracked files do not contain real NuGet API keys, Azure Artifacts PATs, private feed tokens, or other secret values.
- Determine which changes are included in the release.
- Choose the next `X.Y.Z` version using SemVer.
- Create one or more technical Conventional Commits for the actual changes, staging only the files that belong to each commit.
- Prepare the final version bump by updating every file that must mention `X.Y.Z`, including `NugetPublisher.ps1`, `CHANGELOG.md`, `README.md`, `README.es-ES.MD`, and any other affected documentation.
- Stage only the final version bump files.
- Create the final release commit with `chore(release): bump DotnetNuGetPublisherPs to X.Y.Z`.
- Confirm there are no pending tracked changes after the final release commit.
- Create the `X.Y.Z` tag.
- Push the branch.
- Push the `X.Y.Z` tag.
- Run the final checks.

The tag must point to the final release commit, and the final release commit must leave the repository with no pending tracked changes.

## Prepare The Release

Before creating commits:

- Update command documentation when behavior changes.
- Keep the `README.md` section that explains how to install this tool in a consumer project with `ToolsManagerPs`.
- Keep the `README.es-ES.MD` section that explains how to install this tool in a consumer project with `ToolsManagerPs`.
- Update `Version.MD` and `Version.es-ES.MD` if the release workflow changed.
- Run PowerShell parser validation for `NugetPublisher.ps1`.
- Run relevant smoke checks for commands that do not modify secrets, create packages, or publish artifacts.

Secrets are machine-local values managed by `DevSecretsManagerPs` or injected through environment variables in CI/CD systems. They are not release artifacts, they are not part of the Git working tree, and they can vary per developer or build machine.

## Documentation Requirements

For every release:

- `README.md` and `README.es-ES.MD` must show valid commands.
- `README.md` and `README.es-ES.MD` must document command flags, required parameters, behavior, return values, and safety rules.
- `README.md` and `README.es-ES.MD` must keep the consumer-project installation flow that uses `ToolsManagerPs`.
- `README.md` and `README.es-ES.MD` must show the current version if they reference a version.
- `CHANGELOG.md` must contain a section for the released version using the repository format `## X.Y.Z`, without a date suffix.
- `Version.MD` and `Version.es-ES.MD` must remain repository-local and must describe the current release workflow.

Keep `README.md` and `README.es-ES.MD` as the source of truth for tool usage, installation, and available commands.

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

Do not run `-List`, `-Set`, `-Edit`, or `-Publish` as part of a normal release validation unless the release explicitly requires reading or changing local secrets or performing a real NuGet publication.

If list-related behavior changed, validate `-List` only in a controlled environment with dummy secrets.

If set-related validation changed, prefer checks that do not write real secrets. For example, invalid values can validate rejection behavior:

```powershell
.\NugetPublisher.ps1 -Set -Configuration Invalid
```

Do not run `-Publish` during release validation unless the user explicitly asks for a real package publication.

## Conventional Commits

Create commits using Conventional Commits. Use a short subject and a detailed body when the change needs context for future changelog generation.

Example:

```powershell
git commit -m "docs: update release guide" -m "Update the internal release guide for DotnetNuGetPublisherPs with the current validation, documentation, staging, tagging, and push workflow. This change does not alter script behavior."
```

Use commit types according to the release impact:

- `feat` for backward-compatible features.
- `fix` or `perf` for patch-level runtime changes.
- `docs` for documentation-only changes.
- `test` for test-only changes.
- `chore`, `refactor`, `style`, `build`, or `ci` for maintenance changes that do not affect runtime behavior.
- Add `!` or `BREAKING CHANGE:` only for breaking changes.

Do not include personal data, secrets, credentials, tokens, certificates, private URLs, or connection strings in commit messages.

Use one or more technical conventional commits before the final release commit. Stage only the files that belong to each commit.

Do not include the final version bump in a technical commit unless the entire release consists only of the version bump. The version bump belongs in the final release commit.

Examples for the current repository:

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

Commit messages must be detailed enough to understand what changed from the Git history.

## Final Release Commit

After feature, fix, test, and documentation commits are complete, create one final release commit:

```text
chore(release): bump DotnetNuGetPublisherPs to X.Y.Z
```

Before this commit:

- Ensure `NugetPublisher.ps1` has `$ScriptVersion = "X.Y.Z"`.
- Ensure `README.md` and `README.es-ES.MD` reference `X.Y.Z` where relevant.
- Ensure `CHANGELOG.md` moved the released items from `Unreleased` into `## X.Y.Z`.
- Ensure no generated NuGet output, secret files, consumer project state, or local environment files are staged.

Stage only the final bump files:

```powershell
git add NugetPublisher.ps1 README.md README.es-ES.MD CHANGELOG.md Version.MD Version.es-ES.MD
```

Create the final release commit:

```powershell
git commit -m "chore(release): bump DotnetNuGetPublisherPs to X.Y.Z"
```

After this commit, there must be no pending tracked changes. If anything remains pending, fix it with another appropriate commit before tagging.

In normal releases, do not stage:

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

Create a Git tag using only the SemVer release version.

```powershell
git tag X.Y.Z
```

Example:

```powershell
git tag 1.0.7
```

Do not prefix the tag with `v`.

Use an annotated tag only if the user or repository policy asks for one. The tag name still must not use `v`:

```powershell
git tag -a X.Y.Z -m "Release X.Y.Z"
```

## Push

Push the branch:

```powershell
git push origin main
```

Push the release tag:

```powershell
git push origin X.Y.Z
```

If the branch is not `main`, verify the target branch with the user or repository policy before pushing.

## Final Check

Confirm the working tree is clean or only contains intentionally untracked local files:

```powershell
git status --short
```

Confirm the tag points at the release commit:

```powershell
git tag --points-at HEAD
```

Confirm the tag exists on the remote:

```powershell
git ls-remote --tags origin X.Y.Z
```

## Safety Notes

- Do not stage local project environment files, secret files, generated NuGet output, or package artifacts.
- Do not stage consumer-generated `.gitmodules`, `Tools/`, or project build output unless the user explicitly asks for that repository state.
- Do not run destructive cleanup unless explicitly requested.
- Do not create tags before the final release commit exists.
- If tests or validation require network access, real secret writes, or a real NuGet publish, ask for approval before running them.
- Do not print real API keys, PATs, or private feed tokens. `NugetPublisher.ps1` must keep `NUGET_API_KEY` masked in capturable output and command logs.

## Future Improvement

A more automated release flow could later:

- Read the latest tag.
- Calculate the next SemVer version from conventional commits.
- Update `NugetPublisher.ps1`, `README.md`, `README.es-ES.MD`, and `CHANGELOG.md`.
- Run safe validations.
- Create the release commit and tag.

Until that exists, agents should follow this manual release workflow.
