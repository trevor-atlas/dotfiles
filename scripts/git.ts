import { $ } from 'bun';
import { select } from '@inquirer/prompts';

const replacements = {
  $: 'dollars', // Match one or more '$' characters
  '&&': 'and', // Match one or more '&' characters
  '&': 'and', // Match one or more '&' characters
  '*': 'x',
  '++': 'increment',
  '+': 'plus',
  '===': 'equals',
  '==': 'equals',
  '=': 'eq',
  '://': '_',
} satisfies Record<string, string>;

function sanitizeIssueTitle(issueTitle: string): string {
  // Replace specific characters with their 'smart' counterparts

  for (const [pat, value] of Object.entries(replacements)) {
    issueTitle = issueTitle.replace(pat, value);
  }
  return (
    issueTitle
      // spaces to hyphens
      .replace(/\s+/gm, '-')
      // Remove or replace all other characters not allowed in git branch names
      .replace(/[^a-zA-Z0-9.\-/_]/g, '')
      .toLowerCase()
  );
}

const repo = 'HubSpot/Billing-Management-Team';
const team_acronym = 'BLT';
const username = 'tatlas';

// the crazy sed here is stripping any terminal color codes out so that
// the json can be cleanly parsed
const issue_list =
  await $`TERM=xterm-mono GH_FORCE_TTY=true gh issue list --repo ${repo} --assignee '@me' --json=title,number | cat | sed -r 's/[\x1B\x9B][][()#;?]*(([a-zA-Z0-9;]*\x07)|([0-9;]*[0-9A-PRZcf-ntqry=><~]))//g'`.json();
console.log(issue_list);

const { number, title } = await select({
  message: 'Select an issue to create a branch from',
  choices: issue_list.map((issue) => ({
    name: `${issue.number} ${issue.title}`,
    value: issue,
  })),
});

const branch_name = `${username}/${team_acronym}-${number}/${sanitizeIssueTitle(
  title
)}`;

console.log(branch_name);
console.log('----------------------------');
