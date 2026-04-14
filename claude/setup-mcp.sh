#!/bin/sh

SETTINGS="$HOME/.claude/settings.json"
MCP_FILE="$HOME/.claude.json"

# Ensure files exist with valid JSON
if [ ! -f "$SETTINGS" ]; then
  echo "{}" > "$SETTINGS"
fi
if [ ! -f "$MCP_FILE" ]; then
  echo "{}" > "$MCP_FILE"
fi

# Add an MCP server if it doesn't already exist.
# Usage: add_mcp <name> <json-object>
add_mcp() {
  name="$1"
  config="$2"

  existing=$(jq -r --arg name "$name" '.mcpServers[$name] // empty' "$MCP_FILE")
  if [ -n "$existing" ]; then
    echo "  ↳ MCP '$name' already configured, skipping"
    return
  fi

  tmp=$(mktemp)
  jq --arg name "$name" --argjson config "$config" \
    '.mcpServers[$name] = $config' "$MCP_FILE" > "$tmp" && mv "$tmp" "$MCP_FILE"
  echo "  ✔ MCP '$name' added"
}

# Add a permission if it doesn't already exist.
# Usage: add_permission <tool>
add_permission() {
  tool="$1"

  existing=$(jq -r --arg tool "$tool" '.permissions.allow // [] | index($tool)' "$SETTINGS")
  if [ "$existing" != "null" ]; then
    echo "  ↳ Permission '$tool' already set, skipping"
    return
  fi

  tmp=$(mktemp)
  jq --arg tool "$tool" \
    '.permissions.allow = ((.permissions.allow // []) + [$tool])' "$SETTINGS" > "$tmp" && mv "$tmp" "$SETTINGS"
  echo "  ✔ Permission '$tool' added"
}

echo "Configuring Claude MCP servers..."

add_mcp "context7" '{
  "command": "npx",
  "args": ["-y", "@upstash/context7-mcp@latest"]
}'

add_permission "mcp__context7__resolve-library-id"
add_permission "mcp__context7__query-docs"

if [ -z "$LINEAR_API_KEY" ]; then
  echo "  ⚠ LINEAR_API_KEY not set, skipping Linear MCP"
else
  add_mcp "linear" "{
    \"command\": \"npx\",
    \"args\": [\"-y\", \"@linear/mcp-server\"],
    \"env\": { \"LINEAR_API_KEY\": \"$LINEAR_API_KEY\" }
  }"
fi

# We want to allow permissions anyway, if Linear is configured directly from Claude Code.
add_permission "mcp__linear__get_authenticated_user"
add_permission "mcp__linear__save_issue"
add_permission "mcp__linear__list_teams"
add_permission "mcp__linear__list_milestones"

if [ -z "$NOTION_API_TOKEN" ]; then
  echo "  ⚠ NOTION_API_TOKEN not set, skipping Notion MCP"
else
  add_mcp "notion" "{
    \"command\": \"notion-mcp-server\",
    \"env\": { \"NOTION_TOKEN\": \"$NOTION_API_TOKEN\" }
  }"
fi
