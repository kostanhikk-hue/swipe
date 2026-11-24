@echo off
call "%~dp0_find_godot.bat" || exit /b 1
start "" "%GODOT_EXE%" -e --path "%~dp0game"
