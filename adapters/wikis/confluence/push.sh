#!/usr/bin/env bash
# Confluence wiki adapter — push learnings via REST API v1
# Sourced by push scripts. Expects: CONFIG_FILE, PYTHON3

run_push() {
    local title="$1" body="$2" scope="$3"

    WIKI_ENV="$HOME/.config/confluence/.env"
    if [ ! -f "$WIKI_ENV" ]; then
        echo "[context-memory] No wiki credentials at $WIKI_ENV"
        return 1
    fi
    # shellcheck disable=SC1090
    source "$WIKI_ENV"

    local page_id
    case "$scope" in
        cross-team) page_id=$("$PYTHON3" -c "import json; print(json.load(open('$CONFIG_FILE')).get('_meta',{}).get('shared_page_id',''))" 2>/dev/null) ;;
        atlas)      page_id=$("$PYTHON3" -c "import json; print(json.load(open('$CONFIG_FILE')).get('_meta',{}).get('dependency_map_page_id',''))" 2>/dev/null) ;;
        domain:*)   local dname="${scope#domain:}"; page_id=$("$PYTHON3" -c "import json; print(json.load(open('$CONFIG_FILE')).get('_meta',{}).get('domain_pages',{}).get('$dname',''))" 2>/dev/null) ;;
        repo:*)     local rname="${scope#repo:}"; page_id=$("$PYTHON3" -c "import json; print(json.load(open('$CONFIG_FILE')).get('repos',{}).get('$rname',{}).get('page_id',''))" 2>/dev/null) ;;
    esac

    if [ -z "$page_id" ]; then
        echo "[context-memory] Could not resolve page ID for scope: $scope"
        return 1
    fi

    local wiki_base
    wiki_base=$("$PYTHON3" -c "import json; print(json.load(open('$CONFIG_FILE')).get('_meta',{}).get('wiki_base_url',''))" 2>/dev/null)

    local current
    current=$(curl -sf -u "$CONFLUENCE_USERNAME:$CONFLUENCE_API_TOKEN" \
        "$wiki_base/wiki/rest/api/content/$page_id?expand=body.storage,version" 2>/dev/null)

    if [ -z "$current" ]; then
        echo "[context-memory] Failed to read current page $page_id"
        return 1
    fi

    local version_num page_title
    version_num=$("$PYTHON3" -c "import json; print(json.load(open('/dev/stdin')).get('version',{}).get('number',0))" <<< "$current")
    page_title=$("$PYTHON3" -c "import json,sys; print(json.load(sys.stdin).get('title',''))" <<< "$current")
    local next_version=$((version_num + 1))

    local current_body
    current_body=$("$PYTHON3" -c "import json,sys; print(json.load(sys.stdin).get('body',{}).get('storage',{}).get('value',''))" <<< "$current")

    local date_stamp
    date_stamp=$(date +%Y-%m-%d)
    local new_section="<h3>$date_stamp: $title</h3>$body"

    local updated_body
    if echo "$current_body" | grep -q "Recent Learnings"; then
        updated_body=$(echo "$current_body" | "$PYTHON3" -c "
import sys, re
body = sys.stdin.read()
body = re.sub(r'(<h2[^>]*>.*?Recent Learnings.*?</h2>)', r'\1\n$new_section', body, count=1)
print(body)
")
    else
        updated_body="$current_body<h2>Recent Learnings (Auto-Updated)</h2>$new_section"
    fi

    local payload_file
    payload_file=$(mktemp)

    "$PYTHON3" -c "
import json, sys
body = sys.stdin.read()
payload = {
    'version': {'number': $next_version, 'message': $(printf '%s' "$title" | "$PYTHON3" -c "import json,sys; print(json.dumps(sys.stdin.read()))")},
    'title': $(printf '%s' "$page_title" | "$PYTHON3" -c "import json,sys; print(json.dumps(sys.stdin.read()))"),
    'type': 'page',
    'status': 'current',
    'body': {'storage': {'value': body, 'representation': 'storage'}}
}
print(json.dumps(payload))
" <<< "$updated_body" > "$payload_file"

    curl -sf -X PUT \
        -u "$CONFLUENCE_USERNAME:$CONFLUENCE_API_TOKEN" \
        -H "Content-Type: application/json" \
        -d @"$payload_file" \
        "$wiki_base/wiki/rest/api/content/$page_id" > /dev/null

    rm -f "$payload_file"

    echo "[context-memory] ✓ Pushed learning to page $page_id"
}
