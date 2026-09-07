# dotfiles â€” agizy's Windows setup

Exact replica of my current daily driver: **Vivobook ASUS X7600PC (11th Gen i7-11370H, RTX 3050, 16GB) â€” Windows 11 10.0.26200**.  
One command to go from a fresh Windows install to the same shells, prompts, fonts, tools, Raycast, Syncthing and configs I use every day.

> Public, no secrets inside. API keys (`GITHUB_PERSONAL_ACCESS_TOKEN`, `BRAVE_API_KEY`) are read from `HKCU:\Environment` at runtime â€” never committed.

---

## âš¡ One-line setup on a brand-new machine

### Option A â€” with Git (recommended)
```powershell
git clone https://github.com/agizy/dotfiles.git $HOME\dotfiles
Set-ExecutionPolicy Bypass -Scope Process -Force
& $HOME\dotfiles\setup.ps1
```

### Option B â€” without Git (bootstrap, no clone needed)
```powershell
powershell -ExecutionPolicy Bypass -Command "irm https://raw.githubusercontent.com/agizy/dotfiles/main/bootstrap.ps1 | iex"
```
`bootstrap.ps1` clones the repo to `$HOME\dotfiles` and then hands off to `setup.ps1`.

### What the one-liner does

| Area | Action | Source in repo |
|---|---|---|
| **Winget** | `winget import -i winget/packages.json` â€” 34 version-pinned packages (Git, Brave 152.1.94.121, Zen, Node 24, Deno, Fastfetch 2.68.1, zoxide 0.10.0, Syncthing 2.1.3, VLC/MPV yt-dlp FFmpeg, JetBrainsMono Nerd Font, etc.) | `winget/packages.json` |
| **Brave debloat** | winutil copy â€” 12 policies `HKLM:\SOFTWARE\Policies\BraveSoftware\Brave` (Rewards/Wallet/VPN/AI/News/Talk/Tor/P3A disabled, Stats ping off) â€” applied automatically after Brave install | `setup.ps1` + `brave/README.md` |
| **Brave exact config** | DNS `secure` â†’ `https://family.dns.mullvad.net/dns-query`, 13 filterlists, languages `fr-FR,fr,en-US,en`, 78 accelerators, shields â€” `Local State` + `Preferences` + `ExtensionInstallForcelist` | `brave/Local State`, `brave/Preferences`, `brave/extensions.json` |
| **Brave default** | Sets `BraveHTML` for `http/https/.html/.htm/.xhtml` via `brave.exe --make-default-browser` + UserChoice hash, fallback `ms-settings:defaultapps` | `setup.ps1:Set-BraveAsDefault` |
| **Chocolatey** | `choco install` from `choco/packages.config` â€” fzf, ripgrep, opencode, unzip | `choco/packages.config` |
| **PowerShell** | Deploys profile to **both** `Documents\WindowsPowerShell` (5.1) and `Documents\PowerShell` (7+) | `powershell/` |
| **PS modules** | `PSReadLine`, `PSFzf` | `setup.ps1` |
| **Fastfetch** | `~\.config\fastfetch\config.jsonc` + `gh0stzk-logo.txt` | `fastfetch/` |
| **Windows Terminal** | `settings.json` â†’ `%LOCALAPPDATA%\Packages\Microsoft.WindowsTerminalâ€¦\LocalState` (backs up original) | `terminal/settings.json` |
| **Raycast** | Detects `Raycast 2.2.0 (MSIX)`, lists 7 Store extensions to re-install (Spotify, Translate, Coffee, YouTube, etc.) | `raycast/extensions.json` |
| **Syncthing** | `winget install Syncthing.Syncthing`, `syncthing generate`, scheduled task `Syncthing` at logon + `Startup\Syncthing.lnk`, firewall rule | `syncthing/` |
| **Wallpaper** | `Seongjin Park.jpg` `5281757` bytes `Fill` via `SystemParametersInfo` â†’ `~/Pictures/Seongjin Park.jpg` (from `Pictures/Seongjin Park.jpg`, Asus OLED Shifter source) | `wallpaper/wallpaper.jpg` |
| **Default Apps** | `Dism /Online /Import-DefaultAppAssociations` + per-user `UserChoice` â€” Brave `http/https/.html/.htm/.xhtml/.pdf`, ImageGlass `jpg/svg`, Photos `png/bmp/gif`, Media `mp4/mkv/mp3`, Notepad `txt` | `defaultapps/AppAssoc.xml` |
| **Organization** | `O&OShutUp10++` recommended `2026-09-06T03:00:11Z` **except clipboard** â€” `OOSU10.cfg` 45077 bytes `~150` settings `true` (`A001-003`, `C008-015`, `E001-256` etc.) â†’ `OOSU10.exe /quiet` (79 MB) | `ooshutup/OOSU10.cfg` |
| **ani-cli** | `pystardust/ani-cli 5.0.4` `27689` bytes `#!/bin/sh` + `mpv v0.41.0` `fzf 0.74.3` `yt-dlp 2026.07.04` `ffmpeg 9.0.1` `aria2 1.37.0` + `Git Bash` â€” `~\.local\bin\ani-cli` | `ani-cli/ani-cli` + `.ps1/.cmd` |
| **Progress** | Cute adaptive `â™¡  60% [â–ˆâ–ˆâ–ˆâ–ˆâ–‘â–‘] 6/17` â€” `Get-TerminalWidth` each step, `â–ˆ/â–‘` (â™¥ at 100%), `âœ—` on error, `âœ¨` elapsed, `chcp 65001` UTF8 | `setup.ps1:Show-CuteProgress` |
| **Font & polish** | JetBrainsMono Nerd Font 3.3.0, Windows logo prompt (`0xf17a` ï…º, not Apple ï…¹) | profile |

---

## ðŸ“ Layout

```
dotfiles/
â”œâ”€ setup.ps1                 # â† consolidated installer (idempotent, supports -DryRun)
â”œâ”€ bootstrap.ps1             # â† irm one-liner entry point
â”œâ”€ winget/packages.json      # winget export --include-versions (34 pkgs, Teams/Outlook removed)
â”œâ”€ choco/packages.config     # choco list snapshot
â”œâ”€ powershell/
â”‚  â”œâ”€ Microsoft.PowerShell_profile.ps1        # Windows PowerShell 5.1 (gh0stzk, Windows logo)
â”‚  â””â”€ Microsoft.PowerShell_profile.ps1.pwsh7  # PowerShell 7+ (fastfetch+zoxide minimal)
â”œâ”€ fastfetch/
â”‚  â”œâ”€ config.jsonc
â”‚  â”œâ”€ config-no-nerd.jsonc
â”‚  â””â”€ gh0stzk-logo.txt
â”œâ”€ terminal/settings.json    # Windows Terminal, One Half Dark + JetBrainsMono NF
â”œâ”€ brave/
â”‚  â”œâ”€ Local State            # dns_over_https Mullvad family, 13 filterlists (sanitized encrypted_key)
â”‚  â”œâ”€ Preferences            # languages fr-FR, 78 accelerators, shields
â”‚  â”œâ”€ extensions.json        # Tampermonkey 5.5.0, Malwarebytes 3.3.4, SponsorBlock 6.1.6
â”‚  â””â”€ README.md              # debloat + default browser docs
â”œâ”€ wallpaper/
â”‚  â””â”€ wallpaper.jpg          # Seongjin Park 5281757 bytes Fill (exact)
â”œâ”€ defaultapps/
â”‚  â””â”€ AppAssoc.xml           # Dism export 12944 bytes (Brave, ImageGlass, Photos, Media, Notepad)
â”œâ”€ ooshutup/
â”‚  â”œâ”€ OOSU10.cfg             # recommended - clipboard 45077 bytes 2026-09-06T03:00:11Z
â”‚  â””â”€ README.md              # O&O docs
â”œâ”€ ani-cli/
â”‚  â”œâ”€ ani-cli                # pystardust 5.0.4 27689 bytes sh
â”‚  â”œâ”€ ani-cli.ps1            # PowerShell wrapper (Git Bash -l)
â”‚  â”œâ”€ ani-cli.cmd            # CMD wrapper
â”‚  â””â”€ README.md
â”œâ”€ raycast/
â”‚  â”œâ”€ extensions.json        # 7 installed Store extensions
â”‚  â””â”€ extensions.txt
â””â”€ syncthing/                # autostart + config docs
```

---

## ðŸ”§ Usage

```powershell
# dry run â€” see what would happen
.\setup.ps1 -DryRun

# only configs, skip package installs
.\setup.ps1 -OnlyConfigs

# force overwrite without backup
.\setup.ps1 -Force

# interactive menu (no args) â€” prompt Install vs Undo
.\setup.ps1
# â†’ 1. Install / Setup  2. Undo / Restore  3. Exit
# â†’ Undo submenu: All, Brave, Dev Tools (Terminal/PowerShell/Fastfetch), 
#   Windows (wallpaper/default apps/DNS with/without O&O), O&O only, 
#   Wallpaper/DefaultApps/DNS/Syncthing/ani-cli

# non-interactive undo â€” no prompt
.\setup.ps1 -Mode Undo -UndoCategory All -DryRun        # preview
.\setup.ps1 -Mode Undo -UndoCategory Brave -Force       # no confirm
.\setup.ps1 -Mode Undo -UndoCategory DevTools
.\setup.ps1 -Mode Undo -UndoCategory WindowsWithOO      # wallpaper+defaultapps+DNS+O&O
.\setup.ps1 -Mode Undo -UndoCategory WindowsWithoutOO   # wallpaper+defaultapps+DNS
.\setup.ps1 -Mode Undo -UndoCategory OO                 # O&O only
.\setup.ps1 -Mode Install -DryRun                       # explicit install
```

Options: `-DryRun`, `-Force`, `-OnlyConfigs`, `-NoPackages`, `-NoSyncthing`, `-Mode {Install|Undo}`, `-UndoCategory {All|Brave|DevTools|WindowsWithOO|WindowsWithoutOO|OO|Wallpaper|DefaultApps|DNS|Syncthing|AniCli}`, `-NonInteractive`

Re-run any time â€” idempotent. Backups are written as `*.bak.<yyyyMMdd_HHmmss>`. Undo restores `*.bak.*` where exists; registry (Brave debloat `HKLM\...\Brave`, O&O `~150` policies, DNS `194.234.2.6` DoH) is removed/reset, firewall `Private`â†’removed, task `Limited`â†’removed.

---

## ðŸ” Secrets

Profile reads at startup:

```powershell
[System.Environment]::GetEnvironmentVariable("GITHUB_PERSONAL_ACCESS_TOKEN","User")
[System.Environment]::GetEnvironmentVariable("BRAVE_API_KEY","User")
```

Set once on a new machine:

```powershell
[System.Environment]::SetEnvironmentVariable("GITHUB_PERSONAL_ACCESS_TOKEN","ghp_...","User")
[System.Environment]::SetEnvironmentVariable("BRAVE_API_KEY","BSA...","User")
# restart terminal â€” no plaintext in repo
```

---

## ðŸ–¥ï¸ Current machine snapshot

* **Export date:** 2026-09-06
* **OS:** Windows 11 10.0.26200.9168
* **Terminal:** Windows Terminal 1.24.11911.0
* **Shell:** Windows PowerShell 5.1.26100.8875 (+ PowerShell profile also covers pwsh 7)
* **Prompt:** gh0stzk-inspired, `ï…º $USER ï‡¥ $DIR ï˜ branch >>` â€” Windows logo `0xf17a`, PSReadLine, zoxide (`z`, `zi`), aliases `batâ†’cat`, `ezaâ†’ls/ll`, `rgâ†’grep`, `fdâ†’find`
* **Packages:** 34 winget (+ Brave 152.1.94.121 with debloat) + 7 choco (see `winget/packages.json`, `choco/packages.config`)
* **Brave:** debloated via winutil 12 policies, DNS Secure Mullvad Family `https://family.dns.mullvad.net/dns-query`, 13 filterlists, languages `fr-FR,fr,en-US,en`, 78 accelerators, 3 extensions (Tampermonkey, Malwarebytes, SponsorBlock), default browser `BraveHTML`
* **Wallpaper:** `Seongjin Park.jpg` `5281757` bytes `SHA256 07386AE035C39A786EDBBF30FD2C775B956FFDB25B8B18BBE961C2480619480F` â€” `Fill` â€” Asus OLED Shifter source `C:\Users\Panaino\Pictures\Seongjin Park.jpg`
* **Default Apps:** `Brave` â†’ `http/https/.html/.htm/.xhtml/.mhtml/.shtml/.pdf`, `ImageGlass` â†’ `.jpg/.svg`, `Photos` â†’ `.png/.bmp/.gif/.jpeg`, `Lecteur multimÃ©dia` â†’ `.mp4/.mkv/.mp3/.avi/.mov`, `Bloc-notes` â†’ `.txt/.ini/.log`, `CompressedFolder` â†’ `.zip` (12944 bytes `AppAssoc.xml` via `Dism`)
* **Organization:** `O&OShutUp10++` `2026-09-06T03:00:11Z` recommended minus clipboard â€” `OOSU10.cfg` `45077` bytes, `RecentStates` `~150` true (`E001-256`, `P001-194` etc.), `OOSU10.exe` `79 MB` portable via `https://dl5.oo-software.com/files/ooshutup10/OOSU10.exe`
* **ani-cli:** `5.0.4` `mpv v0.41.0` `fzf 0.74.3` `yt-dlp 2026.07.04` `ffmpeg 9.0.1` `aria2 1.37.0` `Git Bash` â€” `~\.local\bin\ani-cli` + `~\bin\mpv.exe` shim
* **Progress:** `â™¡  60% [â–ˆâ–ˆâ–ˆâ–ˆâ–‘â–‘] 6/17` cute adaptive â€” `Get-TerminalWidth` each `Step-Progress`, `â–ˆ` filled `â–‘` empty `â™¥` at 100% `âœ—` red on error `âœ¨` elapsed, `UTF8` `chcp 65001`, not verbose but shows `âœ“/!` per step

---

## â™»ï¸ Keeping it fresh

```powershell
# on your main machine after changing something:
winget export -o winget/packages.json --include-versions --accept-source-agreements
choco list --limit-output > choco/packages.config  # or copy back
Copy-Item $PROFILE powershell/Microsoft.PowerShell_profile.ps1 -Force
Copy-Item ~\.config\fastfetch\config.jsonc fastfetch/ -Force
Copy-Item $env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json terminal/ -Force
Copy-Item "$env:LOCALAPPDATA\BraveSoftware\Brave-Browser\User Data\Local State" brave/ -Force
Copy-Item "$env:LOCALAPPDATA\BraveSoftware\Brave-Browser\User Data\Default\Preferences" brave/ -Force
(Get-Content brave/"Local State" -Raw) -replace '"encrypted_key"\s*:\s*"[^"]+"','"encrypted_key":"REPLACE_WITH_MACHINE_KEY_DPAPI"' | Set-Content brave/"Local State" -NoNewline -Encoding UTF8
Copy-Item "$env:APPDATA\Microsoft\Windows\Themes\TranscodedWallpaper" -Destination wallpaper/wallpaper.jpg -Force # or $HOME\Pictures\Seongjin Park.jpg
Copy-Item "$env:USERPROFILE\Pictures\Seongjin Park.jpg" wallpaper/wallpaper.jpg -Force
Dism /Online /Export-DefaultAppAssociations:"$PWD\defaultapps\AppAssoc.xml"
git add -A; git commit -m "snapshot $(Get-Date -Format yyyy-MM-dd)"; git push
```

---

## ðŸ“„ License

MIT â€” see `LICENSE`.

## ðŸ™ Credits

Prompt structure translated from `~/.zshrc` gh0stzk style. Fastfetch gh0stzk logo from `gh0stzk/dotfiles`.


