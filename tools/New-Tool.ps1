<#
.SYNOPSIS
    Scaffold a new public command in the PowerToolbox module.

.DESCRIPTION
    Writes PowerToolbox/Public/<Name>.ps1 from a template and adds <Name> to FunctionsToExport
    in the manifest, keeping that list sorted. Refuses to overwrite an existing file.

.PARAMETER Name
    The command name, in Verb-Noun form. The verb must be an approved PowerShell verb.

.PARAMETER Synopsis
    One-line description for the generated comment-based help.

.PARAMETER ModulePath
    The module folder to scaffold into. Defaults to the PowerToolbox folder beside this script's
    parent, which is what you want unless you are testing the scaffolder itself.

.EXAMPLE
    ./tools/New-Tool.ps1 -Name Get-MailboxReport -Synopsis 'Summarise mailbox sizes.'
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidatePattern('^[A-Z][a-z]+-[A-Z]\w+$')]
    [string]$Name,

    [string]$Synopsis = 'TODO: one line describing what this command does.',

    [string]$ModulePath
)

$ErrorActionPreference = 'Stop'

if (-not $ModulePath) {
    $ModulePath = Join-Path (Split-Path -Path $PSScriptRoot -Parent) 'PowerToolbox'
}

$verb = $Name.Split('-')[0]
if ((Get-Verb).Verb -notcontains $verb) {
    throw "'$verb' is not an approved PowerShell verb. Run Get-Verb to see the list."
}

$publicDir = Join-Path $ModulePath 'Public'
if (-not (Test-Path $publicDir)) {
    throw "No Public folder at $publicDir."
}

$target = Join-Path $publicDir "$Name.ps1"
if (Test-Path $target) {
    throw "$Name already exists at $target."
}

$template = @"
function $Name {
    <#
    .SYNOPSIS
        $Synopsis

    .DESCRIPTION
        TODO: describe the behaviour, including anything surprising about it.

    .PARAMETER Target
        TODO: what this identifies.

    .EXAMPLE
        $Name -Target user@contoso.com

        TODO: what this example does.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [string]`$Target
    )

    # Connect first if this command needs a service:
    #   Connect-PtGraph      for Microsoft Graph
    #   Connect-PtExchange   for Exchange Online

    if (`$PSCmdlet.ShouldProcess(`$Target, '$verb')) {
        # TODO: the state-changing call goes here.
        throw 'TODO: $Name is not implemented yet.'
    }
}
"@

Set-Content -Path $target -Value $template -Encoding ascii

# Insert into FunctionsToExport in place: rewriting the whole manifest would drop comments
# and formatting that are there on purpose.
$manifestPath = Join-Path $ModulePath 'PowerToolbox.psd1'
$manifestText = Get-Content -Path $manifestPath -Raw

$pattern = "(?s)(FunctionsToExport\s*=\s*@\()(.*?)(\))"
$match = [regex]::Match($manifestText, $pattern)
if (-not $match.Success) {
    throw "Could not find a FunctionsToExport = @( ... ) block in $manifestPath."
}

$existing = @(
    [regex]::Matches($match.Groups[2].Value, "'([^']+)'") |
        ForEach-Object { $_.Groups[1].Value }
)
$all = @($existing + $Name | Sort-Object -Unique)

$indent = '        '
$body = "`n" + (($all | ForEach-Object { "$indent'$_'" }) -join ",`n") + "`n    "
$updated = $manifestText.Remove($match.Groups[2].Index, $match.Groups[2].Length).Insert($match.Groups[2].Index, $body)

Set-Content -Path $manifestPath -Value $updated -Encoding ascii

Write-Host "Created $target" -ForegroundColor Green
Write-Host "Added $Name to FunctionsToExport ($($all.Count) exported)." -ForegroundColor Green
Write-Host ''
Write-Host 'Next:' -ForegroundColor Cyan
Write-Host "  1. Implement $Name and finish its comment-based help."
Write-Host '  2. Invoke-Pester ./tests'
Write-Host '  3. Bump ModuleVersion and add a CHANGELOG entry if this is user-facing.'
