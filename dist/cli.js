#!/usr/bin/env node

// src/cli.js
var import_child_process = require("child_process");
var SOCKET_PATH = "/tmp/idle-tv-mpv.sock";
function mpvCommand(command2) {
  try {
    const cmd = JSON.stringify({ command: command2 });
    (0, import_child_process.execSync)(`echo '${cmd}' | nc -U ${SOCKET_PATH} 2>/dev/null`, {
      encoding: "utf8",
      timeout: 1e3
    });
    return true;
  } catch (e) {
    return false;
  }
}
function isMpvRunning() {
  try {
    (0, import_child_process.execSync)("pgrep -x mpv", { encoding: "utf8", stdio: "pipe" });
    return true;
  } catch (e) {
    return false;
  }
}
var command = process.argv[2];
switch (command) {
  case "play":
  case "resume":
    if (isMpvRunning()) {
      mpvCommand(["set_property", "pause", false]);
    }
    break;
  case "pause":
    if (isMpvRunning()) {
      mpvCommand(["set_property", "pause", true]);
    }
    break;
  case "stop":
    (0, import_child_process.execSync)("pkill mpv 2>/dev/null || true");
    break;
  case "status":
    console.log(isMpvRunning() ? "playing" : "stopped");
    break;
  default:
    console.log("Usage: idle-tv <play|pause|stop|status>");
    process.exit(1);
}
