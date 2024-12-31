@echo off
setlocal enabledelayedexpansion
cd /D "%~dp0"
for %%a in (%*) do set "%%a=1"

:: --- Usage Notes ------------------------------------------------------------
:: `debug` 	will produce a debug build
:: `release' 	will produce a release build
:: `run`	will run the game (without building)

set target=aseprite_exporter

:: --- Run --------------------------------------------------------------------
if "%run%"=="1" (
	echo [Running]
	.\%target%.exe
	goto :end
)

set extra_flags=-strict-style -vet-style -vet-semicolon -vet-unused-imports
if "%debug%"=="1" set extra_flags=%extra_flags% -debug -o:none
if "%release%"=="1" set extra_flags=%extra_flags% -o:speed -no-bounds-check

set compile=odin build . -out:%target%.exe %extra_flags%
echo [Compile cmd]: "%compile%"
echo.
%compile%

:end
echo [Finished]
