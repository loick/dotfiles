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

# Copy zsh selection to system clipboard
function shift-select::copy-region() {
  if ((REGION_ACTIVE)); then
    local start=$MARK end=$CURSOR
    if ((start > end)); then local tmp=$start; start=$end; end=$tmp; fi
    print -rn -- "${BUFFER[$start+1,$end]}" | pbcopy
    zle deactivate-region -w
    zle -K main
  fi
}
zle -N shift-select::copy-region

# Type over selection: delete selected text then process the key
function shift-select::replace-region() {
  zle kill-region -w
  zle -K main
  zle -U "$KEYS"
}
zle -N shift-select::replace-region
bindkey -M shift-select -R '^@'-'^?' shift-select::replace-region

# Bind Cmd+C (sent as custom escape from Ghostty) to copy selection.
# Bound in emacs keymap too so the escape is swallowed (no-op when no region),
# otherwise '^[y' triggers yank-pop and 'c' leaks as literal text.
bindkey -M emacs '^[yc' shift-select::copy-region
bindkey -M shift-select '^[yc' shift-select::copy-region

# Bind Cmd+Shift+Left/Right (sent as custom escapes from Ghostty) to select to line boundaries
bindkey -M emacs '^[yl' shift-select::beginning-of-line
bindkey -M shift-select '^[yl' shift-select::beginning-of-line
bindkey -M emacs '^[yr' shift-select::end-of-line
bindkey -M shift-select '^[yr' shift-select::end-of-line

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

export _ZO_DOCTOR=0 # Claude Code shell integration triggers a false positive
eval "$(zoxide init zsh --cmd cd)"
