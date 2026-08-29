# AGENTS.md

This file provides guidance to AI coding agents working with code in this repository.

## Repository Overview

This repository contains dotfiles and configuration files managed by a user named Trevor Atlas. It uses [chezmoi](https://chezmoi.io) for installation and management of dotfiles. The repository contains configurations for:

- Shell environments (primarily zsh)
- Text editors (Neovim, Emacs)
- Terminal emulators (Alacritty, Kitty, iTerm2)
- Window managers (Yabai, skhd, i3)
- Zellij (terminal multiplexing)
- Git configuration
- Various utility scripts and functions
- macOS system preferences
- Raycast scripts

## Key Components

- **settings/**: The chezmoi source state (wired in via `.chezmoiroot`). `dot_*` files map to `~/.`, `dot_config/*` to `~/.config/*`; OS-specific files are gated by `.chezmoiignore` templates; `run_once_*` scripts handle one-time setup (dirs, macOS defaults + Homebrew). chezmoi runs in `mode = "symlink"` (set in the generated `~/.config/chezmoi/chezmoi.toml`), so static files are applied as symlinks back into `settings/` and edits to the deployed file edit the repo directly. Templates (`*.tmpl`), modify-templates (`modify_*`), and scripts (`run_once_*`) are still copied/rendered, never symlinked — so sensitive/generated files are never live-linked. New files still need a one-time `chezmoi add`.
- **index**: Main shell entry point, sourced from `~/.zshrc`
- **source/**: Shell scripts sourced by `index`
- **functions/**: Standalone utility scripts
- **init/**: Setup scripts referenced by the `run_once_*` chezmoi scripts
- **scripts/**: Standalone utilities (Raycast, applescript, zellij switchers)

## Installation Process

The repository is designed to be installed at `~/.config/atlas` with:

```bash
git clone https://github.com/trevor-atlas/dotfiles ~/.config/atlas &&\
echo "source $HOME/.config/atlas/index" >> .zshrc &&\
source "$HOME/.zshrc" &&\
sh ~/.config/atlas/install
```

This will:
1. Clone the repository to `~/.config/atlas`
2. Add a source line to the user's `.zshrc`
3. Reload the shell configuration
4. Run the `install` script, which bootstraps chezmoi (installing it if needed, writing `~/.config/chezmoi/chezmoi.toml` to point at the repo) and applies the source state

## Common Commands

### Dotfiles Management

- **`install_dotfiles`**: Re-run the chezmoi bootstrap (`sh ~/.config/atlas/install`)
- **`install_dotfiles_once`**: Full one-time setup — delegates to `install_dotfiles`; chezmoi's `run_once_*` scripts handle macOS prefs and Homebrew on first apply
- **`chezmoi diff` / `chezmoi apply` / `chezmoi add ~/.file` / `chezmoi update`**: Standard chezmoi workflow (config at `~/.config/chezmoi/chezmoi.toml` points at this repo)

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

### Tmux/Zellij Session Management

- **`bool`**: Launch or reconnect to main tmux session with predefined windows
- **`unbool`**: Kill tmux server
- **`zbool`**: Zellij version of `bool`

## Environment Variables

Key environment variables:
- `ATLAS_ROOT`: Base directory for dotfiles (defaults to `~/.config/atlas`)
- `ATLAS_NOTES_DIR`: Directory for notes — auto-detected Obsidian vault via `obsidian_vault()` (Obsidian's registry, then common locations, then `~/Dropbox/notes`); WSL-aware (Windows drive paths → `/mnt/<drive>/…`)
- `ATLAS_PROJECTS_DIR`: Directory for code repositories
- `CODE_DIR`: Alias for source code repositories (typically `~/src`)
- `DEEPSEEK_API_KEY`: pi provider key, injected into `~/.pi/agent/models.json` by a chezmoi template (never commit the raw key)
- `OPENAI_API_KEY`: pi provider key, injected into `~/.pi/agent/models.json` by a chezmoi template (never commit the raw key)

## Pi config

When working in pi config, extensions, packages, skills, script placement, or wiring under
`~/.pi/agent/`, read `settings/dot_pi/agent/README.md` first — it maps the directory, the
chezmoi manage/ignore boundaries (incl. herdr-managed vs repo-managed), and the
extension discovery/import-alias rules.

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
