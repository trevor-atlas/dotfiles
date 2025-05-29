// Name: Normalize Git branch name
// Description: Normalized clipboard text into a valid Git branch name
// Author: Trevor Atlas

import '@johnlindquist/kit';

const delimiterChar = '-';
const illegalChar = '';

// not sure what purpose this really serves... especially 'illegalChar' which is an empty string
const mergableChars = [delimiterChar, illegalChar];
const edgePattern = /^[-\s]+|[-\s]+$/g;
const delimiterPattern = /\s+|_+|-+/g;

const illegalChars = /[^a-zA-Z0-9\-&\$\.]/g;
// not comprehensive, but a good start
const illegalPattern = /^-+|^\.|\/\.|\.\.|~|\^|:|\/$|\.lock$|\.lock\/|\\|\*|\?|@{|^@$|\.$|\[|\]$|^\/|\/$/g;

// Sanitize references
// https://github.com/microsoft/vscode/blob/main/extensions/git/src/commands.ts#L2182
// https://github.com/gitextensions/gitextensions/blob/6eab7392839c4d103bad1581fba5eaf6f008d766/GitCommands/Git/GitBranchNameNormaliser.cs
function sanitize(text: string) {
  const isInvalidChar =
    (!edgePattern.test(delimiterChar) && illegalPattern.test(delimiterChar)) ||
    (!edgePattern.test(illegalChar) && illegalPattern.test(illegalChar));

  if (isInvalidChar) {
    throw new Error('Invalid delimiter/illegal character!');
  }

  // really hate that this is mutable
  let sanitized = text
    .trim()
    .replace(delimiterPattern, delimiterChar)
    .replace(illegalPattern, illegalChar);

  for (const char of mergableChars) {
    sanitized = sanitized.replace(new RegExp(`\\${char}+`, 'g'), char);
  }
  return sanitized.replace(edgePattern, '').toLowerCase();
};

const input = await paste();

try {
  const branchName = sanitize(input);

  if (!branchName) {
    throw new Error('Invalid input!');
  }
  await copy(branchName);
} catch (error) {
  const hint = `${error.message}`;
  await editor({ hint, input, description: 'ERROR', readOnly: true, lineNumbers: 'on' });
  exit();
}


