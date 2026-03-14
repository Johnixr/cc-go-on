#!/usr/bin/env bash
# cc-go-on: import session — download, decrypt, install
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"
source "$SCRIPT_DIR/crypto.sh"

# Decode token to URL and key
# Token format: ccgo_ + base64url( {"u":"<url>","k":"<key>"} )
decode_token() {
    local token="$1"
    local encoded="${token#ccgo_}"

    python3 -c "
import base64, json, sys
encoded = '$encoded'
# Restore base64 padding
padding = 4 - len(encoded) % 4
if padding != 4:
    encoded += '=' * padding
try:
    payload = base64.urlsafe_b64decode(encoded).decode()
    data = json.loads(payload)
    print(data.get('u', ''))
    print(data.get('k', ''))
except Exception as e:
    print('', file=sys.stderr)
    print('', file=sys.stderr)
    sys.exit(1)
"
}

import_session() {
    local token_or_url="$1"
    local adapter="$2"
    local project_dir="${3:-.}"

    check_deps || return 1
    ensure_config
    ensure_temp

    # 1. Resolve URL and key from token
    local url=""
    local key=""

    if [[ "$token_or_url" == ccgo_* ]]; then
        local decoded
        decoded=$(decode_token "$token_or_url")
        url=$(echo "$decoded" | head -1)
        key=$(echo "$decoded" | tail -1)
        if [[ -z "$url" || -z "$key" ]]; then
            log_error "Invalid token"
            return 1
        fi
        log_info "Token decoded"
    elif [[ "$token_or_url" == http* || "$token_or_url" == s3://* ]]; then
        log_error "Direct URLs no longer supported. Use a ccgo_ token."
        return 1
    else
        log_error "Invalid token: $token_or_url"
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

    # 3. Decrypt with embedded key
    local archive="$CCGO_TEMP/session.tar.gz"
    decrypt_file "$encrypted" "$archive" "$key" || {
        log_error "Decryption failed — token may be corrupted"
        return 1
    }
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

    local target_project_path
    target_project_path="$(cd "$project_dir" && pwd)"

    # 6. Convert format if source != target adapter
    if [[ "$source_adapter" != "$adapter" ]]; then
        log_info "Converting $source_adapter → $adapter format"
        local converter="$SCRIPT_DIR/convert.py"
        find "$extract_dir/session" -maxdepth 1 -name "*.jsonl" -type f | while read -r jsonl_file; do
            local conv_result
            conv_result=$(python3 "$converter" "$jsonl_file" "$jsonl_file.tmp" --target "$adapter" 2>&1)
            local conv_format
            conv_format=$(echo "$conv_result" | grep "^format:" | cut -d: -f2)
            local conv_action
            conv_action=$(echo "$conv_result" | grep "^action:" | cut -d: -f2)

            if [[ "$conv_action" == "converted" ]]; then
                mv "$jsonl_file.tmp" "$jsonl_file"
                local conv_count
                conv_count=$(echo "$conv_result" | grep "^messages:" | cut -d: -f2)
                log_info "Converted $jsonl_file ($conv_format → $adapter, $conv_count messages)"
            else
                rm -f "$jsonl_file.tmp"
            fi
        done
    fi

    # 7. Remap paths in session files
    if [[ "$source_project_path" != "$target_project_path" ]]; then
        log_info "Remapping paths"
        find "$extract_dir/session" -type f \( -name "*.jsonl" -o -name "*.json" \) | while read -r f; do
            python3 -c "
with open('$f', 'r') as fh:
    content = fh.read()
content = content.replace('$source_project_path', '$target_project_path')
with open('$f', 'w') as fh:
    fh.write(content)
"
        done
    fi

    # 8. Call adapter to install
    local adapter_script="$SCRIPT_DIR/../adapters/$adapter/import.sh"
    if [[ ! -f "$adapter_script" ]]; then
        log_error "Adapter not found: $adapter"
        log_error "Available adapters: $(ls "$SCRIPT_DIR/../adapters/")"
        return 1
    fi

    source "$adapter_script"
    adapter_import "$extract_dir/session" "$target_project_path" "$metadata"

    # 9. Branch check — inform, never block
    local current_branch=""
    current_branch=$(cd "$target_project_path" && git rev-parse --abbrev-ref HEAD 2>/dev/null || true)

    echo ""
    log_info "Session imported successfully!"

    if [[ -n "$source_git_branch" && -n "$current_branch" && "$source_git_branch" != "$current_branch" ]]; then
        echo -e "  ${YELLOW}Branch:${NC}  session was on ${CYAN}$source_git_branch${NC}, you're on ${CYAN}$current_branch${NC}"
    elif [[ -n "$current_branch" ]]; then
        echo -e "  ${CYAN}Branch:${NC}  $current_branch"
    fi

    echo -e "  ${CYAN}Source:${NC}  $source_adapter"

    # Adapter-specific resume hint
    local resume_hint=""
    case "$adapter" in
        claude-code) resume_hint="/resume" ;;
        codex)       resume_hint="codex --resume" ;;
        *)           resume_hint="" ;;
    esac
    if [[ -n "$resume_hint" ]]; then
        echo ""
        echo -e "  Next: ${GREEN}$resume_hint${NC} to load the session"
    fi
    echo ""
}
