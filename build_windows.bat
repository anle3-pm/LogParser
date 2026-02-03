@echo off
REM Build script for Windows

echo === Building Log Parser for Windows ===

REM Create virtual environment if it doesn't exist
if not exist "venv" (
    echo Creating virtual environment...
    python -m venv venv
)

REM Activate virtual environment
call venv\Scripts\activate.bat

REM Install dependencies
echo Installing dependencies...
pip install --upgrade pip
pip install -r requirements.txt
pip install pywebview pyinstaller

REM Ensure uploads directory exists
if not exist "uploads" mkdir uploads

REM Build the app
echo Building application...
pyinstaller logparser.spec --clean --noconfirm

echo.
echo === Build complete! ===
echo Windows executable location: dist\LogParser.exe
echo.
echo To run: double-click dist\LogParser.exe
pause
