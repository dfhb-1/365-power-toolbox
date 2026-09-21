# Contributing to PowerToolbox

## Adding a tool

1. **Scaffold it.**

   ```powershell
   ./tools/New-Tool.ps1 -Name Get-MailboxReport -Synopsis 'Summarise mailbox sizes.'
   ```

   This writes `PowerToolbox/Public/Get-MailboxReport.ps1` from a template and adds the name to
   `FunctionsToExport` in the manifest. It refuses to overwrite an existing file.

2. **Write the function**, reusing the private helpers rather than reinventing them:

   | Helper | What it does |
   |---|---|
   | `Connect-PtExchange` | Ensures an Exchange Online session; throws a clear `Install-Module` message if the SDK is missing. |
   | `Connect-PtGraph` | Same for Microsoft Graph, requesting the group and user scopes. |
   | `Write-PtLog` | Timestamped console output, colour-coded by level, optionally appended to `-LogPath`. |
   | `Get-PtInstallPath` | The current user's module folder for the running edition. |
   | `Get-PtGitHubRelease` | Looks up a release on GitHub and returns its version, notes and asset URL. |
   | `Resolve-EgmGroup` | Resolves a group by name or ID, failing clearly when a name is ambiguous. |
   | `Get-EgmUserList` | Merges `-Users` and `-CsvPath` into one de-duplicated list. |
   | `Invoke-EgmMembershipChange` | The add/remove worker: handles ShouldProcess, skipping and the summary. |

3. **Add comment-based help** with a `.SYNOPSIS` and at least one `.EXAMPLE`. The tests enforce
   both. Use `contoso.com` placeholders — this repository is public, so never commit real user
   addresses, group names or tenant IDs.

4. **Run the tests.**

   ```powershell
   Invoke-Pester ./tests
   ```

5. **Bump `ModuleVersion`** in `PowerToolbox/PowerToolbox.psd1` and add a `CHANGELOG.md` entry
   under `[Unreleased]`, if the change is user-facing.

6. **Open a pull request.** CI runs the suite on Ubuntu, Windows PowerShell 7 and Windows
   PowerShell 5.1.

## Releasing

1. Move the `[Unreleased]` notes into a new `## [x.y.z] - YYYY-MM-DD` section in `CHANGELOG.md`,
   and add the two link definitions at the bottom of the file.
2. Set the matching `ModuleVersion` in the manifest. The release workflow **fails** if the tag
   and the manifest disagree, so these must be changed together.
3. Merge to `main` and let CI pass.
4. Tag and push:

   ```powershell
   git tag v1.2.0
   git push origin v1.2.0
   ```

GitHub Actions then reruns the tests, builds `PowerToolbox.zip` (with `PowerToolbox/` and
`install.ps1` side by side at its root), verifies that layout, and publishes the release using
your changelog section as the notes. Users pick it up with `Update-PowerToolbox`.

## Conventions

**One function per file**, in `Public/` or `Private/`, named exactly like the file. A test
enforces this in both directions, so a new tool cannot be silently left unexported.

**`Verb-Noun` with an approved verb** — check with `Get-Verb`. `New-Tool.ps1` validates this
for you.

**Prefix shared private helpers with `Pt-`** (`Write-PtLog`, `Connect-PtGraph`). Helpers
specific to one tool family keep that family's prefix, as the `Egm-` group helpers do.

**`SupportsShouldProcess` on anything that changes state**, and actually call
`$PSCmdlet.ShouldProcess(...)` before the change. If you delegate that call to a worker
function, suppress `PSShouldProcess` on the wrapper with a `Justification` explaining where
the real call lives.

**Write PowerShell 5.1-compatible syntax.** 5.1 is still the default shell on Windows and CI
tests against it. Banned, because 5.1 cannot parse them:

- null-coalescing `??` and `??=`
- null-conditional `$x?.Prop`
- pipeline chain operators `&&` and `||`
- ternary `a ? b : c`
- `ForEach-Object -Parallel`

Also never dereference `$IsWindows` bare — it does not exist on 5.1. Guard it:

```powershell
$onWindows = ($PSVersionTable.PSEdition -eq 'Desktop')
if (-not $onWindows -and (Get-Variable -Name 'IsWindows' -ErrorAction SilentlyContinue)) {
    $onWindows = $IsWindows
}
```

**Keep every shipped file pure ASCII.** Windows PowerShell 5.1 decodes a BOM-less UTF-8 file
as the system ANSI code page, so a stray em dash or curly quote becomes mojibake. A test
enforces this.

**Use `Write-PtLog` for operator output** and return objects to the pipeline for data. Console
colour is deliberate here, which is why `PSAvoidUsingWriteHost` is disabled repo-wide.

**Throw actionable errors for missing dependencies** — name the exact `Install-Module` command
rather than letting a `CommandNotFoundException` surface.
