@echo off
setlocal
cd /d "%~dp0\.."
bash scripts/start-local-server.sh
pause
