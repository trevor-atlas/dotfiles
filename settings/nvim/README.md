# neovim config

Neovim configuration lives under the following paths:

| OS | Path |
| :- | :--- |
| Linux | `$XDG_CONFIG_HOME/nvim`, `~/.config/nvim` |
| macOS | `$XDG_CONFIG_HOME/nvim`, `~/.config/nvim` |
| Windows | `%userprofile%\AppData\Local\nvim\` |

## Plugin management

This config uses Neovim's built-in `vim.pack` plugin manager.

Plugins are tracked in:

- `nvim-pack-lock.json`

On first startup, `vim.pack` installs missing plugins from the lockfile.

To review and apply plugin updates:

```sh
nvim
:lua vim.pack.update()
```

## Post installation

Start Neovim:

```sh
nvim
```

## Install Neovim nightly

```sh
brew install --HEAD neovim
```
