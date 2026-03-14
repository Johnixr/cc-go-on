#!/usr/bin/env bash
# cc-go-on: transfer.sh storage backend
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$SCRIPT_DIR/common.sh"

storage_upload() {
    local file="$1"
    local host
    host="$(config_get 'storage_options.transfer_sh.host' 'https://transfer.sh')"
    local max_days
    max_days="$(config_get 'storage_options.transfer_sh.max_days' '7')"

    local filename
    filename="$(basename "$file")"

    local response
    response=$(curl -s -w "\n%{http_code}" \
        --upload-file "$file" \
        -H "Max-Days: $max_days" \
        "$host/$filename")

    local http_code
    http_code=$(echo "$response" | tail -1)
    local url
    url=$(echo "$response" | head -1)

    if [[ "$http_code" -ge 200 && "$http_code" -lt 300 && -n "$url" ]]; then
        echo "$url"
    else
        log_error "Upload failed (HTTP $http_code)"
        log_error "Response: $url"
        return 1
    fi
}

storage_download() {
    local url="$1"
    local output="$2"

    local http_code
    http_code=$(curl -s -w "%{http_code}" -o "$output" "$url")

    if [[ "$http_code" -ge 200 && "$http_code" -lt 300 ]]; then
        return 0
    else
        log_error "Download failed (HTTP $http_code)"
        return 1
    fi
}
