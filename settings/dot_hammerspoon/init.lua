-- Hammerspoon config
-- Push-to-talk dictation into a new pi session via Handy + handy-pi.ts.
--
-- Hold the hotkey to record (Handy captures while held), release to transcribe
-- and hand the text to pi. Uses hs.hotkey's separate pressed/released callbacks,
-- which is the only reliable way to get true "record while held" on macOS.

local home = os.getenv("HOME")
local bun = home .. "/.bun/bin/bun"
local handyPi = home .. "/.config/atlas/scripts/handy-pi.ts"

-- Give the spawned bun/pi/pkill a usable PATH (hs.task starts with a minimal env).
local env = {
  PATH = "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:" .. home .. "/.bun/bin",
  HOME = home,
}

local function runHandyPi(args)
  local full = { handyPi }
  for _, a in ipairs(args) do
    full[#full + 1] = a
  end
  local task = hs.task.new(bun, nil, full)
  task:setEnvironment(env)
  task:start()
end

-- ⌃⌥⌘D — hold to record, release to open pi seeded with the transcript.
-- Change the mods/key to taste. Pick something that doesn't clash with Handy's
-- own bindings (⌥Space transcribe, ⌥⇧Space post-process).
hs.hotkey.bind(
  { "ctrl", "alt", "cmd" },
  "d",
  function() runHandyPi({ "start" }) end, -- key down
  function() runHandyPi({ "stop" }) end   -- key up
)

-- Variant: hold to dictate and get a one-shot pi answer copied to the clipboard.
-- hs.hotkey.bind(
--   { "ctrl", "alt", "cmd" },
--   "s",
--   function() runHandyPi({ "start" }) end,
--   function() runHandyPi({ "stop", "--print" }) end
-- )

hs.alert.show("handy-pi loaded")
