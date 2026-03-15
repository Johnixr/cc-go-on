#!/usr/bin/env bash
# cc-go-on: export session — package, encrypt, upload
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"
source "$SCRIPT_DIR/crypto.sh"
source "$SCRIPT_DIR/redact.sh"

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

    # 2. Redact sensitive information
    local redact_count
    redact_count=$(redact_session_dir "$pack_dir/session")
    if [[ "$redact_count" -gt 0 ]]; then
        log_info "Redacted $redact_count sensitive patterns"
    fi

    # 3. Generate metadata
    local git_data
    git_data=$(git_info "$project_dir")

    python3 -c "
import json, datetime, os
meta = {
    'version': '$CCGO_VERSION',
    'adapter': '$adapter',
    'exported_at': datetime.datetime.now(datetime.timezone.utc).isoformat().replace('+00:00', 'Z'),
    'git': json.loads('$git_data'),
    'project_path': os.path.realpath('$project_dir'),
    'platform': '$(uname -s)',
    'hostname': '$(hostname -s 2>/dev/null || echo unknown)',
}
json.dump(meta, open('$pack_dir/metadata.json', 'w'), indent=2)
"

    # 4. Create tar.gz
    local archive="$CCGO_TEMP/session.tar.gz"
    tar -czf "$archive" -C "$pack_dir" .

    local archive_size
    archive_size=$(wc -c < "$archive" | tr -d ' ')
    log_info "Packaged session: $(( archive_size / 1024 )) KB"

    # 5. Generate random key and encrypt
    local key
    key=$(generate_key)
    local encrypted="$CCGO_TEMP/session.tar.gz.enc"
    encrypt_file "$archive" "$encrypted" "$key"
    log_info "Encrypted with random key"

    # 6. Upload
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

    # 7. Generate token: base64url( JSON{"u": url, "k": key} )
    local token
    token="ccgo_$(python3 -c "
import json, base64
payload = json.dumps({'u': '$url', 'k': '$key'}, separators=(',',':'))
encoded = base64.urlsafe_b64encode(payload.encode()).decode().rstrip('=')
print(encoded)
")"

    # 8. Track gist + auto-cleanup old ones
    if [[ "$url" == gist://* ]]; then
        local gist_id="${url#gist://}"
        gist_id="${gist_id%%/*}"
        local history_file="$HOME/.cc-go-on/gist_history.jsonl"

        # Record this gist, then clean expired ones (>7 days)
        python3 << PYEOF
import json, datetime, os, subprocess

history_file = "$history_file"
now = datetime.datetime.now(datetime.timezone.utc)
max_age_days = 7

# Append new entry
new_entry = {
    "gist_id": "$gist_id",
    "created_at": now.isoformat().replace("+00:00", "Z"),
}
entries = []
if os.path.exists(history_file):
    with open(history_file, "r") as f:
        for line in f:
            line = line.strip()
            if line:
                try:
                    entries.append(json.loads(line))
                except:
                    pass
entries.append(new_entry)

# Split into keep vs expired
keep = []
for e in entries:
    try:
        created = datetime.datetime.fromisoformat(e["created_at"].replace("Z", "+00:00"))
        age = (now - created).days
        if age > max_age_days:
            # Auto-delete expired gist (best-effort, silent failure)
            gid = e.get("gist_id", "")
            if gid:
                subprocess.run(["gh", "gist", "delete", gid],
                    capture_output=True, timeout=10)
        else:
            keep.append(e)
    except:
        keep.append(e)

# Rewrite history with only active entries
with open(history_file, "w") as f:
    for e in keep:
        f.write(json.dumps(e) + "\n")
PYEOF
    fi

    # 9. Output result
    echo ""
    log_info "Session shared successfully!"
    echo ""
    echo "CCGO_TOKEN=$token"
    echo "CCGO_URL=$url"
    echo ""
}
