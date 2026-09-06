# O&O ShutUp10++ — organization settings

**Source machine:** `OOSU10.cfg` `45077` bytes, `OOSU10.exe` `79 MB` portable, applied `2026-09-06T03:00:11Z` on `VIVO\Panaino`.

**Settings:** Recommended by `O&OShutUp10++` **except clipboard** (user kept clipboard history). See `OOSU10.cfg` → `<RecentStates>` where ~150 settings are `Value="true"` (recommended) vs `<InitialStates>` where most were `false`. Clipboard-related setting(s) remain `false` in `<RecentStates>` (e.g. `W011` etc. — O&O keeps their IDs opaque, but the diff between `Recommended` and this file is exactly the clipboard exception).

**Repo:** Only `OOSU10.cfg` is committed (79 MB exe is downloaded on demand by `setup.ps1` from `https://dl5.oo-software.com/files/ooshutup10/OOSU10.exe`).

**Apply manually:**
```powershell
# GUI
.\ooshutup\OOSU10.exe

# Silent CLI (as setup does)
.\OOSU10.exe OOSU10.cfg /quiet
# or
OOSU10.exe ooshutup/OOSU10.cfg /quiet
```

**Setup does:**
1. Downloads `OOSU10.exe` to `$env:TEMP\OOSU10.exe` if missing (79930408 bytes)
2. Copies `ooshutup/OOSU10.cfg` to temp
3. Runs `OOSU10.exe OOSU10.cfg /quiet` (requires admin) — applies recommended minus clipboard
4. Verifies via `HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection` etc.

**Update after you change O&O on this machine:**
```powershell
Copy-Item "$env:LOCALAPPDATA\OO Software\OO ShutUp10\OOSU10.cfg" ooshutup/OOSU10.cfg -Force
git add ooshutup/OOSU10.cfg; git commit -m "ooshutup: snapshot $(Get-Date -Format yyyy-MM-dd)"; git push
```

**Note:** Keep `OOSU10.cfg` as UTF8 (O&O expects it). Do not edit manually — use O&O GUI then export.
