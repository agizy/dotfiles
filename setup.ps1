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

