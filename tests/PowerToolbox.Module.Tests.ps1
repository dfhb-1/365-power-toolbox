BeforeAll {
    $script:RepoRoot   = Split-Path -Path $PSScriptRoot -Parent
    $script:ModuleRoot = Join-Path $RepoRoot 'PowerToolbox'
    $script:ManifestPath = Join-Path $ModuleRoot 'PowerToolbox.psd1'
    $script:InstallScript = Join-Path $RepoRoot 'install.ps1'
    $script:Repo = 'dfhb-1/365-power-toolbox'

    $script:Manifest = Test-ModuleManifest -Path $ManifestPath
    Import-Module $ModuleRoot -Force

    $script:PublicNames = @(
        Get-ChildItem (Join-Path $ModuleRoot 'Public') -Filter '*.ps1' -File |
            Select-Object -ExpandProperty BaseName
    )
    $script:PrivateNames = @(
        Get-ChildItem (Join-Path $ModuleRoot 'Private') -Filter '*.ps1' -File |
            Select-Object -ExpandProperty BaseName
    )
    $script:Exported = @(Get-Command -Module PowerToolbox | Select-Object -ExpandProperty Name)

    # Everything that runs as PowerShell: the module, the installer, and the maintainer
    # scripts in tools/, which contributors may well run on Windows PowerShell 5.1.
    $script:ShippedFiles = @(
        Get-ChildItem $ModuleRoot -Recurse -Include '*.ps1', '*.psm1' -File
        Get-Item $InstallScript
        $toolsDir = Join-Path $RepoRoot 'tools'
        if (Test-Path $toolsDir) { Get-ChildItem $toolsDir -Recurse -Include '*.ps1' -File }
    )
}

Describe 'Manifest' {
    It 'passes Test-ModuleManifest' {
        $Manifest | Should -Not -BeNullOrEmpty
    }

    It 'has a three-part version' {
        $Manifest.Version.Major | Should -BeGreaterOrEqual 0
        $Manifest.Version.Minor | Should -BeGreaterOrEqual 0
        $Manifest.Version.Build | Should -BeGreaterOrEqual 0
    }

    It 'declares no wildcard exports' {
        $Manifest.ExportedFunctions.Keys | Should -Not -Contain '*'
    }
}

Describe 'Import' {
    It 'imports with no errors or warnings' {
        $warnings = $null
        $errors = $null
        Import-Module $ModuleRoot -Force -WarningVariable warnings -ErrorVariable errors
        $warnings | Should -BeNullOrEmpty
        $errors | Should -BeNullOrEmpty
    }
}

Describe 'Public surface' {
    It 'exports every function that has a Public file' {
        foreach ($name in $PublicNames) {
            $Manifest.ExportedFunctions.Keys | Should -Contain $name -Because "Public/$name.ps1 exists but is not in FunctionsToExport"
        }
    }

    It 'has a Public file for every exported function' {
        foreach ($name in $Manifest.ExportedFunctions.Keys) {
            $PublicNames | Should -Contain $name -Because "FunctionsToExport lists $name but Public/$name.ps1 does not exist"
        }
    }

    It 'defines exactly one function per Public file, named after the file' {
        foreach ($name in $PublicNames) {
            $path = Join-Path $ModuleRoot "Public/$name.ps1"
            $errors = $null
            $ast = [System.Management.Automation.Language.Parser]::ParseFile($path, [ref]$null, [ref]$errors)
            $functions = @($ast.FindAll({ $args[0] -is [System.Management.Automation.Language.FunctionDefinitionAst] }, $false))
            $functions.Count | Should -Be 1 -Because "Public/$name.ps1 should define exactly one function"
            $functions[0].Name | Should -Be $name
        }
    }

    It 'does not export any Private helper' {
        foreach ($name in $PrivateNames) {
            $Exported | Should -Not -Contain $name -Because "$name is a Private helper and must stay internal"
        }
    }
}

Describe 'Comment-based help' {
    It 'gives every public command a synopsis and at least one example' {
        foreach ($name in $Exported) {
            $help = Get-Help $name
            $help.Synopsis | Should -Not -BeNullOrEmpty -Because "$name needs a .SYNOPSIS"
            @($help.Examples.Example).Count | Should -BeGreaterThan 0 -Because "$name needs at least one .EXAMPLE"
        }
    }
}

Describe 'install.ps1' {
    It 'parses without errors' {
        $errors = $null
        [System.Management.Automation.Language.Parser]::ParseFile($InstallScript, [ref]$null, [ref]$errors) | Out-Null
        $errors.Count | Should -Be 0
    }
}

Describe 'Windows PowerShell 5.1 compatibility' {
    # $IsWindows does not exist on 5.1, so dereferencing it bare throws there. The correct
    # idiom spans several lines, which is why this is a per-FILE rule and not a per-line grep.
    It 'guards every reference to $IsWindows' {
        foreach ($file in $ShippedFiles) {
            $text = Get-Content -Path $file.FullName -Raw
            if ($text -match '\$IsWindows') {
                $guarded = ($text -match 'PSEdition') -or ($text -match "Get-Variable -Name 'IsWindows'")
                $guarded | Should -BeTrue -Because "$($file.Name) uses `$IsWindows without an edition guard"
            }
        }
    }

    It 'contains only ASCII, so 5.1 cannot mis-decode a BOM-less UTF-8 file' {
        # Windows PowerShell 5.1 reads a UTF-8 file without a BOM as the system ANSI code
        # page. Staying ASCII sidesteps that entirely and keeps install.ps1 safe to pipe
        # through `irm | iex`.
        foreach ($file in $ShippedFiles) {
            $bytes = [System.IO.File]::ReadAllBytes($file.FullName)
            $nonAscii = @($bytes | Where-Object { $_ -gt 127 })
            $nonAscii.Count | Should -Be 0 -Because "$($file.Name) contains non-ASCII bytes"
        }
    }

    It 'uses no PowerShell 7-only syntax' {
        # '??' also matches '??=' ; '&&' and '||' are pipeline chain operators.
        $banned = @('\?\?', '\$\w+\?\.', '&&', '\|\|', '-Parallel')
        foreach ($file in $ShippedFiles) {
            $lines = @(Get-Content -Path $file.FullName | Where-Object { $_ -notmatch '^\s*#' })
            foreach ($pattern in $banned) {
                $hits = @($lines | Where-Object { $_ -match $pattern })
                $hits.Count | Should -Be 0 -Because "$($file.Name) contains PS7-only syntax matching $pattern"
            }
        }
    }
}

Describe 'Repository references' {
    # A half-applied rename would leave the installer pointing at one repo and the updater
    # at another, and the failure would only show up at release time.
    It 'points install.ps1 and Get-PtGitHubRelease.ps1 at the same owner/repo' {
        $targets = @(
            $InstallScript,
            (Join-Path $ModuleRoot 'Private/Get-PtGitHubRelease.ps1')
        )
        foreach ($path in $targets) {
            $text = Get-Content -Path $path -Raw
            $found = @([regex]::Matches($text, 'github\.com/([A-Za-z0-9._-]+/[A-Za-z0-9._-]+)') |
                ForEach-Object { $_.Groups[1].Value } |
                Where-Object { $_ -notmatch '^(repos|raw)$' } |
                Select-Object -Unique)
            foreach ($slug in $found) {
                $slug | Should -Be $Repo -Because "$(Split-Path $path -Leaf) references $slug"
            }
        }
    }

    It 'declares the same repo in the manifest ProjectUri' {
        $Manifest.PrivateData.PSData.ProjectUri | Should -Match ([regex]::Escape($Repo))
    }
}
