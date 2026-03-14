#!/usr/bin/env bash
# cc-go-on: Claude Code adapter — import session
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../core/common.sh"

adapter_import() {
    local session_data_dir="$1"   # extracted session directory
    local target_project_dir="$2" # local project path
    local metadata_file="$3"      # global metadata.json

    local cc_home="$HOME/.claude"
    local target_path
    target_path="$(cd "$target_project_dir" && pwd)"

    # Compute local project hash
    local project_hash
    project_hash=$(echo "$target_path" | tr '/' '-')
    local cc_project_dir="$cc_home/projects/$project_hash"

    mkdir -p "$cc_project_dir"

    # Read session ID from adapter metadata
    local adapter_meta="$session_data_dir/adapter_meta.json"
    local session_id
    if [[ -f "$adapter_meta" ]]; then
        session_id=$(python3 -c "import json; print(json.load(open('$adapter_meta'))['session_id'])")
    else
        # Guess from JSONL filename
        session_id=$(find "$session_data_dir" -maxdepth 1 -name "*.jsonl" -type f | head -1 | xargs basename | sed 's/.jsonl$//')
    fi

    if [[ -z "$session_id" ]]; then
        log_error "Cannot determine session ID"
        return 1
    fi

    # Check if session already exists
    if [[ -f "$cc_project_dir/$session_id.jsonl" ]]; then
        log_warn "Session $session_id already exists locally"
        log_warn "It will be overwritten"
    fi

    # Copy session JSONL
    local jsonl_file
    jsonl_file=$(find "$session_data_dir" -maxdepth 1 -name "*.jsonl" -type f | head -1)
    if [[ -n "$jsonl_file" ]]; then
        cp "$jsonl_file" "$cc_project_dir/$session_id.jsonl"
        log_info "Installed session JSONL"
    fi

    # Copy subagents and tool-results into session directory
    local session_subdir="$cc_project_dir/$session_id"
    if [[ -d "$session_data_dir/subagents" ]]; then
        mkdir -p "$session_subdir/subagents"
        cp -r "$session_data_dir/subagents/"* "$session_subdir/subagents/" 2>/dev/null || true
        log_info "Installed subagent data"
    fi

    if [[ -d "$session_data_dir/tool-results" ]]; then
        mkdir -p "$session_subdir/tool-results"
        cp -r "$session_data_dir/tool-results/"* "$session_subdir/tool-results/" 2>/dev/null || true
        log_info "Installed tool results"
    fi

    # Update sessions-index.json
    local index_file="$cc_project_dir/sessions-index.json"

    python3 -c "
import json, os, datetime

index_file = '$index_file'
session_id = '$session_id'
project_path = '$target_path'
jsonl_path = '$cc_project_dir/$session_id.jsonl'

# Load or create index
if os.path.exists(index_file):
    idx = json.load(open(index_file))
else:
    idx = {'version': 1, 'entries': []}

# Remove existing entry for same session
idx['entries'] = [e for e in idx['entries'] if e.get('sessionId') != session_id]

# Read first user prompt from JSONL
first_prompt = '(shared session)'
try:
    with open(jsonl_path, 'r') as f:
        for line in f:
            entry = json.loads(line)
            if entry.get('type') == 'user':
                msg = entry.get('message', {})
                if isinstance(msg, dict):
                    content = msg.get('content', '')
                    if isinstance(content, list):
                        for c in content:
                            if isinstance(c, dict) and c.get('type') == 'text':
                                first_prompt = c['text'][:100]
                                break
                    elif isinstance(content, str):
                        first_prompt = content[:100]
                break
except:
    pass

# Count messages
msg_count = 0
try:
    with open(jsonl_path, 'r') as f:
        msg_count = sum(1 for _ in f)
except:
    pass

# Read git branch from metadata
git_branch = ''
try:
    meta = json.load(open('$session_data_dir/../metadata.json'))
    git_branch = meta.get('git', {}).get('branch', '')
except:
    pass

# Get file mtime
mtime = int(os.path.getmtime(jsonl_path) * 1000)

# Add new entry
idx['entries'].append({
    'sessionId': session_id,
    'fullPath': jsonl_path,
    'fileMtime': mtime,
    'firstPrompt': '[shared] ' + first_prompt,
    'messageCount': msg_count,
    'created': datetime.datetime.utcnow().isoformat() + 'Z',
    'modified': datetime.datetime.utcnow().isoformat() + 'Z',
    'gitBranch': git_branch,
    'projectPath': project_path,
    'isSidechain': False,
})

json.dump(idx, open(index_file, 'w'), indent=2)
"

    log_info "Registered in sessions index"
    log_info "Session ID: $session_id"
}
