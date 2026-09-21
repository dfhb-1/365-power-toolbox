BeforeAll {
    $script:RepoRoot = Split-Path -Path $PSScriptRoot -Parent
    $script:Scaffold = Join-Path $RepoRoot 'tools/New-Tool.ps1'
}

Describe 'New-Tool.ps1' {
    BeforeEach {
        # Scaffold into a throwaway copy so a test run never mutates the real manifest.
        $script:Sandbox = Join-Path ([System.IO.Path]::GetTempPath()) ("newtool-" + [Guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $Sandbox -Force | Out-Null
        Copy-Item -Path (Join-Path $RepoRoot 'PowerToolbox') -Destination (Join-Path $Sandbox 'PowerToolbox') -Recurse
        $script:ModulePath = Join-Path $Sandbox 'PowerToolbox'
    }

    AfterEach {
        if ($Sandbox -and (Test-Path $Sandbox)) {
            Remove-Item -Path $Sandbox -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    It 'creates the Public file' {
        & $Scaffold -Name 'Get-Widget' -ModulePath $ModulePath | Out-Null
        Join-Path $ModulePath 'Public/Get-Widget.ps1' | Should -Exist
    }

    It 'adds the name to FunctionsToExport' {
        & $Scaffold -Name 'Get-Widget' -ModulePath $ModulePath | Out-Null
        $manifest = Import-PowerShellDataFile (Join-Path $ModulePath 'PowerToolbox.psd1')
        $manifest.FunctionsToExport | Should -Contain 'Get-Widget'
    }

    It 'keeps the pre-existing exports' {
        $before = (Import-PowerShellDataFile (Join-Path $ModulePath 'PowerToolbox.psd1')).FunctionsToExport
        & $Scaffold -Name 'Get-Widget' -ModulePath $ModulePath | Out-Null
        $after = (Import-PowerShellDataFile (Join-Path $ModulePath 'PowerToolbox.psd1')).FunctionsToExport
        foreach ($name in $before) { $after | Should -Contain $name }
        $after.Count | Should -Be ($before.Count + 1)
    }

    It 'leaves the manifest valid' {
        & $Scaffold -Name 'Get-Widget' -ModulePath $ModulePath | Out-Null
        { Test-ModuleManifest -Path (Join-Path $ModulePath 'PowerToolbox.psd1') } | Should -Not -Throw
    }

    It 'produces a file that parses and defines the named function' {
        & $Scaffold -Name 'Get-Widget' -ModulePath $ModulePath | Out-Null
        $path = Join-Path $ModulePath 'Public/Get-Widget.ps1'
        $errors = $null
        $ast = [System.Management.Automation.Language.Parser]::ParseFile($path, [ref]$null, [ref]$errors)
        $errors.Count | Should -Be 0
        $functions = @($ast.FindAll({ $args[0] -is [System.Management.Automation.Language.FunctionDefinitionAst] }, $false))
        $functions.Count | Should -Be 1
        $functions[0].Name | Should -Be 'Get-Widget'
    }

    It 'writes ASCII only, so 5.1 cannot mis-decode it' {
        & $Scaffold -Name 'Get-Widget' -ModulePath $ModulePath | Out-Null
        $bytes = [System.IO.File]::ReadAllBytes((Join-Path $ModulePath 'Public/Get-Widget.ps1'))
        @($bytes | Where-Object { $_ -gt 127 }).Count | Should -Be 0
    }

    It 'refuses to overwrite an existing command' {
        & $Scaffold -Name 'Get-Widget' -ModulePath $ModulePath | Out-Null
        { & $Scaffold -Name 'Get-Widget' -ModulePath $ModulePath } | Should -Throw '*already exists*'
    }

    It 'rejects an unapproved verb' {
        { & $Scaffold -Name 'Frobnicate-Widget' -ModulePath $ModulePath } | Should -Throw '*not an approved PowerShell verb*'
    }

    It 'rejects a name that is not Verb-Noun' {
        { & $Scaffold -Name 'notavalidname' -ModulePath $ModulePath } | Should -Throw
    }
}
