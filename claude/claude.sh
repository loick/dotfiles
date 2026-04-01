#!/bin/sh

AGENTS_REPO="https://github.com/contains-studio/agents.git"
AGENTS_DIR="$(pwd)/claude/agents"

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# CLAUDE.md
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

mkdir -p ~/.claude
ln -Fs "$(pwd)/claude/CLAUDE.md" ~/.claude/CLAUDE.md
echo "✔ Claude.md symlink"

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Agents (contains-studio/agents)
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

if [ -d "$AGENTS_DIR" ]; then
  git -C "$AGENTS_DIR" pull --ff-only
else
  git clone "$AGENTS_REPO" "$AGENTS_DIR"
fi

ln -Fs "$AGENTS_DIR" ~/.claude/agents
echo "✔ Claude agents symlink"

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# MCP Servers
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

sh "$(pwd)/claude/setup-mcp.sh"
