@echo off
cd /d "%~dp0"
if exist "builds\windows\AEROFIELD.exe" (
  start "" "builds\windows\AEROFIELD.exe"
  exit /b
)
if defined GODOT (
  "%GODOT%" --path "%CD%"
  exit /b
)
godot --path "%CD%"
if errorlevel 1 (
  echo Please install Godot 4.7.2 or download the Windows executable from GitHub Releases.
  pause
)
