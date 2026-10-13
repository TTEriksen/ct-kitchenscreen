@echo off
REM Starts the kitchen screen server and opens it full screen in Microsoft Edge.
REM Put a shortcut to this file in shell:startup to run it at login.
cd /d "%~dp0\.."
start "Kitchenscreen server" /min node server\index.js
timeout /t 3 /nobreak >nul
start "" msedge --kiosk http://localhost:8080 --edge-kiosk-type=fullscreen --no-first-run --autoplay-policy=no-user-gesture-required
