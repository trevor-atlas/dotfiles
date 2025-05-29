// Name: humanlike typing
// Description: Type the contents of your clipboard as if you were a human
// Author: Trevor Atlas
// Twitter: @trevoratlas

import "@johnlindquist/kit"

await hide();

await applescript(String.raw`
set texttowrite to the clipboard as text
tell application "System Events"
  repeat with i from 1 to count characters of texttowrite
    if (character i of texttowrite) is equal to linefeed or (character i of texttowrite) is equal to return & linefeed or (character i of texttowrite) is equal to return then
      keystroke return
    else
      keystroke (character i of texttowrite)
    end
    if (character i of texttowrite) is equal to " " then
      delay (random number from 0.01 to 0.1)
    else if (character i of texttowrite) is equal to "\n" then
      delay (random number from 0.1 to 0.3)
    else
      delay (random number from 0.01 to 0.05)
    end
  end repeat
end tell
`);
