# Brave — exact config + winutil debloat + default

**Source machine:** Brave `152.1.94.121` (channel stable), User Data at `%LOCALAPPDATA%\BraveSoftware\Brave-Browser\User Data`, profile `Default` ("Personnel").

`setup.ps1` reproduces this *exactly* on a new machine after `winget install Brave.Brave` — all steps are idempotent and run automatically (no extra command needed).

## What is captured

| Area | Source file in repo | Exact values on this machine | How restored |
|---|---|---|---|
| **DNS** | `brave/Local State` → `dns_over_https` | `mode: "secure"`, `templates: "https://family.dns.mullvad.net/dns-query"` (Mullvad Family) | Copy `Local State`, re-inject original `os_crypt.encrypted_key` so logins still decrypt |
| **Filter lists** | `brave/Local State` → `brave.ad_block.regional_filters` | 13 enabled GUIDs: `49958da7-f532-…`, `564C3B75-…`, `67E792D4-…`, `690FF3B4-…`, `6b91e355-…`, `78672887-…`, `7911A1CB-…`, `7f11b964-…`, `9852EFC4-…`, `9E8EC586-…`, `E2FA7D98-…`, `F61D6B7B-…`, `d579f370-…` | Same file |
| **Languages** | `brave/Preferences` → `intl` | `accept_languages: "en-US,en,fr"` / `selected_languages: "fr-FR,fr,en-US,en"` (`fr-FR` primary, UI `app_locale: fr`) | Copy `Preferences` |
| **Keyboard shortcuts** | `brave/Preferences` → `brave.accelerators` | 78 custom accelerators e.g. `33000: Alt+ArrowLeft`, `33002: Ctrl+KeyR/F5`, `33007: Ctrl+Shift+R` etc. | Same file |
| **Shields / prefs** | `brave/Preferences` + `brave/Local State` | `brave.shields`, `brave.tabs.vertical_tabs_*`, `autofill`, `browser`, etc. | Same file |
| **Extensions** | `brave/extensions.json` | 3 user extensions: `Tampermonkey 5.5.0` (`dhdgffkkebhmkfjojejmpbldmpobfkfo`), `Malwarebytes Browser Guard 3.3.4` (`ihcjicgdanjaechkgeegckofjjedodee`), `SponsorBlock 6.1.6` (`mnjggcdmjocbbbhaepdhchncahnbgone`) + 2 built-ins (Brave, PDF) | `HKLM\SOFTWARE\Policies\BraveSoftware\Brave\ExtensionInstallForcelist` → Brave auto-installs from Chrome Web Store on next launch |
| **Debloat** | `setup.ps1` winutil copy | 12 policies under `HKLM:\SOFTWARE\Policies\BraveSoftware\Brave` | `setup.ps1` writes them automatically (see below) |
| **Default browser** | `setup.ps1:Set-BraveAsDefault` | BraveHTML ProgId (`BraveHTML.NYWPG…`) for `http/https/.html/.htm/.xhtml` | `brave.exe --make-default-browser` + UserChoice hash + fallback `ms-settings:defaultapps` |

## Winutil debloat (copied from `ChrisTitusTech/winutil` `WPFTweaksBraveDebloat`)

`setup.ps1` writes these at `HKLM:\SOFTWARE\Policies\BraveSoftware\Brave` (admin):

```
BraveRewardsDisabled=1, BraveWalletDisabled=1, BraveVPNDisabled=1, BraveAIChatEnabled=0
BraveStatsPingEnabled=0, BraveNewsDisabled=1, BraveTalkDisabled=1, TorDisabled=1
BraveP3AEnabled=0, UrlKeyedAnonymizedDataCollectionEnabled=0
SafeBrowsingExtendedReportingEnabled=0, MetricsReportingEnabled=0
```

Verify: `Get-ItemProperty HKLM:\SOFTWARE\Policies\BraveSoftware\Brave` — all 12 present on this machine.

## How `setup.ps1` applies it (hands-off)

1. **Install** `Brave.Brave` via `winget` if missing.
2. **Stop** Brave (`Get-Process brave | Stop-Process`) to avoid file lock.
3. **Backup** existing `Local State` + `Default\Preferences` to `*.bak.<timestamp>`.
4. **Copy** repo `brave/Local State` → `%LOCALAPPDATA%\BraveSoftware\Brave-Browser\User Data\Local State` and `brave/Preferences` → `...Default\Preferences` (preserving original `os_crypt.encrypted_key` so saved passwords still decrypt).
5. **Force extensions** via `ExtensionInstallForcelist` (IDs + `https://clients2.google.com/service/update2/crx`).
6. **Set default** via `brave.exe --make-default-browser` + UserChoice hash for `http/https/.html/.htm/.xhtml` (hash via `Get-UserChoiceHash`); if Windows rejects hash, opens `ms-settings:defaultapps` for one-click confirm.

Re-run any time — idempotent.

## Manual update (when you change Brave on this machine)

```powershell
Copy-Item "$env:LOCALAPPDATA\BraveSoftware\Brave-Browser\User Data\Local State" brave/ -Force
Copy-Item "$env:LOCALAPPDATA\BraveSoftware\Brave-Browser\User Data\Default\Preferences" brave/ -Force
# sanitize encrypted_key placeholder for commit
(Get-Content brave/"Local State" -Raw) -replace '"encrypted_key"\s*:\s*"[^"]+"','"encrypted_key":"REPLACE_WITH_MACHINE_KEY_DPAPI"' | Set-Content brave/"Local State" -NoNewline -Encoding UTF8
# update extensions.json if you add/remove one
git add brave/; git commit -m "brave: snapshot $(Get-Date -Format yyyy-MM-dd)"; git push
```

## Caveats

* `os_crypt.encrypted_key` is DPAPI-machine-bound — repo stores placeholder, `setup.ps1` restores the target machine's own key after copy. Logins/bookmarks/sync still need Brave Sync or manual password export for true cross-machine password sync.
* Brave must be closed during copy — `setup.ps1` stops it automatically.
* Setting default browser on Windows 11 needs admin + hash; if silent set fails, `setup.ps1` opens Settings → Default apps → pick Brave once, then re-run `setup.ps1` will report `Default browser → BraveHTML`.
