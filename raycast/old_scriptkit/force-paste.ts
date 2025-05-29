// Name: force paste
// Description: Paste the contents of your clipboard, even in fields that wouldn't let you paste
// Author: Trevor Atlas
// Twitter: @trevoratlas
// test it out on the email field here: https://codepen.io/andersschmidt/pen/kOOMmw

import "@johnlindquist/kit"

await hide();
await applescript(`tell application "System Events" to keystroke the clipboard as text`);
