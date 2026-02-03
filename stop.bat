@echo off
REM Stop script for Log Parser (Windows)

setlocal enabledelayedexpansion

echo ========================================
echo   Log Parser - Stopping Service
echo ========================================
echo.

REM Get the directory where this script is located
set "SCRIPT_DIR=%~dp0"
cd /d "%SCRIPT_DIR%"

set "STOPPED=0"

REM Check if PID file exists
if exist ".logparser.pid" (
    set /p PID=<.logparser.pid
    
    echo Checking for process PID: !PID!
    
    tasklist /FI "PID eq !PID!" 2>nul | find /I "python" >nul
    if !ERRORLEVEL! EQU 0 (
        echo Stopping Log Parser (PID: !PID!)...
        taskkill /PID !PID! /F >nul 2>&1
        if !ERRORLEVEL! EQU 0 (
            echo [OK] Service stopped successfully
            set "STOPPED=1"
        ) else (
            echo [ERROR] Failed to stop service
        )
    ) else (
        echo [!] Service was not running (stale PID file)
    )
    del .logparser.pid 2>nul
)

REM Also try to find and kill any running instance
for /f "tokens=2" %%i in ('wmic process where "commandline like '%%app.py%%'" get processid 2^>nul ^| findstr /r "[0-9]"') do (
    if !STOPPED! EQU 0 (
        echo [!] Found running Log Parser process: %%i
        echo Stopping...
        taskkill /PID %%i /F >nul 2>&1
        echo [OK] Process stopped
        set "STOPPED=1"
    )
)

if !STOPPED! EQU 0 (
    echo [!] Service is not running
)

echo.
echo ========================================
echo   Log Parser stopped
echo ========================================
echo.

pause
