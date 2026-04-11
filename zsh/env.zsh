#!/bin/zsh

export PATH="$PATH:./node_modules/.bin"
export EDITOR="code --wait"

# Make Option+Arrow word movement behave like a text editor:
# stop at the end of the current word, not the start of the next one.
# Words = alphanumeric + underscore. Everything else is a boundary.
autoload -U select-word-style
select-word-style bash
