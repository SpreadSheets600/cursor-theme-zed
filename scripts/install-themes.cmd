@echo off
REM Install Zed themes from the repository into the current user's Zed themes directory.
REM Usage:
REM   install-themes.cmd         -> interactive (asks to proceed)
REM   install-themes.cmd -y      -> proceed without prompting (overwrite existing files)
REM   install-themes.cmd -n      -> dry-run (lists actions but does not copy)
REM   install-themes.cmd -h|--help -> show this help
REM Notes:
REM   - This script assumes it lives in the repository's "scripts" folder and that there is a sibling "themes" folder:
REM       <repo>/scripts/install-themes.cmd
REM       <repo>/themes/*.json
REM   - Target for Windows: %USERPROFILE%\AppData\Roaming\Zed\themes (that's %APPDATA%\Zed\themes)

setlocal enabledelayedexpansion

:: ---- Argument parsing ----
set "AUTO_CONFIRM=0"
set "DRY_RUN=0"

if /I "%1"=="-y"  set "AUTO_CONFIRM=1"
if /I "%1"=="--yes" set "AUTO_CONFIRM=1"
if /I "%1"=="-n"  set "DRY_RUN=1"
if /I "%1"=="--dry-run" set "DRY_RUN=1"
if /I "%1"=="-h"  goto :usage
if /I "%1"=="--help" goto :usage

:: ---- Resolve repository themes directory relative to this script ----
REM %~dp0 is the directory of this script (ends with a backslash)
set "SCRIPT_DIR=%~dp0"
REM Move up one level from scripts to repo root
pushd "%SCRIPT_DIR%..\%" >nul 2>&1
if errorlevel 1 (
  REM If pushd failed, fall back to script directory parent using %SCRIPT_DIR%
  pushd "%SCRIPT_DIR%.." >nul 2>&1
)
set "REPO_ROOT=%CD%"
popd >nul

set "THEMES_SRC=%REPO_ROOT%\themes"
set "TARGET=%APPDATA%\Zed\themes"

echo.
echo Repository root: "%REPO_ROOT%"
echo Themes source:   "%THEMES_SRC%"
echo Zed target dir:  "%TARGET%"
echo.

:: ---- Basic checks ----
if "%APPDATA%"=="" (
  echo ERROR: The %%APPDATA%% environment variable is not set. Cannot determine target path.
  exit /b 1
)

if not exist "%THEMES_SRC%\" (
  echo ERROR: Themes folder not found at "%THEMES_SRC%". Nothing to do.
  exit /b 1
)

REM Check for any JSON theme files
set "FOUND=0"
for %%F in ("%THEMES_SRC%\*.json") do (
  set "FOUND=1"
)
if "%FOUND%"=="0" (
  echo WARNING: No .json theme files found in "%THEMES_SRC%".
  exit /b 0
)

:: ---- Prepare action summary ----
echo The following theme files were found:
for %%F in ("%THEMES_SRC%\*.json") do echo    %%~nxF
echo.

if "%DRY_RUN%"=="1" (
  echo DRY-RUN mode: no files will be copied.
  echo Files WOULD be copied to: "%TARGET%"
  echo.
  exit /b 0
)

:: ---- Confirmation ----
if "%AUTO_CONFIRM%"=="0" (
  echo Proceed to copy the above files to "%TARGET%"? [Y/N]
  choice /C YN /N /M "" >nul 2>&1
  if errorlevel 2 (
    echo Aborted by user.
    exit /b 0
  )
) else (
  echo Auto-confirm enabled: proceeding without prompt.
)

:: ---- Create target directory if needed ----
if not exist "%TARGET%\" (
  echo Creating target directory: "%TARGET%"
  mkdir "%TARGET%" 2>nul
  if errorlevel 1 (
    echo ERROR: Failed to create "%TARGET%". Check permissions.
    exit /b 1
  )
)

echo.
echo Copying theme files...
pushd "%THEMES_SRC%" >nul 2>&1
if errorlevel 1 (
  echo ERROR: Unable to switch to themes source directory "%THEMES_SRC%".
  exit /b 1
)

set "COPY_ERRORS=0"
for %%F in (*.json) do (
  echo - Copying "%%~nxF" ...
  copy /Y "%%~fF" "%TARGET%\" >nul 2>&1
  if errorlevel 1 (
    echo   FAILED to copy "%%~nxF"
    set /A COPY_ERRORS+=1
  ) else (
    echo   Copied.
  )
)

popd >nul 2>&1

echo.
if "%COPY_ERRORS%"=="0" (
  echo All themes installed successfully.
  echo They will be available in Zed the next time it loads.
  exit /b 0
) else (
  echo Completed with %COPY_ERRORS% errors.
  exit /b 2
)

:usage
echo.
echo Usage: install-themes.cmd [options]
echo.
echo Options:
echo   -y, --yes        Proceed without prompting (overwrite existing files).
echo   -n, --dry-run    Show what would be done but do not copy files.
echo   -h, --help       Show this help message.
echo.
exit /b 0
