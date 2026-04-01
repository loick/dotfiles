#!/bin/sh

SETTINGS="$HOME/.claude/settings.json"

# Ensure settings.json exists with valid JSON
if [ ! -f "$SETTINGS" ]; then
  echo "{}" > "$SETTINGS"
fi

# Add an MCP server if it doesn't already exist.
# Usage: add_mcp <name> <json-object>
add_mcp() {
  name="$1"
  config="$2"

  existing=$(jq -r --arg name "$name" '.mcpServers[$name] // empty' "$SETTINGS")
  if [ -n "$existing" ]; then
    echo "  ↳ MCP '$name' already configured, skipping"
    return
  fi

  tmp=$(mktemp)
  jq --arg name "$name" --argjson config "$config" \
    '.mcpServers[$name] = $config' "$SETTINGS" > "$tmp" && mv "$tmp" "$SETTINGS"
  echo "  ✔ MCP '$name' added"
}

echo "Configuring Claude MCP servers..."

add_mcp "context7" '{
  "command": "npx",
  "args": ["-y", "@upstash/context7-mcp@latest"]
}'

if [ -z "$NOTION_API_TOKEN" ]; then
  echo "  ⚠ NOTION_API_TOKEN not set, skipping Notion MCP"
else
  add_mcp "notion" "{
    \"command\": \"npx\",
    \"args\": [\"-y\", \"@notionhq/notion-mcp-server\"],
    \"env\": { \"OPENAPI_MCP_HEADERS\": \"{\\\"Authorization\\\": \\\"Bearer $NOTION_API_TOKEN\\\", \\\"Notion-Version\\\": \\\"2022-06-28\\\"}\" }
  }"
fi
