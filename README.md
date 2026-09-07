# dotfiles - agizy's Windows setup

Exact replica of my current daily driver: **Vivobook ASUS X7600PC (11th Gen i7-11370H, RTX 3050, 16GB) - Windows 11 10.0.26200**.
One command to go from a fresh Windows install to the same shells, prompts, fonts, tools, Raycast, Syncthing and configs I use every day.

> Public, no secrets inside. API keys (`GITHUB_PERSONAL_ACCESS_TOKEN`, `BRAVE_API_KEY`) are read from `HKCU:\Environment` at runtime - never committed.

---

## One-line setup on a brand-new machine

**No Git required - just run this (like winutil):**
```powershell
irm https://raw.githubusercontent.com/agizy/dotfiles/main/bootstrap.ps1 | iex
```
`bootstrap.ps1` clones the repo to `$HOME\dotfiles` and then hands off to `setup.ps1`.

**With Git (alternative):**
```powershell
git clone https://github.com/agizy/dotfiles.git $HOME\dotfiles
Set-ExecutionPolicy Bypass -Scope Process -Force
& $HOME\dotfiles\setup.ps1
```

### What the one-liner does

| Area | Action | Source in repo |
|---|---|---|
| **Winget** | `winget import -i winget/packages.json` - 34 version-pinned packages (Git, Brave 152.1.94.121, Zen, Node 24, Deno, Fastfetch 2.68.1, zoxide 0.10.0, Syncthing 2.1.3, VLC/MPV yt-dlp FFmpeg, JetBrainsMono Nerd Font, etc.) | `winget/packages.json` |
| **Brave debloat** | winutil copy - 12 policies `HKLM:\SOFTWARE\Policies\BraveSoftware\Brave` (Rewards/Wallet/VPN/AI/News/Talk/Tor/P3A disabled, Stats ping off) - applied automatically after Brave install | `setup.ps1` + `brave/README.md` |
| **Brave exact config** | DNS `secure` -> `https://family.dns.mullvad.net/dns-query`, 13 filterlists, languages `fr-FR,fr,en-US,en`, 78 accelerators, shields - `Local State` + `Preferences` + `ExtensionInstallForcelist` | `brave/Local State`, `brave/Preferences`, `brave/extensions.json` |
| **Brave default** | Sets `BraveHTML` for `http/https/.html/.htm/.xhtml` via `brave.exe --make-default-browser` + UserChoice hash, fallback `ms-settings:defaultapps` | `setup.ps1:Set-BraveAsDefault` |
| **Chocolatey** | `choco install` from `choco/packages.config` - fzf, ripgrep, opencode, unzip | `choco/packages.config` |
| **PowerShell** | Deploys profile to **both** `Documents\WindowsPowerShell` (5.1) and `Documents\PowerShell` (7+) | `powershell/` |
| **PS modules** | `PSReadLine`, `PSFzf` | `setup.ps1` |
| **Fastfetch** | `~\.config\fastfetch\config.jsonc` + `gh0stzk-logo.txt` | `fastfetch/` |
| **Windows Terminal** | `settings.json` -> `%LOCALAPPDATA%\Packages\Microsoft.WindowsTerminal\LocalState` (backs up original) | `terminal/settings.json` |
| **Raycast** | Detects `Raycast 2.2.0 (MSIX)`, lists 7 Store extensions to re-install (Spotify, Translate, Coffee, YouTube, etc.) | `raycast/extensions.json` |
| **Syncthing** | `winget install Syncthing.Syncthing`, `syncthing generate`, scheduled task `Syncthing` at logon + `Startup\Syncthing.lnk`, firewall rule | `syncthing/` |
| **Wallpaper** | `Seongjin Park.jpg` `5281757` bytes `Fill` via `SystemParametersInfo` -> `~/Pictures/Seongjin Park.jpg` (from `Pictures/Seongjin Park.jpg`, Asus OLED Shifter source) | `wallpaper/wallpaper.jpg` |
| **Default Apps** | `Dism /Online /Import-DefaultAppAssociations` + per-user `UserChoice` - Brave `http/https/.html/.htm/.xhtml/.pdf`, ImageGlass `jpg/svg`, Photos `png/bmp/gif`, Media `mp4/mkv/mp3`, Notepad `txt` | `defaultapps/AppAssoc.xml` |
| **DNS** | Windows + Brave `Mullvad Family` `194.242.2.6` / `2a07:e340::6` `https://family.dns.mullvad.net/dns-query` `AllowFallback true` | `setup.ps1` + `brave/Local State` |
| **Organization** | `O&OShutUp10++` recommended `2026-09-06T03:00:11Z` **except clipboard** - `OOSU10.cfg` 45077 bytes `~150` settings `true` (`A001-003`, `C008-015`, `E001-256` etc.) -> `OOSU10.exe /quiet` (79 MB) | `ooshutup/OOSU10.cfg` |
| **ani-cli** | `pystardust/ani-cli 5.0.4` `27689` bytes `#!/bin/sh` + `mpv v0.41.0` `fzf 0.74.3` `yt-dlp 2026.07.04` `ffmpeg 9.0.1` `aria2 1.37.0` + `Git Bash` - `~\.local\bin\ani-cli` | `ani-cli/ani-cli` + `.ps1/.cmd` |
| **Progress** | Cute adaptive `60% [####....] 6/18` - `Get-TerminalWidth` each step, `#` filled `-` empty `*` at 100% `x` on error, `UTF8` `chcp 65001` | `setup.ps1:Show-CuteProgress` |
| **Font & polish** | JetBrainsMono Nerd Font 3.3.0, Windows logo prompt (`0xf17a`, not Apple `0xf179`) | `profile` |

---

## Layout

```
dotfiles/
|-- setup.ps1                 # <- consolidated installer (idempotent, supports -DryRun)
|-- bootstrap.ps1             # <- irm one-liner entry point
|-- winget/packages.json      # winget export --include-versions (34 pkgs, Teams/Outlook removed)
|-- choco/packages.config     # choco list snapshot
|-- powershell/
|   |-- Microsoft.PowerShell_profile.ps1        # Windows PowerShell 5.1 (gh0stzk, Windows logo)
|   `-- Microsoft.PowerShell_profile.ps1.pwsh7  # PowerShell 7+ (fastfetch+zoxide minimal)
|-- fastfetch/
|   |-- config.jsonc
|   |-- config-no-nerd.jsonc
|   `-- gh0stzk-logo.txt
|-- terminal/settings.json    # Windows Terminal, One Half Dark + JetBrainsMono NF
|-- brave/
|   |-- Local State            # dns_over_https Mullvad family, 13 filterlists (sanitized encrypted_key)
|   |-- Preferences            # languages fr-FR, 78 accelerators, shields
|   |-- extensions.json        # Tampermonkey 5.5.0, Malwarebytes 3.3.4, SponsorBlock 6.1.6
|   `-- README.md              # debloat + default browser docs
|-- wallpaper/
|   `-- wallpaper.jpg          # Seongjin Park 5281757 bytes Fill (exact)
|-- defaultapps/
|   `-- AppAssoc.xml           # Dism export 12944 bytes (Brave, ImageGlass, Photos, Media, Notepad)
|-- ooshutup/
|   |-- OOSU10.cfg             # recommended - clipboard 45077 bytes 2026-09-06T03:00:11Z
|   |-- ooshutup10.cfg         # P001 + format 3261 bytes
|   `-- README.md              # O&O docs
|-- ani-cli/
|   |-- ani-cli                # pystardust 5.0.4 27689 bytes sh
|   |-- ani-cli.ps1            # PowerShell wrapper (Git Bash -l)
|   |-- ani-cli.cmd            # CMD wrapper
|   `-- README.md
|-- raycast/
|   |-- extensions.json        # 7 installed Store extensions
|   `-- extensions.txt
`-- syncthing/                # autostart + config docs
```

---

## Usage

```powershell
# dry run - see what would happen
.\setup.ps1 -DryRun

# only configs, skip package installs
.\setup.ps1 -OnlyConfigs

# force overwrite without backup
.\setup.ps1 -Force

# interactive menu (no args) - prompt Install vs Undo
.\setup.ps1
# -> 1. Install / Setup  2. Undo / Restore  3. Exit
# -> Undo submenu: All, Brave, Dev Tools (Terminal/PowerShell/Fastfetch), 
#   Windows (wallpaper/default apps/DNS with/without O&O), O&O only, 
#   Wallpaper/DefaultApps/DNS/Syncthing/ani-cli

# non-interactive undo - no prompt
.\setup.ps1 -Mode Undo -UndoCategory All -DryRun        # preview
.\setup.ps1 -Mode Undo -UndoCategory Brave -Force       # no confirm
.\setup.ps1 -Mode Undo -UndoCategory DevTools
.\setup.ps1 -Mode Undo -UndoCategory WindowsWithOO      # wallpaper+defaultapps+DNS+O&O
.\setup.ps1 -Mode Undo -UndoCategory WindowsWithoutOO   # wallpaper+defaultapps+DNS
.\setup.ps1 -Mode Undo -UndoCategory OO                 # O&O only
.\setup.ps1 -Mode Install -DryRun                       # explicit install
```

Options: `-DryRun`, `-Force`, `-OnlyConfigs`, `-NoPackages`, `-NoSyncthing`, `-Mode {Install|Undo}`, `-UndoCategory {All|Brave|DevTools|WindowsWithOO|WindowsWithoutOO|OO|Wallpaper|DefaultApps|DNS|Syncthing|AniCli}`, `-NonInteractive`

Re-run any time - idempotent. Backups are written as `*.bak.<yyyyMMdd_HHmmss>`. Undo restores `*.bak.*` where exists; registry (Brave debloat `HKLM\...\Brave`, O&O `~150` policies, DNS `194.242.2.6` DoH) is removed/reset, firewall `Private`->removed, task `Limited`->removed.

---

## Secrets

Profile reads at startup:

```powershell
[System.Environment]::GetEnvironmentVariable("GITHUB_PERSONAL_ACCESS_TOKEN","User")
[System.Environment]::GetEnvironmentVariable("BRAVE_API_KEY","User")
```

Set once on a new machine:

```powershell
[System.Environment]::SetEnvironmentVariable("GITHUB_PERSONAL_ACCESS_TOKEN","ghp_...","User")
[System.Environment]::SetEnvironmentVariable("BRAVE_API_KEY","BSA...","User")
# restart terminal - no plaintext in repo
```

---

## Current machine snapshot

* **Export date:** 2026-09-06
* **OS:** Windows 11 10.0.26200.9168
* **Terminal:** Windows Terminal 1.24.11911.0
* **Shell:** Windows PowerShell 5.1.26100.8875 (+ PowerShell profile also covers pwsh 7)
* **Prompt:** gh0stzk-inspired, `0xf17a $USER $DIR branch >>` - Windows logo `0xf17a`, PSReadLine, zoxide (`z`, `zi`), aliases `bat->cat`, `eza->ls/ll`, `rg->grep`, `fd->find`
* **Packages:** 34 winget (+ Brave 152.1.94.121 with debloat) + 7 choco (see `winget/packages.json`, `choco/packages.config`)
* **Brave:** debloated via winutil 12 policies, DNS Secure Mullvad Family `https://family.dns.mullvad.net/dns-query`, 13 filterlists, languages `fr-FR,fr,en-US,en`, 78 accelerators, 3 extensions (Tampermonkey, Malwarebytes, SponsorBlock), default browser `BraveHTML`
* **Wallpaper:** `Seongjin Park.jpg` `5281757` bytes `SHA256 07386AE035C39A786EDBBF30FD2C775B956FFDB25B8B18BBE961C2480619480F` - `Fill` - Asus OLED Shifter source `C:\Users\Panaino\Pictures\Seongjin Park.jpg`
* **Default Apps:** `Brave` -> `http/https/.html/.htm/.xhtml/.mhtml/.shtml/.pdf`, `ImageGlass` -> `.jpg/.svg`, `Photos` -> `.png/.bmp/.gif/.jpeg`, `Lecteur multimedia` -> `.mp4/.mkv/.mp3/.avi/.mov`, `Bloc-notes` -> `.txt/.ini/.log`, `CompressedFolder` -> `.zip` (12944 bytes `AppAssoc.xml` via `Dism`)
* **DNS:** `194.242.2.6` / `2a07:e340::6` `https://family.dns.mullvad.net/dns-query` `AllowFallback true` + Brave `Secure`
* **Organization:** `O&OShutUp10++` `2026-09-06T03:00:11Z` recommended minus clipboard - `OOSU10.cfg` `45077` bytes, `RecentStates` `~150` true (`E001-256`, `P001-194` etc.), `OOSU10.exe` `79 MB` portable via `https://dl5.oo-software.com/files/ooshutup10/OOSU10.exe`
* **ani-cli:** `5.0.4` `mpv v0.41.0` `fzf 0.74.3` `yt-dlp 2026.07.04` `ffmpeg 9.0.1` `aria2 1.37.0` `Git Bash` - `~\.local\bin\ani-cli` + `~\bin\mpv.exe` shim
* **Progress:** `60% [####....] 6/18` cute adaptive - `Get-TerminalWidth` each `Step-Progress`, `#` filled `-` empty `*` at 100% `x` on error, `UTF8` `chcp 65001`, not verbose but shows `ok/!` per step

---

## Keeping it fresh

```powershell
# on your main machine after changing something:
winget export -o winget/packages.json --include-versions --accept-source-agreements
choco list --limit-output > choco/packages.config  # or copy back
Copy-Item $PROFILE powershell/Microsoft.PowerShell_profile.ps1 -Force
Copy-Item ~/.config/fastfetch/config.jsonc fastfetch/ -Force
Copy-Item $env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json terminal/ -Force
Copy-Item "$env:LOCALAPPDATA\BraveSoftware\Brave-Browser\User Data\Local State" brave/ -Force
Copy-Item "$env:LOCALAPPDATA\BraveSoftware\Brave-Browser\User Data\Default\Preferences" brave/ -Force
(Get-Content brave/"Local State" -Raw) -replace '"encrypted_key"\s*:\s*"[^"]+"','"encrypted_key":"REPLACE_WITH_MACHINE_KEY_DPAPI"' | Set-Content brave/"Local State" -NoNewline -Encoding UTF8
Copy-Item "$env:APPDATA\Microsoft\Windows\Themes\TranscodedWallpaper" -Destination wallpaper/wallpaper.jpg -Force # or $HOME\Pictures\Seongjin Park.jpg
Copy-Item "$env:USERPROFILE\Pictures\Seongjin Park.jpg" wallpaper/wallpaper.jpg -Force
Dism /Online /Export-DefaultAppAssociations:"$PWD\defaultapps\AppAssoc.xml"
Copy-Item "$env:LOCALAPPDATA\OO Software\OO ShutUp10\OOSU10.cfg" ooshutup/ -Force
# generate ooshutup10.cfg from OOSU10.cfg RecentStates if needed
git add -A; git commit -m "snapshot $(Get-Date -Format yyyy-MM-dd)"; git push
```

---

## License

MIT - see `LICENSE`.

## Credits

* **Git for Windows** — [Git for Windows](https://gitforwindows.org) ([GitHub](https://github.com/git-for-windows/git)) `2.55.0` + `bash` for `ani-cli`
* **PowerShell** — [PowerShell](https://github.com/PowerShell/PowerShell) + [PSReadLine](https://github.com/PowerShell/PSReadLine) + [PSFzf](https://github.com/kelleyma49/PSFzf)
* **Windows Terminal** — [Windows Terminal](https://github.com/microsoft/terminal) `1.24.11911.0`
* **Node.js** — [Node.js](https://nodejs.org) `24.19.0 LTS` + [Deno](https://deno.land) `2.9.6`
* **Brave** — [Brave](https://brave.com) `152.1.94.121` ([GitHub](https://github.com/brave/brave-browser))
* **VLC** — [VLC](https://www.videolan.org/vlc) `3.0.23`
* **Steam** — [Steam](https://store.steampowered.com) `2.10.91.91` + [Epic Games Store](https://store.epicgames.com) ([Epic Online Services](https://dev.epicgames.com/docs/epic-online-services))
* **FFmpeg** — [FFmpeg](https://ffmpeg.org) `9.0.1` ([gyan.dev builds](https://www.gyan.dev/ffmpeg/builds/)) + [yt-dlp FFmpeg](https://github.com/yt-dlp/FFmpeg-Builds) + [yt-dlp](https://github.com/yt-dlp/yt-dlp) `2026.07.04`
* **Chris Titus Tech (christitus)** — [winutil](https://github.com/ChrisTitusTech/winutil) — `irm | iex` pattern + Brave 12-policy
* **JetBrains Mono + Nerd Fonts** — [JetBrains Mono](https://www.jetbrains.com/mono) + [Nerd Fonts](https://github.com/ryanoasis/nerd-fonts) `3.3.0`
* **fzf** — [fzf](https://github.com/junegunn/fzf) `0.74.3`
* **ripgrep** — [ripgrep](https://github.com/BurntSushi/ripgrep) `15.2.0`
* **Syncthing** — [Syncthing](https://syncthing.net) `2.1.3` ([GitHub](https://github.com/syncthing/syncthing))
* **Mullvad** — [Mullvad DNS](https://mullvad.net/en/help/dns-over-https-and-dns-over-tls) Family `194.242.2.6` / `2a07:e340::6`
* **Raycast** — [Raycast](https://www.raycast.com) `2.2.0`
* **ImageGlass** — [ImageGlass](https://imageglass.org) `10.0.906.0` ([GitHub](https://github.com/d2phap/ImageGlass))
* **mpv** — [mpv](https://mpv.io) ([GitHub](https://github.com/mpv-player/mpv)) `v0.41.0`
* **fastfetch** — [fastfetch](https://github.com/fastfetch-cli/fastfetch) `2.68.1`
* **zoxide** — [zoxide](https://github.com/ajeetdsouza/zoxide) `0.10.0`
* **gh0stzk** — [gh0stzk/dotfiles](https://github.com/gh0stzk/dotfiles) — prompt + `gh0stzk-logo.txt` `6026` bytes
* **O&O Software** — [O&O ShutUp10++](https://www.oo-software.com/en/shutup10) `OOSU10.exe` `3.5.1130`
* **pystardust** — [ani-cli](https://github.com/pystardust/ani-cli) `5.0.4`
* **aria2** — [aria2](https://aria2.github.io) `1.37.0`
* **bat** — [bat](https://github.com/sharkdp/bat)
* **eza** — [eza](https://github.com/eza-community/eza)
* **Zen Browser** — [Zen Browser](https://zen-browser.app) `1.21.16b`
* **LocalSend** — [LocalSend](https://localsend.org) ([GitHub](https://github.com/localsend/localsend)) `1.17.0`
* **KDE Connect** — [KDE Connect](https://kdeconnect.kde.org) `26.04.2`
* **Transmission** — [Transmission](https://transmissionbt.com) ([GitHub](https://github.com/transmission/transmission)) `4.1.3`
* **Malwarebytes** — [Malwarebytes](https://www.malwarebytes.com) `5.6.5.306`
* **Unified Remote** — [Unified Remote](https://www.unifiedremote.com) `3.13.0`
* **Seongjin Park** — wallpaper via [Unsplash](https://unsplash.com/photos/Ks3NL6OH36g)
* **Dotfiles community** — r/unixporn & GitHub dotfiles inspiration
