#!/usr/bin/bash

# Install homebrew
/usr/bin/ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"

# this is the install script for my dotfiles. it should only be run once
# setup OSX specific preferences
source "$ATLAS_ROOT/init/.macos"
. "$ATLAS_ROOT/init/brew.sh"

# add a .hushlogin to ~ to prevent login messages
touch "$HOME/.hushlogin"


mkdir -p "$HOME/projects"
mkdir -p "$HOME/go"
