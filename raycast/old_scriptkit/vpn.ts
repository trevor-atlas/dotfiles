// Name: vpn
// Schedule: */15 * * * *
// Author: Trevor Atlas
// Twitter: @trevoratlas
// Group: work

import "@johnlindquist/kit"

applescript(`
tell application "System Events" to tell process "GlobalProtect"
	set connectionStatus to get help of every menu bar item of menu bar 2
	if item 1 of connectionStatus contains "Not Connected" then
		-- Activates the GlobalProtect panel in the menubar
		click menu bar item 1 of menu bar 2
		delay(0.1)
		try
			click button "Connect" of window 1
		end try
		delay(0.1)
		-- close the GlobalProtect panel after clicking Connect/Disconnect.
		click menu bar item 1 of menu bar 2
	end if
end tell
`);

