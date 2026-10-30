@echo off
rem Exports custom\<map>\ as a map pack (build\map_packs\<map>.zip).
rem Usage: tools\export_map_pack.bat my_map
rem Set GODOT to your Godot 4.7 executable if "godot" isn't on your PATH, e.g.
rem   set GODOT=C:\Godot\Godot_v4.7.2-stable_win64_console.exe
if "%~1"=="" (
  echo Usage: tools\export_map_pack.bat ^<map folder in custom\^>
  exit /b 1
)
if "%GODOT%"=="" set GODOT=godot
"%GODOT%" --headless --path "%~dp0.." --script res://tools/export_map_pack.gd -- %*
