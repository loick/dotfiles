#!/bin/sh

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Env
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

if [ -f "$(pwd)/.env" ]; then
  set -a
  . "$(pwd)/.env"
  set +a
  echo "✔ .env loaded"
else
  echo "⚠ No .env file found — copy .env.example to .env and fill in your values"
fi

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# ZSH
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

ln -Fs "$(pwd)/zsh/.zshrc" ~/.zshrc

mkdir -p ~/.config/zsh
ln -Fs "$(pwd)/zsh/aliases.zsh" ~/.config/zsh/aliases.zsh
ln -Fs "$(pwd)/zsh/env.zsh"     ~/.config/zsh/env.zsh

if [ ! -d ~/.config/zsh/plugins/zsh-shift-select ]; then
  git clone https://github.com/jirutka/zsh-shift-select ~/.config/zsh/plugins/zsh-shift-select
  echo "✔ zsh-shift-select plugin installed"
fi

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Git
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

mkdir -p ~/.config/git
ln -Fs "$(pwd)/git/.gitconfig"      ~/.gitconfig
ln -Fs "$(pwd)/git/.gitignore"      ~/.config/git/.gitignore
ln -Fs "$(pwd)/git/.git-commit.tpl" ~/.config/git/.git-commit.tpl
ln -Fs "$(pwd)/git/.gitaliases"     ~/.config/git/.gitaliases

if [ -n "$GIT_USER_NAME" ] && [ -n "$GIT_USER_EMAIL" ]; then
  printf '[user]\n  name = %s\n  email = %s\n' "$GIT_USER_NAME" "$GIT_USER_EMAIL" > ~/.config/git/user.gitconfig
  echo "✔ Git user configured ($GIT_USER_NAME <$GIT_USER_EMAIL>)"
else
  echo "⚠ GIT_USER_NAME or GIT_USER_EMAIL not set — skipping git user config"
fi

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Brew
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

if ! [ -x "$(command -v brew)" ]; then
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  echo >> $(pwd)/.zprofile
  echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> $(pwd)/.zprofile
  eval "$(/opt/homebrew/bin/brew shellenv)"
fi

brew update
brew bundle install --file "$(pwd)/Brewfile"

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Applications
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

gh config set git_protocol ssh
gh config set editor "cursor --wait"
echo "✔ gh configured"

mkdir -p ~/.config
ln -Fs "$(pwd)/starship/starship.toml" ~/.config/starship.toml
echo "✔ Starship config linked"

mkdir -p ~/.config/ghostty
ln -Fs "$(pwd)/ghostty/config" ~/.config/ghostty/config
echo "✔ Ghostty config linked"

mkdir -p ~/Library/Application\ Support/Cursor/User
ln -Fs "$(pwd)/cursor/settings.json"    ~/Library/Application\ Support/Cursor/User/settings.json
ln -Fs "$(pwd)/cursor/keybindings.json" ~/Library/Application\ Support/Cursor/User/keybindings.json
echo "✔ Cursor config linked"

if [ -n "$CLEANSHOT_ACTIVATION_KEY" ]; then
  sed -e "s|__HOME__|$HOME|g" -e "s|__CLEANSHOT_ACTIVATION_KEY__|$CLEANSHOT_ACTIVATION_KEY|g" "$(pwd)/cleanshot/config.xml" | plutil -convert binary1 -o ~/Library/Preferences/pl.maketheweb.cleanshotx.plist -
  echo "✔ CleanShot config restored"
else
  echo "⚠ CLEANSHOT_ACTIVATION_KEY not set — skipping CleanShot config"
fi

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# LinearMouse
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

mkdir -p ~/.config/linearmouse
ln -Fs "$(pwd)/linearmouse/linearmouse.json" ~/.config/linearmouse/linearmouse.json


# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# # MacOS Settings
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

sh "$(pwd)/mac/install.sh"

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Claude
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

sh "$(pwd)/claude/claude.sh"
