#!/usr/bin/env bash
# cc-go-on: GitHub Gist storage backend
set -euo pipefail

STORAGE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$STORAGE_DIR/common.sh"

storage_upload() {
    local file="$1"

    if ! command -v gh &>/dev/null; then
        log_error "gh CLI not found. Install: https://cli.github.com"
        return 1
    fi

    # Check auth
    if ! gh auth status &>/dev/null 2>&1; then
        log_error "gh not authenticated. Run: gh auth login"
        return 1
    fi

    local filename
    filename="$(basename "$file")"

    # Create a secret gist (unlisted, not discoverable, but accessible via URL)
    # Binary files need base64 encoding since gist only supports text
    local encoded="/tmp/ccgo_${filename}.b64"
    base64 < "$file" > "$encoded"

    local gist_url
    gist_url=$(gh gist create "$encoded" --desc "cc-go-on session (auto-expires)" --filename "${filename}.b64" 2>/dev/null)

    rm -f "$encoded"

    if [[ -z "$gist_url" || "$gist_url" != *"gist.github.com"* ]]; then
        log_error "Gist creation failed"
        return 1
    fi

    # Extract gist ID and construct raw URL
    local gist_id
    gist_id=$(echo "$gist_url" | grep -o '[a-f0-9]\{32\}')

    if [[ -z "$gist_id" ]]; then
        # Fallback: use the URL as-is
        echo "$gist_url"
    else
        # Raw content URL for direct download
        echo "gist://$gist_id/${filename}.b64"
    fi
}

storage_download() {
    local url="$1"
    local output="$2"

    if ! command -v gh &>/dev/null; then
        log_error "gh CLI not found. Install: https://cli.github.com"
        return 1
    fi

    if [[ "$url" == gist://* ]]; then
        # Parse gist://GIST_ID/FILENAME
        local path="${url#gist://}"
        local gist_id="${path%%/*}"
        local filename="${path#*/}"

        # Download via gh CLI
        local tmp_dir="/tmp/ccgo_gist_$$"
        mkdir -p "$tmp_dir"

        gh gist clone "$gist_id" "$tmp_dir" 2>/dev/null || {
            log_error "Failed to download gist $gist_id"
            rm -rf "$tmp_dir"
            return 1
        }

        local b64_file="$tmp_dir/$filename"
        if [[ ! -f "$b64_file" ]]; then
            # Try without path
            b64_file=$(find "$tmp_dir" -name "*.b64" -type f | head -1)
        fi

        if [[ -z "$b64_file" || ! -f "$b64_file" ]]; then
            log_error "Gist file not found"
            rm -rf "$tmp_dir"
            return 1
        fi

        # Decode base64 back to binary
        base64 -d < "$b64_file" > "$output"
        rm -rf "$tmp_dir"
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
