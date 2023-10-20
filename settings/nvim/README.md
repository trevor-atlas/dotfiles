# neovim config

Neovim's configurations are located under the following paths, depending on your OS:

| OS | PATH |
| :- | :--- |
| Linux | `$XDG_CONFIG_HOME/nvim`, `~/.config/nvim` |
| MacOS | `$XDG_CONFIG_HOME/nvim`, '~/.config/nvim` |
| Windows | `%userprofile%\AppData\Local\nvim\` |


### Post Installation

Run the following command and then **you are ready to go**!

```sh
nvim --headless "+Lazy! sync" +qa
```
