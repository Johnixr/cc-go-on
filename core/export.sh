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

    # 4. Generate random key and encrypt
    local key
    key=$(generate_key)
    local encrypted="$CCGO_TEMP/session.tar.gz.enc"
    encrypt_file "$archive" "$encrypted" "$key"
    log_info "Encrypted with random key"

    # 5. Upload
    local storage_backend
    storage_backend="$(config_get 'storage' 'transfer.sh')"

    local storage_script="$SCRIPT_DIR/storage/$(echo "$storage_backend" | tr '.' '_').sh"
    if [[ ! -f "$storage_script" ]]; then
        log_error "Unknown storage backend: $storage_backend"
        return 1
    fi

    source "$storage_script"

    log_info "Uploading to $storage_backend ..."
    local url
    url=$(storage_upload "$encrypted")

    if [[ -z "$url" ]]; then
        log_error "Upload failed"
        return 1
    fi

    # 6. Generate token: base64url( JSON{"u": url, "k": key} )
    local token
    token="ccgo_$(python3 -c "
import json, base64
payload = json.dumps({'u': '$url', 'k': '$key'}, separators=(',',':'))
encoded = base64.urlsafe_b64encode(payload.encode()).decode().rstrip('=')
print(encoded)
")"

    # 7. Generate shareable snippet
    local snippet
    snippet=$(generate_share_snippet "$token")

    echo ""
    log_info "Session shared successfully!"
    echo ""
    echo -e "${CYAN}--- Copy everything below and send to your teammate ---${NC}"
    echo ""
    echo "$snippet"
    echo ""
    echo -e "${CYAN}------------------------------------------------------${NC}"
    echo ""
}

generate_share_snippet() {
    local token="$1"
    cat <<SNIPPET
I'm sharing an AI coding session with you via cc-go-on.
Install (if first time): curl -fsSL https://raw.githubusercontent.com/Johnixr/cc-go-on/main/install.sh | bash
Then load the session: /share $token
SNIPPET
}
