#!/usr/bin/env bash
# Directories that dotbot's `create` step used to make. Idempotent.
set -e

mkdir -p "$HOME/src"

# ~/go was macOS-only in the old setup (install_dotfiles_once)
if [ "$(uname -s)" = "Darwin" ]; then
  mkdir -p "$HOME/go"
fi
