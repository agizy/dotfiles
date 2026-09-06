# ani-cli — pystardust/ani-cli 5.0.4

Terminal anime streaming via `mpv` + `fzf` + `yt-dlp` + `aria2`.

**Source:** https://github.com/pystardust/ani-cli (`ani-cli` 27689 bytes, `#!/bin/sh`)

**This machine:** `mpv v0.41.0-244-gaf9c81fa1`, `fzf 0.74.3`, `yt-dlp 2026.07.04`, `ffmpeg 9.0.1`, `curl 8.21.0`, `aria2 1.37.0` (via winget), `Git Bash` `bash` at `C:\Program Files\Git\usr\bin\bash.exe`.

**Wrappers:**
* `ani-cli` — original sh script (run via `bash -l ~/.local/bin/ani-cli`)
* `ani-cli.ps1` — PowerShell wrapper that sets PATH for MPV/FFmpeg/yt-dlp then calls `bash -l`
* `ani-cli.cmd` — CMD wrapper

**Usage after `setup.ps1`:**
```powershell
ani-cli --help
ani-cli "naruto"
ani-cli -d "one piece"   # download via aria2
```

**Setup does:**
1. `winget install aria2.aria2 --silent` (if missing, for downloads)
2. Copies `ani-cli/ani-cli` → `~\.local\bin\ani-cli` + `~\bin\mpv.exe` shim if needed
3. Copies `ani-cli.cmd`/`ani-cli.ps1` → `~\.local\bin`
4. Ensures `~\.local\bin` in `$env:Path` via profile (`if (Test-Path "$HOME\.local\bin") { $env:Path = "$HOME\.local\bin;$env:Path" }`)
5. `chmod +x` via bash

**Update:**
```powershell
irm https://raw.githubusercontent.com/pystardust/ani-cli/master/ani-cli -OutFile ~\.local\bin\ani-cli
Copy-Item dotfiles/ani-cli/ani-cli ~\.local\bin\ani-cli -Force
```

**Deps check:** `bash -l -c "which mpv; which fzf; which yt-dlp; which ffmpeg; which aria2c"`
