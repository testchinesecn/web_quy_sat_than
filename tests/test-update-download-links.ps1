# Integration tests use temporary repositories and a local bare remote only.
$ErrorActionPreference = 'Stop'
$sourceRoot = Split-Path -Parent $PSScriptRoot
$testRoot = Join-Path ([IO.Path]::GetTempPath()) ('qst-link-tests-' + [guid]::NewGuid().ToString('N'))
$remote = Join-Path $testRoot 'remote.git'
$repo = Join-Path $testRoot 'site'

function Invoke-TestGit {
    param([string[]]$Arguments)
    $output = & git @Arguments 2>&1
    if ($LASTEXITCODE -ne 0) { throw ($output -join "`n") }
    return $output
}
function Assert {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw $Message }
}
function Run-Updater {
    param([string[]]$Answers, [int]$ExpectedExit = 0)
    $info = New-Object Diagnostics.ProcessStartInfo
    $info.FileName = 'powershell.exe'
    $info.Arguments = '-NoLogo -NoProfile -ExecutionPolicy Bypass -File "' + (Join-Path $repo 'scripts/update-download-links.ps1') + '"'
    $info.UseShellExecute = $false
    $info.CreateNoWindow = $true
    $info.RedirectStandardInput = $true
    $info.RedirectStandardOutput = $true
    $info.RedirectStandardError = $true
    $process = New-Object Diagnostics.Process
    $process.StartInfo = $info
    [void]$process.Start()
    $stdout = $process.StandardOutput.ReadToEndAsync()
    $stderr = $process.StandardError.ReadToEndAsync()
    foreach ($answer in $Answers) { $process.StandardInput.WriteLine($answer) }
    $process.StandardInput.Close()
    if (-not $process.WaitForExit(30000)) { $process.Kill(); throw 'Updater timed out.' }
    $result = $stdout.Result + $stderr.Result
    Assert ($process.ExitCode -eq $ExpectedExit) ("Unexpected exit: " + $result)
    $process.Dispose()
    return $result
}
function Current-Links {
    $config = [IO.File]::ReadAllText((Join-Path $repo 'assets/js/config.js'))
    $result = @{}
    foreach ($key in @('ios', 'pc', 'android', 'zalo')) {
        $match = [regex]::Match($config, '(?m)^\s*' + $key + '\s*:\s*("(?:\\.|[^"\\])*")')
        $result[$key] = ConvertFrom-Json -InputObject $match.Groups[1].Value
    }
    return $result
}

New-Item -ItemType Directory -Path $testRoot, $repo | Out-Null
Push-Location $repo
try {
    Invoke-TestGit -Arguments @('init', '--bare', $remote) | Out-Null
    Invoke-TestGit -Arguments @('init', '-b', 'main') | Out-Null
    Invoke-TestGit -Arguments @('config', 'user.name', 'Updater Test') | Out-Null
    Invoke-TestGit -Arguments @('config', 'user.email', 'updater-test@example.invalid') | Out-Null
    New-Item -ItemType Directory -Path 'scripts', 'assets/js' | Out-Null
    Copy-Item -LiteralPath (Join-Path $sourceRoot 'scripts/update-download-links.ps1') -Destination 'scripts/'
    Copy-Item -LiteralPath (Join-Path $sourceRoot 'assets/js/config.js') -Destination 'assets/js/'
    Copy-Item -LiteralPath (Join-Path $sourceRoot 'index.html') -Destination '.'
    Invoke-TestGit -Arguments @('add', '.') | Out-Null
    Invoke-TestGit -Arguments @('commit', '-m', 'Seed') | Out-Null
    Invoke-TestGit -Arguments @('remote', 'add', 'origin', $remote) | Out-Null
    Invoke-TestGit -Arguments @('push', '-u', 'origin', 'main') | Out-Null
    $before = Invoke-TestGit -Arguments @('rev-parse', 'HEAD')
    $original = Current-Links

    Run-Updater -Answers @('', '', '') | Out-Null
    Assert ((Invoke-TestGit -Arguments @('rev-parse', 'HEAD')) -eq $before) 'Enter-only created a commit.'
    Assert (-not (Invoke-TestGit -Arguments @('status', '--porcelain'))) 'Enter-only changed files.'
    Write-Host 'PASS: Enter skips all links with no commit.'

    $pcUrl = 'https://drive.google.com/file/d/new-pc/view?usp=sharing&test=1'
    Run-Updater -Answers @('', $pcUrl, '') | Out-Null
    $links = Current-Links
    Assert ($links.pc -eq $pcUrl) 'PC was not updated.'
    Assert ($links.ios -eq $original.ios -and $links.android -eq $original.android -and $links.zalo -eq $original.zalo) 'Skipped links changed.'
    $html = [IO.File]::ReadAllText((Join-Path $repo 'index.html'))
    Assert ([regex]::Matches($html, [regex]::Escape('href="https://drive.google.com/file/d/new-pc/view?usp=sharing&amp;test=1"')).Count -eq 2) 'Both PC anchors must be HTML escaped.'
    Assert ($html -match 'assets/js/config.js\?v=[a-f0-9]{12}') 'Missing config cache version.'
    Assert ((Invoke-TestGit -Arguments @('rev-parse', 'HEAD')) -eq (Invoke-TestGit -Arguments @('--git-dir', $remote, 'rev-parse', 'main'))) 'Commit did not reach remote.'
    Write-Host 'PASS: Partial update preserves skipped links and pushes both PC buttons.'

    $iosUrl = 'https://testflight.apple.com/join/new-ios?one=1&two=2'
    $apkUrl = 'https://drive.google.com/file/d/new-apk/view?usp=sharing&literal=$value'
    $output = Run-Updater -Answers @('javascript:alert(1)', $iosUrl, '', $apkUrl)
    Assert ($output -match 'Link khong hop le') 'Invalid URL did not trigger retry.'
    $links = Current-Links
    Assert ($links.ios -eq $iosUrl -and $links.pc -eq $pcUrl -and $links.android -eq $apkUrl) 'iOS/APK update or PC skip failed.'
    $html = [IO.File]::ReadAllText((Join-Path $repo 'index.html'))
    Assert ([regex]::Matches($html, [regex]::Escape([Security.SecurityElement]::Escape($iosUrl))).Count -eq 2) 'Both iOS buttons must update.'
    Assert ([regex]::Matches($html, [regex]::Escape([Security.SecurityElement]::Escape($apkUrl))).Count -eq 2) 'Both APK buttons must update.'
    Assert (-not (Invoke-TestGit -Arguments @('status', '--porcelain'))) 'Successful update left dirty files.'
    Write-Host 'PASS: Invalid input retries; iOS/APK update; URL query characters survive.'

    $before = Invoke-TestGit -Arguments @('rev-parse', 'HEAD')
    Run-Updater -Answers @($iosUrl, $pcUrl, $apkUrl) | Out-Null
    Assert ((Invoke-TestGit -Arguments @('rev-parse', 'HEAD')) -eq $before) 'Identical links created a commit.'
    Write-Host 'PASS: Pasting existing links creates no commit.'

    [IO.File]::AppendAllText((Join-Path $repo 'index.html'), "`n<!-- local edit -->")
    Run-Updater -Answers @() -ExpectedExit 1 | Out-Null
    Assert ((Invoke-TestGit -Arguments @('rev-parse', 'HEAD')) -eq $before) 'Dirty repository was committed.'
    Assert (([IO.File]::ReadAllText((Join-Path $repo 'index.html'))).Contains('<!-- local edit -->')) 'Local edit was lost.'
    Invoke-TestGit -Arguments @('restore', '--', 'index.html') | Out-Null
    Write-Host 'PASS: Existing local changes are preserved and block publishing.'

    Invoke-TestGit -Arguments @('remote', 'set-url', '--push', 'origin', (Join-Path $testRoot 'missing.git')) | Out-Null
    Run-Updater -Answers @('', 'https://example.com/pc.zip', '') -ExpectedExit 1 | Out-Null
    Assert ((Current-Links).pc -eq 'https://example.com/pc.zip') 'Failed push lost the entered link.'
    Assert ((Invoke-TestGit -Arguments @('rev-parse', 'HEAD')) -ne (Invoke-TestGit -Arguments @('--git-dir', $remote, 'rev-parse', 'main'))) 'Failure case unexpectedly pushed.'
    $output = Run-Updater -Answers @() -ExpectedExit 1
    Assert ($output -match 'git push origin main') 'Missing retry instructions for pending commit.'
    Write-Host 'PASS: Push failure keeps the commit and gives retry instructions.'
    Write-Host 'All integration tests passed.' -ForegroundColor Green
} finally {
    Pop-Location
    $fullTestRoot = [IO.Path]::GetFullPath($testRoot)
    $expectedParent = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\') + '\'
    if ($fullTestRoot.StartsWith($expectedParent, [StringComparison]::OrdinalIgnoreCase) -and
        [IO.Path]::GetFileName($fullTestRoot) -match '^qst-link-tests-[a-f0-9]{32}$') {
        Remove-Item -LiteralPath $fullTestRoot -Recurse -Force
    }
}
