// Menu: De-Acronym-ify
// Description: Replace acronyms with their full names
// Author: Trevor Atlas
// Twitter: @trevoratlas
// Shortcut: cmd ctrl opt shift a
// Group: work

import '@johnlindquist/kit';

let text = '';
const clipboardValue = await paste();
const selection = await getSelectedText();

if (selection) {
  text = selection;
  console.log('use selection', selection);
}

if (clipboardValue && !selection) {
  text = clipboardValue;
  console.log('use clipboard', text);
}

if (!text) {
  text = await arg('Enter text to de-acronym-ify');
  console.log('use prompt', text);
}

const acronyms: Array<[string | RegExp, string]> = [
  ['PD', 'Product Design'],
  ['PM', 'Product Management'],
  ['JS', 'JavaScript'],
  ['TS', 'TypeScript'],
];

const result = acronyms.reduce(
  (acc, [acronym, expansion]) => acc.replace(acronym, expansion),
  text
);

if (!selection) {
  copy(result);
} else {
  await setSelectedText(result);
}
