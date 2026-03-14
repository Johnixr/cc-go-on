#!/usr/bin/env bash
# cc-go-on: export session — package, encrypt, upload
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"
source "$SCRIPT_DIR/crypto.sh"

export_session() {
    local adapter="$1"
    local session_dir="$2"       # directory containing session files to package
    local project_dir="${3:-.}"  # git project directory
    local passphrase="${4:-}"

    check_deps || return 1
    ensure_config
    ensure_temp

    local pack_dir="$CCGO_TEMP/pack"
    mkdir -p "$pack_dir"

    # 1. Copy session data
    cp -r "$session_dir" "$pack_dir/session"

    # 2. Generate metadata
    local git_data
    git_data=$(git_info "$project_dir")

    python3 -c "
import json, datetime, os
meta = {
    'version': '$CCGO_VERSION',
    'adapter': '$adapter',
    'exported_at': datetime.datetime.utcnow().isoformat() + 'Z',
    'git': json.loads('$git_data'),
    'project_path': os.path.realpath('$project_dir'),
    'platform': '$(uname -s)',
    'hostname': '$(hostname -s 2>/dev/null || echo unknown)',
}
json.dump(meta, open('$pack_dir/metadata.json', 'w'), indent=2)
"

    # 3. Create tar.gz
    local archive="$CCGO_TEMP/session.tar.gz"
    tar -czf "$archive" -C "$pack_dir" .

    local archive_size
    archive_size=$(wc -c < "$archive" | tr -d ' ')
    log_info "Packaged session: $(( archive_size / 1024 )) KB"

    # 4. Encrypt
    local encrypted="$CCGO_TEMP/session.tar.gz.enc"
    local key_file=""

    if [[ -z "$passphrase" ]]; then
        key_file=$(find_project_key "$project_dir" 2>/dev/null || true)
    fi

    if [[ -n "$key_file" ]]; then
        log_info "Using project key: $key_file"
        encrypt_file "$archive" "$encrypted" "" "$key_file"
    elif [[ -n "$passphrase" ]]; then
        encrypt_file "$archive" "$encrypted" "$passphrase"
    else
        log_error "No passphrase provided and no .cc-go-on-key found in project"
        log_error "Usage: share export --passphrase <passphrase>"
        log_error "   or: create .cc-go-on-key in your project root"
        return 1
    fi

    log_info "Encrypted successfully"

    # 5. Upload
    local storage_backend
    storage_backend="$(config_get 'storage' 'transfer.sh')"

    local storage_script="$SCRIPT_DIR/storage/${storage_backend//./_}.sh"
    if [[ ! -f "$storage_script" ]]; then
        # Normalize: "transfer.sh" -> "transfer_sh"
        storage_script="$SCRIPT_DIR/storage/$(echo "$storage_backend" | tr '.' '_').sh"
    fi

    if [[ ! -f "$storage_script" ]]; then
        log_error "Unknown storage backend: $storage_backend"
        return 1
    fi

    # Re-source to get the right storage functions
    source "$storage_script"

    log_info "Uploading to $storage_backend ..."
    local url
    url=$(storage_upload "$encrypted")

    if [[ -z "$url" ]]; then
        log_error "Upload failed"
        return 1
    fi

    # 6. Generate token (base64 encoded URL with prefix)
    local token
    token="ccgo_$(echo -n "$url" | base64 | tr -d '\n' | tr '+/' '-_' | tr -d '=')"

    echo ""
    log_info "Session shared successfully!"
    echo ""
    echo -e "  ${CYAN}Token:${NC}  $token"
    echo -e "  ${CYAN}URL:${NC}    $url"
    if [[ -n "$key_file" ]]; then
        echo -e "  ${CYAN}Key:${NC}    project key (.cc-go-on-key)"
    else
        echo -e "  ${CYAN}Key:${NC}    passphrase (share it securely)"
    fi
    echo ""
    echo -e "  Recipient command: ${GREEN}/share $token${NC}"
    echo ""

    # Return token for programmatic use
    echo "$token"
}
