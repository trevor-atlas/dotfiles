#!/usr/bin/env bash
# One-time macOS setup, run on the first `chezmoi apply` on a new Mac.
# Replaces install_dotfiles_once() + the dotbot `install` shell steps.
# Single source of truth: the existing init/ scripts are sourced, not duplicated.
set -e

if [ "$(uname -s)" != "Darwin" ]; then
  exit 0
fi

setup_marker="$HOME/.macos-setup-complete"
if [ -f "$setup_marker" ]; then
  echo "macOS setup already completed; skipping. Remove $setup_marker to rerun intentionally."
  exit 0
fi

# Homebrew (modern installer; the old ruby one-liner no longer exists)
if ! command -v brew >/dev/null 2>&1; then
  echo "==> Installing Homebrew …"
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

# init/macos ends with `source ./brew`, so it must run with cwd = init/
cd "$HOME/.config/atlas/init" || exit 1
source ./macos

# npm package-manager preferences that used to live in install_dotfiles_once
npm set fund false 2>/dev/null || true
npm set audit false 2>/dev/null || true

# was a top-level step of the old dotbot `install` script
defaults write -g ApplePressAndHoldEnabled -bool false

# Record completion only after every setup step above has succeeded. Write the
# marker atomically so an interrupted write cannot suppress a later rerun.
marker_tmp="$(mktemp "${setup_marker}.tmp.XXXXXX")"
printf 'macOS setup completed on %s\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" > "$marker_tmp"
mv -f "$marker_tmp" "$setup_marker"
echo "Created macOS setup completion marker at $setup_marker"
