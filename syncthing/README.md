# Syncthing

**Installed:** `Syncthing.Syncthing` `v2.1.3 "Hafnium Hornet"` (go1.26.5 windows-amd64)

## What setup.ps1 provisions

1. **Install** (if missing)
   ```powershell
   winget install --id Syncthing.Syncthing --silent --accept-package-agreements --accept-source-agreements
   # link: %LOCALAPPDATA%\Microsoft\WinGet\Links\syncthing.exe
   ```

2. **Generate identity** (if no config)
   ```powershell
   syncthing generate
   # → %LOCALAPPDATA%\Syncthing\config.xml, key.pem, cert.pem
   # Device ID on source: LJDNQIS-B3RS2WX-2Q4GDYN-KFOXHG4-NWAIJ24-PEKAZX4-IYR5YEY-OQ32MAO (Vivo)
   ```

3. **Autostart — two mechanisms (redundant, safe)**

   * **Scheduled Task** `Syncthing`: trigger `AtLogOn` +30s, hidden, `Highest` run level
     ```powershell
     Get-ScheduledTask -TaskName Syncthing
     ```
   * **Startup shortcut**: `%APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup\Syncthing.lnk`
     target `syncthing.exe --no-browser --no-restart`, window minimized

   Check: `Get-Process syncthing`, GUI at `http://127.0.0.1:8384`

4. **Firewall**
   ```powershell
   New-NetFirewallRule -DisplayName "Syncthing" -Program <real exe> -Direction Inbound -Action Allow
   ```

5. **Default folder**: `%USERPROFILE%\Sync` created if missing. Add folders/devices at `http://127.0.0.1:8384`.

## Re-connect a new machine to the old one

On the new machine after `setup.ps1`:

1. Open `http://127.0.0.1:8384` on **both** machines
2. On each, **Actions → Show ID**, copy Device ID
3. On one, **+ Add Remote Device** → paste other ID → save
4. Accept prompt on the other side
5. Share folder `Sync` (or add custom folder path) between them

## Files we do NOT commit

* `key.pem`, `cert.pem`, `https-*.pem` — device identity (generated per machine)
* `index-v2/` — database
* `syncthing.log` — logs

Only `config.xml` structure is documented here; real sync state is per-device.
