const express = require("express");
const { spawn } = require("child_process");
const fs = require("fs");
const path = require("path");
const multer = require("multer");

const app = express();
const clients = new Set();
let ffmpeg = null;

const soundsDir = path.join(__dirname, "sounds");
if (!fs.existsSync(soundsDir)) {
  fs.mkdirSync(soundsDir, { recursive: true });
}

const upload = multer({ dest: soundsDir });

app.use(express.json());
app.use(express.static(path.join(__dirname, "public")));

/**
 * STREAM ENDPOINT
 */
app.get("/stream", (req, res) => {
  res.writeHead(200, {
    "Content-Type": "audio/mpeg",
    "Cache-Control": "no-cache",
    "Connection": "keep-alive",
  });
  clients.add(res);
  req.on("close", () => {
    clients.delete(res);
  });
});

/**
 * Start silence (stream stays alive)
 */
function startSilence() {
  if (ffmpeg) {
    ffmpeg.kill("SIGKILL");
  }
  ffmpeg = spawn("ffmpeg", [
    "-f",
    "lavfi",
    "-i",
    "anullsrc=channel_layout=stereo:sample_rate=44100",
    "-f",
    "mp3",
    "pipe:1",
  ]);
  ffmpeg.stdout.on("data", (chunk) => {
    for (const client of clients) {
      client.write(chunk);
    }
  });
  ffmpeg.stderr.on("data", () => {});
}

/**
 * Start streaming a specific file
 */
function startFile(filePath) {
  if (ffmpeg) {
    ffmpeg.kill("SIGKILL");
  }
  ffmpeg = spawn("ffmpeg", ["-re", "-i", filePath, "-f", "mp3", "pipe:1"]);
  ffmpeg.stdout.on("data", (chunk) => {
    for (const client of clients) {
      client.write(chunk);
    }
  });
  ffmpeg.stderr.on("data", () => {});
}

/**
 * List audio files
 */
app.get("/files", (req, res) => {
  fs.readdir(soundsDir, (err, files) => {
    if (err) {
      return res.status(500).json({ error: "Failed to read sounds directory" });
    }
    const audioFiles = files.filter((f) =>
      /\.(mp3|wav|ogg|m4a)$/i.test(f)
    );
    res.json(audioFiles);
  });
});

/**
 * Upload file
 */
app.post("/upload", upload.single("file"), (req, res) => {
  if (!req.file) {
    return res.status(400).json({ error: "No file uploaded" });
  }
  const originalName = req.file.originalname.replace(/[^\w.-]/g, "_");
  const targetPath = path.join(soundsDir, originalName);
  fs.rename(req.file.path, targetPath, (err) => {
    if (err) {
      return res.status(500).json({ error: "Failed to save file" });
    }
    res.json({ success: true, file: originalName });
  });
});

/**
 * Play file endpoint
 */
app.post("/play/:file", (req, res) => {
  const fileName = req.params.file;
  const fullPath = path.join(soundsDir, fileName);
  if (!fs.existsSync(fullPath)) {
    return res.status(404).json({ error: "File not found" });
  }
  startFile(fullPath);
  res.json({ success: true });
});

/**
 * Stop (silence)
 */
app.post("/stop", (req, res) => {
  startSilence();
  res.json({ success: true });
});

const PORT = process.env.PORT || 3000;

app.listen(PORT, () => {
  console.log(`SoundTag server running on port ${PORT}`);
  console.log("Control panel: /control");
  console.log("Listener page: /listener");
  startSilence();
});
