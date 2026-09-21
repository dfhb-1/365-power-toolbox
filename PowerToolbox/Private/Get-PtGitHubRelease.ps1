function Get-PtGitHubRelease {
    param(
        [string]$Repo = 'dfhb-1/365-power-toolbox',
        [string]$Tag
    )

    if ($Tag) {
        $apiUrl = "https://api.github.com/repos/$Repo/releases/tags/$Tag"
    }
    else {
        $apiUrl = "https://api.github.com/repos/$Repo/releases/latest"
    }

    # Windows PowerShell 5.1 still defaults to TLS 1.0, which api.github.com refuses.
    [Net.ServicePointManager]::SecurityProtocol =
        [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12

    # GitHub rejects requests without a User-Agent.
    $headers = @{ 'User-Agent' = 'PowerToolbox' }

    # The repo is public, so no token is needed. Honour one only if the caller already has it
    # set: it raises the 60/hour unauthenticated rate limit. Never discover or prompt for one.
    if ($env:GITHUB_TOKEN) {
        $headers['Authorization'] = "Bearer $env:GITHUB_TOKEN"
    }

    try {
        $release = Invoke-RestMethod -Uri $apiUrl -Headers $headers -UseBasicParsing
    }
    catch {
        $status = $null
        if ($_.Exception.Response) { $status = [int]$_.Exception.Response.StatusCode }

        if ($status -eq 404) {
            if ($Tag) { throw "No release found for $Repo with tag '$Tag'." }
            throw "No releases found for $Repo."
        }

        if ($status -eq 403) {
            $remaining = $null
            $reset     = $null
            if ($_.Exception.Response.Headers) {
                $remaining = $_.Exception.Response.Headers['X-RateLimit-Remaining']
                $reset     = $_.Exception.Response.Headers['X-RateLimit-Reset']
            }
            if ($remaining -eq '0') {
                $resetText = 'shortly'
                if ($reset) {
                    $resetLocal = [DateTimeOffset]::FromUnixTimeSeconds([long]$reset).ToLocalTime()
                    $resetText  = $resetLocal.ToString('t')
                }
                throw ("GitHub API rate limit reached; it resets at $resetText. " +
                       "Set `$env:GITHUB_TOKEN to a personal access token to raise the limit.")
            }
        }

        throw
    }

    $versionText = $release.tag_name -replace '^v', ''
    $version = $null
    if (-not [version]::TryParse($versionText, [ref]$version)) {
        throw "Release tag '$($release.tag_name)' is not a parseable version."
    }

    $asset = @($release.assets | Where-Object { $_.name -eq 'PowerToolbox.zip' }) | Select-Object -First 1
    if (-not $asset) {
        throw "Release $($release.tag_name) has no PowerToolbox.zip asset."
    }

    return [PSCustomObject]@{
        Version     = $version
        Tag         = $release.tag_name
        HtmlUrl     = $release.html_url
        PublishedAt = $release.published_at
        Body        = $release.body
        ZipAssetUrl = $asset.browser_download_url
    }
}
