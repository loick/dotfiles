# History
HISTFILE=~/.zsh_history
HISTSIZE=10000
SAVEHIST=10000
setopt SHARE_HISTORY
setopt HIST_IGNORE_ALL_DUPS
setopt HIST_REDUCE_BLANKS

# Completion
autoload -Uz compinit && compinit

# Brew
export PATH="/opt/homebrew/bin:$PATH"
export PATH=/usr/local/bin:$PATH

export ANDROID_HOME=$HOME/Library/Android/sdk
export PATH=$PATH:$ANDROID_HOME/emulator
export PATH=$PATH:$ANDROID_HOME/platform-tools

# Plugins
source /opt/homebrew/share/zsh-autosuggestions/zsh-autosuggestions.zsh
source ~/.config/zsh/plugins/zsh-shift-select/zsh-shift-select.plugin.zsh

# Custom config
source ~/.config/zsh/aliases.zsh
source ~/.config/zsh/env.zsh

# Apps
function cursor {
  open -a "/Applications/Cursor.app" "$@"
}
export CLAUDE_CODE_EXECUTABLE="/opt/homebrew/bin/claude"
eval "$(mise activate zsh)"
eval "$(starship init zsh)"

# TELEMETRY DISABLED
export RTK_TELEMETRY_DISABLED=1
export KUBB_DISABLE_TELEMETRY=1

# NVM (Lucis)
export NVM_DIR="$HOME/.nvm"
[ -s "/opt/homebrew/opt/nvm/nvm.sh" ] && \. "/opt/homebrew/opt/nvm/nvm.sh"
[ -s "/opt/homebrew/opt/nvm/etc/bash_completion.d/nvm" ] && \. "/opt/homebrew/opt/nvm/etc/bash_completion.d/nvm"

eval "$(zoxide init zsh --cmd cd)"
