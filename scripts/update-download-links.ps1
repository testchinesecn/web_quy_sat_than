# Compatible with Windows PowerShell 5.1. Run through CAP_NHAT_LINK.cmd.
$ErrorActionPreference = 'Stop'

function Invoke-Git {
    param([string[]]$GitArgs)
    & git @GitArgs
    if ($LASTEXITCODE -ne 0) {
        throw ('Git that bai: git ' + ($GitArgs -join ' '))
    }
}

function Read-DownloadUrl {
    param([string]$Label, [string]$CurrentUrl)
    Write-Host ''
    Write-Host ($Label + ' hien tai: ' + $CurrentUrl)
    while ($true) {
        $answer = Read-Host ('Dan link ' + $Label + ' moi (Enter = giu nguyen)')
        if ($null -eq $answer) { return $CurrentUrl }
        $answer = $answer.Trim()
        if ($answer.Length -eq 0) { return $CurrentUrl }
        $parsed = $null
        if ($answer -match '[\s<>"\\]' -or
            -not [Uri]::TryCreate($answer, [UriKind]::Absolute, [ref]$parsed) -or
            $parsed.Scheme -notin @('https', 'http') -or
            [string]::IsNullOrWhiteSpace($parsed.Host) -or
            $parsed.UserInfo.Length -gt 0) {
            Write-Host 'Link khong hop le. Hay dan URL bat dau bang https:// hoac http://' -ForegroundColor Yellow
            continue
        }
        return $answer
    }
}

Push-Location (Split-Path -Parent $PSScriptRoot)
try {
    Write-Host '=== CAP NHAT LINK TAI GAME LEN GITHUB ===' -ForegroundColor Cyan
    Write-Host 'Nhap lan luot iOS, PC, APK. Enter de giu link hien tai.'
    if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
        throw 'Chua co Git. Hay cai Git for Windows va dang nhap GitHub truoc.'
    }
    $branch = Invoke-Git -GitArgs @('branch', '--show-current')
    if ($branch -ne 'main') { throw 'Hay chuyen ve nhanh main truoc khi cap nhat.' }
    $status = Invoke-Git -GitArgs @('status', '--porcelain')
    if ($status) {
        Write-Host ($status -join "`n")
        throw 'Thu muc dang co thay doi chua commit. Hay luu/commit cac thay doi do truoc khi chay lai.'
    }
    Invoke-Git -GitArgs @('fetch', 'origin', 'main')
    $ahead = Invoke-Git -GitArgs @('rev-list', '--count', 'origin/main..HEAD')
    if ([int]$ahead -gt 0) {
        throw 'Con commit chua day len GitHub. Chay: git push origin main, sau do mo lai chuong trinh.'
    }
    Invoke-Git -GitArgs @('merge', '--ff-only', 'origin/main')

    $configPath = Join-Path (Get-Location) 'assets/js/config.js'
    $htmlPath = Join-Path (Get-Location) 'index.html'
    $config = [IO.File]::ReadAllText($configPath)
    $html = [IO.File]::ReadAllText($htmlPath)
    $platforms = @(
        @{ Key = 'ios'; Label = 'iOS'; Class = 'link-download-ios' },
        @{ Key = 'pc'; Label = 'PC'; Class = 'link-download-pc' },
        @{ Key = 'android'; Label = 'APK'; Class = 'link-download-android' }
    )
    $changes = @()
    foreach ($platform in $platforms) {
        $pattern = '(?m)^(?<prefix>\s*' + $platform.Key + '\s*:\s*)(?<value>"(?:\\.|[^"\\])*")'
        $matchesForKey = [regex]::Matches($config, $pattern)
        if ($matchesForKey.Count -ne 1) { throw ('Khong doc duoc link ' + $platform.Label + ' trong config.js.') }
        $current = ConvertFrom-Json -InputObject $matchesForKey[0].Groups['value'].Value
        $newUrl = Read-DownloadUrl -Label $platform.Label -CurrentUrl $current
        if ($newUrl -eq $current) { continue }

        $jsonUrl = ConvertTo-Json -InputObject $newUrl -Compress
        $config = [regex]::Replace($config, $pattern, [Text.RegularExpressions.MatchEvaluator]{
            param($match)
            return $match.Groups['prefix'].Value + $jsonUrl
        })
        $className = $platform.Class
        $escapedUrl = [Security.SecurityElement]::Escape($newUrl)
        $anchors = @([regex]::Matches($html, '<a\b[^>]*>') | Where-Object {
            $classMatch = [regex]::Match($_.Value, '\bclass="([^"]*)"')
            ($classMatch.Groups[1].Value -split '\s+') -contains $className
        })
        if ($anchors.Count -ne 2) { throw ('Can co 2 nut tai ' + $platform.Label + ' trong index.html. Chua ghi thay doi.') }
        foreach ($anchor in $anchors) {
            if ([regex]::Matches($anchor.Value, '\bhref="[^"]*"').Count -ne 1) {
                throw ('Khong doc duoc href cua nut ' + $platform.Label + '. Chua ghi thay doi.')
            }
            $updatedAnchor = [regex]::Replace($anchor.Value, '\bhref="[^"]*"', [Text.RegularExpressions.MatchEvaluator]{
                param($match)
                return 'href="' + $escapedUrl + '"'
            })
            $html = $html.Replace($anchor.Value, $updatedAnchor)
        }
        $changes += $platform.Label
    }
    if ($changes.Count -eq 0) {
        Write-Host "`nKhong co link nao thay doi. Da giu nguyen tat ca." -ForegroundColor Green
        exit 0
    }

    # Refresh the config URL so returning visitors receive the new download links.
    $utf8 = New-Object Text.UTF8Encoding($false)
    $sha = [Security.Cryptography.SHA256]::Create()
    try {
        $version = ([BitConverter]::ToString($sha.ComputeHash($utf8.GetBytes($config)))).Replace('-', '').Substring(0, 12).ToLowerInvariant()
    } finally { $sha.Dispose() }
    $scriptPattern = '(?<prefix><script\s+src=")assets/js/config\.js(?:\?[^"\s]*)?(?<suffix>")'
    if ([regex]::Matches($html, $scriptPattern).Count -ne 1) {
        throw 'Khong tim thay script config.js trong index.html. Chua ghi thay doi.'
    }
    $html = [regex]::Replace($html, $scriptPattern, [Text.RegularExpressions.MatchEvaluator]{
        param($match)
        return $match.Groups['prefix'].Value + 'assets/js/config.js?v=' + $version + $match.Groups['suffix'].Value
    })

    $originalConfig = [IO.File]::ReadAllText($configPath)
    $originalHtml = [IO.File]::ReadAllText($htmlPath)
    try {
        [IO.File]::WriteAllText($configPath, $config, $utf8)
        [IO.File]::WriteAllText($htmlPath, $html, $utf8)
    } catch {
        [IO.File]::WriteAllText($configPath, $originalConfig, $utf8)
        [IO.File]::WriteAllText($htmlPath, $originalHtml, $utf8)
        throw
    }
    Invoke-Git -GitArgs @('diff', '--check')
    Invoke-Git -GitArgs @('add', '--', 'assets/js/config.js', 'index.html')
    $message = 'Update download links: ' + ($changes -join ', ')
    Invoke-Git -GitArgs @('commit', '-m', $message)
    Invoke-Git -GitArgs @('push', 'origin', 'main')
    Write-Host ("`nDA DAY LEN GITHUB: " + ($changes -join ', ')) -ForegroundColor Green
    Write-Host 'Web se cap nhat khi GitHub Pages trien khai xong (thuong khoang 1-2 phut).'
    Write-Host 'Neu trinh duyet con hien link cu, nhan Ctrl + F5.'
} catch {
    Write-Host ("`nLOI: " + $_.Exception.Message) -ForegroundColor Red
    Write-Host 'Chua xac nhan day len GitHub thanh cong. Khong tu xoa thay doi khi gap loi.'
    Write-Host 'Neu loi dang nhap, hay dang nhap GitHub trong cua so Git/mo trinh duyet duoc hien ra.'
    Write-Host 'Neu da commit nhung push loi, chay: git push origin main'
    exit 1
} finally {
    Pop-Location
}
