#!/usr/bin/env node

import { existsSync, readdirSync, statSync } from 'fs';
import { join } from 'path';
import { homedir } from 'os';

type BendProjectDescriptor = {
  reactorDirectories: string[];
  sessionPath: string;
  instanceId: string;
};

export function getArgs() {
  return process.argv.slice(2);
}

export function getProjectConfig(project_root: string, instance_id: string) {
  if (!project_root && !instance_id) {
  }
  if (!project_root) {
    console.error('Error: No project_root given');
    process.exit(1);
  }
  if (!instance_id) {
    console.error('Error: No instance_id given');
    process.exit(1);
  }
  if (!existsSync(join(project_root, '.git'))) {
    console.error(
      'Error: Not a git repository (no .git directory found in ${project_root})',
    );
    process.exit(1);
  }

  const result: BendProjectDescriptor = {
    reactorDirectories: [],
    sessionPath: getSessionPath(instance_id),
    instanceId: instance_id,
  };

  for (const entry of readdirSync(project_root)) {
    const e = join(project_root, entry);
    if (!statSync(e).isDirectory()) {
      continue;
    }

    const hasTsConfig = existsSync(join(e, 'tsconfig.json'));
    const hasStaticDir =
      existsSync(join(e, 'static')) &&
      statSync(join(e, 'static')).isDirectory();

    if (hasTsConfig && hasStaticDir) {
      result.reactorDirectories.push(e);
    }
  }

  return result;
}

export function getSessionPath(id: string) {
  return join(homedir(), '.hubspot/bend-sessions', `zed-${id}.json`);
}

function main() {
  let [command, ...args] = getArgs();

  let [project_root, instance_id] = args;

  const config = getProjectConfig(project_root, instance_id);

  switch (command) {
    case 'get-session-path':
      console.log(getSessionPath(instance_id));
      break;
    case 'get-bend-command':
      // `/opt/homebrew/bin/bend reactor host --update --session-path "${config.sessionPath}" ${config.reactorDirectories.join(' ')`,
      console.log(config.reactorDirectories.join(' '));
      break;
    default:
      console.error(`Usage: node bend-zed.ts <command> <...args>
  Arguments:
    project_root: a fully qualified filesystem path
    instance_id: a unique identifier for this editor instance.
`);
      process.exit(1);
  }
}

main();

// function run() {
//   const config = getHsProjectDirectories();

//   // console.log(
//   //   `starting bend host with config${JSON.stringify(config, null, 2)}`,
//   // );
//   const bend_host = spawn(
//     // must use fully qualified path since we do not receive the full PATH env
//     '/opt/homebrew/bin/bend',
//     [
//       'reactor',
//       'host',
//       '--update',
//       '--session-path',
//       config.sessionPath,
//       ...config.reactorDirectories,
//     ],
//     { env: { BEND_SESSION_PATH: config.sessionPath, ...process.env } },
//   );

//   // bend_host.stdout.on('data', (data) => {
//   //   console.log(`stdout: ${data}`);
//   // });

//   // bend_host.stderr.on('data', (data) => {
//   //   console.error(`stderr: ${data}`);
//   // });

//   bend_host.on('close', (code) => {
//     // console.log(`child process exited with code ${code}`);
//     process.exit(code);
//   });

//   console.log(config.sessionPath);
// }
//
