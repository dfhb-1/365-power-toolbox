# PowerToolbox

PowerShell commands for the Microsoft 365 administration we do often: granting calendar
access on an Exchange Online mailbox, and adding or removing members of Microsoft Entra ID
groups. Everything supports `-WhatIf`, takes users inline or from a CSV, and skips work that
is already done rather than erroring.

## Install

```powershell
irm https://raw.githubusercontent.com/dfhb-1/365-power-toolbox/main/install.ps1 | iex
```

Or from a clone:

```powershell
git clone https://github.com/dfhb-1/365-power-toolbox.git
cd 365-power-toolbox
./install.ps1
```

No admin rights needed — it installs to your own user module folder. **No `$PROFILE` changes
needed either:** the commands load automatically the first time you use one.

To pin a specific version: `./install.ps1 -Version v1.0.0`

## Prerequisites

Install these once, for the commands you actually use:

```powershell
Install-Module ExchangeOnlineManagement -Scope CurrentUser   # Add-CalendarPermission
Install-Module Microsoft.Graph -Scope CurrentUser            # Add-/Remove-EntraGroupMember
```

The installer tells you which are missing but never installs them for you. PowerToolbox
imports fine without them; you only get an error if you run a command that needs one.

Each command signs you in on first use. To connect ahead of time:

```powershell
Connect-ExchangeOnline
Connect-MgGraph -Scopes GroupMember.ReadWrite.All, User.Read.All, Group.Read.All
```

## Update

```powershell
Update-PowerToolbox -CheckOnly   # report only
Update-PowerToolbox              # install the latest release
```

Open a new PowerShell session afterwards — the running session keeps the old code loaded.

## Commands

### `Add-CalendarPermission`

Grant a user or group access to a mailbox's calendar.

```powershell
Add-CalendarPermission -Mailbox conference-room@contoso.com -User user@contoso.com

Add-CalendarPermission -Mailbox director@contoso.com -User assistant@contoso.com -AccessRights Editor

Add-CalendarPermission -Mailbox director@contoso.com -User "Sales Team" -AccessRights LimitedDetails -WhatIf
```

`-AccessRights` defaults to `Reviewer` (read everything, change nothing). The other roles are
`None`, `AvailabilityOnly`, `LimitedDetails`, `Contributor`, `NonEditingAuthor`, `Author`,
`PublishingAuthor`, `Editor`, `PublishingEditor` and `Owner`. Run it with no arguments and it
prompts for the mailbox and user.

### `Add-EntraGroupMember`

Add one or more users to a Microsoft Entra ID group.

```powershell
Add-EntraGroupMember -GroupName "Sales Team" -Users "user@contoso.com"

Add-EntraGroupMember -GroupName "All Staff" -CsvPath .\newhires.csv -WhatIf
```

### `Remove-EntraGroupMember`

Remove one or more users from a Microsoft Entra ID group.

```powershell
Remove-EntraGroupMember -GroupName "Sales Team" -Users "user@contoso.com"

Remove-EntraGroupMember -GroupId "11111111-2222-3333-4444-555555555555" -CsvPath .\offboarding.csv -WhatIf
```

Both group commands accept the group by `-GroupName` or `-GroupId`, and users by UPN, email
or object ID — inline via `-Users`, from a CSV via `-CsvPath`, or both at once. A CSV needs a
`UserPrincipalName`, `Email` or `UPN` column. Users already in the desired state are skipped,
and you get a Success / Skipped / Failed summary at the end. Add `-LogPath .\run.log` to write
that to a file.

### `Update-PowerToolbox`

Update PowerToolbox to the latest published release.

```powershell
Update-PowerToolbox -CheckOnly

Update-PowerToolbox

Update-PowerToolbox -Force -WhatIf
```

Run `Get-Help <command> -Full` for the complete parameter list on any of these.

## Troubleshooting

**"The term 'Add-EntraGroupMember' is not recognized" right after installing.**
You installed from one PowerShell edition and are running another. Windows PowerShell 5.1 and
PowerShell 7 read different module folders, so run `install.ps1` from the shell you actually
use. Check where it landed with `Get-Module PowerToolbox -ListAvailable`.

**Commands work in the window where you installed, but not a new one.** That is the same
edition mismatch — or the install failed partway. Rerun the installer and read its final line.

**"Required module 'Microsoft.Graph.Groups' is not installed."** Run the `Install-Module`
command from Prerequisites. This is deliberate: PowerToolbox never installs SDKs for you.

**"No group found with display name ..."** Matching is exact, though not case-sensitive. Find
the real name with:

```powershell
Get-MgGroup -Filter "startswith(displayName,'Sales')"
```

**"Ambiguous group name - rerun with -GroupId."** Two groups share that display name. The
command lists both with their IDs; pick one and pass `-GroupId`.

**Removing a member fails on a group that looks fine.** Dynamic-membership groups compute
their members from a rule, so members cannot be removed directly. Change the rule instead.

**Install fails on Windows PowerShell 5.1 with a TLS or "could not create SSL/TLS secure
channel" error.** 5.1 defaults to TLS 1.0, which GitHub rejects. The installer sets TLS 1.2
itself, so if you hit this before it runs, set it first:

```powershell
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
```

**An older `CalendarPermissions` or `EntraGroupMembers` module is still installed.** The
installer removes both, because they export the same command names and would otherwise shadow
PowerToolbox unpredictably. Pass `-KeepLegacy` if you need them kept.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for adding a tool and cutting a release.
