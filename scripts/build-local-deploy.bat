@echo off
setlocal
cd /d "%~dp0\.."
bash scripts/build-local-deploy.sh
if errorlevel 1 exit /b 1
echo.
echo Jalankan server: bash scripts/start-local-server.sh
pause
