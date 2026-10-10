# Runs elevated (UAC). Installs VirtualBox silently and logs to .cache.
$ErrorActionPreference = 'Continue'
$project = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$cache = Join-Path $project '.cache'
if (-not (Test-Path $cache)) { New-Item -ItemType Directory -Path $cache | Out-Null }
$log = Join-Path $cache 'vbox-install.log'

"=== start $(Get-Date -Format o) ===" | Out-File -FilePath $log -Encoding utf8

# Already installed?
$vbox = 'C:\Program Files\Oracle\VirtualBox\VirtualBox.exe'
if (Test-Path $vbox) {
    "VirtualBox already present at $vbox" | Out-File -FilePath $log -Append -Encoding utf8
    "exit=0 (already installed)" | Out-File -FilePath $log -Append -Encoding utf8
    exit 0
}

winget install --id Oracle.VirtualBox --exact --source winget `
    --accept-source-agreements --accept-package-agreements `
    --disable-interactivity --silent 2>&1 |
    Out-File -FilePath $log -Append -Encoding utf8

"exit=$LASTEXITCODE === end $(Get-Date -Format o) ===" | Out-File -FilePath $log -Append -Encoding utf8
