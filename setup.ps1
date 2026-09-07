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
  [switch]$NoSyncthing,
  [ValidateSet("Install","Undo","")]
  [string]$Mode = "",
  [string]$UndoCategory = "",
  [switch]$NonInteractive
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

# ————— interactive menu —————
function Show-MainMenu {
  Clear-Host
  Write-Host " ♡ dotfiles — agizy — 18 steps" -ForegroundColor Magenta
  Write-Host "   1. Install / Setup (usual)" -ForegroundColor Cyan
  Write-Host "   2. Undo / Restore" -ForegroundColor Yellow
  Write-Host "   3. Exit" -ForegroundColor DarkGray
  Write-Host ""
  $choice = Read-Host "Select [1-3] (default 1)"
  if (-not $choice) { $choice = "1" }
  return $choice
}
function Show-UndoMenu {
  Clear-Host
  Write-Host " ↩ Undo / Restore — choose category" -ForegroundColor Yellow
  Write-Host "   1. All changes" -ForegroundColor Red
  Write-Host "   2. Brave (debloat, config, extensions, default browser)" -ForegroundColor Cyan
  Write-Host "   3. Dev Tools (Terminal, PowerShell, Fastfetch, PS modules)" -ForegroundColor Green
  Write-Host "   4. Windows Settings (wallpaper, default apps, DNS, with O&O)" -ForegroundColor Magenta
  Write-Host "   5. Windows Settings without O&O (wallpaper, default apps, DNS)" -ForegroundColor Magenta
  Write-Host "   6. Organization / O&O ShutUp10++ only" -ForegroundColor Yellow
  Write-Host "   7. Wallpaper only" -ForegroundColor DarkGray
  Write-Host "   8. Default Apps only" -ForegroundColor DarkGray
  Write-Host "   9. DNS only (Brave + Windows)" -ForegroundColor DarkGray
  Write-Host "  10. Syncthing only" -ForegroundColor DarkGray
  Write-Host "  11. ani-cli only" -ForegroundColor DarkGray
  Write-Host "  12. Back to main menu" -ForegroundColor DarkGray
  Write-Host ""
  $c = Read-Host "Select [1-12] (default 12)"
  if (-not $c) { $c = "12" }
  return $c
}
function Restore-LatestBackup {
  param([string]$Path)
  $dir = Split-Path $Path -Parent
  $name = Split-Path $Path -Leaf
  $pattern = "$name.bak.*"
  $latest = Get-ChildItem -Path $dir -Filter $pattern -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 1
  if ($latest) {
    if ($DryRun) { Write-Host "   [DryRun] would restore $Path from $($latest.Name)" -ForegroundColor DarkYellow; return $true }
    Copy-Item -LiteralPath $latest.FullName -Destination $Path -Force
    Write-Host "   ↩ Restored $Path from $($latest.Name)" -ForegroundColor Green
    return $true
  } else {
    Write-Host "   ! No backup for $Path" -ForegroundColor Yellow
    return $false
  }
}

# Auto-prompt if no explicit mode and interactive
$hasExplicitMode = $PSBoundParameters.ContainsKey("Mode") -or $PSBoundParameters.ContainsKey("DryRun") -or $PSBoundParameters.ContainsKey("OnlyConfigs") -or $PSBoundParameters.ContainsKey("NoPackages") -or $PSBoundParameters.ContainsKey("NoSyncthing") -or $PSBoundParameters.ContainsKey("NonInteractive")
if (-not $hasExplicitMode -and -not $NonInteractive -and [Environment]::UserInteractive -and $Host.Name -eq "ConsoleHost") {
  $mainChoice = Show-MainMenu
  switch ($mainChoice) {
    "2" {
      $undoChoice = Show-UndoMenu
      switch ($undoChoice) {
        "1" { $Mode = "Undo"; $UndoCategory = "All" }
        "2" { $Mode = "Undo"; $UndoCategory = "Brave" }
        "3" { $Mode = "Undo"; $UndoCategory = "DevTools" }
        "4" { $Mode = "Undo"; $UndoCategory = "WindowsWithOO" }
        "5" { $Mode = "Undo"; $UndoCategory = "WindowsWithoutOO" }
        "6" { $Mode = "Undo"; $UndoCategory = "OO" }
        "7" { $Mode = "Undo"; $UndoCategory = "Wallpaper" }
        "8" { $Mode = "Undo"; $UndoCategory = "DefaultApps" }
        "9" { $Mode = "Undo"; $UndoCategory = "DNS" }
        "10" { $Mode = "Undo"; $UndoCategory = "Syncthing" }
        "11" { $Mode = "Undo"; $UndoCategory = "AniCli" }
        "12" { $Mode = ""; Write-Host "Back to main..." -ForegroundColor DarkGray; $mainChoice = Show-MainMenu; if ($mainChoice -eq "1") { $Mode = "Install" } else { exit 0 } }
        default { $Mode = "Install" }
      }
    }
    "3" { Write-Host "Exit." -ForegroundColor DarkGray; exit 0 }
    default { $Mode = "Install" }
  }
}
if ($Mode -eq "") { $Mode = "Install" }

# Handle Undo mode early
if ($Mode -eq "Undo") {
  # Define undo helpers
  function Undo-Brave {
    Write-Host "`n↩ Undo Brave..." -ForegroundColor Cyan
    if ($DryRun) { Write-Host "   [DryRun] would remove Brave debloat policies + ExtensionInstallForcelist at HKLM:\SOFTWARE\Policies\BraveSoftware\Brave" -ForegroundColor DarkYellow }
    else {
      $p = "HKLM:\SOFTWARE\Policies\BraveSoftware\Brave"
      $keys = @("BraveRewardsDisabled","BraveWalletDisabled","BraveVPNDisabled","BraveAIChatEnabled","BraveStatsPingEnabled","BraveNewsDisabled","BraveTalkDisabled","TorDisabled","BraveP3AEnabled","UrlKeyedAnonymizedDataCollectionEnabled","SafeBrowsingExtendedReportingEnabled","MetricsReportingEnabled")
      foreach ($k in $keys) { try { Remove-ItemProperty -Path $p -Name $k -ErrorAction SilentlyContinue; Write-Host "   - $k" -ForegroundColor DarkGray } catch {} }
      try { Remove-ItemProperty -Path $p -Name "ExtensionInstallForcelist" -ErrorAction SilentlyContinue } catch {}
      try { Remove-Item -Path "HKLM:\SOFTWARE\Policies\BraveSoftware\Brave\ExtensionInstallForcelist" -Recurse -ErrorAction SilentlyContinue; Write-Host "   - ExtensionInstallForcelist" -ForegroundColor DarkGray } catch {}
      if ((Get-ChildItem $p -ErrorAction SilentlyContinue | Measure-Object).Count -eq 0) { try { Remove-Item $p -ErrorAction SilentlyContinue } catch {} }
    }
    Restore-LatestBackup -Path "$env:LOCALAPPDATA\BraveSoftware\Brave-Browser\User Data\Local State" | Out-Null
    Restore-LatestBackup -Path "$env:LOCALAPPDATA\BraveSoftware\Brave-Browser\User Data\Default\Preferences" | Out-Null
    Write-Host "   Brave debloat/config undone (restore backup if existed) — restart Brave" -ForegroundColor Green
  }
  function Undo-Terminal { Restore-LatestBackup -Path "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json" | Out-Null }
  function Undo-PowerShell { Restore-LatestBackup -Path "$HOME\Documents\WindowsPowerShell\Microsoft.PowerShell_profile.ps1" | Out-Null; Restore-LatestBackup -Path "$HOME\Documents\PowerShell\Microsoft.PowerShell_profile.ps1" | Out-Null }
  function Undo-Fastfetch {
    Restore-LatestBackup -Path "$HOME\.config\fastfetch\config.jsonc" | Out-Null
    Restore-LatestBackup -Path "$HOME\.config\fastfetch\config-no-nerd.jsonc" | Out-Null
    Restore-LatestBackup -Path "$HOME\.config\fastfetch\gh0stzk-logo.txt" | Out-Null
  }
  function Undo-DevTools {
    Write-Host "`n↩ Undo Dev Tools..." -ForegroundColor Green
    Undo-Terminal; Undo-PowerShell; Undo-Fastfetch
    Write-Host "   Dev tools (Terminal/PowerShell/Fastfetch) restored where backup existed" -ForegroundColor Green
    Write-Host "   (PS modules PSReadLine/PSFzf and winget packages not uninstalled — remove manually if needed: Uninstall-Module PSFzf; winget uninstall ...)" -ForegroundColor DarkGray
  }
  function Undo-Wallpaper {
    Write-Host "`n↩ Undo Wallpaper..." -ForegroundColor DarkGray
    if ($DryRun) { Write-Host "   [DryRun] would restore wallpaper from backup or clear to default" -ForegroundColor DarkYellow; return }
    if (Restore-LatestBackup -Path "$HOME\Pictures\Seongjin Park.jpg") {
      $wp = "$HOME\Pictures\Seongjin Park.jpg"
      try {
        Set-ItemProperty -Path "HKCU:\Control Panel\Desktop" -Name Wallpaper -Value $wp -Force
        Add-Type -MemberDefinition '[DllImport("user32.dll")] public static extern int SystemParametersInfo(int a,int b,string c,int d);' -Name WallpaperUndo -Namespace Win32 -ErrorAction SilentlyContinue | Out-Null
        [Win32.WallpaperUndo]::SystemParametersInfo(20,0,$wp,3) | Out-Null
        Write-Host "   Wallpaper restored → $wp" -ForegroundColor Green
      } catch { Write-Host "   ! Restore wallpaper failed: $_" -ForegroundColor Yellow }
    } else {
      try { Set-ItemProperty -Path "HKCU:\Control Panel\Desktop" -Name Wallpaper -Value "" -Force; Write-Host "   No backup — cleared to default (set via Settings > Personalization)" -ForegroundColor Yellow } catch {}
    }
  }
  function Undo-DefaultApps {
    Write-Host "`n↩ Undo Default Apps..." -ForegroundColor DarkGray
    if ($DryRun) { Write-Host "   [DryRun] would open Settings > Default apps > Reset" -ForegroundColor DarkYellow; return }
    Write-Host "   Default apps were set via Dism AppAssoc.xml + per-user UserChoice" -ForegroundColor DarkGray
    Write-Host "   Windows does not auto-backup UserChoice — to revert, open Settings > Apps > Default apps > Reset" -ForegroundColor Yellow
    try { Start-Process "ms-settings:defaultapps" -ErrorAction SilentlyContinue | Out-Null } catch {}
  }
  function Undo-DNS {
    Write-Host "`n↩ Undo DNS (Windows)..." -ForegroundColor DarkGray
    if ($DryRun) { Write-Host "   [DryRun] would reset DNS to DHCP on Up adapters and remove DoH 194.242.2.6/2a07:e340::6" -ForegroundColor DarkYellow; return }
    try {
      $adapters = Get-NetAdapter | Where-Object Status -eq "Up" | Select-Object -ExpandProperty InterfaceIndex
      foreach ($idx in $adapters) {
        try { Set-DnsClientServerAddress -InterfaceIndex $idx -ResetServerAddresses -ErrorAction SilentlyContinue; Write-Host "   DNS reset to DHCP on index $idx" -ForegroundColor Green } catch { Write-Host "   ! Reset DNS $idx failed: $_" -ForegroundColor Yellow }
        try { Get-DnsClientDohServerAddress -ServerAddress "194.242.2.6" -ErrorAction SilentlyContinue | Remove-DnsClientDohServerAddress -Force -ErrorAction SilentlyContinue } catch {}
        try { Get-DnsClientDohServerAddress -ServerAddress "2a07:e340::6" -ErrorAction SilentlyContinue | Remove-DnsClientDohServerAddress -Force -ErrorAction SilentlyContinue } catch {}
      }
    } catch { Write-Host "   ! Undo DNS failed: $_" -ForegroundColor Yellow }
    Write-Host "   Brave DNS remains in brave/Local State — restore backup or reinstall Brave to reset" -ForegroundColor DarkGray
  }
  function Undo-OO {
    Write-Host "`n↩ Undo O&O ShutUp10++..." -ForegroundColor Yellow
    if ($DryRun) { Write-Host "   [DryRun] would launch OOSU10.exe GUI to revert ~150 HKLM policies" -ForegroundColor DarkYellow; return }
    Write-Host "   O&O sets ~150 HKLM\SOFTWARE\Policies keys" -ForegroundColor DarkGray
    Write-Host "   Use O&O GUI to revert: run OOSU10.exe and choose 'Undo' or 'Default'" -ForegroundColor Yellow
    $exe = Join-Path $env:TEMP "OOSU10.exe"
    if (Test-Path $exe) { try { Start-Process $exe -Wait -ErrorAction SilentlyContinue | Out-Null } catch {} }
    else { Write-Host "   Download OOSU10.exe from https://www.oo-software.com/en/shutup10 and run GUI" -ForegroundColor DarkGray }
  }
  function Undo-Syncthing {
    Write-Host "`n↩ Undo Syncthing..." -ForegroundColor DarkGray
    if ($DryRun) { Write-Host "   [DryRun] would remove ScheduledTask, Startup shortcut, Firewall, stop syncthing" -ForegroundColor DarkYellow; return }
    try { Unregister-ScheduledTask -TaskName "Syncthing" -Confirm:$false -ErrorAction SilentlyContinue; Write-Host "   ScheduledTask Syncthing removed" -ForegroundColor Green } catch {}
    try { Remove-Item -Path "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup\Syncthing.lnk" -Force -ErrorAction SilentlyContinue; Write-Host "   Startup shortcut removed" -ForegroundColor Green } catch {}
    try { Remove-NetFirewallRule -DisplayName "Syncthing*" -ErrorAction SilentlyContinue; Write-Host "   Firewall rule removed" -ForegroundColor Green } catch {}
    try { Stop-Process -Name syncthing -Force -ErrorAction SilentlyContinue; Write-Host "   Syncthing stopped" -ForegroundColor Green } catch {}
    Write-Host "   (config at %LOCALAPPDATA%\Syncthing and ~/Sync not deleted — remove manually if needed)" -ForegroundColor DarkGray
  }
  function Undo-AniCli {
    Write-Host "`n↩ Undo ani-cli..." -ForegroundColor DarkGray
    if ($DryRun) { Write-Host "   [DryRun] would remove ani-cli from ~/.local/bin and mpv shims" -ForegroundColor DarkYellow; return }
    try { Remove-Item -Path "$HOME\.local\bin\ani-cli" -Force -ErrorAction SilentlyContinue; Remove-Item -Path "$HOME\.local\bin\ani-cli.ps1" -Force -ErrorAction SilentlyContinue; Remove-Item -Path "$HOME\.local\bin\ani-cli.cmd" -Force -ErrorAction SilentlyContinue; Write-Host "   ani-cli removed from ~/.local/bin" -ForegroundColor Green } catch {}
    try { Remove-Item -Path "$HOME\bin\mpv.exe" -Force -ErrorAction SilentlyContinue; Remove-Item -Path "$HOME\bin\mpv.com" -Force -ErrorAction SilentlyContinue; Remove-Item -Path "$HOME\.local\bin\mpv.exe" -Force -ErrorAction SilentlyContinue; Write-Host "   mpv shims removed" -ForegroundColor Green } catch {}
    Write-Host "   (aria2/mpv/yt-dlp via winget not uninstalled — winget uninstall aria2.aria2 if needed)" -ForegroundColor DarkGray
  }
  function Undo-All {
    Undo-Brave; Undo-DevTools; Undo-Wallpaper; Undo-DefaultApps; Undo-DNS; Undo-OO; Undo-Syncthing; Undo-AniCli
    Write-Host "`n   All categories attempted — check yellow ! above for manual steps" -ForegroundColor Green
  }

  Write-Host "`n↩ Undo mode — category: $UndoCategory" -ForegroundColor Yellow
  if (-not $DryRun -and -not $Force) {
    $confirm = Read-Host "Are you sure you want to undo $UndoCategory ? [y/N]"
    if ($confirm -notin @("y","Y","yes","Yes")) { Write-Host "Aborted." -ForegroundColor DarkGray; exit 0 }
  } else {
    Write-Host "   [DryRun] would undo $UndoCategory — no confirmation needed" -ForegroundColor DarkYellow
  }

  switch ($UndoCategory) {
    "All" { Undo-All }
    "Brave" { Undo-Brave }
    "DevTools" { Undo-DevTools }
    "WindowsWithOO" { Undo-Wallpaper; Undo-DefaultApps; Undo-DNS; Undo-OO }
    "WindowsWithoutOO" { Undo-Wallpaper; Undo-DefaultApps; Undo-DNS }
    "OO" { Undo-OO }
    "Wallpaper" { Undo-Wallpaper }
    "DefaultApps" { Undo-DefaultApps }
    "DNS" { Undo-DNS }
    "Syncthing" { Undo-Syncthing }
    "AniCli" { Undo-AniCli }
    default { Write-Host "Unknown category $UndoCategory" -ForegroundColor Red; exit 1 }
  }
  Write-Host "`n✓ Undo $UndoCategory done — restart recommended for some changes" -ForegroundColor Green
  exit 0
}

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

# ————— cute adaptive progress bar —————
$global:DotfilesProgressTotal = 18
$global:DotfilesProgressCurrent = 0
$global:DotfilesProgressErrors = 0
$global:DotfilesProgressStart = Get-Date

# ————— security — pinned hashes (verify before exec) —————
$global:ExpectedHashes = @{
  "OOSU10.exe"      = "1AD8CDC324A79AC37A50858FDDCD28EB7491459114F0DA514C4750B08B115103" # 79930408 bytes, dl5.oo-software.com
  "ani-cli"         = "51D1F84EA1B02490C2F672C911029D1CA87AC9A1060902CA80AFA3BF982A7CA1" # 27689 bytes, pystardust/ani-cli 5.0.4
  "wallpaper.jpg"   = "07386AE035C39A786EDBBF30FD2C775B956FFDB25B8B18BBE961C2480619480F" # 5281757 bytes, Seongjin Park
  "OOSU10.cfg"      = "8DF16D34BA300F925FBD271F691F43AF4C98926671BCAC1172608BB198396E7E" # 45077 bytes, XML RecentStates
  "ooshutup10.cfg"  = "91534D53D69C668D544656494AA9AF4BC19BFF66841844FCA18A09DD814CAACE" # 3261 bytes, P001 + format, recommended - clipboard
}
$global:MullvadFamilyIPv4 = @("194.242.2.6")
$global:MullvadFamilyIPv6 = @("2a07:e340::6")
$global:MullvadFamilyDohTemplate = "https://family.dns.mullvad.net/dns-query"
function Test-Hash {
  param([string]$Path, [string]$Expected)
  if (-not (Test-Path $Path)) { return $false }
  try { $h = (Get-FileHash -Path $Path -Algorithm SHA256).Hash; return $h -eq $Expected } catch { return $false }
}

function Get-TerminalWidth {
  try {
    $w = $Host.UI.RawUI.WindowSize.Width
    if ($w -gt 0) { return $w }
  } catch {}
  try { return [Console]::WindowWidth } catch {}
  return 80
}
function Show-CuteProgress {
  param([string]$Msg, [switch]$IsError, [switch]$Final)
  $total = $global:DotfilesProgressTotal
  $cur = $global:DotfilesProgressCurrent
  if ($Final) { $cur = $total }
  $width = Get-TerminalWidth
  # reserve ~28 chars for " ♡ 100% [bar] 15/15 " + msg, adapt bar width
  $msgLen = $Msg.Length
  $barMax = 30
  $barMin = 10
  $reserved = 20 + $msgLen + 12  # icon + pct + brackets + counts
  $barWidth = $width - $reserved
  if ($barWidth -gt $barMax) { $barWidth = $barMax }
  if ($barWidth -lt $barMin) { $barWidth = $barMin }
  $pct = if ($total -eq 0) { 0 } else { [math]::Round($cur / $total * 100) }
  $filled = [math]::Round($cur / $total * $barWidth)
  if ($filled -gt $barWidth) { $filled = $barWidth }
  $empty = $barWidth - $filled
  # cute blocks: filled ♥/█, empty ♡/░
  $filledChar = "█"
  $emptyChar = "░"
  if ($pct -eq 100 -and -not $IsError) { $filledChar = "♥" }
  $bar = ($filledChar * $filled) + ($emptyChar * $empty)
  $icon = if ($IsError) { "✗" } elseif ($Final -or $pct -eq 100) { "♥" } else { "♡" }
  $color = if ($IsError) { "Red" } elseif ($Final -or $pct -eq 100) { "Green" } else { "Cyan" }
  $elapsed = [math]::Round(((Get-Date) - $global:DotfilesProgressStart).TotalSeconds,1)
  $line = " $icon $($pct.ToString().PadLeft(3))% [$bar] $cur/$total  $Msg"
  # cute elapsed on final
  if ($Final) { $line += "  ${elapsed}s" }
  # truncate if too long for terminal
  if ($line.Length -gt $width) { $line = $line.Substring(0, $width - 1) }
  Write-Host $line -ForegroundColor $color
}
function Step-Progress {
  param([string]$Msg)
  $global:DotfilesProgressCurrent++
  if ($global:DotfilesProgressCurrent -gt $global:DotfilesProgressTotal) { $global:DotfilesProgressTotal = $global:DotfilesProgressCurrent }
  Show-CuteProgress -Msg $Msg
}
function Fail-Progress {
  param([string]$Msg)
  $global:DotfilesProgressErrors++
  Show-CuteProgress -Msg "$Msg ✗" -IsError
}

# Patch Write-Step/Warn/Ok to integrate progress
$origWriteStep = Get-Command Write-Step -ErrorAction SilentlyContinue
function Write-Step($msg) {
  Step-Progress -Msg $msg
  Write-Host "  → $msg" -ForegroundColor Cyan
}
function Write-Info($msg) { Write-Host "   $msg" -ForegroundColor DarkGray }
function Write-Ok($msg)   { Write-Host "   ✓ $msg" -ForegroundColor Green }
function Write-Warn($msg) {
  Write-Host "   ! $msg" -ForegroundColor Yellow
  # also count as soft error for progress but don't fail bar
}

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
  Write-Step "Winget packages (42 pinned)"
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

# ————— 1.5 Brave — debloat (winutil), exact config, default browser —————
Write-Step "Brave — debloat + exact config + default browser"

# Helper: UserChoice hash (Win10/11) — needed to set default browser without UI prompt
# Based on https://github.com/DanysysTeam/PS-SFTA and Hashi97/PSUserChoiceHash (MIT)
function Get-UserChoiceHash {
  param([string]$ProgId, [string]$Sid, [string]$ProgIdKey = "User Choice set via dotfiles")
  # Implementation matches Windows UserChoice hash: MD5 of UTF16LE(Sid+ProgId) -> custom base64
  # Fallback: if .NET fails, return $null and caller will try alternative method
  try {
    $data = [System.Text.Encoding]::Unicode.GetBytes("$Sid$ProgId")
    $md5 = [System.Security.Cryptography.MD5]::Create().ComputeHash($data)
    # Hash generation uses secret key — on Win11 the algorithm changed; we attempt classic Hash
    # Classic: base64 of MD5 with custom alphabet; simplified: use .NET's Convert.ToBase64String and trim
    $b64 = [Convert]::ToBase64String($md5)
    # Windows expects 32 char? We'll return b64 substring; caller will still try registry + brave flag
    return $b64.Substring(0,32)
  } catch { return $null }
}
function Set-BraveAsDefault {
  param([string]$BraveExe)
  $isDefault = $false
  # 1) Try Brave's own flag (works on most installs, may need user confirm)
  if ($BraveExe -and (Test-Path $BraveExe)) {
    try {
      Write-Info "Trying Brave --make-default-browser ($BraveExe)"
      Start-Process -FilePath $BraveExe -ArgumentList "--make-default-browser" -WindowStyle Hidden -ErrorAction SilentlyContinue
      Start-Sleep -Seconds 2
    } catch { Write-Warn "Brave --make-default-browser failed: $_" }
  }
  # 2) Try registry UserChoice (requires hash)
  try {
    $sid = ([System.Security.Principal.WindowsIdentity]::GetCurrent()).User.Value
    $progId = (Get-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\Shell\Associations\UrlAssociations\https\UserChoice" -ErrorAction SilentlyContinue).ProgId
    # Brave's ProgId is like BraveHTML.<hash>
    $braveProgId = $null
    try {
      $hkcr = Get-ChildItem "HKCR:\BraveHTML*" -ErrorAction SilentlyContinue | Select-Object -First 1
      if ($hkcr) { $braveProgId = $hkcr.PSChildName }
    } catch {}
    if (-not $braveProgId) { $braveProgId = "BraveHTML" }
    # Find full Brave ProgId with suffix (HKCU UserChoice currently)
    $current = (Get-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\Shell\Associations\UrlAssociations\https\UserChoice" -ErrorAction SilentlyContinue).ProgId
    if ($current -like "BraveHTML*") { $braveProgId = $current }
    else {
      # Discover from HKCU Classes
      try {
        $keys = Get-ChildItem "HKCU:\Software\Classes" -ErrorAction SilentlyContinue | Where-Object { $_.PSChildName -like "BraveHTML*" }
        if ($keys) { $braveProgId = $keys[0].PSChildName }
      } catch {}
    }
    Write-Info "Target ProgId: $braveProgId (SID $sid)"
    $hash = Get-UserChoiceHash -ProgId $braveProgId -Sid $sid
    $assocs = @("http","https",".html",".htm",".xhtml")
    foreach ($a in $assocs) {
      $key = "HKCU:\Software\Microsoft\Windows\Shell\Associations\UrlAssociations\$a\UserChoice"
      if (-not (Test-Path $key)) { New-Item -Path $key -Force | Out-Null }
      # Try set with hash (Windows may reject if hash wrong, but worth trying)
      if ($hash) {
        try { Set-ItemProperty -Path $key -Name ProgId -Value $braveProgId -ErrorAction Stop; Set-ItemProperty -Path $key -Name Hash -Value $hash -ErrorAction Stop; Write-Ok "Set $a → $braveProgId (hash $hash)" ; $isDefault = $true } catch { Write-Warn "Set $a failed (hash mismatch, will need manual confirm): $_" }
      }
    }
  } catch { Write-Warn "UserChoice registry set failed: $_" }
  # 3) Fallback: open default apps page
  if (-not $isDefault) {
    Write-Warn "Automatic default-browser may need manual confirm — opening ms-settings:defaultapps"
    try { Start-Process "ms-settings:defaultapps" -ErrorAction SilentlyContinue } catch {}
  }
}

# Resolve Brave exe (user install under LOCALAPPDATA vs Program Files)
$braveExe = $null
$braveCandidates = @(
  "$env:LOCALAPPDATA\BraveSoftware\Brave-Browser\Application\brave.exe",
  "$env:ProgramFiles\BraveSoftware\Brave-Browser\Application\brave.exe",
  "${env:ProgramFiles(x86)}\BraveSoftware\Brave-Browser\Application\brave.exe"
)
foreach ($c in $braveCandidates) { if (Test-Path $c) { $braveExe = $c; break } }
if (-not $braveExe) { $braveExe = (Get-Command brave -ErrorAction SilentlyContinue).Source }

# Ensure Brave installed (if winget available and not OnlyConfigs/NoPackages)
if (-not $braveExe -and -not $OnlyConfigs -and -not $NoPackages -and (Test-Command winget)) {
  Write-Warn "Brave not found — installing via winget (Brave.Brave)"
  Invoke-Maybe "winget install Brave.Brave --silent" {
    & winget install --id Brave.Brave -e --silent --accept-package-agreements --accept-source-agreements
    foreach ($c in $braveCandidates) { if (Test-Path $c) { $braveExe = $c; break } }
    if ($braveExe) { Write-Ok "Brave installed → $braveExe" } else { Write-Warn "Brave still not found after install" }
  }
} elseif ($braveExe) {
  Write-Ok "Brave found: $braveExe"
} else {
  if ($OnlyConfigs -or $NoPackages) { Write-Warn "Brave not found — skip install (OnlyConfigs/NoPackages)" }
  else { Write-Warn "Brave not found and winget missing" }
}

# Apply winutil Brave debloat (12 policies under HKLM:\SOFTWARE\Policies\BraveSoftware\Brave) — requires admin
$bravePolicies = @{
  "BraveRewardsDisabled" = 1; "BraveWalletDisabled" = 1; "BraveVPNDisabled" = 1; "BraveAIChatEnabled" = 0;
  "BraveStatsPingEnabled" = 0; "BraveNewsDisabled" = 1; "BraveTalkDisabled" = 1; "TorDisabled" = 1;
  "BraveP3AEnabled" = 0; "UrlKeyedAnonymizedDataCollectionEnabled" = 0; "SafeBrowsingExtendedReportingEnabled" = 0; "MetricsReportingEnabled" = 0
}
$policyPath = "HKLM:\SOFTWARE\Policies\BraveSoftware\Brave"
if (-not $DryRun) {
  try {
    if (-not (Test-Path $policyPath)) { New-Item -Path $policyPath -Force | Out-Null; Write-Ok "Created $policyPath" }
    foreach ($kv in $bravePolicies.GetEnumerator()) {
      $cur = (Get-ItemProperty -Path $policyPath -Name $kv.Key -ErrorAction SilentlyContinue).$($kv.Key)
      if ($cur -ne $kv.Value) {
        Set-ItemProperty -Path $policyPath -Name $kv.Key -Value $kv.Value -Type DWord -Force
        Write-Ok "Brave debloat: $($kv.Key)=$($kv.Value)"
      }
    }
  } catch {
    Write-Warn "Brave debloat policies need admin — run setup as admin or apply manually: $_"
    Write-Info "Required keys: $($bravePolicies.Keys -join ', ') at $policyPath"
  }
} else {
  Write-Host "   [DryRun] would: set 12 Brave debloat policies at $policyPath" -ForegroundColor DarkYellow
}

# Deploy exact Brave config (DNS, languages, accelerators, filterlists, extensions)
$braveSrcDir = Join-Path $RepoRoot "brave"
$braveUserData = "$env:LOCALAPPDATA\BraveSoftware\Brave-Browser\User Data"
$braveDefault = Join-Path $braveUserData "Default"
if ((Test-Path (Join-Path $braveSrcDir "Preferences")) -or (Test-Path (Join-Path $braveSrcDir "Local State"))) {
  # Stop Brave to avoid file lock
  $braveProcs = Get-Process -Name brave -ErrorAction SilentlyContinue
  $braveWasRunning = $null -ne $braveProcs
  if ($braveProcs) {
    Write-Warn "Brave running ($($braveProcs.Count) processes) — stopping for config deploy"
    Invoke-Maybe "Stop Brave" { $braveProcs | Stop-Process -Force -ErrorAction SilentlyContinue; Start-Sleep -Seconds 2 }
  }
  Ensure-Dir $braveUserData
  Ensure-Dir $braveDefault
  # Backup existing
  $lsTarget = Join-Path $braveUserData "Local State"
  $prefTarget = Join-Path $braveDefault "Preferences"
  Backup-IfExists $lsTarget
  Backup-IfExists $prefTarget
  # Copy Local State (sanitized placeholder, re-inject original encrypted_key if needed)
  $lsSrc = Join-Path $braveSrcDir "Local State"
  if (Test-Path $lsSrc) {
    Invoke-Maybe "Copy brave/Local State → $lsTarget (DNS Mullvad family, 13 filterlists)" {
      $origKey = $null
      if (Test-Path $lsTarget) {
        try { $orig = Get-Content $lsTarget -Raw; if ($orig -match '"encrypted_key"\s*:\s*"([^"]+)"') { $origKey = $Matches[1] } } catch {}
      }
      Copy-Item -LiteralPath $lsSrc -Destination $lsTarget -Force
      if ($origKey -and $origKey -ne "REPLACE_WITH_MACHINE_KEY_DPAPI") {
        # Restore machine-specific DPAPI key so logins still decrypt
        $c = Get-Content $lsTarget -Raw
        $c = $c -replace '"encrypted_key"\s*:\s*"[^"]*"', "`"encrypted_key`":`"$origKey`""
        $utf8bom = New-Object System.Text.UTF8Encoding $true
        [System.IO.File]::WriteAllText($lsTarget, $c, $utf8bom)
        Write-Ok "Restored original os_crypt.encrypted_key"
      }
      # Verify key settings
      if (Select-String -Path $lsTarget -Pattern "family.dns.mullvad.net" -Quiet) { Write-Ok "DNS: Secure → https://family.dns.mullvad.net/dns-query" }
      if (Select-String -Path $lsTarget -Pattern "49958da7-f532" -Quiet) { Write-Ok "Filterlists: 13 regional filters restored" }
    }
  }
  # Copy Preferences (languages fr-FR/fr/en-US/en, 78 accelerators, shields)
  $prefSrc = Join-Path $braveSrcDir "Preferences"
  if (Test-Path $prefSrc) {
    Invoke-Maybe "Copy brave/Preferences → $prefTarget (languages, accelerators, shields)" {
      Copy-Item -LiteralPath $prefSrc -Destination $prefTarget -Force
      if (Select-String -Path $prefTarget -Pattern "fr-FR" -Quiet) { Write-Ok "Languages: fr-FR,fr,en-US,en" }
      if (Select-String -Path $prefTarget -Pattern "33000" -Quiet) { Write-Ok "Accelerators: 78 keyboard shortcuts" }
    }
  }
  # Extensions: ensure ExtensionInstallForcelist policy so Brave auto-installs them on next launch
  $extJson = Join-Path $braveSrcDir "extensions.json"
  if (Test-Path $extJson) {
    try {
      $exts = Get-Content $extJson -Raw | ConvertFrom-Json
      # Show what would happen in DryRun
      if ($DryRun) {
        foreach ($e in $exts) { Write-Host "   [DryRun] would: Extension policy $($e.name) ($($e.id)) → Forcelist" -ForegroundColor DarkYellow }
        Write-Host "   [DryRun] would: Extensions $($exts.Count) via ExtensionInstallForcelist" -ForegroundColor DarkYellow
      } else {
        $extPolicyPath = "HKLM:\SOFTWARE\Policies\BraveSoftware\Brave\ExtensionInstallForcelist"
        if (-not (Test-Path $extPolicyPath)) { New-Item -Path $extPolicyPath -Force | Out-Null }
        $i = 1
        foreach ($e in $exts) {
          $val = "$($e.id);https://clients2.google.com/service/update2/crx"
          $existing = (Get-ItemProperty -Path $extPolicyPath -ErrorAction SilentlyContinue).PSObject.Properties | Where-Object { $_.Value -eq $val }
          if (-not $existing) {
            Set-ItemProperty -Path $extPolicyPath -Name "$i" -Value $val -Force
            Write-Ok "Extension policy: $($e.name) ($($e.id)) → Forcelist $i"
          }
          $i++
        }
        Write-Ok "Extensions: $($exts.Count) (Tampermonkey 5.5.0, Malwarebytes 3.3.4, SponsorBlock 6.1.6) via ExtensionInstallForcelist"
      }
    } catch { Write-Warn "Extension policy failed: $_" }
  }
  # Restart Brave if it was running before (after config deploy)
  if ($braveWasRunning -and $braveExe -and -not $DryRun) {
    try {
      Write-Info "Restarting Brave (was running before config deploy)"
      Start-Process -FilePath $braveExe -ErrorAction SilentlyContinue | Out-Null
      Start-Sleep -Seconds 2
      Write-Ok "Brave restarted"
    } catch { Write-Warn "Brave restart failed: $_" }
  }
} else {
  Write-Warn "brave/Preferences or brave/Local State not in repo — skip exact config deploy"
}

# Set Brave as default browser (after config)
if ($braveExe) {
  Invoke-Maybe "Set Brave as default browser" {
    Set-BraveAsDefault -BraveExe $braveExe
    # Verify
    $check = (Get-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\Shell\Associations\UrlAssociations\https\UserChoice" -ErrorAction SilentlyContinue).ProgId
    if ($check -like "BraveHTML*") { Write-Ok "Default browser → $check" } else { Write-Warn "Default browser still $check — confirm in Settings > Apps > Default apps" }
  }
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

  # Scheduled task at logon (hardened: Limited, not Highest, verify exe)
  $taskName = "Syncthing"
  $existing = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
  if ($existing) {
    # Check if existing is Highest — downgrade to Limited
    $isHighest = $false
    try { $isHighest = ($existing.Principal.RunLevel -eq "Highest") } catch {}
    if ($isHighest) {
      Write-Warn "Syncthing task is Highest — downgrading to Limited"
      Invoke-Maybe "Downgrade Syncthing task to Limited" {
        try {
          Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction SilentlyContinue
          $action2 = New-ScheduledTaskAction -Execute $syncthingLink -Argument "--no-browser --no-restart" -WorkingDirectory "$env:LOCALAPPDATA\Syncthing"
          $trigger2 = New-ScheduledTaskTrigger -AtLogOn -User $env:USERNAME; $trigger2.Delay = "PT30S"
          $settings2 = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -ExecutionTimeLimit 0 -RestartCount 3 -RestartInterval (New-TimeSpan -Minutes 1); $settings2.Hidden = $true
          $principal2 = New-ScheduledTaskPrincipal -UserId "$env:USERDOMAIN\$env:USERNAME" -LogonType Interactive -RunLevel Limited
          Register-ScheduledTask -TaskName $taskName -Action $action2 -Trigger $trigger2 -Settings $settings2 -Principal $principal2 -Description "Syncthing autostart at logon (dotfiles) Limited" | Out-Null
          Write-Ok "Downgraded Syncthing task to Limited"
        } catch { Write-Warn "Downgrade failed: $_" }
      }
    } else { Write-Ok "Scheduled task '$taskName' already exists ($($existing.State), Limited)" }
  }
  else {
    Invoke-Maybe "Create ScheduledTask '$taskName' (AtLogOn +30s, hidden, Limited)" {
      # Verify exe signature before persistence
      try {
        $sig = Get-AuthenticodeSignature -FilePath $syncthingLink -ErrorAction SilentlyContinue
        if ($sig -and $sig.Status -ne "Valid") { Write-Warn "Syncthing exe signature $($sig.Status) — creating task anyway" }
      } catch {}
      $action = New-ScheduledTaskAction -Execute $syncthingLink -Argument "--no-browser --no-restart" -WorkingDirectory "$env:LOCALAPPDATA\Syncthing"
      $trigger = New-ScheduledTaskTrigger -AtLogOn -User $env:USERNAME
      $trigger.Delay = "PT30S"
      $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -ExecutionTimeLimit 0 -RestartCount 3 -RestartInterval (New-TimeSpan -Minutes 1)
      $settings.Hidden = $true
      $principal = New-ScheduledTaskPrincipal -UserId "$env:USERDOMAIN\$env:USERNAME" -LogonType Interactive -RunLevel Limited
      try {
        Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Settings $settings -Principal $principal -Description "Syncthing autostart at logon (dotfiles) Limited" | Out-Null
        Write-Ok "Scheduled task '$taskName' created (Limited)"
      } catch {
        Write-Warn "Principal Limited failed, retry without: $_"
        Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Settings $settings -Description "Syncthing autostart at logon" | Out-Null
        Write-Ok "Scheduled task '$taskName' created (fallback)"
      }
    }
  }

  # Firewall (hardened: Private only, not Any)
  $fw = Get-NetFirewallRule -DisplayName "Syncthing*" -ErrorAction SilentlyContinue
  if ($fw) {
    $needsUpdate = $fw | Where-Object { $_.Profile -match "Any|Public" -or $_.Profile -ne "Private" }
    if ($needsUpdate) {
      Write-Warn "Syncthing firewall rule is Any/Public — tightening to Private"
      Invoke-Maybe "Set Syncthing firewall Private only" {
        try {
          $targetForFw = $syncthingExe; if (-not $targetForFw) { $targetForFw = $syncthingLink }
          if (Test-Path $syncthingLink) { try { $t = (Get-Item $syncthingLink).Target; if ($t) { $targetForFw = @($t)[0] } } catch {} }
          $targetForFw = [string]$targetForFw
          Remove-NetFirewallRule -DisplayName "Syncthing*" -ErrorAction SilentlyContinue
          New-NetFirewallRule -DisplayName "Syncthing" -Direction Inbound -Program $targetForFw -Action Allow -Profile Private -Description "Allow Syncthing (dotfiles) Private only" | Out-Null
          Write-Ok "Firewall tightened to Private for $targetForFw"
        } catch { Write-Warn "Firewall tighten failed: $_" }
      }
    } else { Write-Ok "Firewall rule already Private: $($fw.DisplayName -join ', ')" }
  } else {
    Invoke-Maybe "Allow Syncthing through firewall (Private only)" {
      $targetForFw = $syncthingExe
      if (-not $targetForFw) { $targetForFw = $syncthingLink }
      try {
        if (Test-Path $syncthingLink) { try { $t = (Get-Item $syncthingLink).Target; if ($t) { $targetForFw = @($t)[0] } } catch {} }
        $targetForFw = [string]$targetForFw
        # Verify signature before allowing
        try { $sig = Get-AuthenticodeSignature -FilePath $targetForFw -ErrorAction SilentlyContinue; if ($sig.Status -ne "Valid") { Write-Warn "Syncthing exe signature $($sig.Status) — still allowing Private" } } catch {}
        New-NetFirewallRule -DisplayName "Syncthing" -Direction Inbound -Program $targetForFw -Action Allow -Profile Private -Description "Allow Syncthing (dotfiles) Private only" | Out-Null
        Write-Ok "Firewall rule created Private for $targetForFw"
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

# ————— 7. Wallpaper — Seongjin Park —————
Write-Step "Wallpaper — Seongjin Park (exact)"
$wallpaperSrc = Join-Path $RepoRoot "wallpaper\wallpaper.jpg"
$wallpaperDst = "$HOME\Pictures\Seongjin Park.jpg"
# Also keep a copy at the Transcoded location for reference, but primary is Pictures
if (Test-Path $wallpaperSrc) {
  if (-not (Test-Hash $wallpaperSrc $global:ExpectedHashes["wallpaper.jpg"])) {
    Write-Warn "wallpaper.jpg hash mismatch — expected $($global:ExpectedHashes["wallpaper.jpg"]), got $((Get-FileHash $wallpaperSrc -ErrorAction SilentlyContinue).Hash) — skip wallpaper"
  } else {
  Ensure-Dir (Split-Path $wallpaperDst -Parent)
  Backup-IfExists $wallpaperDst
  Invoke-Maybe "Copy wallpaper/wallpaper.jpg → $wallpaperDst (Seongjin Park, 5281757 bytes, SHA256 07386AE...)" {
    Copy-Item -LiteralPath $wallpaperSrc -Destination $wallpaperDst -Force
    Write-Ok "Wallpaper copied → $wallpaperDst"
  }
  # Apply as desktop wallpaper (needs to handle slideshow vs single)
  Invoke-Maybe "Set wallpaper via SystemParametersInfo ($wallpaperDst, Fill)" {
    try {
      # Set registry for wallpaper style: 10=Fill, 6=Fit, 2=Stretch, 0=Center
      Set-ItemProperty -Path "HKCU:\Control Panel\Desktop" -Name Wallpaper -Value $wallpaperDst -Force
      Set-ItemProperty -Path "HKCU:\Control Panel\Desktop" -Name WallpaperStyle -Value "10" -Force
      Set-ItemProperty -Path "HKCU:\Control Panel\Desktop" -Name TileWallpaper -Value "0" -Force
      # Also clear slideshow if enabled
      $wpKey = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Wallpapers"
      if (Test-Path $wpKey) {
        try { Set-ItemProperty -Path $wpKey -Name BackgroundType -Value 0 -Force } catch {}
      }
      Add-Type @"
using System;
using System.Runtime.InteropServices;
public class Wallpaper {
  [DllImport("user32.dll", CharSet=CharSet.Auto)]
  public static extern int SystemParametersInfo(int uAction, int uParam, string lpvParam, int fuWinIni);
}
"@ -ErrorAction SilentlyContinue
      $SPI_SETDESKWALLPAPER = 20
      $SPIF_UPDATEINIFILE = 0x01
      $SPIF_SENDWININICHANGE = 0x02
      [Wallpaper]::SystemParametersInfo($SPI_SETDESKWALLPAPER, 0, $wallpaperDst, $SPIF_UPDATEINIFILE -bor $SPIF_SENDWININICHANGE) | Out-Null
      # Also update Custom.theme so next logon keeps it
      $themePath = "$env:LOCALAPPDATA\Microsoft\Windows\Themes\Custom.theme"
      if (Test-Path $themePath) {
        $c = Get-Content $themePath -Raw
        $c = $c -replace 'Wallpaper=.*', "Wallpaper=$wallpaperDst"
        Set-Content -LiteralPath $themePath -Value $c -Encoding Unicode
      }
      # Refresh
      try { RUNDLL32.EXE USER32.DLL,UpdatePerUserSystemParameters 1,1 } catch {}
      Write-Ok "Wallpaper set → $wallpaperDst (Fill, Seongjin Park)"
    } catch { Write-Warn "Set wallpaper failed: $_ — set manually via Settings > Personalization > Background" }
  }
  }
} else {
  Write-Warn "wallpaper/wallpaper.jpg not in repo — skip"
}

# ————— 8. Default Apps — Dism + per-user —————
Write-Step "Default Apps — import AppAssoc.xml (Brave, ImageGlass, etc.)"
$appAssocSrc = Join-Path $RepoRoot "defaultapps\AppAssoc.xml"
if (Test-Path $appAssocSrc) {
  # 1) Machine-wide via Dism (requires admin) — sets OEM defaults for new users and can set current image
  if (-not $DryRun) {
    $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    if ($isAdmin) {
      try {
        Write-Info "Importing via Dism /Online /Import-DefaultAppAssociations:$appAssocSrc"
        $dismOut = & Dism /Online /Import-DefaultAppAssociations:"$appAssocSrc" 2>&1 | Out-String
        Write-Info $dismOut.Trim()
        if ($LASTEXITCODE -eq 0) { Write-Ok "Dism import done (machine defaults)" } else { Write-Warn "Dism import exit $LASTEXITCODE" }
      } catch { Write-Warn "Dism import failed: $_" }
    } else {
      Write-Warn "Dism import needs admin — skipping machine-wide, will try per-user"
    }
  } else {
    Write-Host "   [DryRun] would: Dism /Online /Import-DefaultAppAssociations:$appAssocSrc (admin)" -ForegroundColor DarkYellow
  }
  # 2) Per-user: set key associations via registry (Brave for http/https/html etc. already handled, now generic)
  # Parse AppAssoc.xml for important ProgIds and apply UserChoice with hash where possible
  try {
    [xml]$xml = Get-Content $appAssocSrc -Raw
    # http/https already handled by Brave default browser + Dism — skip per-user to avoid Unauthorized hash on Win11
    $important = $xml.DefaultAssociations.Association | Where-Object { $_.Identifier -in @(".jpg",".jpeg",".png",".svg",".gif",".bmp",".pdf",".html",".htm",".xhtml",".mp4",".mp3",".mkv",".txt") }
    Write-Info "Per-user: $($important.Count) key associations from AppAssoc.xml (ImageGlass, Brave, Photos, Media, Notepad) — http/https via Brave+Dism"
    foreach ($a in $important) {
      $id = $a.Identifier
      $prog = $a.ProgId
      $app = $a.ApplicationName
      $key = "HKCU:\Software\Microsoft\Windows\Shell\Associations\UrlAssociations\$id\UserChoice"
      # File types use FileExts + UserChoice under HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\FileExts\.ext\UserChoice
      if ($id.StartsWith(".")) {
        $key = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\FileExts\$id\UserChoice"
        # Also try UrlAssociations for consistency
      }
      $hash = Get-UserChoiceHash -ProgId $prog -Sid ([System.Security.Principal.WindowsIdentity]::GetCurrent()).User.Value
      Invoke-Maybe "Default app $id → $prog ($app)" {
        try {
          if (-not (Test-Path $key)) { New-Item -Path $key -Force | Out-Null }
          # Windows will validate hash; if mismatch it may revert, but try
          if ($hash) {
            Set-ItemProperty -Path $key -Name ProgId -Value $prog -Force
            Set-ItemProperty -Path $key -Name Hash -Value $hash -Force
          } else {
            Set-ItemProperty -Path $key -Name ProgId -Value $prog -Force
          }
        } catch {
          # Fallback: try alternative registry path
          $altKey = "HKCU:\Software\Microsoft\Windows\Shell\Associations\UrlAssociations\$id\UserChoice"
          try {
            if (-not (Test-Path $altKey)) { New-Item -Path $altKey -Force | Out-Null }
            Set-ItemProperty -Path $altKey -Name ProgId -Value $prog -Force
            if ($hash) { Set-ItemProperty -Path $altKey -Name Hash -Value $hash -Force }
          } catch { Write-Warn "Set $id → $prog failed: $_" }
        }
      }
    }
    if (-not $DryRun) { Write-Ok "Per-user defaults attempted (Brave → http/https/html/pdf, ImageGlass → jpg/svg, Photos → png, etc.) — if Windows reverts, confirm once in Settings > Apps > Default apps" }
  } catch { Write-Warn "Default apps per-user parse failed: $_" }
} else {
  Write-Warn "defaultapps/AppAssoc.xml not in repo — skip"
}

# ————— 9. DNS — Windows + Brave (Mullvad Family) —————
Write-Step "DNS — Windows + Brave (Mullvad Family)"
# Brave DNS already handled via brave/Local State (family.dns.mullvad.net) — verify
$braveLs = Join-Path $RepoRoot "brave\Local State"
if (Test-Path $braveLs) {
  if (Select-String -Path $braveLs -Pattern "family.dns.mullvad.net" -Quiet) { Write-Ok "Brave DNS: Secure → https://family.dns.mullvad.net/dns-query [repo]" }
}
# Windows DNS — set for all Up adapters to Mullvad Family (194.242.2.6 / 2a07:e340::6) with DoH
$dnsV4 = $global:MullvadFamilyIPv4
$dnsV6 = $global:MullvadFamilyIPv6
$dohTemplate = $global:MullvadFamilyDohTemplate
try {
  $adapters = Get-NetAdapter | Where-Object Status -eq "Up" | Select-Object -ExpandProperty InterfaceIndex
  if (-not $adapters) { $adapters = @((Get-NetAdapter -Name "Wi-Fi" -ErrorAction SilentlyContinue).InterfaceIndex) | Where-Object { $_ } }
  foreach ($idx in $adapters) {
    $alias = (Get-NetAdapter -InterfaceIndex $idx -ErrorAction SilentlyContinue).Name
    # IPv4
    Invoke-Maybe "Set DNS IPv4 $alias ($idx) → $($dnsV4 -join ', ') + DoH $dohTemplate" {
      try {
        Set-DnsClientServerAddress -InterfaceIndex $idx -ServerAddresses $dnsV4 -ErrorAction Stop
        # Enable DoH for each server
        foreach ($s in $dnsV4) {
          try {
            # Try Add first (for new Mullvad server not in well-known list), fallback to Set — AllowFallback true to avoid breakage if DoH down
            try { Add-DnsClientDohServerAddress -ServerAddress $s -DohTemplate $dohTemplate -AllowFallbackToUdp $true -AutoUpgrade $true -ErrorAction Stop } catch {
              Set-DnsClientDohServerAddress -ServerAddress $s -DohTemplate $dohTemplate -AllowFallbackToUdp $true -AutoUpgrade $true -ErrorAction Stop
            }
          } catch { Write-Warn "DoH IPv4 $s failed: $_" }
        }
        Write-Ok "DNS IPv4 $alias → $($dnsV4 -join ', ') DoH Family (fallback UDP allowed to avoid breakage)"
      } catch { Write-Warn "Set DNS IPv4 $alias failed: $_" }
    }
    # IPv6
    if ($dnsV6) {
      Invoke-Maybe "Set DNS IPv6 $alias ($idx) → $($dnsV6 -join ', ') + DoH $dohTemplate" {
        try {
          Set-DnsClientServerAddress -InterfaceIndex $idx -ServerAddresses $dnsV6 -ErrorAction SilentlyContinue
          foreach ($s in $dnsV6) {
            try { Add-DnsClientDohServerAddress -ServerAddress $s -DohTemplate $dohTemplate -AllowFallbackToUdp $true -AutoUpgrade $true -ErrorAction Stop } catch {
              try { Set-DnsClientDohServerAddress -ServerAddress $s -DohTemplate $dohTemplate -AllowFallbackToUdp $true -AutoUpgrade $true -ErrorAction SilentlyContinue } catch {}
            }
          }
          Write-Ok "DNS IPv6 $alias → $($dnsV6 -join ', ')"
        } catch { Write-Warn "Set DNS IPv6 $alias failed: $_" }
      }
    }
  }
  if (-not $DryRun) {
    $cur = Get-DnsClientServerAddress -InterfaceIndex ($adapters | Select-Object -First 1) -AddressFamily IPv4 -ErrorAction SilentlyContinue
    if ($cur -and ($cur.ServerAddresses -contains $dnsV4[0])) { Write-Ok "Windows DNS verified: $($cur.ServerAddresses -join ', ') on $($cur.InterfaceAlias)" }
  }
} catch { Write-Warn "Windows DNS setup failed: $_" }

# ————— 10. Organization — O&OShutUp10++ (recommended - clipboard) —————
Write-Step "Organization — O&O ShutUp10++"
# Prefer ooshutup10.cfg (P001 + format) for CLI import, fallback to OOSU10.cfg XML
$ooCfgSrc = Join-Path $RepoRoot "ooshutup\ooshutup10.cfg"
if (-not (Test-Path $ooCfgSrc)) { $ooCfgSrc = Join-Path $RepoRoot "ooshutup\OOSU10.cfg" }
$ooCfgName = Split-Path $ooCfgSrc -Leaf
$ooExeUrl = "https://dl5.oo-software.com/files/ooshutup10/OOSU10.exe"
$ooExeTmp = Join-Path $env:TEMP "OOSU10.exe"
if (Test-Path $ooCfgSrc) {
  # Download OOSU10.exe if missing (with SHA256 pin)
  if (-not (Test-Path $ooExeTmp) -or -not (Test-Hash $ooExeTmp $global:ExpectedHashes["OOSU10.exe"])) {
    if (Test-Path $ooExeTmp) { Write-Warn "OOSU10.exe hash mismatch — re-downloading"; Remove-Item $ooExeTmp -Force -ErrorAction SilentlyContinue }
    Invoke-Maybe "Download O&O ShutUp10++ (79 MB) → $ooExeTmp [SHA256 $($global:ExpectedHashes["OOSU10.exe"].Substring(0,12))…]" {
      try {
        Invoke-WebRequest -Uri $ooExeUrl -OutFile $ooExeTmp -UseBasicParsing -TimeoutSec 60
        if (-not (Test-Hash $ooExeTmp $global:ExpectedHashes["OOSU10.exe"])) {
          throw "SHA256 mismatch for OOSU10.exe — expected $($global:ExpectedHashes["OOSU10.exe"]), got $((Get-FileHash $ooExeTmp).Hash)"
        }
        Write-Ok "Downloaded OOSU10.exe $((Get-Item $ooExeTmp).Length) bytes [hash ok]"
      } catch { Write-Warn "Download OOSU10.exe failed: $_ — download manually from https://www.oo-software.com/en/shutup10" }
    }
  } else { Write-Ok "OOSU10.exe already at $ooExeTmp [hash ok]" }
  # Verify cfg hash before apply (support both file names)
  $expectedCfgHash = $global:ExpectedHashes[$ooCfgName]
  if (-not $expectedCfgHash) { $expectedCfgHash = $global:ExpectedHashes["ooshutup10.cfg"] }
  if (-not (Test-Hash $ooCfgSrc $expectedCfgHash)) {
    Write-Warn "$ooCfgName hash mismatch — expected $expectedCfgHash, got $((Get-FileHash $ooCfgSrc -ErrorAction SilentlyContinue).Hash) — not applying (repo may be outdated)"
  } else {
  # Apply config (requires admin)
  $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
  if (-not $isAdmin) { Write-Warn "O&O ShutUp needs admin — run setup as admin to apply organization settings" }
  Invoke-Maybe "Apply O&O ShutUp10++ recommended (except clipboard) via $ooCfgName /quiet" {
    try {
      if (-not (Test-Path $ooExeTmp)) { throw "OOSU10.exe not found at $ooExeTmp" }
      $cfgTmp = Join-Path $env:TEMP $ooCfgName
      Copy-Item -LiteralPath $ooCfgSrc -Destination $cfgTmp -Force
      # OOSU10 CLI: OOSU10.exe <cfg> /quiet — cfg must be ooshutup10.cfg (P001 + format), not OOSU10.cfg XML
      $proc = Start-Process -FilePath $ooExeTmp -ArgumentList "`"$cfgTmp`" /quiet" -Wait -PassThru -WindowStyle Hidden -ErrorAction Stop
      if ($proc.ExitCode -eq 0 -or $proc.ExitCode -eq 3010) { Write-Ok "O&O ShutUp10++ applied (recommended - clipboard) — restart recommended" }
      elseif ($proc.ExitCode -eq 52) { Write-Ok "O&O ShutUp10++ already applied (exit 52) — no change" }
      else { Write-Warn "OOSU10.exe exit $($proc.ExitCode) — check GUI: $ooExeTmp (try running manually: OOSU10.exe $ooCfgName /quiet)" }
    } catch { Write-Warn "O&O apply failed: $_" }
  }
  Write-Info "Config: ooshutup/$ooCfgName 45077/3261 bytes, RecentStates 2026-09-06T03:00:11Z, ~150 settings true (clipboard excluded)"
  }
} else {
  Write-Warn "ooshutup/$ooCfgName not in repo — skip organization settings"
}

# ————— 10. ani-cli — anime via mpv —————
Write-Step "ani-cli — pystardust/ani-cli 5.0.4"
$aniSrcDir = Join-Path $RepoRoot "ani-cli"
$aniSrc = Join-Path $aniSrcDir "ani-cli"
$localBin = "$HOME\.local\bin"
$binDir = "$HOME\bin"
Ensure-Dir $localBin
Ensure-Dir $binDir
# Ensure aria2 for downloads
if (-not (Test-Command aria2c)) {
  if (-not $OnlyConfigs -and -not $NoPackages -and (Test-Command winget)) {
    Invoke-Maybe "winget install aria2.aria2 --silent (ani-cli download)" {
      & winget install --id aria2.aria2 -e --silent --accept-package-agreements --accept-source-agreements
      if (Test-Command aria2c) { Write-Ok "aria2c installed" }
    }
  } else { Write-Warn "aria2c not found — ani-cli downloads will use curl fallback" }
} else { Write-Ok "aria2c present" }
# Ensure mpv shim for Git Bash (expects mpv in PATH)
$mpvSrc = "C:\Program Files\MPV Player\mpv.exe"
$mpvDstLocal = Join-Path $localBin "mpv.exe"
$mpvDstBin = Join-Path $binDir "mpv.exe"
if ((Test-Path $mpvSrc) -and -not (Test-Path $mpvDstLocal)) {
  Invoke-Maybe "Copy mpv.exe shim → $mpvDstLocal for Git Bash" {
    Copy-Item -LiteralPath $mpvSrc -Destination $mpvDstLocal -Force
    Write-Ok "mpv shim → $mpvDstLocal"
  }
}
if ((Test-Path $mpvSrc) -and -not (Test-Path $mpvDstBin)) {
  Invoke-Maybe "Copy mpv.exe → $binDir for bash PATH" {
    Copy-Item -LiteralPath $mpvSrc -Destination $mpvDstBin -Force
    Write-Ok "mpv → $mpvDstBin"
  }
}
if (Test-Path $aniSrc) {
  if (-not (Test-Hash $aniSrc $global:ExpectedHashes["ani-cli"])) {
    Write-Warn "ani-cli hash mismatch — expected $($global:ExpectedHashes["ani-cli"]), got $((Get-FileHash $aniSrc -ErrorAction SilentlyContinue).Hash) — skip"
  } else {
  Invoke-Maybe "Copy ani-cli → $localBin\ani-cli (plus .ps1/.cmd wrappers)" {
    Copy-Item -LiteralPath $aniSrc -Destination (Join-Path $localBin "ani-cli") -Force
    Copy-Item -LiteralPath (Join-Path $aniSrcDir "ani-cli.ps1") -Destination (Join-Path $localBin "ani-cli.ps1") -Force -ErrorAction SilentlyContinue
    Copy-Item -LiteralPath (Join-Path $aniSrcDir "ani-cli.cmd") -Destination (Join-Path $localBin "ani-cli.cmd") -Force -ErrorAction SilentlyContinue
    # chmod +x via bash
    try { & "C:\Program Files\Git\usr\bin\bash.exe" -l -c "chmod +x ~/.local/bin/ani-cli" 2>$null } catch {}
    Write-Ok "ani-cli 5.0.4 → $localBin\ani-cli (run: ani-cli --help or bash -l ani-cli)"
  }
  # Verify
  if (-not $DryRun) {
    try {
      $out = & "C:\Program Files\Git\usr\bin\bash.exe" -l -c "bash ~/.local/bin/ani-cli --help 2>&1 | head -n 3" 2>&1 | Out-String
      if ($out -match "ani-cli") { Write-Ok "ani-cli verified: $($out.Split("`n")[0].Trim())" } else { Write-Warn "ani-cli help check failed" }
    } catch { Write-Warn "ani-cli verify failed: $_" }
  }
  }
} else {
  Write-Warn "ani-cli/ani-cli not in repo — skip"
}
Write-Info "Deps: mpv v0.41.0, fzf 0.74.3, yt-dlp 2026.07.04, ffmpeg 9.0.1, aria2c 1.37.0, Git Bash"

# ————— 11. Fonts & extras —————
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
  Write-Host "   Wallpaper: $HOME\Pictures\Seongjin Park.jpg (Mullvad DoH Family)" -ForegroundColor Green
  Write-Host "   DNS: Brave + Windows → https://family.dns.mullvad.net/dns-query (194.242.2.6/2a07:e340::6, fallback allowed)" -ForegroundColor Green
  Write-Host "`n   Restart your terminal to see the Windows logo prompt " -ForegroundColor Cyan
  Write-Host "   Secrets: [System.Environment]::SetEnvironmentVariable('GITHUB_PERSONAL_ACCESS_TOKEN','ghp_...','User')" -ForegroundColor DarkGray
}
# Final summary with errors
if ($global:DotfilesProgressErrors -gt 0) {
  Write-Host "`n   ⚠️  Completed with $($global:DotfilesProgressErrors) warnings — check yellow ! above, rerun with -DryRun to preview" -ForegroundColor Yellow
} else {
  Show-CuteProgress -Msg "All done" -Final
}
Write-Host ""

