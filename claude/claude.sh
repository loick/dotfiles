#!/bin/sh

AGENTS_REPO="https://github.com/VoltAgent/awesome-claude-code-subagents.git"
AGENTS_CACHE="$HOME/.claude/agents-src"

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# CLAUDE.md
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

mkdir -p ~/.claude
ln -Fs "$(pwd)/claude/CLAUDE.md" ~/.claude/CLAUDE.md
echo "✔ Claude.md symlink"

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Agents (VoltAgent/awesome-claude-code-subagents)
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

if [ -d "$AGENTS_CACHE" ]; then
  git -C "$AGENTS_CACHE" pull --ff-only
else
  git clone "$AGENTS_REPO" "$AGENTS_CACHE"
fi

# Claude Code doesn't follow directory symlinks — ensure it's a real directory
[ -L ~/.claude/agents ] && rm ~/.claude/agents
mkdir -p ~/.claude/agents

AGENTS_LIST="$(pwd)/claude/agents.txt"
while IFS= read -r agent_name || [ -n "$agent_name" ]; do
  # Skip comments and blank lines
  case "$agent_name" in
    '#'*|'') continue ;;
  esac
  agent_file=$(find "$AGENTS_CACHE/categories" -name "${agent_name}.md" | head -1)
  if [ -n "$agent_file" ]; then
    cp "$agent_file" ~/.claude/agents/"${agent_name}.md"
  else
    echo "⚠ Agent not found: $agent_name"
  fi
done < "$AGENTS_LIST"
echo "✔ Claude agents installed globally"

# Claude Code bundles its own ripgrep binary to scan ~/.claude/agents/, ~/.claude/skills/,
# etc. for .md files. npm installs it without execute permissions, so Claude silently finds
# nothing. Fix it here so agents/skills/commands always load after a fresh npm install.
RG_BIN="$(npm root -g 2>/dev/null)/@anthropic-ai/claude-code/vendor/ripgrep/arm64-darwin/rg"
if [ -f "$RG_BIN" ] && [ ! -x "$RG_BIN" ]; then
  chmod +x "$RG_BIN"
  echo "✔ Fixed Claude bundled ripgrep permissions"
fi

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Custom Skills
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

SKILLS_SRC="$(pwd)/claude/skills"
SKILLS_DST="$HOME/.claude/skills"

mkdir -p "$SKILLS_DST"

for skill in "$SKILLS_SRC"/*; do
  name="$(basename "$skill")"
  [ "$name" = ".gitkeep" ] && continue
  cp -rf "$skill" "$SKILLS_DST/$name"
done
echo "✔ Custom skills copied"

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Remote Skills
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

SKILLS_LIST="$(pwd)/claude/skills.txt"

if command -v skills > /dev/null 2>&1 || npm install -g skills > /dev/null 2>&1; then
  # Group skills by repo and install in one call per repo
  grep -v '^\s*#' "$SKILLS_LIST" | grep -v '^\s*$' | awk '{repos[$1] = repos[$1] " --skill " $2} END {for (r in repos) print r repos[r]}' | while read -r cmd; do
    repo=$(echo "$cmd" | awk '{print $1}')
    skill_flags=$(echo "$cmd" | cut -d' ' -f2-)
    # shellcheck disable=SC2086
    skills add "$repo" $skill_flags -y
  done
  echo "✔ Remote skills installed"
else
  echo "⚠ Could not install skills CLI — skipping remote skills"
fi

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# MCP Servers
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

sh "$(pwd)/claude/setup-mcp.sh"
