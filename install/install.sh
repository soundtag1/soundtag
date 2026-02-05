#!/bin/bash

# SoundTag installer for macOS/Linux
BASEDIR=$(cd "$(dirname "$0")"/.. && pwd)
cd "$BASEDIR" || exit 1

# Check Node.js
if ! command -v node >/dev/null 2>&1; then
  echo "[ERROR] Node.js not found. Install Node.js and re-run."
  exit 1
fi

# Warn if ffmpeg missing
if ! command -v ffmpeg >/dev/null 2>&1; then
  echo "[WARNING] ffmpeg not found. The sound stream may not work."
fi

# Initialize npm if missing
if [ ! -f package.json ]; then
  npm init -y >/dev/null 2>&1
fi

# Install dependencies
npm install express multer >/dev/null 2>&1

# Start server
echo "Starting SoundTag server at http://localhost:3000"
node server.js
