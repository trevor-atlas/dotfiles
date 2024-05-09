import { $ } from 'bun';
import { mkdir } from 'node:fs/promises';

// https://github.com/johnlindquist/kit/blob/0de31f203dca2f90ce6f518e9292616a810a1a24/src/api/kit.ts#L495
async function applescript(
  script: string,
  options: { scriptType: 'osascript' | 'JavaScript' } = {
    scriptType: 'osascript',
  }
) {
  const cmd =
    options.scriptType === 'JavaScript'
      ? ['/usr/bin/osascript', '-l', 'JavaScript', '-e', script]
      : ['/usr/bin/osascript', '-e', script];

  return new Promise<string | null>((res, rej) => {
    Bun.spawn({
      cmd,
      windowsHide: true,
      async onExit(subprocess, exitCode, signalCode, error) {
        await subprocess.exited;
        if (error) {
          rej(error.message);
        } else if (exitCode) {
          const text = await new Response(subprocess?.stderr).text();
          rej(`${text}` ?? null);
        } else if (signalCode) {
          res(`Execution halted by signal ${signalCode}`);
        } else {
          const text = await new Response(subprocess?.stdout).text();
          res(text ?? null);
        }
      },
    });
  });
}

async function terminal(script: string) {
  const formatted = script.replace(/'|"/g, '\\"');

    // if not application "Terminal" is running then launch
  return await applescript(`
  tell application "Terminal"
    if not (exists window 1) then reopen
    if busy of window 1 then
        tell application "System Events" to keystroke "t" using command down
    end if
    do script "${formatted}"
  end tell
`);
}

// await applescript(`display dialog "I'm shown!"`);
await applescript(`
  const app = Application.currentApplication();
  app.includeStandardAdditions = true;
  console.log(':D');
  app.displayDialog(\`The current date and time is \${app.currentDate()}\`);
`,
  { scriptType: 'JavaScript' }
);

// const a = await applescript(`
// tell application "Terminal" to get {properties, properties of tab 1} of window 1
// `)
// console.log(a);
await terminal(`echo hello`);
// await terminal(`pwd`);
