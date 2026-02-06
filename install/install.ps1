# SoundTag full Windows installer
$ErrorActionPreference = "Stop"

Write-Host "=== SoundTag Installer (Windows) ==="

# Install location
$Home = [Environment]::GetFolderPath("UserProfile")
$InstallDir = Join-Path $Home "soundtag"

Write-Host "Installing to $InstallDir"

# -----------------------------
# Check Node.js
# -----------------------------
if (-not (Get-Command node -ErrorAction SilentlyContinue)) {
    Write-Error "Node.js is required. Install Node.js from https://nodejs.org and re-run."
    exit 1
}

# -----------------------------
# FFmpeg auto-install
# -----------------------------
function Has-FFmpeg {
    return [bool](Get-Command ffmpeg -ErrorAction SilentlyContinue)
}

if (-not (Has-FFmpeg)) {
    Write-Host "FFmpeg not found. Attempting automatic install..." -ForegroundColor Yellow

    if (Get-Command winget -ErrorAction SilentlyContinue) {
        try {
            winget install --id=Gyan.FFmpeg --accept-source-agreements --accept-package-agreements
        } catch {
            Write-Warning "Winget install failed."
        }

        # Refresh PATH
        $env:PATH =
            [Environment]::GetEnvironmentVariable("PATH","Machine") + ";" +
            [Environment]::GetEnvironmentVariable("PATH","User")
    }

    if (-not (Has-FFmpeg)) {
        Write-Error @"
FFmpeg could not be installed automatically.

Install manually from:
https://www.gyan.dev/ffmpeg/builds/

Then restart PowerShell and re-run this installer.
"@
        exit 1
    }

    Write-Host "FFmpeg installed successfully." -ForegroundColor Green
}

# -----------------------------
# Create folders
# -----------------------------
New-Item -ItemType Directory -Force -Path $InstallDir | Out-Null
New-Item -ItemType Directory -Force -Path "$InstallDir\sounds" | Out-Null
New-Item -ItemType Directory -Force -Path "$InstallDir\public" | Out-Null
Set-Location $InstallDir

# -----------------------------
# package.json
# -----------------------------
@"
{
  "name": "soundtag",
  "version": "1.0.0",
  "private": true,
  "dependencies": {
    "express": "^4.19.2",
    "multer": "^2.0.0"
  }
}
"@ | Out-File -Encoding UTF8 package.json

npm install

# -----------------------------
# server.js
# -----------------------------
@"
const express = require("express");
const { spawn } = require("child_process");
const fs = require("fs");
const path = require("path");
const multer = require("multer");

const app = express();
const clients = new Set();
let ffmpeg = null;

const soundsDir = path.join(__dirname, "sounds");
if (!fs.existsSync(soundsDir)) fs.mkdirSync(soundsDir);

const upload = multer({ dest: soundsDir });

app.use(express.static("public"));

app.get("/stream", (req, res) => {
  res.writeHead(200, {
    "Content-Type": "audio/mpeg",
    "Cache-Control": "no-cache",
    "Connection": "keep-alive"
  });
  clients.add(res);
  req.on("close", () => clients.delete(res));
});

function startSilence() {
  if (ffmpeg) ffmpeg.kill("SIGKILL");
  ffmpeg = spawn("ffmpeg", ["-f","lavfi","-i","anullsrc","-f","mp3","pipe:1"]);
  ffmpeg.on("error", e => console.error("FFmpeg error:", e.message));
  ffmpeg.stdout.on("data", d => clients.forEach(c => c.write(d)));
}

function playFile(file) {
  if (ffmpeg) ffmpeg.kill("SIGKILL");
  ffmpeg = spawn("ffmpeg", ["-re","-i",file,"-f","mp3","pipe:1"]);
  ffmpeg.on("error", e => console.error("FFmpeg error:", e.message));
  ffmpeg.stdout.on("data", d => clients.forEach(c => c.write(d)));
}

app.get("/files", (req,res)=>{
  res.json(fs.readdirSync(soundsDir).filter(f=>/\.(mp3|wav|ogg|m4a)$/i.test(f)));
});

app.post("/upload", upload.single("file"), (req,res)=>{
  const name = req.file.originalname.replace(/[^\w.-]/g,"_");
  fs.renameSync(req.file.path, path.join(soundsDir, name));
  res.json({ok:true});
});

app.post("/play/:file",(req,res)=>{
  playFile(path.join(soundsDir, req.params.file));
  res.json({ok:true});
});

app.post("/stop",(req,res)=>{
  startSilence();
  res.json({ok:true});
});

app.listen(3000, ()=>{
  console.log("SoundTag running at http://localhost:3000");
  startSilence();
});
"@ | Out-File -Encoding UTF8 server.js

# -----------------------------
# listener.html
# -----------------------------
@"
<!DOCTYPE html>
<html>
<body style="margin:0;background:white;height:100vh">
<script>
const a=new Audio("/stream");
function u(){a.play().catch(()=>{});}
document.addEventListener("click",u,{once:true});
document.addEventListener("touchstart",u,{once:true});
</script>
</body>
</html>
"@ | Out-File -Encoding UTF8 public\listener.html

# -----------------------------
# control.html
# -----------------------------
@"
<!DOCTYPE html>
<html>
<body style="margin:0;padding:16px;font-family:system-ui;background:#0b0b10;color:#fff">
<h1>SoundTag</h1>
<input id="u" type="file" accept="audio/*"><br><br>
<div id="list">Loading…</div><br>
<button onclick="fetch('/stop',{method:'POST'})">Stop (Silent)</button>
<script>
async function load(){
  const r=await fetch('/files');
  const f=await r.json();
  list.innerHTML='';
  f.forEach(n=>{
    const d=document.createElement('div');
    d.style.padding='12px';
    d.style.cursor='pointer';
    d.textContent=n;
    d.onclick=()=>fetch('/play/'+encodeURIComponent(n),{method:'POST'});
    list.appendChild(d);
  });
}
u.onchange=async()=>{
  const fd=new FormData();
  fd.append('file',u.files[0]);
  await fetch('/upload',{method:'POST',body:fd});
  load();
};
load();
</script>
</body>
</html>
"@ | Out-File -Encoding UTF8 public\control.html

Write-Host ""
Write-Host "✅ SoundTag installed successfully."
Write-Host "Control:  http://localhost:3000/control"
Write-Host "Listener: http://localhost:3000/listener"
Write-Host ""

node server.js
