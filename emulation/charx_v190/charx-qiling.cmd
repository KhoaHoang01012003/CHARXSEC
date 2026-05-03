@echo off
setlocal
powershell -ExecutionPolicy Bypass -NoProfile -File "%~dp0charx-qiling.ps1" %*
exit /b %ERRORLEVEL%
