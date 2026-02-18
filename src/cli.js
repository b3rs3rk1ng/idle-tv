#!/usr/bin/env node
import { execSync } from "child_process";

const SOCKET_PATH = "/tmp/idle-tv-mpv.sock";

function mpvCommand(command) {
  try {
    const cmd = JSON.stringify({ command });
    execSync(`echo '${cmd}' | nc -U ${SOCKET_PATH} 2>/dev/null`, {
      encoding: "utf8",
      timeout: 1000,
    });
    return true;
  } catch (e) {
    return false;
  }
}

function isMpvRunning() {
  try {
    execSync("pgrep -x mpv", { encoding: "utf8", stdio: "pipe" });
    return true;
  } catch (e) {
    return false;
  }
}

const command = process.argv[2];

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
    execSync("pkill mpv 2>/dev/null || true");
    break;

  case "status":
    console.log(isMpvRunning() ? "playing" : "stopped");
    break;

  default:
    console.log("Usage: idle-tv <play|pause|stop|status>");
    process.exit(1);
}
