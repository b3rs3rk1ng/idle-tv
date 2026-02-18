import { Server } from "@modelcontextprotocol/sdk/server/index.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import {
  CallToolRequestSchema,
  ListToolsRequestSchema,
} from "@modelcontextprotocol/sdk/types.js";
import { execSync, spawn } from "child_process";
import { existsSync, readFileSync, writeFileSync, mkdirSync } from "fs";
import { homedir } from "os";
import { join } from "path";

// Paths
const CONFIG_DIR = join(homedir(), ".idle-tv");
const CONFIG_FILE = join(CONFIG_DIR, "config.json");
const SOCKET_PATH = "/tmp/idle-tv-mpv.sock";

// Default config
const DEFAULT_CONFIG = {
  lastUrl: null,
  volume: 50,
  queue: [],
};

// Ensure config directory exists
function ensureConfigDir() {
  if (!existsSync(CONFIG_DIR)) {
    mkdirSync(CONFIG_DIR, { recursive: true });
  }
}

// Load config
function loadConfig() {
  ensureConfigDir();
  try {
    if (existsSync(CONFIG_FILE)) {
      return { ...DEFAULT_CONFIG, ...JSON.parse(readFileSync(CONFIG_FILE, "utf8")) };
    }
  } catch (e) {}
  return DEFAULT_CONFIG;
}

// Save config
function saveConfig(config) {
  ensureConfigDir();
  writeFileSync(CONFIG_FILE, JSON.stringify(config, null, 2));
}

// Check if mpv is installed
function checkMpv() {
  try {
    execSync("which mpv", { encoding: "utf8", stdio: "pipe" });
    return true;
  } catch (e) {
    return false;
  }
}

// Check if mpv is running
function isMpvRunning() {
  try {
    execSync("pgrep -x mpv", { encoding: "utf8", stdio: "pipe" });
    return true;
  } catch (e) {
    return false;
  }
}

// Get number of windows in current Kitty tab
function getKittyWindowCount() {
  try {
    const currentWindowId = process.env.KITTY_WINDOW_ID;
    if (!currentWindowId) return 1;

    const output = execSync('kitty @ ls 2>/dev/null', { encoding: "utf8" });
    const data = JSON.parse(output);

    // Find the tab containing our window
    for (const osWindow of data) {
      for (const tab of osWindow.tabs) {
        if (tab.windows) {
          for (const win of tab.windows) {
            if (String(win.id) === String(currentWindowId)) {
              return tab.windows.length;
            }
          }
        }
      }
    }
    return 1;
  } catch (e) {
    return 1;
  }
}

// Get split location based on current layout
function getSplitLocation() {
  const windowCount = getKittyWindowCount();
  // If only 1 window (Claude alone), split right (vsplit)
  // If 2+ windows (already split), split below (hsplit)
  return windowCount === 1 ? "vsplit" : "hsplit";
}

// Send command to mpv via socket
function mpvCommand(command) {
  try {
    const cmd = JSON.stringify({ command });
    const result = execSync(`echo '${cmd}' | nc -U ${SOCKET_PATH} 2>/dev/null`, {
      encoding: "utf8",
      timeout: 5000,
    });
    return JSON.parse(result);
  } catch (e) {
    return { error: e.message };
  }
}

// Get mpv property
function getMpvProperty(property) {
  const result = mpvCommand(["get_property", property]);
  return result.data;
}

// Set mpv property
function setMpvProperty(property, value) {
  return mpvCommand(["set_property", property, value]);
}

// Get stream URL using yt-dlp
function getStreamUrl(url) {
  try {
    const streamUrl = execSync(`yt-dlp -f best -g "${url}" 2>/dev/null`, {
      encoding: "utf8",
      timeout: 30000,
    }).trim();
    return streamUrl;
  } catch (e) {
    return null;
  }
}

// Start mpv with URL in Kitty split
function startMpv(url) {
  if (!checkMpv()) {
    return {
      success: false,
      message: "mpv not installed. Run: brew install mpv yt-dlp",
    };
  }

  // If mpv is already running, load the new URL
  if (isMpvRunning()) {
    const streamUrl = getStreamUrl(url);
    if (!streamUrl) {
      return { success: false, message: "Failed to get stream URL" };
    }
    mpvCommand(["loadfile", streamUrl, "replace"]);
    setMpvProperty("pause", false);

    const config = loadConfig();
    config.lastUrl = url;
    saveConfig(config);

    return {
      success: true,
      message: `Now playing: ${url}`,
    };
  }

  // Get stream URL first
  const streamUrl = getStreamUrl(url);
  if (!streamUrl) {
    return { success: false, message: "Failed to get stream URL. Check if yt-dlp supports this site." };
  }

  // Start new mpv instance in Kitty split
  try {
    // Close existing idle-tv window if any
    execSync('kitty @ close-window --match="title:idle-tv" 2>/dev/null || true');

    // Launch in Kitty split with video in terminal
    const splitLocation = getSplitLocation();
    const windowId = process.env.KITTY_WINDOW_ID || "";
    const nextTo = windowId ? `--next-to="id:${windowId}"` : "";
    execSync(`kitty @ launch --location=${splitLocation} ${nextTo} --title="idle-tv" mpv --vo=kitty --keep-open=yes --input-ipc-server=${SOCKET_PATH} "${streamUrl}"`, {
      encoding: "utf8",
    });

    const config = loadConfig();
    config.lastUrl = url;
    saveConfig(config);

    return {
      success: true,
      message: `Started playing: ${url}`,
    };
  } catch (e) {
    return {
      success: false,
      message: `Failed to start mpv: ${e.message}`,
    };
  }
}

// Play/resume
function play() {
  if (!isMpvRunning()) {
    const config = loadConfig();
    if (config.lastUrl) {
      return startMpv(config.lastUrl);
    }
    return {
      success: false,
      message: "No video loaded. Use media_open to open a URL first.",
    };
  }

  setMpvProperty("pause", false);
  return {
    success: true,
    message: "Resumed playback",
  };
}

// Pause
function pause() {
  if (!isMpvRunning()) {
    return {
      success: true,
      message: "No video playing",
    };
  }

  setMpvProperty("pause", true);
  return {
    success: true,
    message: "Paused",
  };
}

// Stop (close mpv)
function stop() {
  if (!isMpvRunning()) {
    return {
      success: true,
      message: "No video playing",
    };
  }

  mpvCommand(["quit"]);
  return {
    success: true,
    message: "Stopped and closed player",
  };
}

// Next in playlist
function next() {
  if (!isMpvRunning()) {
    return { success: false, message: "No video playing" };
  }
  mpvCommand(["playlist-next"]);
  return { success: true, message: "Skipped to next" };
}

// Previous in playlist
function previous() {
  if (!isMpvRunning()) {
    return { success: false, message: "No video playing" };
  }
  mpvCommand(["playlist-prev"]);
  return { success: true, message: "Went to previous" };
}

// Add to queue
function queue(url) {
  if (!isMpvRunning()) {
    return startMpv(url);
  }

  mpvCommand(["loadfile", url, "append"]);

  const config = loadConfig();
  config.queue.push(url);
  saveConfig(config);

  return {
    success: true,
    message: `Added to queue: ${url}`,
  };
}

// Get status
function getStatus() {
  if (!isMpvRunning()) {
    return {
      playing: false,
      message: "No video playing",
    };
  }

  const paused = getMpvProperty("pause");
  const title = getMpvProperty("media-title") || getMpvProperty("filename");
  const position = getMpvProperty("time-pos");
  const duration = getMpvProperty("duration");
  const volume = getMpvProperty("volume");
  const playlistCount = getMpvProperty("playlist-count");
  const playlistPos = getMpvProperty("playlist-pos");

  return {
    playing: !paused,
    paused: paused,
    title: title,
    position: position ? Math.floor(position) : 0,
    duration: duration ? Math.floor(duration) : 0,
    volume: volume,
    playlistPosition: playlistPos + 1,
    playlistCount: playlistCount,
  };
}

// Set volume
function setVolume(level) {
  if (!isMpvRunning()) {
    return { success: false, message: "No video playing" };
  }

  const vol = Math.max(0, Math.min(100, level));
  setMpvProperty("volume", vol);

  return { success: true, message: `Volume set to ${vol}%` };
}

// Seek
function seek(seconds) {
  if (!isMpvRunning()) {
    return { success: false, message: "No video playing" };
  }

  mpvCommand(["seek", seconds, "relative"]);
  return { success: true, message: `Seeked ${seconds > 0 ? '+' : ''}${seconds}s` };
}

// Create MCP Server
const server = new Server(
  {
    name: "idle-tv",
    version: "1.0.0",
  },
  {
    capabilities: {
      tools: {},
    },
  }
);

// Define tools
server.setRequestHandler(ListToolsRequestSchema, async () => {
  return {
    tools: [
      {
        name: "media_play",
        description: "Resume video playback. Call this when you start working on a task that takes time - the user can watch while waiting for you to finish.",
        inputSchema: {
          type: "object",
          properties: {},
        },
      },
      {
        name: "media_pause",
        description: "Pause video playback. Call this when you finish your task and need user input or attention.",
        inputSchema: {
          type: "object",
          properties: {},
        },
      },
      {
        name: "media_open",
        description: "Open and play a video URL. Supports YouTube, Twitch, and 1000+ streaming sites via yt-dlp.",
        inputSchema: {
          type: "object",
          properties: {
            url: {
              type: "string",
              description: "The video URL to play (YouTube, Twitch, etc.)",
            },
          },
          required: ["url"],
        },
      },
      {
        name: "media_stop",
        description: "Stop playback and close the video player completely.",
        inputSchema: {
          type: "object",
          properties: {},
        },
      },
      {
        name: "media_next",
        description: "Skip to the next video in the playlist/queue.",
        inputSchema: {
          type: "object",
          properties: {},
        },
      },
      {
        name: "media_previous",
        description: "Go back to the previous video in the playlist/queue.",
        inputSchema: {
          type: "object",
          properties: {},
        },
      },
      {
        name: "media_queue",
        description: "Add a video URL to the playback queue.",
        inputSchema: {
          type: "object",
          properties: {
            url: {
              type: "string",
              description: "The video URL to add to queue",
            },
          },
          required: ["url"],
        },
      },
      {
        name: "media_status",
        description: "Get current playback status including title, position, and queue info.",
        inputSchema: {
          type: "object",
          properties: {},
        },
      },
      {
        name: "media_volume",
        description: "Set the playback volume (0-100).",
        inputSchema: {
          type: "object",
          properties: {
            level: {
              type: "number",
              description: "Volume level from 0 to 100",
            },
          },
          required: ["level"],
        },
      },
      {
        name: "media_seek",
        description: "Seek forward or backward in the current video.",
        inputSchema: {
          type: "object",
          properties: {
            seconds: {
              type: "number",
              description: "Seconds to seek (positive = forward, negative = backward)",
            },
          },
          required: ["seconds"],
        },
      },
    ],
  };
});

// Handle tool calls
server.setRequestHandler(CallToolRequestSchema, async (request) => {
  const { name, arguments: args } = request.params;

  try {
    let result;

    switch (name) {
      case "media_play":
        result = play();
        break;

      case "media_pause":
        result = pause();
        break;

      case "media_open":
        result = startMpv(args.url);
        break;

      case "media_stop":
        result = stop();
        break;

      case "media_next":
        result = next();
        break;

      case "media_previous":
        result = previous();
        break;

      case "media_queue":
        result = queue(args.url);
        break;

      case "media_status":
        result = getStatus();
        break;

      case "media_volume":
        result = setVolume(args.level);
        break;

      case "media_seek":
        result = seek(args.seconds);
        break;

      default:
        return {
          content: [{ type: "text", text: `Unknown tool: ${name}` }],
          isError: true,
        };
    }

    return {
      content: [{ type: "text", text: JSON.stringify(result, null, 2) }],
    };
  } catch (error) {
    return {
      content: [{ type: "text", text: `Error: ${error.message}` }],
      isError: true,
    };
  }
});

// Start server
async function main() {
  const transport = new StdioServerTransport();
  await server.connect(transport);
  console.error("idle-tv MCP server running");
}

main().catch(console.error);
