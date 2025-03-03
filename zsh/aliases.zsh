# Set personal aliases, overriding those provided by oh-my-zsh libs,
# plugins, and themes. Aliases can be placed here, though oh-my-zsh
# users are encouraged to define aliases within the ZSH_CUSTOM folder.
# For a full list of active aliases, run `alias`.
#
# Example aliases
# alias zshconfig="mate ~/.zshrc"
# alias ohmyzsh="mate ~/.oh-my-zsh"

alias where='git ls-tree -r HEAD | grep'
alias k="kubectl"
alias n="sudo n"
alias la="ls -la"
alias cat="bat"
alias y="yarn"
alias grep="rg"
alias cd="z"
alias p="pnpm"

# Graphite
function gcreate() {
  gt create $1 --all --ai
}
alias gsubmit="gt submit --publish --ai --web false --no-edit"
