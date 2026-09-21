# Changelog

All notable changes to PowerToolbox are documented here.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.0.0] - 2026-09-21

First release.

### Added

- `PowerToolbox`, a single module for Microsoft 365 administration, replacing the separate
  `CalendarPermissions` and `EntraGroupMembers` modules. One import, one install, one
  version to track.
- `Add-CalendarPermission`, which grants a user or group access to an Exchange Online
  mailbox calendar. It takes `-Mailbox`, `-User` and `-AccessRights` parameters and supports
  `-WhatIf`, so it can be scripted and previewed; called with no arguments it prompts.
- `Add-EntraGroupMember` and `Remove-EntraGroupMember`, which take users inline or from a
  CSV, skip anyone already in the desired state, and print a Success / Skipped / Failed
  summary.
- `Update-PowerToolbox`, which compares the installed version against the latest GitHub
  release and installs it by running that release's own installer. `-CheckOnly` reports
  without changing anything.
- `install.ps1`, a single installer that works piped through `irm | iex`, from a clone, or
  from any folder via `-Source`. It resolves the current user's module path for the running
  PowerShell edition (following a OneDrive-redirected Documents folder on Windows), records
  version and provenance in `install.json`, and reports missing Exchange or Graph
  dependencies without installing them for you.
- Pester tests and GitHub Actions CI covering Windows PowerShell 5.1, PowerShell 7 on
  Windows, and PowerShell 7 on Linux.

### Notes

- Exchange Online and Microsoft Graph are declared as external dependencies rather than
  required modules, so importing PowerToolbox succeeds on a machine with neither SDK
  installed. They are checked when a command that needs them actually runs.
- `install.ps1` removes the superseded `CalendarPermissions` and `EntraGroupMembers` modules
  from your module path, since they export the same command names and would otherwise shadow
  PowerToolbox unpredictably. Pass `-KeepLegacy` to leave them in place.

[Unreleased]: https://github.com/dfhb-1/365-power-toolbox/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/dfhb-1/365-power-toolbox/releases/tag/v1.0.0
