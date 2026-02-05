@echo off
setlocal

REM Determine project directory (parent of install folder)
set "BASEDIR=%~dp0"
set "PROJECTDIR=%BASEDIR%.."
cd /d "%PROJECTDIR%"

REM Check Node.js
where node >nul 2>nul
if %errorlevel% neq 0 (
  echo Node.js is required. Please install Node.js and re-run.
  pause
  exit /b 1
)

REM Warn if ffmpeg missing
where ffmpeg >nul 2>nul
if %errorlevel% neq 0 (
  echo [WARNING] ffmpeg not found. The sound stream may not work.
)

REM Initialize npm if missing
if not exist package.json (
  npm init -y >nul 2>nul
)

REM Install dependencies
npm install express multer >nul 2>nul

REM Start server
echo Starting SoundTag server at http://localhost:3000
node server.js
pause
