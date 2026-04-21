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

# Upsert an MCP server config. Always overwrites so the script stays the source
# of truth — re-running install.sh reconciles any config drift in ~/.claude.json.
# Usage: add_mcp <name> <json-object>
add_mcp() {
  name="$1"
  config="$2"

  tmp=$(mktemp)
  jq --arg name "$name" --argjson config "$config" \
    '.mcpServers[$name] = $config' "$MCP_FILE" > "$tmp" && mv "$tmp" "$MCP_FILE"
  echo "  ✔ MCP '$name' configured"
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

add_mcp "chrome-devtools" '{
  "command": "npx",
  "args": ["-y", "chrome-devtools-mcp@latest"]
}'

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

# Pinned to 1.1.11: upstream repo (GongRzhe/Gmail-MCP-Server) is archived, so we
# freeze to the last published version to avoid any surprise supply-chain updates.
GMAIL_OAUTH_KEYS="$(pwd)/gmail-oauth.keys.json"
GMAIL_CREDENTIALS="$(pwd)/gmail-oauth.credentials.json"
if [ ! -f "$GMAIL_OAUTH_KEYS" ]; then
  echo "  ⚠ $GMAIL_OAUTH_KEYS not found — skipping personal Gmail MCP (see .env.example)"
else
  add_mcp "gmail-personal" "{
    \"command\": \"npx\",
    \"args\": [\"-y\", \"@gongrzhe/server-gmail-autoauth-mcp@1.1.11\"],
    \"env\": {
      \"GMAIL_OAUTH_PATH\": \"$GMAIL_OAUTH_KEYS\",
      \"GMAIL_CREDENTIALS_PATH\": \"$GMAIL_CREDENTIALS\"
    }
  }"

  if [ -f "$GMAIL_CREDENTIALS" ]; then
    echo "  ↳ Gmail OAuth already authorized ($GMAIL_CREDENTIALS)"
  else
    echo "  ↳ Running one-time Gmail OAuth authorization (browser will open)..."
    GMAIL_OAUTH_PATH="$GMAIL_OAUTH_KEYS" GMAIL_CREDENTIALS_PATH="$GMAIL_CREDENTIALS" \
      npx -y @gongrzhe/server-gmail-autoauth-mcp@1.1.11 auth
  fi
fi

add_permission "mcp__gmail-personal__send_email"
add_permission "mcp__gmail-personal__draft_email"
add_permission "mcp__gmail-personal__read_email"
add_permission "mcp__gmail-personal__search_emails"
add_permission "mcp__gmail-personal__modify_email"
add_permission "mcp__gmail-personal__delete_email"
add_permission "mcp__gmail-personal__list_email_labels"
add_permission "mcp__gmail-personal__batch_modify_emails"
add_permission "mcp__gmail-personal__batch_delete_emails"
add_permission "mcp__gmail-personal__create_label"
add_permission "mcp__gmail-personal__update_label"
add_permission "mcp__gmail-personal__delete_label"
add_permission "mcp__gmail-personal__get_or_create_label"
add_permission "mcp__gmail-personal__create_filter"
add_permission "mcp__gmail-personal__list_filters"
add_permission "mcp__gmail-personal__get_filter"
add_permission "mcp__gmail-personal__delete_filter"
add_permission "mcp__gmail-personal__create_filter_from_template"
add_permission "mcp__gmail-personal__download_attachment"
