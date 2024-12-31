@echo off
setlocal enabledelayedexpansion
cd /D "%~dp0"

:: --- Usage Notes ------------------------------------------------------------
:: `debug` 	will produce a debug build
:: `release' 	will produce a release build
:: `run`	will run the game (without building)

:: --- Unpack Arguments -------------------------------------------------------
for %%a in (%*) do set "%%a=1"
if not "%release%"=="1" set debug=1
if "%debug%"=="1"   set release=0 && echo [debug mode]
if "%release%"=="1" set debug=0 && echo [release mode]

:: --- Paths ------------------------------------------------------------------
:: NOTE: all paths are relative to the root folder
set root=%cd%
set build_dir=%root%\bin\
set src_dir=%root%\code
set target=game
set assets_dir=%root%\assets
set shaders_dir=%assets_dir%\shaders
set shaders_out_dir=%assets_dir%\built_shaders

:: --- Run --------------------------------------------------------------------
if "%run%"=="1" (
	echo [Running]
	pushd "%build_dir%"
	.\%target%.exe
	popd
	goto :end
)

:: --- Prep Directories -------------------------------------------------------
if not exist "%build_dir%" mkdir "%build_dir%"

:: --- Produce Logo Icon File -------------------------------------------------

:: --- Build Shaders ----------------------------------------------------------

:: --- Build Packages ---------------------------------------------------------

:: --- Build Engine -----------------------------------------------------------
pushd "%build_dir%"

set extra_flags=-strict-style -vet-style -vet-semicolon -vet-unused-imports -collection:engine=%src_dir%
if "%debug%"=="1" set extra_flags=%extra_flags% -debug -o:none
if "%release%"=="1" set extra_flags=%extra_flags% -o:speed -no-bounds-check -subsystem:windows

set compile=odin build %src_dir%\win32 -out:%target%.exe %extra_flags%

echo [Building main]
echo [Compile cmd]: "%compile%"
echo.
%compile%

:: --- Popd ------------------------------------------------------------------
popd

:: --- Unset ------------------------------------------------------------------
:end

echo [finished]