# Proposed PowerShell profile - translated from C:\Users\Panaino\Downloads\.zshrc
# Backup original: Copy-Item $PROFILE "$PROFILE.bak.$(Get-Date -Format yyyyMMdd_HHmmss)"
# Apply: Copy-Item "C:\Users\Panaino\AppData\Local\Temp\opencode\proposed_profile.ps1" $PROFILE -Force

# â”€â”€ Existing Windows config (preserved) â”€â”€
$env:Path += ";$env:LOCALAPPDATA\Microsoft\WinGet\Links"
$ff = "$env:LOCALAPPDATA\Microsoft\WinGet\Links\fastfetch.exe"
if (Test-Path $ff) {
  $isInteractive = [Environment]::UserInteractive -and $Host.Name -eq "ConsoleHost"
  if ($isInteractive) { & $ff }
}

# â”€â”€ Translated from .zshrc: User's existing config â”€â”€
# NOTE: macOS paths (/opt/homebrew, /Applications, $HOME/Android/Sdk, /Users/shalashaska) have no Windows equivalent and are commented.
# Uncomment/adapt only if you installed those tools via WSL/scoop/choco.

# from .zshrc:9 - PATH="/opt/homebrew/bin:$HOME/.local/bin:$PATH"
if (Test-Path "$HOME\.local\bin") { $env:Path = "$HOME\.local\bin;$env:Path" }
# from .zshrc:16 - Android
# $env:ANDROID_HOME = "$HOME\Android\Sdk"
# $env:ANDROID_SDK_ROOT = "$HOME\Android\Sdk"
# $env:Path += ";$env:ANDROID_HOME\cmdline-tools\latest\bin;$env:ANDROID_HOME\platform-tools;$HOME\.rbenv\shims"
# from .zshrc:17 - CHROME_EXECUTABLE="/Applications/Brave Browser.app/..."
# $env:CHROME_EXECUTABLE = "C:\Program Files\BraveSoftware\Brave-Browser\Application\brave.exe"
# from .zshrc:39-40 - Windsurf / openjdk@17 (macOS brew) - ignore on Windows unless installed
# $env:Path = "C:\path\to\windsurf\bin;$env:Path"

# â”€â”€ Secrets / API Keys (from .zshrc:12-13 and mcp.json:52) - SECURE MODE â”€â”€
# Keys are NOT stored in this file. They are in Windows User Environment (HKCU:\Environment)
# Set/updated via: [System.Environment]::SetEnvironmentVariable("GITHUB_PERSONAL_ACCESS_TOKEN","...","User")
# They auto-load into $env: at logon. Verify: Get-ChildItem Env:GITHUB*, Env:BRAVE*
# To rotate: generate new token, run SetEnvironmentVariable again, then restart terminal. Old plaintext in Downloads\.zshrc should be deleted.
# NOTE: .zshrc had ghp_UU6C... and mcp.json had ghp_2ow0... â€” unified to ghp_UU6C... (mcp.json backup not persisted).
if (-not $env:GITHUB_PERSONAL_ACCESS_TOKEN) { $env:GITHUB_PERSONAL_ACCESS_TOKEN = [System.Environment]::GetEnvironmentVariable("GITHUB_PERSONAL_ACCESS_TOKEN","User") }
if (-not $env:BRAVE_API_KEY) { $env:BRAVE_API_KEY = [System.Environment]::GetEnvironmentVariable("BRAVE_API_KEY","User") }
if (-not $env:GITHUB_PERSONAL_ACCESS_TOKEN) { Write-Warning "GITHUB_PERSONAL_ACCESS_TOKEN not set. Set it: [System.Environment]::SetEnvironmentVariable('GITHUB_PERSONAL_ACCESS_TOKEN','ghp_...','User')" }
if (-not $env:BRAVE_API_KEY) { Write-Warning "BRAVE_API_KEY not set. Set it: [System.Environment]::SetEnvironmentVariable('BRAVE_API_KEY','BSA...','User')" }

# â”€â”€ Environment (from .zshrc:46-49) â”€â”€
if ($env:EDITOR) { $env:VISUAL = $env:EDITOR }
# $env:BROWSER = "C:\Program Files\Zen Browser\zen.exe"  # .zshrc:47 was /Applications/Zen.app - adapt path if installed
$env:BAT_THEME = "base16"
$env:HISTORY_IGNORE = "(ls|cd|pwd|exit|history|cd -|cd ..)"

# â”€â”€ Aliases / Functions (from .zshrc:11,18-36,167-175) â”€â”€
function push { git push origin main }                    # .zshrc:11 alias push="git push origin main"
function ezrc { notepad $PROFILE }                        # .zshrc:18 alias ezrc="nano ~/.zshrc" -> Windows: edit profile
# function ezrc { code $PROFILE } # alternative if you use VS Code

# macOS sleep toggles have no direct equivalent - mapping to Windows powercfg / sleep
function OTG  { powercfg /change standby-timeout-ac 0; powercfg /change standby-timeout-dc 0; Write-Host "Sleep disabled (AC+DC)" -ForegroundColor Yellow } # .zshrc:21
function EOTG { powercfg /change standby-timeout-ac 15; powercfg /change standby-timeout-dc 10; Write-Host "Sleep re-enabled" -ForegroundColor Green } # .zshrc:24

# Smart suffix aliases (.zshrc:27-36 alias -s) have no PowerShell equivalent - use explicit functions instead

# gh0stzk style tool aliases (.zshrc:167-173) - with graceful fallback if tool not installed
if (Get-Command bat -ErrorAction SilentlyContinue) {
  function cat { bat --theme=base16 @args }  # use `batcat` on some installs
  Set-Alias -Name batcat -Value bat -ErrorAction SilentlyContinue
} # else keep default cat

if (Get-Command eza -ErrorAction SilentlyContinue) {
  function ls { eza --icons=always --color=always -a @args }
  function ll { eza --icons=always --color=always -la @args }
} elseif (Get-Command exa -ErrorAction SilentlyContinue) {
  function ls { exa --icons --color=always -a @args }
  function ll { exa --icons --color=always -la @args }
}

if (Get-Command rg -ErrorAction SilentlyContinue) { Set-Alias -Name grep -Value rg -Scope Global -Force -ErrorAction SilentlyContinue }
if (Get-Command fd -ErrorAction SilentlyContinue) { Set-Alias -Name find -Value fd -Scope Global -Force -ErrorAction SilentlyContinue }
# dust = du replacement, doggo = dig replacement, pipes.sh
if (Get-Command dust -ErrorAction SilentlyContinue) { function du { dust @args } }
if (Get-Command doggo -ErrorAction SilentlyContinue) { function dig { doggo @args } }
if (Get-Command pipes.sh -ErrorAction SilentlyContinue) { function pipes { pipes.sh @args } }

# â”€â”€ PSReadLine (replaces zsh-autosuggestions, syntax-highlighting, history-substring-search, completion) â”€â”€
# Install/update: Install-Module PSReadLine -Force -SkipPublisherCheck
if (Get-Module -ListAvailable -Name PSReadLine) {
  Import-Module PSReadLine -ErrorAction SilentlyContinue
  Set-PSReadLineOption -HistoryNoDuplicates:$true -HistorySearchCursorMovesToEnd:$true
  Set-PSReadLineOption -BellStyle None
  # PSReadLine >=2.1 has PredictionSource/PredictionViewStyle (PS 7+), 5.1 ships 2.0 - guard
  try {
    if (Get-Command Set-PSReadLineOption | ForEach-Object { $_.Parameters.ContainsKey("PredictionSource") }) {
      Set-PSReadLineOption -PredictionSource HistoryAndPlugin -PredictionViewStyle ListView
    }
  } catch {}
  try { Set-PSReadLineOption -Colors @{ Command = '#89b4fa'; Parameter = '#a6e3a1'; String = '#f9e2af' } } catch {}
  # Add InlinePrediction color only if supported
  try {
    $c = Get-PSReadLineOption
    if ($c -and $c.PSObject.Properties.Match("Colors").Count -gt 0) {}
    Set-PSReadLineOption -Colors @{ InlinePrediction = '#6c7086' } -ErrorAction SilentlyContinue
  } catch {}
  Set-PSReadLineKeyHandler -Key UpArrow -Function HistorySearchBackward
  Set-PSReadLineKeyHandler -Key DownArrow -Function HistorySearchForward
  Set-PSReadLineKeyHandler -Key Tab -Function MenuComplete
  # History file is at (Get-PSReadLineOption).HistorySavePath ; default ~\AppData\Roaming\Microsoft\Windows\PowerShell\PSReadLine\ConsoleHost_history.txt
  # To mimic HISTSIZE=5000 .zshrc:103
  Set-PSReadLineOption -MaximumHistoryCount 5000
}

# â”€â”€ Completion (replaces compinit / fzf-tab) â”€â”€
# For fzf-tab equivalent, install PSFzf: Install-Module PSFzf -Scope CurrentUser -Force
if (Get-Module -ListAvailable -Name PSFzf) {
  Import-Module PSFzf -ErrorAction SilentlyContinue
  Set-PsFzfOption -PSReadlineChordProvider 'Ctrl+t' -PSReadlineChordReverseHistory 'Ctrl+r'
  # Enable Tab completion with fzf preview like zstyle ':fzf-tab:*' in .zshrc:81-90
}

# â”€â”€ Prompt (replaces .zshrc:122-138 PROMPT) â”€â”€
# For full gh0stzk aesthetic, recommended: oh-my-posh or starship. Minimal fallback below mimics dir_icon + vcs_info + exit code.
function prompt {
  $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
  $lastOk = $?
  # dir_icon logic .zshrc:130-136
  $dirIcon = if ($PWD.Path -eq $HOME) { [char]0xf015 } else { [char]0xe5fe } # P_ICON_HOME / P_ICON_DIR
  $windows = [char]0xf17a  # Windows logo (replaced Apple 0xf179)
  # git branch (vcs_info .zshrc:69-80)
  $branch = ""
  try { $branch = (git branch --show-current 2>$null) } catch {}
  $gitInfo = if ($branch) { " $([char]0xe725) $branch" } else { "" }
  $statusIcon = if ($lastOk) { "$([char]0xf054)$([char]0xf054)." } else { "$([char]0xf054)$([char]0xf054)" }
  $color = if ($lastOk) { "Green" } else { "Red" }
  # Build prompt: similar to PS1="%B%F{blue}...%n @ dir git status"
  Write-Host "$windows " -NoNewline -ForegroundColor Blue
  Write-Host "$env:USERNAME " -NoNewline -ForegroundColor Magenta
  Write-Host "$dirIcon " -NoNewline -ForegroundColor Cyan
  Write-Host "$($PWD.Path.Replace($HOME,'~'))" -NoNewline -ForegroundColor Red
  if ($gitInfo) { Write-Host $gitInfo -NoNewline -ForegroundColor Yellow }
  Write-Host " $statusIcon" -ForegroundColor $color -NoNewline
  return " "
}
# To use oh-my-posh instead (closer to gh0stzk), install and uncomment:
# winget install JanDeDobbeleer.OhMyPosh -s winget
# oh-my-posh init pwsh | Invoke-Expression

# â”€â”€ zoxide (from .zshrc:175) â”€â”€
# Already at top - re-init to ensure after PATH changes
try { Invoke-Expression (& { (zoxide init powershell | Out-String) }) } catch {}
Set-Alias -Name cdz -Value __zoxide_z -ErrorAction SilentlyContinue

# â”€â”€ rbenv (from .zshrc:43 eval "$(rbenv init - zsh)") - Windows equivalent is rbenv-win or just ruby installer â”€â”€
# if (Get-Command rbenv -ErrorAction SilentlyContinue) { Invoke-Expression (& { rbenv init - --no-rehash | Out-String }) }

# â”€â”€ Kaku integration (from .zshrc:180-181) â”€â”€
if ($env:Path -notlike "*$HOME\.config\kaku\zsh\bin*") { if (Test-Path "$HOME\.config\kaku\zsh\bin") { $env:Path = "$HOME\.config\kaku\zsh\bin;$env:Path" } }
if (Test-Path "$HOME\.config\kaku\zsh\kaku.zsh") { Write-Warning "Kaku zsh integration found but is zsh-only; PowerShell equivalent not loaded." }

Write-Host "Profile loaded (gh0stzk-inspired, translated from .zshrc)" -ForegroundColor DarkGray
