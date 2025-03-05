#!/bin/sh

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# ZSH
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

ln -Fs "$(pwd)/zsh/.zshrc" ~/.zshrc

# Any file symlinked to ZSH custom directory will be automatically sourced.
# See https://github.com/ohmyzsh/ohmyzsh/issues/4865#issuecomment-401121707.
ln -Fs "$(pwd)/zsh/aliases.zsh" "$ZSH/custom/aliases.zsh"
ln -Fs "$(pwd)/zsh/env.zsh"     "$ZSH/custom/env.zsh"

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Git
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

mkdir -p ~/.config/git
ln -Fs "$(pwd)/git/.gitconfig"      ~/.gitconfig
ln -Fs "$(pwd)/git/.gitignore"      ~/.config/git/.gitignore
ln -Fs "$(pwd)/git/.git-commit.tpl" ~/.config/git/.git-commit.tpl

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Brew
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

if ! [ -x "$(command -v brew)" ]; then
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

brew bundle install --file "$(pwd)/Brewfile" --no-lock

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Applications
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

gh config set git_protocol ssh
gh config set editor "code --wait"
echo "✔ gh configured"

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# # MacOS Settings
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

defaults write com.apple.finder QuitMenuItem -bool true
echo "✔ Finder may be quit"

defaults write com.apple.finder AppleShowAllFiles true
echo "✔ Dotfiles shown in Finder"

defaults write com.apple.dock static-only -bool true
echo "✔ Dock now only show active applications"

defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad Clicking -bool true
defaults -currentHost write NSGlobalDomain com.apple.mouse.tapBehavior -int 1
defaults write NSGlobalDomain com.apple.mouse.tapBehavior -int 1
echo "✔ Tap to click configured"

defaults write com.apple.LaunchServices LSQuarantine -bool false
echo "✔ 'Are you sure you want to open this application?' dialog disabled"
