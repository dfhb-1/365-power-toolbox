function Update-PowerToolbox {
    <#
    .SYNOPSIS
        Update PowerToolbox to the latest published release.

    .DESCRIPTION
        Compares the installed module version against the latest GitHub release. If a newer
        release exists, downloads the installer that shipped with that release and runs it.

        The new files replace the ones this command is running from, so the updated code does
        not become active until you open a new PowerShell session.

    .PARAMETER CheckOnly
        Report installed and latest versions without changing anything. Returns an object, so
        it can be used in a script.

    .PARAMETER Force
        Reinstall the latest release even when it matches the installed version.

    .EXAMPLE
        Update-PowerToolbox -CheckOnly

        Reports whether an update is available.

    .EXAMPLE
        Update-PowerToolbox

        Installs the latest release if it is newer than what you have.

    .EXAMPLE
        Update-PowerToolbox -Force -WhatIf

        Shows what a forced reinstall would do, without doing it.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [switch]$CheckOnly,
        [switch]$Force
    )

    $repo = 'dfhb-1/365-power-toolbox'
    $tempDir = $null

    try {
        # ---- What is installed -------------------------------------------------------
        $moduleRoot = Split-Path -Path $PSScriptRoot -Parent
        $installedVersion = $null

        $loaded = Get-Module -Name PowerToolbox
        if ($loaded) {
            $installedVersion = $loaded.Version
        }
        else {
            $manifestPath = Join-Path $moduleRoot 'PowerToolbox.psd1'
            $installedVersion = (Test-ModuleManifest -Path $manifestPath).Version
        }

        $installedAt = $null
        $installRecordPath = Join-Path $moduleRoot 'install.json'
        if (Test-Path $installRecordPath) {
            $record = Get-Content -Path $installRecordPath -Raw | ConvertFrom-Json
            $installedAt = $record.installedAt
        }

        # ---- What is published -------------------------------------------------------
        $release = Get-PtGitHubRelease -Repo $repo

        $isNewer = $release.Version -gt $installedVersion

        if ($CheckOnly) {
            $status = 'Up to date'
            if ($isNewer) { $status = 'Update available' }

            $result = [PSCustomObject]@{
                Installed   = $installedVersion
                Latest      = $release.Version
                Status      = $status
                PublishedAt = $release.PublishedAt
                InstalledAt = $installedAt
                ReleaseUrl  = $release.HtmlUrl
            }

            if ($isNewer) {
                Write-Host "Run Update-PowerToolbox to install $($release.Version)." -ForegroundColor Cyan
            }
            return $result
        }

        if (-not $isNewer -and -not $Force) {
            Write-Host "PowerToolbox $installedVersion is up to date." -ForegroundColor Green
            return
        }

        # ---- Update ------------------------------------------------------------------
        if (-not $PSCmdlet.ShouldProcess("PowerToolbox $installedVersion -> $($release.Version)", 'Update')) {
            return
        }

        [Net.ServicePointManager]::SecurityProtocol =
            [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12

        $tempDir = Join-Path ([System.IO.Path]::GetTempPath()) ("PowerToolboxUpdate-" + [Guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $tempDir -Force | Out-Null

        # Run the installer that shipped with the target release, not this checkout's copy:
        # it knows how to fetch its own payload, so "how to install" exists in exactly one place.
        $installerUrl  = "https://raw.githubusercontent.com/$repo/$($release.Tag)/install.ps1"
        $installerPath = Join-Path $tempDir 'install.ps1'

        try {
            Invoke-WebRequest -Uri $installerUrl -OutFile $installerPath -UseBasicParsing
        }
        catch {
            if ($_.Exception.Response -and [int]$_.Exception.Response.StatusCode -eq 404) {
                throw "Release $($release.Tag) has no install.ps1, so it cannot be installed this way."
            }
            throw
        }

        # Reset first: install.ps1 only sets an exit code on failure, so a non-zero value
        # left behind by some earlier command would otherwise look like a failed install.
        $global:LASTEXITCODE = 0
        & $installerPath -Version $release.Tag
        if ($LASTEXITCODE -ne 0) {
            throw "The installer for $($release.Tag) failed with exit code $LASTEXITCODE."
        }

        Write-Host "Updated $installedVersion -> $($release.Version). Open a new PowerShell session to load the new version." -ForegroundColor Green
    }
    finally {
        if ($tempDir -and (Test-Path $tempDir)) {
            Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}
