BeforeAll {
    $script:RepoRoot = Split-Path -Path $PSScriptRoot -Parent
    $script:WorkflowDir = Join-Path $RepoRoot '.github/workflows'
    $script:Workflows = @(Get-ChildItem $WorkflowDir -Filter '*.yml' -File)
}

Describe 'GitHub Actions workflows' {
    It 'has at least one workflow' {
        $Workflows.Count | Should -BeGreaterThan 0
    }

    # GitHub rejects the whole file with "Unrecognized named-value: 'matrix'" if a step's
    # shell: uses an expression. That makes the workflow silently never run - it reports a
    # failure with zero jobs - and nothing local catches it, so assert it here.
    It 'uses no expression in any step shell: key' {
        foreach ($workflow in $Workflows) {
            $lineNumber = 0
            foreach ($line in (Get-Content -Path $workflow.FullName)) {
                $lineNumber++
                if ($line -match '^\s*#') { continue }
                # The "- " form matters: shell: can be the first key of a step list item.
                if ($line -match '^\s*(?:-\s+)?shell:\s*(.+?)\s*$') {
                    $value = $Matches[1]
                    $value | Should -Not -Match '\$\{\{' -Because "$($workflow.Name):$lineNumber uses an expression in shell:, which GitHub cannot parse"
                    $value | Should -BeIn @('pwsh', 'powershell', 'bash', 'sh', 'cmd', 'python') -Because "$($workflow.Name):$lineNumber has an unexpected shell"
                }
            }
        }
    }

    It 'declares a name for every workflow' {
        foreach ($workflow in $Workflows) {
            $first = (Get-Content -Path $workflow.FullName | Where-Object { $_ -notmatch '^\s*#' -and $_.Trim() })[0]
            $first | Should -Match '^name:\s*\S' -Because "$($workflow.Name) should start with a name: so GitHub lists it by name, not path"
        }
    }
}
