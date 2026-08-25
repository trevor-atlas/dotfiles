# Dotfiles

Managed with [chezmoi](https://chezmoi.io). The source state lives in
[`settings/`](settings/) (wired in via the `.chezmoiroot` file at the repo root);
everything else in this repo is either live shell config (`index`, `source/`,
`functions/`) or tooling (`scripts/`, `raycast/`).

## Requirements

- [Brew](https://brew.sh) — follow install directions (macOS)
- [oh-my-zsh](https://ohmyz.sh)
- [gh](https://cli.github.com) — used by the git credential helper in `.gitconfig`
- [tpm](https://github.com/tmux-plugins/tpm) — `git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm`

## Installation

```
git clone https://github.com/trevor-atlas/dotfiles ~/.config/atlas &&\
echo "source $HOME/.config/atlas/index" >> .zshrc &&\
source "$HOME/.zshrc" &&\
sh ~/.config/atlas/install
```

This will:
1. clone the repo into `~/.config/atlas`
2. source `index` (aliases, functions, environment variables)
3. install chezmoi if needed (via Homebrew on macOS, so it lands on PATH),
   write `~/.config/chezmoi/chezmoi.toml` pointing at the repo (with
   `mode = "symlink"`, see below), and apply the source state — configs
   everywhere, plus (on macOS, once) Homebrew and system prefs via the
   `run_once_*` scripts

## Symlink mode

chezmoi runs in `mode = "symlink"` (set in the generated
`~/.config/chezmoi/chezmoi.toml`). Static config files are applied as symlinks
pointing back into `settings/`, so editing e.g. `~/.vimrc` or `~/.config/nvim/*`
edits the repo file directly — no `chezmoi add`/`apply` round-trip to keep them
in sync.

chezmoi still copies/renders anything that can't be a symlink:

- templates (`*.tmpl`, e.g. `dot_gitconfig.tmpl`, `dot_pi/agent/models.json.tmpl`)
- modify-templates (`modify_*`) and scripts (`run_once_*`)

so nothing sensitive is ever live-linked out of the repo.

Caveats:

- A brand-new file still needs `chezmoi add ~/.somefile` once to bring it under
  management; after that it's symlinked and stays live.
- If a tool saves by writing a temp file and renaming over the target, it
  replaces the symlink with a regular file. Re-run `chezmoi apply` to restore the
  link. (Vim does this for its own files — `set backupcopy=yes` avoids it.)

## Zellij

Installed via Brewfile and configured at `settings/dot_config/zellij`. Use
`zbool` for the Zellij version of the main `Bool` workspace (`zellij-tab-switcher`
and `zellij-pane-switcher` live in `scripts/`).

## Pi provider key

`~/.pi/agent/models.json` is a template that reads the DeepSeek and OpenAI keys
from the `DEEPSEEK_API_KEY` and `OPENAI_API_KEY` environment variables
(the keys themselves are never in the repo).
Export them on each machine before applying, e.g. in your shell profile:

```
export DEEPSEEK_API_KEY=...
export OPENAI_API_KEY=...
```

## Daily use

| Task | Command |
|---|---|
| See what would change | `chezmoi diff` |
| Apply changes | `chezmoi apply` |
| Track a new/changed file | `chezmoi add ~/.somefile` |
| Pull + apply upstream changes | `chezmoi update` |
| Full bootstrap again | `install_dotfiles` (or `sh ~/.config/atlas/install`) |
