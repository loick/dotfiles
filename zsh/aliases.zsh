alias k="kubectl"
alias n="sudo n"
alias la="eza -la --icons --git"
alias cat="bat"
alias y="yarn"
alias grep="rg"
alias p="pnpm"

# Typescript Reset + Force
alias tsr="rm **/tsconfig.tsbuildinfo && y typecheck --force"

# System fixes
alias fixtcc='sudo killall tccd; killall ghostty; sleep 1; open -a Ghostty'
alias fixaudio='sudo killall coreaudiod'
