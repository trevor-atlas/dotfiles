#!/usr/bin/env bash
# PAI (Personal AI Infrastructure) Configuration
# Location: ~/.config/atlas/pai.sh

# PAI Environment
export PAI_DIR="$HOME/.config/atlas/pai"
export DA="Oni"
export PAI_SOURCE_APP="$DA"

# Alias for restoring PAI hooks after system management resets ~/.claude
alias pai-restore='bun run $PAI_DIR/inject-hooks.ts'

# Quick check if PAI hooks are installed
pai-status() {
  if grep -q "atlas/pai/hooks" ~/.claude/settings.json 2>/dev/null; then
    echo "✅ PAI hooks are installed"
  else
    echo "❌ PAI hooks not found in settings.json"
    echo "   Run: pai-restore"
  fi
}
