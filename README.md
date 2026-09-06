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
| **Winget** | `winget import -i winget/packages.json` — 44 version-pinned packages (Git, Brave, Zen, Node 24, Deno, Fastfetch 2.68.1, zoxide 0.10.0, Syncthing 2.1.3, VLC/MPV yt-dlp FFmpeg, JetBrainsMono Nerd Font, etc.) | `winget/packages.json` |
| **Chocolatey** | `choco install` from `choco/packages.config` — fzf, ripgrep, opencode, unzip | `choco/packages.config` |
| **PowerShell** | Deploys profile to **both** `Documents\WindowsPowerShell` (5.1) and `Documents\PowerShell` (7+) | `powershell/` |
| **PS modules** | `PSReadLine`, `PSFzf` | `setup.ps1` |
| **Fastfetch** | `~\.config\fastfetch\config.jsonc` + `gh0stzk-logo.txt` | `fastfetch/` |
| **Windows Terminal** | `settings.json` → `%LOCALAPPDATA%\Packages\Microsoft.WindowsTerminal…\LocalState` (backs up original) | `terminal/settings.json` |
| **Raycast** | Detects `Raycast 2.2.0 (MSIX)`, lists 7 Store extensions to re-install (Spotify, Translate, Coffee, YouTube, etc.) | `raycast/extensions.json` |
| **Syncthing** | `winget install Syncthing.Syncthing`, `syncthing generate`, scheduled task `Syncthing` at logon + `Startup\Syncthing.lnk`, firewall rule | `syncthing/` |
| **Font & polish** | JetBrainsMono Nerd Font 3.3.0, Windows logo prompt (`0xf17a` , not Apple ) | profile |

---

## 📁 Layout

```
dotfiles/
├─ setup.ps1                 # ← consolidated installer (idempotent, supports -DryRun)
├─ bootstrap.ps1             # ← irm one-liner entry point
├─ winget/packages.json      # winget export --include-versions
├─ choco/packages.config     # choco list snapshot
├─ powershell/
│  ├─ Microsoft.PowerShell_profile.ps1        # Windows PowerShell 5.1 (gh0stzk, Windows logo)
│  └─ Microsoft.PowerShell_profile.ps1.pwsh7  # PowerShell 7+ (fastfetch+zoxide minimal)
├─ fastfetch/
│  ├─ config.jsonc
│  ├─ config-no-nerd.jsonc
│  └─ gh0stzk-logo.txt
├─ terminal/settings.json    # Windows Terminal, One Half Dark + JetBrainsMono NF
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
* **Packages:** 44 winget + 7 choco (see `winget/packages.json`, `choco/packages.config`)

---

## ♻️ Keeping it fresh

```powershell
# on your main machine after changing something:
winget export -o winget/packages.json --include-versions --accept-source-agreements
choco list --limit-output > choco/packages.config  # or copy back
Copy-Item $PROFILE powershell/Microsoft.PowerShell_profile.ps1 -Force
Copy-Item ~\.config\fastfetch\config.jsonc fastfetch/ -Force
Copy-Item $env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json terminal/ -Force
git add -A; git commit -m "snapshot $(Get-Date -Format yyyy-MM-dd)"; git push
```

---

## 📄 License

MIT — see `LICENSE`.

## 🙏 Credits

Prompt structure translated from `~/.zshrc` gh0stzk style. Fastfetch gh0stzk logo from `gh0stzk/dotfiles`.
