# SoundTag installer for Windows PowerShell
$ErrorActionPreference = "Stop"

# Determine project directory (one level up from install folder)
$scriptDir = Split-Path $MyInvocation.MyCommand.Path -Parent
$projDir = Join-Path $scriptDir ".."
Set-Location $projDir

# Check Node.js
if (-not (Get-Command node -ErrorAction SilentlyContinue)) {
    Write-Error "Node.js is required. Please install Node.js and re-run."
    exit 1
}

# Warn if ffmpeg missing
if (-not (Get-Command ffmpeg -ErrorAction SilentlyContinue)) {
    Write-Warning "ffmpeg not found. The sound stream may not work."
}

# Initialize npm if missing
if (-not (Test-Path "package.json")) {
    npm init -y | Out-Null
}

# Install dependencies
npm install express multer | Out-Null

# Start server
Write-Host "Starting SoundTag server at http://localhost:3000"
node server.js
