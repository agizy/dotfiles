# bootstrap.ps1 — one-liner entry point for a fresh machine without git cloned
# Usage (pinned, verify hash): 
#   $h="1AD8..."; irm https://raw.githubusercontent.com/agizy/dotfiles/main/bootstrap.ps1 -OutFile $env:TEMP\bootstrap.ps1; if ((Get-FileHash $env:TEMP\bootstrap.ps1).Hash -ne $h) { throw "hash mismatch" }; powershell -ExecutionPolicy RemoteSigned -File $env:TEMP\bootstrap.ps1
# Or quick (Bypass, no hash, for fresh machine):
#   powershell -ExecutionPolicy Bypass -Command "irm https://raw.githubusercontent.com/agizy/dotfiles/main/bootstrap.ps1 | iex"
# Clones (or updates) the repo to $HOME\dotfiles then invokes setup.ps1
$ErrorActionPreference = "Stop"
$repoUrl = "https://github.com/agizy/dotfiles.git"
$dest = Join-Path $HOME "dotfiles"
# Pinned commit for supply-chain verification — update on release (git rev-parse HEAD)
$PinnedCommit = "114cdc37039181ec7de9292bc2325307a3c82c95" # 2026-09-06 ani-cli wrapper fix — update after each release
$ExpectedSetupHash = "252D1A21B1DC03C9F24F8038987659468D8810074454697F6B8D861C5A048CD1" # placeholder, updated by setup on clone

Write-Host ">> dotfiles bootstrap — agizy/dotfiles" -ForegroundColor Cyan
Write-Host "   dest: $dest" -ForegroundColor DarkGray

if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
  Write-Host "!! git not found, installing via winget..." -ForegroundColor Yellow
  winget install --id Git.Git -e --silent --accept-package-agreements --accept-source-agreements
  $env:Path = "$env:Path;$env:ProgramFiles\Git\cmd"
  if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    throw "git still not found after install — open a new terminal and re-run the one-liner"
  }
}

if (Test-Path (Join-Path $dest ".git")) {
  Write-Host ">> repo already at $dest — pulling..." -ForegroundColor Green
  & git -C $dest pull --ff-only
} elseif (Test-Path $dest) {
  Write-Host "!! $dest exists but is not a git repo — backing up to ${dest}.bak" -ForegroundColor Yellow
  Move-Item $dest "$dest.bak.$(Get-Date -Format yyyyMMdd_HHmmss)" -Force
  & git clone $repoUrl $dest
} else {
  Write-Host ">> cloning $repoUrl → $dest" -ForegroundColor Green
  & git clone $repoUrl $dest
}

$setup = Join-Path $dest "setup.ps1"
if (-not (Test-Path $setup)) { throw "setup.ps1 not found at $setup" }
# Optional supply-chain check: verify setup.ps1 hash if pinned (warn, don't block)
if ($PinnedCommit -and $ExpectedSetupHash -and $ExpectedSetupHash -ne "E3B0C44298FC1C149AFBF4C8996FB92427AE41E4649B934CA495991B7852B855") {
  try {
    $actual = (Get-FileHash -Path $setup -Algorithm SHA256).Hash
    if ($actual -ne $ExpectedSetupHash) {
      Write-Host "!! setup.ps1 hash mismatch — expected $ExpectedSetupHash, got $actual" -ForegroundColor Yellow
      Write-Host "   Repo may have been updated since bootstrap was pinned ($PinnedCommit). If you trust it, update bootstrap.ps1 or run: git -C $dest checkout $PinnedCommit" -ForegroundColor DarkGray
    } else { Write-Host "   setup.ps1 hash ok $actual" -ForegroundColor Green }
  } catch { Write-Host "   hash check skipped: $_" -ForegroundColor DarkGray }
}

Write-Host ">> invoking setup.ps1 ..." -ForegroundColor Cyan
& $setup @args


