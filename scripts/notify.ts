#!/usr/bin/env node

import { parseArgs } from 'node:util';
import { spawn, spawnSync } from 'node:child_process';

function printUsage(): void {
  const scriptName = process.argv[1];
  console.log(`Usage: ${scriptName} [-t TITLE] [-s SUBTITLE] [-m MESSAGE] -- COMMAND [ARGS...]

Options:
  -t    Notification title (default: 'Notification')
  -s    Notification subtitle
  -m    Notification message (default: 'COMMAND finished')
  -h    Show this help message

Example: ${scriptName} -t 'Build' -- mvn clean verify
`);
}

const { values, positionals } = parseArgs({
  args: process.argv.slice(2),
  options: {
    title: { type: 'string', short: 't', default: 'Notification' },
    subtitle: { type: 'string', short: 's', default: '' },
    message: { type: 'string', short: 'm', default: '' },
    help: { type: 'boolean', short: 'h', default: false },
  },
  allowPositionals: true,
  strict: true,
});

if (values.help) {
  printUsage();
  process.exit(0);
}

if (positionals.length === 0) {
  printUsage();
  process.exit(1);
}

const [cmd, ...args] = positionals;
const message = values.message || `${positionals.join(' ')} finished`;

const proc = spawn(cmd, args, {
  stdio: 'inherit',
});

proc.on('close', (exitCode) => {
  const escapedTitle = values.title!.replace(/"/g, '\\"');
  const escapedSubtitle = values.subtitle!.replace(/"/g, '\\"');
  const escapedMessage = message.replace(/"/g, '\\"');

  if (!exitCode) {
    spawnSync('/usr/bin/osascript', [
      '-e',
      `display notification "${escapedMessage}" with title "${escapedTitle}" subtitle "${escapedSubtitle}" sound name "glass"`,
    ]);
  } else {
    spawnSync('/usr/bin/osascript', [
      '-e',
      `display notification "${escapedMessage}" with title "${escapedTitle}" subtitle "${escapedSubtitle}" sound name "basso"`,
    ]);
  }

  process.exit(exitCode ?? 0);
});
