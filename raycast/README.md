# Raycast — Windows

**Installed on source machine:** Raycast 2.2.0 (MSIX, `Raycast.Raycast_2.2.0.0_x64__qypenmj9wpt2a`)

Raycast on Windows is currently in preview — Store extensions sync via your **Raycast Cloud account**. Log in on the new machine and they auto-restore. This folder is a snapshot of what was installed.

## 7 extensions installed 2026-09-06

| Title | ID (package `name`) | ID (folder) |
|---|---|---|
| Google Translate | `translate` | `0e43920f-bbf6-4582-bc3f-5f63092c915f` |
| Video Downloader | `video-downloader` | `30370bf8-bb2c-41ad-844b-ff661ae4337a` |
| Spotify Player | `spotify-player` | `320f40ef-a633-415a-ab0e-1e99515478f7` |
| FMHY Search | `fmhy-search` | `626ef38e-1e63-4bcf-9b23-7e7802665073` |
| Coffee | `coffee` | `82c92be8-822f-4923-a5bc-573830b674fb` |
| YouTube | `youtube` | `b3f8cbba-a0f8-4f17-a711-0194a6f2ff4d` |
| Speedtest | `speedtest` | `db530047-6a7d-46d3-bb7d-5d7ba9006b4d` |

See `extensions.json` / `extensions.txt` for the machine-readable list.

## Restore on new machine

1. Install Raycast: `winget install --id Raycast.Raycast -e` or from https://www.raycast.com
2. Sign in → **Settings → Account → Sync** — extensions auto-pull
3. Or reinstall manually: Raycast → Store → search each name above → Install

Hotkeys / aliases are not exported here — they live in Raycast's cloud sync or `%APPDATA%\Raycast` / `~\.config\raycast`. If you customized them, export via Raycast Settings → Advanced → Export.

## Notes

* This repo does **not** commit `.config/raycast/node-compile-cache` or compiled `dist` JS — they are rebuilt on launch.
* If you need exact offline restore, zip `~\.config\raycast` on old machine and copy to new `%USERPROFILE%\.config\raycast` before launching Raycast.
