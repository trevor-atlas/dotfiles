#!/usr/bin/env bash

# Install command-line tools using Homebrew.

# Make sure we’re using the latest Homebrew.
brew update

# Upgrade any already-installed formulae.
brew upgrade

# Install GNU core utilities (those that come with macOS are outdated).
# Don’t forget to add `$(brew --prefix coreutils)/libexec/gnubin` to `$PATH`.
brew install coreutils

# Install some other useful utilities like `sponge`.
brew install moreutils
# Install GNU `find`, `locate`, `updatedb`, and `xargs`, `g`-prefixed.
brew install findutils
# Install GNU `sed`, overwriting the built-in `sed`.
brew install gnu-sed --with-default-names
# Install `wget` with IRI support.
brew install wget --with-iri

# Install more recent versions of some macOS tools.
brew install vim --with-override-system-vi
brew install grep
brew install ripgrep
brew install openssh
brew install screen

# Install other useful binaries.
brew install ack
brew install git
brew install git-lfs
brew install imagemagick --with-webp
brew install tree
brew install neovim
brew install redis
brew install node
brew install go
brew install ccat
brew install openconnect
brew install openssl
brew install docker
brew install heroku
brew install watchman
brew install exa
brew install htop
brew install yarn
brew install hub
brew install postgresql
brew install z
brew install readline
brew install xz
brew install pyenv
brew install pyenv-virtualenv
brew install exa
brew install nvm
brew install hub


# install casks (desktop applications)
brew cask install alfred
brew cask install bartender
brew cask install betterzipql
brew cask install brave
brew cask install docker
brew cask install dropbox
brew cask install firefox
brew cask install flux
brew cask install font-fira-code
brew cask install github
brew cask install google-chrome
brew cask install intellij-idea-ce
brew cask install iterm2
brew cask install macvim
brew cask install ngrok
brew cask install postman
brew cask install psequel
brew cask install qlcolorcode
brew cask install qlimagesize
brew cask install qlmarkdown
brew cask install qlstephen
brew cask install qlvideo
brew cask install quicklook-csv
brew cask install quicklook-json
brew cask install quicklookase
brew cask install react-native-debugger
brew cask install slack
brew cask install spectacle
brew cask install spotify
brew cask install suspicious-package
brew cask install visual-studio-code
brew cask install webpquicklook
brew cask install font-hack-nerd-font
brew cask install zoomus


# Remove outdated versions from the cellar.
brew cleanup
