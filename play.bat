@echo off
call "%~dp0_find_godot.bat" || exit /b 1
start "" "%GODOT_EXE%" --path "%~dp0game"
