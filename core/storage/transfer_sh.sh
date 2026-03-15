#!/usr/bin/env bash
# cc-go-on: transfer.sh storage backend
set -euo pipefail

STORAGE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$STORAGE_DIR/common.sh"

storage_upload() {
    local file="$1"
    local host
    host="$(config_get 'storage_options.transfer_sh.host' 'https://transfer.sh')"
    local max_days
    max_days="$(config_get 'storage_options.transfer_sh.max_days' '7')"

    local filename
    filename="$(basename "$file")"

    local response
    response=$(curl -s --connect-timeout 10 --max-time 120 \
        -w "\n%{http_code}" \
        --upload-file "$file" \
        -H "Max-Days: $max_days" \
        "$host/$filename" 2>&1) || true

    local http_code
    http_code=$(echo "$response" | tail -1)
    local url
    url=$(echo "$response" | head -1)

    if [[ "$http_code" -ge 200 && "$http_code" -lt 300 && -n "$url" ]]; then
        echo "$url"
    else
        log_error "Upload failed (HTTP $http_code)"
        if [[ "$http_code" == "000" ]]; then
            log_error "Cannot connect to $host — service may be down or blocked"
            log_error "Try a different storage backend:"
            log_error "  ccgoon.sh config storage s3"
            log_error "  ccgoon.sh config storage_options.transfer_sh.host https://your-server.com"
        fi
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
