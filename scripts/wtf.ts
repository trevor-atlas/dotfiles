#!/usr/bin/env ts-node

import { execSync } from 'child_process';
import { FgGreen, FgRed, Reset } from './colors';

class Logger {
  constructor(private prefix: string) {}

  print(...msgs: any[]) {
    process.stdout.write(`${this.prefix} ${msgs.join(' ')}\n`);
  }

  error(...msgs: any[]) {
    process.stderr.write(`${this.prefix} ${FgRed}${msgs.join(' ')}${Reset}\n`);
  }

  success(...msgs: any[]) {
    process.stdout.write(
      `${this.prefix} ${FgGreen}${msgs.join(' ')}${Reset}\n`
    );
  }
}

const cmd = `gh issue list --label 'FE' --repo HubSpot/Billing-Management-Team --json assignees,author,body,closed,closedAt,comments,createdAt,id,labels,milestone,number,state,title,updatedAt,url`;

const logger = new Logger('[🐈]');

(async function main() {
  try {
    const res = await execSync(cmd);
    const issues = JSON.parse(res.toString());
    if (!issues.length) {
      logger.error('No issues found.');
      process.exit(1);
    }
  } catch (e) {
    handleError(e);
  }
})();

function handleError(error: unknown) {
  if (error instanceof Error) {
    logger.error(
      'error',
      error.message ? error.message : JSON.stringify(error)
    );
  } else if (typeof error === 'string') {
    logger.error(error);
  } else {
    logger.error('Unknown error', JSON.stringify(error));
  }

  process.exit(1);
}
