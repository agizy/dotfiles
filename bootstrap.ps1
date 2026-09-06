# bootstrap.ps1 — one-liner entry point for a fresh machine without git cloned
# Usage: powershell -ExecutionPolicy Bypass -Command "irm https://raw.githubusercontent.com/agizy/dotfiles/main/bootstrap.ps1 | iex"
# Clones (or updates) the repo to $HOME\dotfiles then invokes setup.ps1
$ErrorActionPreference = "Stop"
$repoUrl = "https://github.com/agizy/dotfiles.git"
$dest = Join-Path $HOME "dotfiles"

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

Write-Host ">> invoking setup.ps1 ..." -ForegroundColor Cyan
& $setup @args
