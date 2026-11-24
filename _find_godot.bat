@echo off
chcp 65001 >nul
rem Ищет Godot 4.6.2: переменная GODOT, папка tools\godot проекта, PATH.
set "GODOT_EXE="
if defined GODOT if exist "%GODOT%" set "GODOT_EXE=%GODOT%"
if not defined GODOT_EXE for %%F in ("%~dp0tools\godot\Godot_v4.6.2-stable_win64.exe" "%USERPROFILE%\Desktop\Godot_v4.6.2-stable_win64.exe") do if exist %%F set "GODOT_EXE=%%~F"
if not defined GODOT_EXE for /f "delims=" %%F in ('where godot 2^>nul') do if not defined GODOT_EXE set "GODOT_EXE=%%F"
if not defined GODOT_EXE (
  echo Godot 4.6.2 не найден. Положите Godot_v4.6.2-stable_win64.exe в папку tools\godot проекта.
  pause
  exit /b 1
)
