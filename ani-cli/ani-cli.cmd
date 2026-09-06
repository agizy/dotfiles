@echo off
setlocal
set "PATH=C:\Program Files\MPV Player;%LOCALAPPDATA%\Microsoft\WinGet\Links;%LOCALAPPDATA%\Microsoft\WinGet\Packages\Gyan.FFmpeg_Microsoft.Winget.Source_8wekyb3d8bbwe\ffmpeg-9.0.1-full_build\bin;%LOCALAPPDATA%\Microsoft\WinGet\Packages\yt-dlp.yt-dlp_Microsoft.Winget.Source_8wekyb3d8bbwe;%ProgramData%\chocolatey\bin;%PATH%"
"C:\Program Files\Git\usr\bin\bash.exe" -l "%~dp0ani-cli" %*
