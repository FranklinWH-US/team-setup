# ============================================================
#  FranklinWH Auto-Save Setup — Windows
#  Called by FranklinWH Auto-Save Setup.bat
# ============================================================

$projectsDir   = "$env:USERPROFILE\Desktop\Claude"
$autoSaveScript = "$env:USERPROFILE\.claude-autosave.ps1"
$logFile       = "$env:USERPROFILE\claude-autosave.log"
$org           = "FranklinWH-US"

Write-Host ""
Write-Host "  ==========================================" -ForegroundColor Cyan
Write-Host "     FranklinWH Auto-Save Setup"            -ForegroundColor Cyan
Write-Host "  ==========================================" -ForegroundColor Cyan
Write-Host ""

# ── Step 1: Check git ────────────────────────────────────
if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    Write-Host "  ERROR: Git is not installed." -ForegroundColor Red
    Write-Host "  Download from: https://git-scm.com/download/win" -ForegroundColor Yellow
    Write-Host "  Install it, then run this setup again."
    Read-Host "  Press Enter to close"
    exit 1
}

# ── Step 2: Install gh CLI if missing ───────────────────
if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
    Write-Host "  Installing GitHub CLI..." -ForegroundColor Yellow
    $ghInstalled = $false
    if (Get-Command winget -ErrorAction SilentlyContinue) {
        winget install --id GitHub.cli --silent --accept-package-agreements --accept-source-agreements
        $ghInstalled = $true
    }
    if (-not $ghInstalled) {
        Write-Host ""
        Write-Host "  Please install the GitHub CLI first:" -ForegroundColor Yellow
        Write-Host "  https://github.com/cli/gh/releases/latest"
        Write-Host "  Download the Windows .msi file, install it,"
        Write-Host "  then run this setup again."
        Read-Host "  Press Enter to close"
        exit 1
    }
    $env:PATH += ";$env:LOCALAPPDATA\Programs\GitHub CLI"
}

# ── Step 3: GitHub login ─────────────────────────────────
Write-Host ""
$authStatus = & gh auth status 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host "  Opening GitHub login in your browser..." -ForegroundColor Yellow
    Write-Host "  (Sign in with the GitHub account you just created)"
    Write-Host ""
    & gh auth login --web -h github.com
} else {
    $ghUser = & gh api user --jq '.login' 2>$null
    Write-Host "  ✓ Already logged in as: $ghUser" -ForegroundColor Green
}
Write-Host ""

# ── Step 4: Write the autosave script ───────────────────
$autoSaveContent = @"
param()
`$projectsDir  = "$projectsDir"
`$logFile      = "$logFile"
`$org          = "$org"

Add-Content -Path `$logFile -Value "=== Auto-save `$(Get-Date -Format 'yyyy-MM-dd HH:mm') ==="

Get-ChildItem -Path `$projectsDir -Depth 2 -Force -Filter ".git" -Directory -ErrorAction SilentlyContinue | ForEach-Object {
    `$repo = `$_.Parent.FullName
    `$name = Split-Path `$repo -Leaf
    Push-Location `$repo
    try {
        `$hasRemote = & git remote get-url origin 2>`$null
        if (-not `$hasRemote) {
            `$hasCommits = & git rev-parse HEAD 2>`$null
            if (`$hasCommits -and (Get-Command gh -ErrorAction SilentlyContinue)) {
                Add-Content -Path `$logFile -Value "  Creating `$org/`$name"
                & gh repo create "`$org/`$name" --private --source="`$repo" --push --remote origin 2>&1 |
                    Out-File -Append -FilePath `$logFile
            } else {
                Add-Content -Path `$logFile -Value "  (no remote - run setup again to connect to GitHub)"
            }
            return
        }
        `$status = & git status --porcelain 2>`$null
        if (`$status) {
            Add-Content -Path `$logFile -Value "  Saving: `$name"
            & git add -A 2>&1 | Out-File -Append -FilePath `$logFile
            & git commit -m "Auto-save `$(Get-Date -Format 'yyyy-MM-dd HH:mm')" 2>&1 | Out-File -Append -FilePath `$logFile
            & git push origin main 2>&1 | Out-File -Append -FilePath `$logFile
        }
    } finally {
        Pop-Location
    }
}
"@

Set-Content -Path $autoSaveScript -Value $autoSaveContent -Encoding UTF8

# ── Step 5: Register Task Scheduler ─────────────────────
$days    = "Monday","Tuesday","Wednesday","Thursday","Friday"
$action  = New-ScheduledTaskAction -Execute "powershell.exe" `
               -Argument "-WindowStyle Hidden -ExecutionPolicy Bypass -File `"$autoSaveScript`""
$triggers = @(
    (New-ScheduledTaskTrigger -Weekly -DaysOfWeek $days -At "9:00AM"),
    (New-ScheduledTaskTrigger -Weekly -DaysOfWeek $days -At "1:00PM"),
    (New-ScheduledTaskTrigger -Weekly -DaysOfWeek $days -At "5:00PM")
)
$settings = New-ScheduledTaskSettingsSet -ExecutionTimeLimit (New-TimeSpan -Minutes 10) -WakeToRun $false
Register-ScheduledTask -TaskName "FranklinWH Auto-Save" `
    -Action $action -Trigger $triggers -Settings $settings `
    -RunLevel Limited -Force | Out-Null

# ── Step 6: Run once now ─────────────────────────────────
Write-Host "  Running first save..." -ForegroundColor Yellow
& powershell -ExecutionPolicy Bypass -File $autoSaveScript

# ── Done ─────────────────────────────────────────────────
Write-Host ""
Write-Host "  ==========================================" -ForegroundColor Green
Write-Host "   ✓  You're all set!"                       -ForegroundColor Green
Write-Host "  ==========================================" -ForegroundColor Green
Write-Host ""
Write-Host "  Watching : $projectsDir"
Write-Host "  Saves to : github.com/$org"
Write-Host "  Schedule : 9am · 1pm · 5pm, Mon-Fri"
Write-Host "  Log      : $logFile"
Write-Host ""
Write-Host "  Your work backs up to the FranklinWH GitHub"
Write-Host "  automatically. Nothing else to do."
Write-Host ""
Read-Host "  Press Enter to close"
