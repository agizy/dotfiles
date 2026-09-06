#!/usr/bin/env pwsh
# ani-cli.ps1 — PowerShell wrapper for ani-cli (pystardust/ani-cli) on Windows via Git Bash
# Ensures mpv, ffmpeg, yt-dlp, fzf, curl are on PATH for Git Bash
$ErrorActionPreference = "Stop"
$bash = "C:\Program Files\Git\usr\bin\bash.exe"
if (-not (Test-Path $bash)) { $bash = "C:\Program Files\Git\bin\bash.exe" }
if (-not (Test-Path $bash)) { throw "Git Bash not found at $bash — install Git for Windows" }

# Ensure dependencies on PATH for bash
$extraPaths = @(
  "C:\Program Files\MPV Player",
  "$env:LOCALAPPDATA\Microsoft\WinGet\Links",
  "$env:LOCALAPPDATA\Microsoft\WinGet\Packages\Gyan.FFmpeg_Microsoft.Winget.Source_8wekyb3d8bbwe\ffmpeg-9.0.1-full_build\bin",
  "$env:LOCALAPPDATA\Microsoft\WinGet\Packages\yt-dlp.yt-dlp_Microsoft.Winget.Source_8wekyb3d8bbwe",
  "C:\ProgramData\chocolatey\bin"
)
$env:Path = ($extraPaths -join ";") + ";" + $env:Path
# Translate args for bash
# args handled via $bashArgs directly
$aniCli = Join-Path $PSScriptRoot "ani-cli"
# If run from installed location (~\.local\bin), fallback to repo path
if (-not (Test-Path $aniCli)) { $aniCli = "$HOME\.local\bin\ani-cli" }
if (-not (Test-Path $aniCli)) { $aniCli = "C:\Users\Panaino\dotfiles\ani-cli\ani-cli" }

# Use bash -l to get proper PATH and run ani-cli
$bashArgs = @("-l", $aniCli) + $args
& $bash @bashArgs
exit $LASTEXITCODE

