<#
.SYNOPSIS
  Consolidated installer for agizy/dotfiles — reproduces the exact Vivobook setup on a fresh Windows.
  Idempotent. Backs up existing configs to *.bak.<timestamp>.

.PARAMETER DryRun  Show what would happen without changing anything.
.PARAMETER Force   Overwrite without prompt (still backs up).
.PARAMETER OnlyConfigs Only deploy configs, skip package installs.
.PARAMETER NoPackages Skip winget/choco installs.
.PARAMETER NoSyncthing Skip Syncthing provisioning.
.EXAMPLE
  ./setup.ps1 -DryRun
  ./setup.ps1 -OnlyConfigs
  irm https://raw.githubusercontent.com/agizy/dotfiles/main/bootstrap.ps1 | iex
#>
[CmdletBinding()]
param(
  [switch]$DryRun,
  [switch]$Force,
  [switch]$OnlyConfigs,
  [switch]$NoPackages,
  [switch]$NoSyncthing
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

# ————— helpers —————
function Write-Step($msg) { Write-Host "`n>> $msg" -ForegroundColor Cyan }
function Write-Info($msg) { Write-Host "   $msg" -ForegroundColor DarkGray }
function Write-Ok($msg)   { Write-Host "   ✓ $msg" -ForegroundColor Green }
function Write-Warn($msg) { Write-Host "   ! $msg" -ForegroundColor Yellow }
function Invoke-Maybe {
  param([string]$What, [scriptblock]$Action)
  if ($DryRun) { Write-Host "   [DryRun] would: $What" -ForegroundColor DarkYellow; return }
  Write-Info $What
  & $Action
}
function Backup-IfExists {
  param([string]$Path)
  if (-not (Test-Path -LiteralPath $Path)) { return }
  if ($DryRun) { Write-Host "   [DryRun] would backup $Path" -ForegroundColor DarkYellow; return }
  $bak = "$Path.bak.$(Get-Date -Format yyyyMMdd_HHmmss)"
  Copy-Item -LiteralPath $Path -Destination $bak -Force
  Write-Ok "backed up $Path → $bak"
}
function Ensure-Dir($Path) {
  if (-not (Test-Path $Path)) {
    if ($DryRun) { Write-Host "   [DryRun] mkdir $Path" -ForegroundColor DarkYellow; return }
    New-Item -ItemType Directory -Path $Path -Force | Out-Null
    Write-Ok "mkdir $Path"
  }
}
function Test-Command($Name) { $null -ne (Get-Command $Name -ErrorAction SilentlyContinue) }

# Resolve repo root (where this script lives)
$RepoRoot = $PSScriptRoot
if (-not $RepoRoot) { $RepoRoot = Split-Path -Parent $MyInvocation.MyCommand.Path }
Write-Step "Repo root: $RepoRoot"
if (-not (Test-Path (Join-Path $RepoRoot "winget/packages.json"))) {
  Write-Warn "winget/packages.json not found — are you running from cloned repo?"
}

# ————— 0. Preflight —————
Write-Step "Preflight"
Write-Info "User: $env:USERNAME @ $env:COMPUTERNAME | PowerShell $($PSVersionTable.PSVersion) | Admin: $(([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator))"
Write-Info "DryRun=$DryRun Force=$Force OnlyConfigs=$OnlyConfigs NoPackages=$NoPackages NoSyncthing=$NoSyncthing"

# Ensure execution policy allows script in this process
try { Set-ExecutionPolicy Bypass -Scope Process -Force -ErrorAction SilentlyContinue } catch {}

# ————— 1. Packages —————
if (-not $OnlyConfigs -and -not $NoPackages) {
  # — winget
  Write-Step "Winget packages (44 pinned)"
  $wingetJson = Join-Path $RepoRoot "winget/packages.json"
  if (Test-Command winget -and (Test-Path $wingetJson)) {
    Invoke-Maybe "winget import -i $wingetJson --accept-package-agreements --accept-source-agreements" {
      # winget import is interactive; we run with accepts
      & winget import -i $wingetJson --accept-package-agreements --accept-source-agreements --disable-interactivity
      if ($LASTEXITCODE -ne 0) { Write-Warn "winget import exited $LASTEXITCODE — some packages may need manual install (see winget/packages.json)" }
      else { Write-Ok "winget import done" }
    }
    # Ensure path links refresh: WinGet Links are added by profile, but also ensure env
    $wingetLinks = "$env:LOCALAPPDATA\Microsoft\WinGet\Links"
    if ($env:Path -notlike "*WinGet\Links*") { $env:Path += ";$wingetLinks"; Write-Info "added WinGet Links to session PATH" }
  } else {
    Write-Warn "winget not found or $wingetJson missing — skipping winget"
  }

  # — chocolatey
  Write-Step "Chocolatey packages (fzf, ripgrep, opencode, ...)"
  $chocoConfig = Join-Path $RepoRoot "choco/packages.config"
  if (-not (Test-Command choco)) {
    Write-Warn "choco not found"
    Invoke-Maybe "Install Chocolatey (https://chocolatey.org/install#individual)" {
      Set-ExecutionPolicy Bypass -Scope Process -Force
      [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
      Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
      $env:Path = "$env:Path;$env:ALLUSERSPROFILE\chocolatey\bin"
      Write-Ok "Chocolatey installed"
    }
  }
  if ((Test-Command choco) -and (Test-Path $chocoConfig)) {
    Invoke-Maybe "choco install from $chocoConfig -y" {
      & choco install (Join-Path $RepoRoot "choco/packages.config") -y --no-progress
      if ($LASTEXITCODE -ne 0) { Write-Warn "choco exited $LASTEXITCODE" } else { Write-Ok "choco packages done" }
      # Also ensure fzf/ripgrep are on PATH (choco shims)
    }
  } else {
    Write-Warn "choco or $chocoConfig missing — skipping"
  }

  # — PS modules
  Write-Step "PowerShell modules (PSReadLine, PSFzf)"
  $modules = @("PSReadLine","PSFzf")
  foreach ($m in $modules) {
    if (Get-Module -ListAvailable -Name $m) { Write-Ok "$m already installed" ; continue }
    Invoke-Maybe "Install-Module $m -Scope CurrentUser -Force" {
      try {
        # Ensure NuGet
        if (-not (Get-PackageProvider -Name NuGet -ErrorAction SilentlyContinue)) {
          Install-PackageProvider -Name NuGet -Force -Scope CurrentUser | Out-Null
        }
        Set-PSRepository -Name PSGallery -InstallationPolicy Trusted -ErrorAction SilentlyContinue
        Install-Module $m -Scope CurrentUser -Force -AllowClobber -ErrorAction Stop
        Write-Ok "$m installed"
      } catch { Write-Warn "Install-Module $m failed: $_" }
    }
  }
} else {
  Write-Step "Skipping package installs (OnlyConfigs/NoPackages)"
}

# ————— 2. PowerShell profiles —————
Write-Step "PowerShell profiles → Documents\WindowsPowerShell + Documents\PowerShell"
$profiles = @(
  @{ Src = Join-Path $RepoRoot "powershell/Microsoft.PowerShell_profile.ps1"; Dest = "$HOME\Documents\WindowsPowerShell\Microsoft.PowerShell_profile.ps1"; Name = "Windows PowerShell 5.1" },
  @{ Src = Join-Path $RepoRoot "powershell/Microsoft.PowerShell_profile.ps1.pwsh7"; Dest = "$HOME\Documents\PowerShell\Microsoft.PowerShell_profile.ps1"; Name = "PowerShell 7+ (pwsh)" }
)
# Also keep the main profile as unified for both if pwsh7 file is minimal: fall back to same Windows logo prompt
$mainProfile = Join-Path $RepoRoot "powershell/Microsoft.PowerShell_profile.ps1"
foreach ($p in $profiles) {
  $src = $p.Src
  $dest = $p.Dest
  if (-not (Test-Path $src)) { Write-Warn "source missing: $src — skipping $($p.Name)"; continue }
  Ensure-Dir (Split-Path $dest -Parent)
  Backup-IfExists $dest
  Invoke-Maybe "Copy $src → $dest [$($p.Name)]" {
    Copy-Item -LiteralPath $src -Destination $dest -Force
    Write-Ok "$($p.Name) deployed → $dest"
  }
}
# Verify Windows logo not Apple
if (-not $DryRun) {
  $deployed = "$HOME\Documents\WindowsPowerShell\Microsoft.PowerShell_profile.ps1"
  if (Test-Path $deployed) {
    $hasWin = Select-String -Path $deployed -Pattern "0xf17a" -Quiet
    $hasApple = Select-String -Path $deployed -Pattern "\[char\]0xf179" -Quiet  # executable char, not comment
    if ($hasWin -and -not $hasApple) { Write-Ok "prompt uses Windows logo 0xf17a  (Apple replaced)" }
    else { Write-Warn "prompt logo check: hasWin=$hasWin hasAppleExec=$hasApple — expected win=true appleExec=false" }
  }
}

# ————— 3. Fastfetch —————
Write-Step "Fastfetch config → ~\.config\fastfetch"
$ffSrc = Join-Path $RepoRoot "fastfetch"
$ffDest = "$HOME\.config\fastfetch"
Ensure-Dir $ffDest
foreach ($f in @("config.jsonc","config-no-nerd.jsonc","gh0stzk-logo.txt")) {
  $s = Join-Path $ffSrc $f
  $d = Join-Path $ffDest $f
  if (-not (Test-Path $s)) { Write-Warn "fastfetch source missing: $f"; continue }
  Backup-IfExists $d
  Invoke-Maybe "Copy fastfetch/$f → $d" {
    Copy-Item -LiteralPath $s -Destination $d -Force
    Write-Ok $f
  }
}

# ————— 4. Windows Terminal —————
Write-Step "Windows Terminal settings.json"
$wtSrc = Join-Path $RepoRoot "terminal/settings.json"
$wtDest = "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"
if (Test-Path $wtSrc) {
  if (Test-Path (Split-Path $wtDest -Parent)) {
    Backup-IfExists $wtDest
    Ensure-Dir (Split-Path $wtDest -Parent)
    Invoke-Maybe "Copy terminal/settings.json → $wtDest" {
      Copy-Item -LiteralPath $wtSrc -Destination $wtDest -Force
      Write-Ok "Windows Terminal settings deployed (One Half Dark, JetBrainsMono NF)"
    }
  } else {
    Write-Warn "Windows Terminal not installed (no LocalState folder) — skipping"
  }
} else { Write-Warn "terminal/settings.json missing in repo" }

# ————— 5. Raycast —————
Write-Step "Raycast — MSIX + 7 Store extensions"
# Raycast on Windows is MSIX: https://www.raycast.com
if (Test-Command winget) {
  $rayInstalled = winget list --id Raycast.Raycast 2>$null | Select-String "Raycast"
  # Also check MSIX package
  $rayMsix = Get-AppxPackage -Name "*Raycast*" -ErrorAction SilentlyContinue
  if ($rayInstalled -or $rayMsix) {
    Write-Ok "Raycast installed ($($rayMsix.PackageFullName))"
  } else {
    Write-Warn "Raycast not detected — install from https://www.raycast.com or via winget: winget install --id Raycast.Raycast -e"
    Invoke-Maybe "winget install --id Raycast.Raycast -e --silent --accept-package-agreements" {
      & winget install --id Raycast.Raycast -e --silent --accept-package-agreements --accept-source-agreements
      Write-Ok "Raycast install attempted"
    }
  }
}
$rayList = Join-Path $RepoRoot "raycast/extensions.json"
if (Test-Path $rayList) {
  Write-Info "Installed extensions on source machine:"
  try {
    $exts = Get-Content $rayList -Raw | ConvertFrom-Json
    foreach ($e in $exts) { Write-Info "  - $($e.title) ($($e.name)) [id: $($e.id)]" }
    Write-Info "Re-install inside Raycast: Store → search by name (or sign in to Raycast Cloud Sync to auto-restore)."
  } catch { Write-Warn "Could not parse raycast/extensions.json" }
} else { Write-Warn "raycast/extensions.json missing" }

# ————— 6. Syncthing —————
if (-not $NoSyncthing) {
  Write-Step "Syncthing — install, generate, autostart, firewall"
  $syncthingLink = "$env:LOCALAPPDATA\Microsoft\WinGet\Links\syncthing.exe"
  $syncthingExe  = $null
  if (Test-Path $syncthingLink) {
    try { $syncthingExe = (Get-Item $syncthingLink).Target } catch { $syncthingExe = $syncthingLink }
    if (-not $syncthingExe -or -not (Test-Path $syncthingExe)) { $syncthingExe = $syncthingLink }
  }
  if (-not (Test-Command syncthing) -and -not (Test-Path $syncthingLink)) {
    if (-not $OnlyConfigs -and -not $NoPackages) {
      Invoke-Maybe "winget install Syncthing.Syncthing --silent" {
        & winget install --id Syncthing.Syncthing --silent --accept-package-agreements --accept-source-agreements
        if (Test-Path $syncthingLink) { $syncthingExe = $syncthingLink; Write-Ok "Syncthing installed" }
        else { Write-Warn "Syncthing link not found after install" }
      }
    } else { Write-Warn "Syncthing not found — skip install due to OnlyConfigs/NoPackages, run: winget install Syncthing.Syncthing" }
  } else {
    Write-Ok "Syncthing present: $syncthingLink → $syncthingExe"
    try { & $syncthingExe --version | ForEach-Object { Write-Info $_ } } catch {}
  }

  # Generate config if missing
  $cfg = "$env:LOCALAPPDATA\Syncthing\config.xml"
  if (-not (Test-Path $cfg)) {
    Invoke-Maybe "syncthing generate → $cfg" {
      & $syncthingExe generate 2>&1 | Out-String | ForEach-Object { Write-Info $_ }
      if (Test-Path $cfg) { Write-Ok "generated $cfg" }
    }
  } else { Write-Ok "Syncthing config already at $cfg" }

  # Startup shortcut
  $startupDir = "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup"
  $lnk = Join-Path $startupDir "Syncthing.lnk"
  Ensure-Dir $startupDir
  Invoke-Maybe "Create Startup shortcut $lnk → syncthing --no-browser --no-restart" {
    $Wsh = New-Object -ComObject WScript.Shell
    $sc = $Wsh.CreateShortcut($lnk)
    $sc.TargetPath = $syncthingLink
    if (-not (Test-Path $sc.TargetPath) -and $syncthingExe) { $sc.TargetPath = $syncthingExe }
    $sc.Arguments = "--no-browser --no-restart"
    $sc.WorkingDirectory = "$env:LOCALAPPDATA\Syncthing"
    $sc.WindowStyle = 7
    $sc.Description = "Syncthing — continuous file synchronization"
    $sc.Save()
    Write-Ok "Startup shortcut → $lnk"
  }

  # Scheduled task at logon
  $taskName = "Syncthing"
  $existing = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
  if ($existing) { Write-Ok "Scheduled task '$taskName' already exists ($($existing.State))" }
  else {
    Invoke-Maybe "Create ScheduledTask '$taskName' (AtLogOn +30s, hidden)" {
      $action = New-ScheduledTaskAction -Execute $syncthingLink -Argument "--no-browser --no-restart" -WorkingDirectory "$env:LOCALAPPDATA\Syncthing"
      $trigger = New-ScheduledTaskTrigger -AtLogOn -User $env:USERNAME
      $trigger.Delay = "PT30S"
      $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -ExecutionTimeLimit 0 -RestartCount 3 -RestartInterval (New-TimeSpan -Minutes 1)
      $settings.Hidden = $true
      $principal = New-ScheduledTaskPrincipal -UserId "$env:USERDOMAIN\$env:USERNAME" -LogonType Interactive -RunLevel Highest
      try {
        Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Settings $settings -Principal $principal -Description "Syncthing autostart at logon (dotfiles)" | Out-Null
        Write-Ok "Scheduled task '$taskName' created"
      } catch {
        Write-Warn "Principal failed, retry without: $_"
        Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Settings $settings -Description "Syncthing autostart at logon" | Out-Null
        Write-Ok "Scheduled task '$taskName' created (fallback)"
      }
    }
  }

  # Firewall
  $fw = Get-NetFirewallRule -DisplayName "Syncthing*" -ErrorAction SilentlyContinue
  if ($fw) { Write-Ok "Firewall rule already present: $($fw.DisplayName -join ', ')" }
  else {
    Invoke-Maybe "Allow Syncthing through firewall" {
      $targetForFw = $syncthingExe
      if (-not $targetForFw) { $targetForFw = $syncthingLink }
      try {
        # Resolve to real exe for firewall
        if (Test-Path $syncthingLink) { try { $targetForFw = (Get-Item $syncthingLink).Target } catch {} }
        New-NetFirewallRule -DisplayName "Syncthing" -Direction Inbound -Program $targetForFw -Action Allow -Profile Any -Description "Allow Syncthing (dotfiles)" | Out-Null
        Write-Ok "Firewall rule created for $targetForFw"
      } catch { Write-Warn "Firewall rule failed: $_ — add manually via Windows Firewall" }
    }
  }

  # Sync folder
  $syncDir = "$HOME\Sync"
  Ensure-Dir $syncDir
  if (-not $DryRun -and (Test-Path $syncDir)) { Write-Ok "Sync folder: $syncDir" }

  # Try start
  Invoke-Maybe "Start Syncthing (check http://127.0.0.1:8384)" {
    try { Start-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue } catch {}
    Start-Sleep -Seconds 2
    $proc = Get-Process -Name syncthing -ErrorAction SilentlyContinue
    if ($proc) { Write-Ok "Syncthing running (PID $($proc.Id -join ', ')) — GUI http://127.0.0.1:8384" }
    else {
      try { Start-Process -FilePath $syncthingLink -ArgumentList "--no-browser","--no-restart" -WindowStyle Hidden } catch {}
      Start-Sleep -Seconds 2
      $proc2 = Get-Process -Name syncthing -ErrorAction SilentlyContinue
      if ($proc2) { Write-Ok "Syncthing started manually (PID $($proc2.Id))" } else { Write-Warn "Syncthing not running — start manually: syncthing --no-browser" }
    }
  }
} else {
  Write-Step "Skipping Syncthing (NoSyncthing)"
}

# ————— 7. Fonts & extras —————
Write-Step "Polish"
Write-Info "JetBrainsMono Nerd Font 3.3.0 should be installed via winget; set as Windows Terminal font (see terminal/settings.json)."
Write-Info "zoxide is initialized in profile via: Invoke-Expression (& { (zoxide init powershell | Out-String) }) — run 'z <fuzzy>' after restart."
Write-Info "Fastfetch runs at shell start via WinGet Links fastfetch.exe — edit via $HOME\.config\fastfetch\config.jsonc"

# ————— done —————
Write-Step "Done!"
if ($DryRun) { Write-Host "   (DryRun — no changes made)" -ForegroundColor Yellow }
else {
  Write-Host "   Profile: Documents\WindowsPowerShell\Microsoft.PowerShell_profile.ps1" -ForegroundColor Green
  Write-Host "   Fastfetch: ~/.config/fastfetch" -ForegroundColor Green
  Write-Host "   Terminal: %LOCALAPPDATA%\Packages\Microsoft.WindowsTerminal…\LocalState\settings.json" -ForegroundColor Green
  Write-Host "   Syncthing GUI: http://127.0.0.1:8384  |  Sync folder: $HOME\Sync" -ForegroundColor Green
  Write-Host "`n   Restart your terminal to see the Windows logo prompt " -ForegroundColor Cyan
  Write-Host "   Secrets: [System.Environment]::SetEnvironmentVariable('GITHUB_PERSONAL_ACCESS_TOKEN','ghp_...','User')" -ForegroundColor DarkGray
}
Write-Host ""
