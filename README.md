# dotfiles — agizy's Windows setup

Exact replica of my current daily driver: **Vivobook ASUS X7600PC (11th Gen i7-11370H, RTX 3050, 16GB) — Windows 11 10.0.26200**.  
One command to go from a fresh Windows install to the same shells, prompts, fonts, tools, Raycast, Syncthing and configs I use every day.

> Public, no secrets inside. API keys (`GITHUB_PERSONAL_ACCESS_TOKEN`, `BRAVE_API_KEY`) are read from `HKCU:\Environment` at runtime — never committed.

---

## ⚡ One-line setup on a brand-new machine

### Option A — with Git (recommended)
```powershell
git clone https://github.com/agizy/dotfiles.git $HOME\dotfiles
Set-ExecutionPolicy Bypass -Scope Process -Force
& $HOME\dotfiles\setup.ps1
```

### Option B — without Git (bootstrap, no clone needed)
```powershell
powershell -ExecutionPolicy Bypass -Command "irm https://raw.githubusercontent.com/agizy/dotfiles/main/bootstrap.ps1 | iex"
```
`bootstrap.ps1` clones the repo to `$HOME\dotfiles` and then hands off to `setup.ps1`.

### What the one-liner does

| Area | Action | Source in repo |
|---|---|---|
| **Winget** | `winget import -i winget/packages.json` — 42 version-pinned packages (Git, Brave 152.1.94.121, Zen, Node 24, Deno, Fastfetch 2.68.1, zoxide 0.10.0, Syncthing 2.1.3, VLC/MPV yt-dlp FFmpeg, JetBrainsMono Nerd Font, etc.) | `winget/packages.json` |
| **Brave debloat** | winutil copy — 12 policies `HKLM:\SOFTWARE\Policies\BraveSoftware\Brave` (Rewards/Wallet/VPN/AI/News/Talk/Tor/P3A disabled, Stats ping off) — applied automatically after Brave install | `setup.ps1` + `brave/README.md` |
| **Brave exact config** | DNS `secure` → `https://family.dns.mullvad.net/dns-query`, 13 filterlists, languages `fr-FR,fr,en-US,en`, 78 accelerators, shields — `Local State` + `Preferences` + `ExtensionInstallForcelist` | `brave/Local State`, `brave/Preferences`, `brave/extensions.json` |
| **Brave default** | Sets `BraveHTML` for `http/https/.html/.htm/.xhtml` via `brave.exe --make-default-browser` + UserChoice hash, fallback `ms-settings:defaultapps` | `setup.ps1:Set-BraveAsDefault` |
| **Chocolatey** | `choco install` from `choco/packages.config` — fzf, ripgrep, opencode, unzip | `choco/packages.config` |
| **PowerShell** | Deploys profile to **both** `Documents\WindowsPowerShell` (5.1) and `Documents\PowerShell` (7+) | `powershell/` |
| **PS modules** | `PSReadLine`, `PSFzf` | `setup.ps1` |
| **Fastfetch** | `~\.config\fastfetch\config.jsonc` + `gh0stzk-logo.txt` | `fastfetch/` |
| **Windows Terminal** | `settings.json` → `%LOCALAPPDATA%\Packages\Microsoft.WindowsTerminal…\LocalState` (backs up original) | `terminal/settings.json` |
| **Raycast** | Detects `Raycast 2.2.0 (MSIX)`, lists 7 Store extensions to re-install (Spotify, Translate, Coffee, YouTube, etc.) | `raycast/extensions.json` |
| **Syncthing** | `winget install Syncthing.Syncthing`, `syncthing generate`, scheduled task `Syncthing` at logon + `Startup\Syncthing.lnk`, firewall rule | `syncthing/` |
| **Wallpaper** | `Seongjin Park.jpg` `5281757` bytes `Fill` via `SystemParametersInfo` → `~/Pictures/Seongjin Park.jpg` (from `Pictures/Seongjin Park.jpg`, Asus OLED Shifter source) | `wallpaper/wallpaper.jpg` |
| **Default Apps** | `Dism /Online /Import-DefaultAppAssociations` + per-user `UserChoice` — Brave `http/https/.html/.htm/.xhtml/.pdf`, ImageGlass `jpg/svg`, Photos `png/bmp/gif`, Media `mp4/mkv/mp3`, Notepad `txt` | `defaultapps/AppAssoc.xml` |
| **Organization** | `O&OShutUp10++` recommended `2026-09-06T03:00:11Z` **except clipboard** — `OOSU10.cfg` 45077 bytes `~150` settings `true` (`A001-003`, `C008-015`, `E001-256` etc.) → `OOSU10.exe /quiet` (79 MB) | `ooshutup/OOSU10.cfg` |
| **ani-cli** | `pystardust/ani-cli 5.0.4` `27689` bytes `#!/bin/sh` + `mpv v0.41.0` `fzf 0.74.3` `yt-dlp 2026.07.04` `ffmpeg 9.0.1` `aria2 1.37.0` + `Git Bash` — `~\.local\bin\ani-cli` | `ani-cli/ani-cli` + `.ps1/.cmd` |
| **Progress** | Cute adaptive `♡  60% [████░░] 6/17` — `Get-TerminalWidth` each step, `█/░` (♥ at 100%), `✗` on error, `✨` elapsed, `chcp 65001` UTF8 | `setup.ps1:Show-CuteProgress` |
| **Font & polish** | JetBrainsMono Nerd Font 3.3.0, Windows logo prompt (`0xf17a` , not Apple ) | profile |

---

## 📁 Layout

```
dotfiles/
├─ setup.ps1                 # ← consolidated installer (idempotent, supports -DryRun)
├─ bootstrap.ps1             # ← irm one-liner entry point
├─ winget/packages.json      # winget export --include-versions (42 pkgs, Teams/Outlook removed)
├─ choco/packages.config     # choco list snapshot
├─ powershell/
│  ├─ Microsoft.PowerShell_profile.ps1        # Windows PowerShell 5.1 (gh0stzk, Windows logo)
│  └─ Microsoft.PowerShell_profile.ps1.pwsh7  # PowerShell 7+ (fastfetch+zoxide minimal)
├─ fastfetch/
│  ├─ config.jsonc
│  ├─ config-no-nerd.jsonc
│  └─ gh0stzk-logo.txt
├─ terminal/settings.json    # Windows Terminal, One Half Dark + JetBrainsMono NF
├─ brave/
│  ├─ Local State            # dns_over_https Mullvad family, 13 filterlists (sanitized encrypted_key)
│  ├─ Preferences            # languages fr-FR, 78 accelerators, shields
│  ├─ extensions.json        # Tampermonkey 5.5.0, Malwarebytes 3.3.4, SponsorBlock 6.1.6
│  └─ README.md              # debloat + default browser docs
├─ wallpaper/
│  └─ wallpaper.jpg          # Seongjin Park 5281757 bytes Fill (exact)
├─ defaultapps/
│  └─ AppAssoc.xml           # Dism export 12944 bytes (Brave, ImageGlass, Photos, Media, Notepad)
├─ ooshutup/
│  ├─ OOSU10.cfg             # recommended - clipboard 45077 bytes 2026-09-06T03:00:11Z
│  └─ README.md              # O&O docs
├─ ani-cli/
│  ├─ ani-cli                # pystardust 5.0.4 27689 bytes sh
│  ├─ ani-cli.ps1            # PowerShell wrapper (Git Bash -l)
│  ├─ ani-cli.cmd            # CMD wrapper
│  └─ README.md
├─ raycast/
│  ├─ extensions.json        # 7 installed Store extensions
│  └─ extensions.txt
└─ syncthing/                # autostart + config docs
```

---

## 🔧 Usage

```powershell
# dry run — see what would happen
.\setup.ps1 -DryRun

# only configs, skip package installs
.\setup.ps1 -OnlyConfigs

# force overwrite without backup
.\setup.ps1 -Force
```

Options: `-DryRun`, `-Force`, `-OnlyConfigs`, `-NoPackages`, `-NoSyncthing`

Re-run any time — idempotent. Backups are written as `*.bak.<yyyyMMdd_HHmmss>`.

---

## 🔐 Secrets

Profile reads at startup:

```powershell
[System.Environment]::GetEnvironmentVariable("GITHUB_PERSONAL_ACCESS_TOKEN","User")
[System.Environment]::GetEnvironmentVariable("BRAVE_API_KEY","User")
```

Set once on a new machine:

```powershell
[System.Environment]::SetEnvironmentVariable("GITHUB_PERSONAL_ACCESS_TOKEN","ghp_...","User")
[System.Environment]::SetEnvironmentVariable("BRAVE_API_KEY","BSA...","User")
# restart terminal — no plaintext in repo
```

---

## 🖥️ Current machine snapshot

* **Export date:** 2026-09-06
* **OS:** Windows 11 10.0.26200.9168
* **Terminal:** Windows Terminal 1.24.11911.0
* **Shell:** Windows PowerShell 5.1.26100.8875 (+ PowerShell profile also covers pwsh 7)
* **Prompt:** gh0stzk-inspired, ` $USER  $DIR  branch >>` — Windows logo `0xf17a`, PSReadLine, zoxide (`z`, `zi`), aliases `bat→cat`, `eza→ls/ll`, `rg→grep`, `fd→find`
* **Packages:** 42 winget (+ Brave 152.1.94.121 with debloat) + 7 choco (see `winget/packages.json`, `choco/packages.config`)
* **Brave:** debloated via winutil 12 policies, DNS Secure Mullvad Family `https://family.dns.mullvad.net/dns-query`, 13 filterlists, languages `fr-FR,fr,en-US,en`, 78 accelerators, 3 extensions (Tampermonkey, Malwarebytes, SponsorBlock), default browser `BraveHTML`
* **Wallpaper:** `Seongjin Park.jpg` `5281757` bytes `SHA256 07386AE035C39A786EDBBF30FD2C775B956FFDB25B8B18BBE961C2480619480F` — `Fill` — Asus OLED Shifter source `C:\Users\Panaino\Pictures\Seongjin Park.jpg`
* **Default Apps:** `Brave` → `http/https/.html/.htm/.xhtml/.mhtml/.shtml/.pdf`, `ImageGlass` → `.jpg/.svg`, `Photos` → `.png/.bmp/.gif/.jpeg`, `Lecteur multimédia` → `.mp4/.mkv/.mp3/.avi/.mov`, `Bloc-notes` → `.txt/.ini/.log`, `CompressedFolder` → `.zip` (12944 bytes `AppAssoc.xml` via `Dism`)
* **Organization:** `O&OShutUp10++` `2026-09-06T03:00:11Z` recommended minus clipboard — `OOSU10.cfg` `45077` bytes, `RecentStates` `~150` true (`E001-256`, `P001-194` etc.), `OOSU10.exe` `79 MB` portable via `https://dl5.oo-software.com/files/ooshutup10/OOSU10.exe`
* **ani-cli:** `5.0.4` `mpv v0.41.0` `fzf 0.74.3` `yt-dlp 2026.07.04` `ffmpeg 9.0.1` `aria2 1.37.0` `Git Bash` — `~\.local\bin\ani-cli` + `~\bin\mpv.exe` shim
* **Progress:** `♡  60% [████░░] 6/17` cute adaptive — `Get-TerminalWidth` each `Step-Progress`, `█` filled `░` empty `♥` at 100% `✗` red on error `✨` elapsed, `UTF8` `chcp 65001`, not verbose but shows `✓/!` per step

---

## ♻️ Keeping it fresh

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

## 📄 License

MIT — see `LICENSE`.

## 🙏 Credits

Prompt structure translated from `~/.zshrc` gh0stzk style. Fastfetch gh0stzk logo from `gh0stzk/dotfiles`.
