BeforeDiscovery {
    $repoRoot = Split-Path -Path $PSScriptRoot -Parent
    $settings = Join-Path $repoRoot 'PSScriptAnalyzerSettings.psd1'

    $targets = @(
        (Join-Path $repoRoot 'PowerToolbox'),
        (Join-Path $repoRoot 'install.ps1'),
        (Join-Path $repoRoot 'tools')
    ) | Where-Object { Test-Path $_ }

    $script:Findings = @(
        foreach ($target in $targets) {
            Invoke-ScriptAnalyzer -Path $target -Settings $settings -Recurse
        }
    )

    $script:FindingCases = @(
        $Findings | ForEach-Object {
            @{
                RuleName = $_.RuleName
                File     = Split-Path $_.ScriptPath -Leaf
                Line     = $_.Line
                Message  = $_.Message
                Severity = $_.Severity
            }
        }
    )
}

Describe 'PSScriptAnalyzer' {
    It 'reports no findings' {
        $Findings.Count | Should -Be 0
    }

    # Only defined when something was found: Pester throws on an empty -TestCases array,
    # so an unguarded block would fail exactly when the codebase is clean.
    if ($FindingCases.Count -gt 0) {
        It '<RuleName> in <File>:<Line> - <Message>' -TestCases $FindingCases {
            param($RuleName, $File, $Line, $Message, $Severity)
            # The detail is already in the test name; failing here surfaces it per finding.
            "$Severity $RuleName" | Should -BeNullOrEmpty
        }
    }
}
