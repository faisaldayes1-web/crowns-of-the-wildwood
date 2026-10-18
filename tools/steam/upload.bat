@echo off
rem Uploads build\steam\windows to Steam (does not go live; set the build live
rem in Steamworks > SteamPipe > Builds). Needs steamcmd.exe from the Steamworks
rem SDK (sdk\tools\ContentBuilder\builder\steamcmd.exe) on PATH or in STEAMCMD.
rem Usage: tools\steam\upload.bat <steam login> <app id> [depot id]
setlocal enabledelayedexpansion
if "%~2"=="" ( echo Usage: upload.bat ^<steam login^> ^<app id^> [depot id] & exit /b 1 )
set USER=%~1
set APP=%~2
set /a DEPOT=%APP%+1
if not "%~3"=="" set DEPOT=%~3
set ROOT=%~dp0..\..
for %%I in ("%ROOT%") do set ROOT=%%~fI
set CONTENT=%ROOT%\build\steam\windows
set OUT=%ROOT%\build\steam\output
if not exist "%CONTENT%\CrownsOfTheWildwood.exe" ( echo Put the Steam build in %CONTENT% first. & exit /b 1 )
if not exist "%OUT%" mkdir "%OUT%"
set VDF=%ROOT%\build\steam\app_build_%APP%.vdf
powershell -NoProfile -Command "(Get-Content '%~dp0app_build.vdf.in') -replace '@APP_ID@','%APP%' -replace '@DEPOT_ID@','%DEPOT%' -replace '@DESC@','Crowns of the Wildwood' -replace '@CONTENT_ROOT@','%CONTENT:\=\\%' -replace '@BUILD_OUTPUT@','%OUT:\=\\%' -replace '@PREVIEW@','0' | Set-Content '%VDF%'"
if "%STEAMCMD%"=="" set STEAMCMD=steamcmd.exe
"%STEAMCMD%" +login %USER% +run_app_build "%VDF%" +quit
