#!/usr/bin/env bash
# Confluence wiki adapter — pull pages via REST API v1
# Sourced by pull_knowledge.sh. Expects: WIKI_CACHE, KNOWLEDGE_FILE, CONFIG_FILE, PYTHON3

run_pull() {
    WIKI_ENV="$HOME/.config/confluence/.env"
    if [ -f "$WIKI_ENV" ]; then
        # shellcheck disable=SC1090
        source "$WIKI_ENV"
        export CONFLUENCE_USERNAME CONFLUENCE_API_TOKEN
    else
        echo "[context-memory] No wiki credentials at $WIKI_ENV — skipping wiki pull"
        echo "[context-memory] Set up credentials: see docs/tutorial.md"
        return 0
    fi

    if [ -z "${CONFLUENCE_USERNAME:-}" ] || [ -z "${CONFLUENCE_API_TOKEN:-}" ] || [ ! -f "$CONFIG_FILE" ]; then
        return 0
    fi

    SHARED_PAGE_ID=$("$PYTHON3" -c "import json; c=json.load(open('$CONFIG_FILE')); print(c.get('_meta',{}).get('shared_page_id',''))" 2>/dev/null || echo "")
    DEPMAP_PAGE_ID=$("$PYTHON3" -c "import json; c=json.load(open('$CONFIG_FILE')); print(c.get('_meta',{}).get('dependency_map_page_id',''))" 2>/dev/null || echo "")
    WIKI_BASE=$("$PYTHON3" -c "import json; c=json.load(open('$CONFIG_FILE')); print(c.get('_meta',{}).get('wiki_base_url',''))" 2>/dev/null || echo "")

    pull_page() {
        local page_id="$1" output_file="$2" label="$3"
        if [ -n "$page_id" ] && [ -n "$WIKI_BASE" ]; then
            echo "[context-memory] Pulling $label (page $page_id)..."
            local response
            response=$(curl -sf -u "$CONFLUENCE_USERNAME:$CONFLUENCE_API_TOKEN" \
                "$WIKI_BASE/wiki/rest/api/content/$page_id?expand=body.storage" 2>/dev/null || echo "")

            if [ -n "$response" ]; then
                local tmpfile
                tmpfile=$(mktemp)
                echo "$response" > "$tmpfile"

                "$PYTHON3" << CONFLUENCE_PYEOF > "$output_file"
import json, re, html, sys

with open('$tmpfile', 'r') as f:
    data = json.load(f)

body = data.get('body', {}).get('storage', {}).get('value', '')

body = re.sub(r'<h1[^>]*>(.*?)</h1>', r'# \1', body, flags=re.DOTALL)
body = re.sub(r'<h2[^>]*>(.*?)</h2>', r'## \1', body, flags=re.DOTALL)
body = re.sub(r'<h3[^>]*>(.*?)</h3>', r'### \1', body, flags=re.DOTALL)
body = re.sub(r'<strong>(.*?)</strong>', r'**\1**', body, flags=re.DOTALL)
body = re.sub(r'<em>(.*?)</em>', r'*\1*', body, flags=re.DOTALL)

def convert_tables(text):
    import re as _re
    def table_to_md(match):
        table_html = match.group(0)
        rows = _re.findall(r'<tr[^>]*>(.*?)</tr>', table_html, _re.DOTALL)
        md_rows = []
        for i, row in enumerate(rows):
            cells = _re.findall(r'<t[hd][^>]*>(.*?)</t[hd]>', row, _re.DOTALL)
            cells = [_re.sub(r'<[^>]+>', '', c).strip() for c in cells]
            md_rows.append('| ' + ' | '.join(cells) + ' |')
            if i == 0:
                md_rows.append('|' + '|'.join(['---'] * len(cells)) + '|')
        return '\n'.join(md_rows)
    return _re.sub(r'<table[^>]*>.*?</table>', table_to_md, text, flags=_re.DOTALL)

body = convert_tables(body)
body = re.sub(r'<li>(.*?)</li>', r'- \1', body, flags=re.DOTALL)
body = re.sub(r'<br\s*/?>', '\n', body)
body = re.sub(r'<p>(.*?)</p>', r'\1\n', body, flags=re.DOTALL)
body = re.sub(r'<[^>]+>', '', body)
body = html.unescape(body)

title = data.get('title', 'Untitled')
print(f"# {title}\n")
print(body.strip())
CONFLUENCE_PYEOF
                rm -f "$tmpfile"
                echo "[context-memory] ✓ $label cached"
            else
                echo "[context-memory] ✗ Failed to pull $label"
            fi
        fi
    }

    [ -n "$SHARED_PAGE_ID" ] && pull_page "$SHARED_PAGE_ID" "$WIKI_CACHE/shared.md" "Shared Standards"
    [ -n "$DEPMAP_PAGE_ID" ] && pull_page "$DEPMAP_PAGE_ID" "$WIKI_CACHE/depmap.md" "Dependency Map"

    DOMAIN_PAGES=$("$PYTHON3" -c "
import json
c = json.load(open('$CONFIG_FILE'))
for k, v in c.get('_meta', {}).get('domain_pages', {}).items():
    print(f'{k}:{v}')
" 2>/dev/null || echo "")

    while IFS=: read -r domain_name domain_page_id; do
        [ -n "$domain_name" ] && pull_page "$domain_page_id" "$WIKI_CACHE/domain_${domain_name}.md" "Domain: $domain_name"
    done <<< "$DOMAIN_PAGES"

    CURRENT_REPO=$(basename "$(pwd)")
    REPO_PAGE_ID=$("$PYTHON3" -c "
import json
c = json.load(open('$CONFIG_FILE'))
print(c.get('repos', {}).get('$CURRENT_REPO', {}).get('page_id', ''))
" 2>/dev/null || echo "")

    [ -n "$REPO_PAGE_ID" ] && pull_page "$REPO_PAGE_ID" "$WIKI_CACHE/${CURRENT_REPO}.md" "Repo: $CURRENT_REPO"

    assemble_knowledge
}
