@echo off
REM Start script for Log Parser (Windows)
REM Checks prerequisites and starts the web service

setlocal enabledelayedexpansion

echo ========================================
echo   Log Parser - Starting Service
echo ========================================
echo.

REM Get the directory where this script is located
set "SCRIPT_DIR=%~dp0"
cd /d "%SCRIPT_DIR%"

echo Checking prerequisites...
echo.

REM Check for Python
where python >nul 2>&1
if %ERRORLEVEL% EQU 0 (
    for /f "tokens=*" %%i in ('python --version 2^>^&1') do set PYTHON_VERSION=%%i
    echo !PYTHON_VERSION! | findstr /C:"Python 3" >nul
    if !ERRORLEVEL! EQU 0 (
        echo [OK] Python found: !PYTHON_VERSION!
        set "PYTHON_CMD=python"
    ) else (
        goto :no_python
    )
) else (
    goto :no_python
)

REM Check for pip
where pip >nul 2>&1
if %ERRORLEVEL% EQU 0 (
    echo [OK] pip found
) else (
    echo [!] pip not found, attempting to install...
    %PYTHON_CMD% -m ensurepip --upgrade
    if %ERRORLEVEL% NEQ 0 (
        echo [ERROR] Could not install pip
        echo Please install pip manually
        pause
        exit /b 1
    )
    echo [OK] pip installed
)

REM Create virtual environment if it doesn't exist
if not exist "venv" (
    echo [!] Virtual environment not found, creating...
    %PYTHON_CMD% -m venv venv
    if %ERRORLEVEL% NEQ 0 (
        echo [ERROR] Failed to create virtual environment
        pause
        exit /b 1
    )
    echo [OK] Virtual environment created
) else (
    echo [OK] Virtual environment found
)

REM Activate virtual environment
call venv\Scripts\activate.bat
echo [OK] Virtual environment activated

REM Install/upgrade dependencies
echo.
echo Checking dependencies...
pip install --quiet --upgrade pip
pip install --quiet -r requirements.txt
if %ERRORLEVEL% NEQ 0 (
    echo [ERROR] Failed to install dependencies
    pause
    exit /b 1
)
echo [OK] Dependencies installed

REM Create uploads directory if it doesn't exist
if not exist "uploads" mkdir uploads
echo [OK] Uploads directory ready

REM Check if already running
if exist ".logparser.pid" (
    set /p OLD_PID=<.logparser.pid
    tasklist /FI "PID eq !OLD_PID!" 2>nul | find /I "python" >nul
    if !ERRORLEVEL! EQU 0 (
        echo [!] Service is already running (PID: !OLD_PID!)
        echo.
        echo To restart, run: stop.bat then start.bat
        pause
        exit /b 0
    ) else (
        del .logparser.pid 2>nul
    )
)

REM Start the service
echo.
echo ========================================
echo   Starting Log Parser Service...
echo ========================================
echo.

REM Start in a new window and capture PID
start "LogParser" /B cmd /c "python app.py > logparser.log 2>&1"

REM Wait a moment for the server to start
timeout /t 3 /nobreak >nul

REM Find the PID of the python process
for /f "tokens=2" %%i in ('tasklist /FI "IMAGENAME eq python.exe" /FI "WINDOWTITLE eq LogParser*" /FO LIST 2^>nul ^| find "PID:"') do (
    set "PID=%%i"
)

REM Alternative: find any python running app.py
if not defined PID (
    for /f "tokens=2" %%i in ('wmic process where "commandline like '%%app.py%%'" get processid 2^>nul ^| findstr /r "[0-9]"') do (
        set "PID=%%i"
    )
)

if defined PID (
    echo !PID! > .logparser.pid
    echo [OK] Service started successfully!
    echo.
    echo ========================================
    echo   Log Parser is running
    echo ========================================
    echo.
    echo   Access URLs:
    echo     http://localhost:5000
    echo     http://127.0.0.1:5000
    REM Get local IP
    for /f "tokens=2 delims=:" %%a in ('ipconfig ^| findstr /c:"IPv4 Address"') do (
        for /f "tokens=1" %%b in ("%%a") do (
            echo     http://%%b:5000 (network^)
            goto :done_ip
        )
    )
    :done_ip
    echo.
    echo   PID:      !PID!
    echo   Log file: %SCRIPT_DIR%logparser.log
    echo.
    echo   To stop:  stop.bat
    echo.
    
    REM Open in browser
    echo Opening browser...
    timeout /t 2 /nobreak >nul
    start http://localhost:5000
) else (
    echo [OK] Service starting...
    echo.
    echo ========================================
    echo   Log Parser is running
    echo ========================================
    echo.
    echo   Access URLs:
    echo     http://localhost:5000
    echo     http://127.0.0.1:5000
    echo.
    echo   Log file: %SCRIPT_DIR%logparser.log
    echo.
    echo   To stop:  stop.bat or close this window
    echo.
    
    REM Open in browser
    timeout /t 2 /nobreak >nul
    start http://localhost:5000
)

pause
exit /b 0

:no_python
echo [ERROR] Python 3 is not installed or not in PATH
echo.
echo Please install Python 3 from:
echo   https://www.python.org/downloads/
echo.
echo Make sure to check "Add Python to PATH" during installation
pause
exit /b 1
