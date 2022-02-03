# My dotfiles

## Dependencies

### [Brew](https://brew.sh)
Follow install directions

### [oh-my-zsh](https://ohmyz.sh)
`sh -c "$(curl -fsSL https://raw.githubusercontent.com/robbyrussell/oh-my-zsh/master/tools/install.sh)"`

### [hub](https://hub.github.com)
`brew install hub`

### [Tmux plugin manager](https://github.com/tmux-plugins/tpm)
`git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm`

## Installation
```
git clone https://github.com/trevor-atlas/config ~/.config/atlas &&\
echo "source $HOME/.config/atlas/index" >> .zshrc &&\
source "$HOME/.zshrc" &&\
sh ~/.config/atlas/install
```

This will:
1. clone this repository into ~/.config/atlas
2. source the index file that exports all of the aliases, functions and environment variables
3. copy all relevant configurations to their home
