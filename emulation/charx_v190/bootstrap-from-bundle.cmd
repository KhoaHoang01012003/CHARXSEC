@echo off
setlocal
powershell -ExecutionPolicy Bypass -NoProfile -File "%~dp0bootstrap-from-bundle.ps1" %*
exit /b %ERRORLEVEL%
