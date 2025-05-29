#!/usr/bin/env /Users/tatlas/.bun/bin/bun

// Required parameters:
// @raycast.schemaVersion 1
// @raycast.title Force Paste
// @raycast.description Paste the contents of your clipboard, even in fields that don't let you paste
// @raycast.mode compact

// Optional parameters:
// @raycast.icon 📋

// Documentation:
// @raycast.author tatlas
// @raycast.authorURL https://trevoratlas.com

import { runAppleScript } from "./utilities";

await runAppleScript(`tell application "System Events" to keystroke the clipboard as text`);

