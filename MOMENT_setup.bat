@echo off
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\MOMENT_setup.ps1"
set "SCRIPT_EXIT_CODE=%ERRORLEVEL%"
set "ROOT_DIR=%~dp0"
set "PROJECT_DIR=%ROOT_DIR%MOMENT\MOMENT-main"
if not exist "%PROJECT_DIR%\src\main.py" goto no_project
cd /d "%ROOT_DIR%"
if exist "%PROJECT_DIR%\.venv\Scripts\activate.bat" call "%PROJECT_DIR%\.venv\Scripts\activate.bat"
echo.
echo Enter MOMENT commands in this window. Type "exit" to close it.
cmd /K
exit /b %SCRIPT_EXIT_CODE%

:no_project
echo Error: The MOMENT project directory was not found.
pause
exit /b %SCRIPT_EXIT_CODE%