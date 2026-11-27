@echo off
REM Abre la consola de pruebas con soporte para Windows Forms.
setlocal
cd /d "%~dp0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -STA -File "%~dp0interfaz-pruebas.ps1"
if errorlevel 1 pause

