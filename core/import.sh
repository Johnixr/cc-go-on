#!/usr/bin/env bash
# cc-go-on: import session — download, decrypt, install
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"
source "$SCRIPT_DIR/crypto.sh"

# Decode token to URL
decode_token() {
    local token="$1"
    # Strip ccgo_ prefix
    local encoded="${token#ccgo_}"
    # Restore base64 padding and chars
    local padded="$encoded"
    padded="${padded//-/+}"
    padded="${padded//_//}"
    # Add padding
    local mod=$(( ${#padded} % 4 ))
    if [[ $mod -eq 2 ]]; then padded="${padded}==";
    elif [[ $mod -eq 3 ]]; then padded="${padded}="; fi
    echo -n "$padded" | base64 -d 2>/dev/null
}

import_session() {
    local token_or_url="$1"
    local adapter="$2"
    local project_dir="${3:-.}"
    local passphrase="${4:-}"

    check_deps || return 1
    ensure_config
    ensure_temp

    # 1. Resolve URL from token
    local url
    if [[ "$token_or_url" == ccgo_* ]]; then
        url=$(decode_token "$token_or_url")
        log_info "Decoded token → $url"
    elif [[ "$token_or_url" == http* || "$token_or_url" == s3://* ]]; then
        url="$token_or_url"
    else
        log_error "Invalid token or URL: $token_or_url"
        return 1
    fi

    # 2. Download
    local encrypted="$CCGO_TEMP/session.tar.gz.enc"

    local storage_backend
    storage_backend="$(config_get 'storage' 'transfer.sh')"
    local storage_script="$SCRIPT_DIR/storage/$(echo "$storage_backend" | tr '.' '_').sh"
    source "$storage_script"

    log_info "Downloading session..."
    storage_download "$url" "$encrypted" || {
        log_error "Download failed"
        return 1
    }

    # 3. Decrypt
    local archive="$CCGO_TEMP/session.tar.gz"
    local key_file=""

    if [[ -z "$passphrase" ]]; then
        key_file=$(find_project_key "$project_dir" 2>/dev/null || true)
    fi

    if [[ -n "$key_file" ]]; then
        log_info "Using project key: $key_file"
        decrypt_file "$encrypted" "$archive" "" "$key_file" || {
            log_error "Decryption failed — wrong key?"
            return 1
        }
    elif [[ -n "$passphrase" ]]; then
        decrypt_file "$encrypted" "$archive" "$passphrase" || {
            log_error "Decryption failed — wrong passphrase?"
            return 1
        }
    else
        log_error "No passphrase provided and no .cc-go-on-key found"
        return 1
    fi

    log_info "Decrypted successfully"

    # 4. Extract
    local extract_dir="$CCGO_TEMP/extracted"
    mkdir -p "$extract_dir"
    tar -xzf "$archive" -C "$extract_dir"

    # 5. Read metadata
    local metadata="$extract_dir/metadata.json"
    if [[ ! -f "$metadata" ]]; then
        log_error "Invalid session package: no metadata.json"
        return 1
    fi

    local source_project_path
    source_project_path=$(python3 -c "import json; print(json.load(open('$metadata'))['project_path'])")
    local source_adapter
    source_adapter=$(python3 -c "import json; print(json.load(open('$metadata'))['adapter'])")
    local source_git_branch
    source_git_branch=$(python3 -c "import json; print(json.load(open('$metadata')).get('git',{}).get('branch',''))")

    log_info "Source: $source_adapter | branch: $source_git_branch"
    log_info "Source path: $source_project_path"

    local target_project_path
    target_project_path="$(cd "$project_dir" && pwd)"

    # 6. Remap paths in session files
    if [[ "$source_project_path" != "$target_project_path" ]]; then
        log_info "Remapping paths: $source_project_path → $target_project_path"
        find "$extract_dir/session" -type f -name "*.jsonl" -o -name "*.json" | while read -r f; do
            # Use python for safe replacement (handles special chars in paths)
            python3 -c "
import sys
with open('$f', 'r') as fh:
    content = fh.read()
content = content.replace('$source_project_path', '$target_project_path')
with open('$f', 'w') as fh:
    fh.write(content)
"
        done
    fi

    # 7. Call adapter to install
    local adapter_script="$SCRIPT_DIR/../adapters/$adapter/import.sh"
    if [[ ! -f "$adapter_script" ]]; then
        log_error "Adapter not found: $adapter"
        log_error "Available adapters: $(ls "$SCRIPT_DIR/../adapters/")"
        return 1
    fi

    source "$adapter_script"
    adapter_import "$extract_dir/session" "$target_project_path" "$metadata"

    echo ""
    log_info "Session imported successfully!"
    echo -e "  ${CYAN}Branch:${NC}  $source_git_branch"
    echo -e "  ${CYAN}Source:${NC}  $source_adapter"
    echo ""
    echo -e "  Use ${GREEN}claude --resume${NC} or ${GREEN}/resume${NC} to load the session"
    echo ""
}
