#!/usr/bin/env bash
# cc-go-on: local file storage (no upload — user transfers file manually)
set -euo pipefail

STORAGE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$STORAGE_DIR/common.sh"

storage_upload() {
    local file="$1"
    local output_dir
    output_dir="$(config_get 'storage_options.local.dir' "$HOME/.cc-go-on/shared")"
    # Expand ~ to $HOME
    output_dir="${output_dir/#\~/$HOME}"

    mkdir -p "$output_dir"

    local filename
    filename="$(basename "$file")"
    local dest="$output_dir/$filename"

    cp "$file" "$dest"

    echo "file://$dest"
}

storage_download() {
    local url="$1"
    local output="$2"

    # Strip file:// prefix
    local path="${url#file://}"

    if [[ ! -f "$path" ]]; then
        log_error "File not found: $path"
        log_error "Ask the sender to share the encrypted file directly"
        return 1
    fi

    cp "$path" "$output"
}
