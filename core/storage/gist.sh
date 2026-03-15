#!/usr/bin/env bash
# cc-go-on: GitHub Gist storage backend
set -euo pipefail

STORAGE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$STORAGE_DIR/common.sh"

# Use python3 for base64 — portable across macOS/Linux (no -d vs -D issues)
b64_encode() { python3 -c "import base64,sys; sys.stdout.buffer.write(base64.b64encode(sys.stdin.buffer.read()))" < "$1"; }
b64_decode() { python3 -c "import base64,sys; sys.stdout.buffer.write(base64.b64decode(sys.stdin.buffer.read()))" < "$1" > "$2"; }

storage_upload() {
    local file="$1"

    if ! command -v gh &>/dev/null; then
        log_error "gh CLI not found. Install: https://cli.github.com"
        return 1
    fi

    if ! gh auth status &>/dev/null 2>&1; then
        log_error "gh not authenticated. Run: gh auth login"
        return 1
    fi

    # Base64 encode (gist only supports text)
    local b64_file="/tmp/ccgo_session_$$.b64"
    b64_encode "$file" > "$b64_file"

    # Use a fixed filename so download knows what to look for
    local gist_filename="ccgo_session.b64"

    local gist_url
    gist_url=$(gh gist create "$b64_file" \
        --desc "cc-go-on shared session" \
        --filename "$gist_filename" 2>/dev/null)

    rm -f "$b64_file"

    if [[ -z "$gist_url" || "$gist_url" != *"gist.github.com"* ]]; then
        log_error "Gist creation failed"
        return 1
    fi

    # Extract gist ID
    local gist_id
    gist_id=$(echo "$gist_url" | grep -oE '[a-f0-9]{32}')

    if [[ -z "$gist_id" ]]; then
        log_error "Cannot parse gist ID from: $gist_url"
        return 1
    fi

    echo "gist://$gist_id"
}

storage_download() {
    local url="$1"
    local output="$2"

    if ! command -v gh &>/dev/null; then
        log_error "gh CLI not found. Install: https://cli.github.com"
        return 1
    fi

    if [[ "$url" == gist://* ]]; then
        local gist_id="${url#gist://}"
        # Remove trailing path if any (backward compat with old token format)
        gist_id="${gist_id%%/*}"

        # Download via gh api (no SSH needed, works with HTTPS auth)
        local b64_file="/tmp/ccgo_download_$$.b64"

        # Get the first file's content from the gist
        gh api "gists/$gist_id" --jq '.files | to_entries[0].value.content' > "$b64_file" 2>/dev/null || {
            log_error "Failed to download gist $gist_id"
            rm -f "$b64_file"
            return 1
        }

        if [[ ! -s "$b64_file" ]]; then
            log_error "Gist content is empty"
            rm -f "$b64_file"
            return 1
        fi

        # Decode base64 back to binary
        b64_decode "$b64_file" "$output" || {
            log_error "Base64 decode failed"
            rm -f "$b64_file"
            return 1
        }

        rm -f "$b64_file"
    else
        # HTTP URL fallback
        local http_code
        http_code=$(curl -sL --connect-timeout 10 -w "%{http_code}" -o "$output" "$url")
        if [[ "$http_code" -lt 200 || "$http_code" -ge 300 ]]; then
            log_error "Download failed (HTTP $http_code)"
            return 1
        fi
    fi
}
