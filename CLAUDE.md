# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This repository contains dotfiles and configuration files managed by a user named Trevor Atlas. It uses [Dotbot](https://github.com/anishathalye/dotbot) for installation and management of dotfiles. The repository contains configurations for:

- Shell environments (primarily zsh)
- Text editors (Neovim, Emacs)
- Terminal emulators (Alacritty, Kitty, iTerm2)
- Window managers (Yabai, skhd)
- Git configuration
- Various utility scripts and functions
- macOS system preferences
- Raycast scripts

## Key Components

- **dotbot/**: Submodule for managing dotfiles
- **install.conf.yaml**: Configuration for dotbot that specifies which files to symlink
- **settings/**: Contains configuration files for various applications
- **source/**: Shell scripts that get sourced by the main `index` file
- **functions/**: Standalone utility scripts
- **init/**: Setup scripts for different environments

## Installation Process

The repository is designed to be installed at `~/.config/atlas` with:

```bash
git clone https://github.com/trevor-atlas/config ~/.config/atlas &&\
echo "source $HOME/.config/atlas/index" >> .zshrc &&\
source "$HOME/.zshrc" &&\
sh ~/.config/atlas/install
```

This will:
1. Clone the repository to `~/.config/atlas`
2. Add a source line to the user's `.zshrc`
3. Reload the shell configuration
4. Run the `install` script which uses Dotbot to create symlinks

## Common Commands

### Dotfiles Management

- **`install_dotfiles`**: Re-run the dotbot installation process
- **`install_dotfiles_once`**: Initial setup including macOS preferences, homebrew packages

### Utility Functions

- **File/Directory Management**:
  - `mkd`: Create and enter a new directory
  - `fs`: Show file/directory size
  - `extract`: Extract most known archives with one command
  - `v`: Quick shortcut to open files in Neovim

- **Note Taking**:
  - `nn`: Create/edit a note in `$ATLAS_NOTES_DIR`
  - `ns`: Search note contents
  - `nl`: Search note filenames

- **Git Helpers**:
  - `gch`: Interactive branch checkout with fzf
  - `gpub`: Publish current branch to origin
  - `git_clean`: Clean up merged branches
  - `gitb`: Create and switch to a new branch
  - `repo`: Clone or navigate to a repository
  - `update_repos`: Update all repositories in `$CODE_DIR`

- **Media Conversion**:
  - `convert_aiff`, `convert_gif`, `convert_webm`, `jpg_to_video`: Various media conversion utilities

### Tmux Session Management

- **`bool`**: Launch or reconnect to main tmux session with predefined windows
- **`unbool`**: Kill tmux server

## Environment Variables

Key environment variables:
- `ATLAS_ROOT`: Base directory for dotfiles (defaults to `~/.config/atlas`)
- `ATLAS_NOTES_DIR`: Directory for notes
- `ATLAS_PROJECTS_DIR`: Directory for code repositories
- `CODE_DIR`: Alias for source code repositories (typically `~/src`)

## Git Workflow

A custom commit helper is available via the `commit` function, which uses [gum](https://github.com/charmbracelet/gum) to create conventional commit messages.

## macOS Configuration

The repository includes comprehensive macOS settings in `init/macos` that configure:
- System preferences
- Finder behavior
- Dock settings
- Safari preferences
- Security settings
- And many other macOS-specific optimizations
