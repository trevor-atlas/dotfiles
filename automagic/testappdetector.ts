/**
 * testappdetector: probe what window titles a running app exposes, so we can
 * encode *real* detection signals rather than guesses.
 *
 * Usage:
 *   bun testappdetector.ts zoom       # list window titles of the zoom process
 *   bun testappdetector.ts teams      # Microsoft Teams
 *   bun testappdetector.ts Meet       # Google Meet (desktop/browser)
 *   bun testappdetector.ts            # default: zoom
 *
 * It lists every window title of the first process whose name *contains* the
 * given substring. The meet apps expose different titles when idle vs. in-call,
 * so per-app you can eyeball which one marks a live meeting.
 */
import { spawnSync } from 'bun';

function getWindowNamesContains(processName: string): string[] {
  const appleScript = `
    tell application "System Events"
      try
        set theProcess to first process whose name contains "${processName}"
        if exists theProcess then
          tell theProcess
            return name of every window
          end tell
        else
          return "No process found"
        end if
      on error
        return "AppleScript error"
      end try
    end tell
  `;

  const proc = spawnSync(['osascript', '-e', appleScript]);
  const output = proc.stdout.toString().trim();

  if (
    !output ||
    output.includes('error') ||
    output.includes('No process found')
  ) {
    return [];
  }
  return output.split(',').map((name) => name.trim());
}

const target = process.argv[2] ?? 'zoom';
const openWindows = getWindowNamesContains(target);

console.log(`--- Windows for process containing "${target}" ---`);
if (openWindows.length === 0) {
  console.log('No windows found (process not running, or no Accessibility access).');
} else {
  openWindows.forEach((window, index) => {
    console.log(`[${index + 1}] "${window}"`);
  });
}
