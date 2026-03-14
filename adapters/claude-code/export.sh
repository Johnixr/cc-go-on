#!/usr/bin/env bash
# cc-go-on: Claude Code adapter — export session
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../core/common.sh"

adapter_export() {
    local session_id="$1"
    local project_dir="${2:-.}"
    local output_dir="$3"

    # Resolve Claude Code project directory
    local cc_home="$HOME/.claude"
    local project_path
    project_path="$(cd "$project_dir" && pwd)"

    # Claude Code uses path hash as project dir name: /a/b/c → -a-b-c
    local project_hash
    project_hash=$(echo "$project_path" | tr '/' '-')
    local cc_project_dir="$cc_home/projects/$project_hash"

    if [[ ! -d "$cc_project_dir" ]]; then
        log_error "No Claude Code project found for: $project_path"
        log_error "Expected: $cc_project_dir"
        return 1
    fi

    # Find session
    local session_dir=""
    local session_jsonl=""

    if [[ -n "$session_id" && "$session_id" != "latest" ]]; then
        # Specific session ID
        session_jsonl="$cc_project_dir/$session_id.jsonl"
        if [[ -d "$cc_project_dir/$session_id" ]]; then
            session_dir="$cc_project_dir/$session_id"
        fi
    else
        # Find latest session from sessions-index.json
        local index="$cc_project_dir/sessions-index.json"
        if [[ -f "$index" ]]; then
            session_id=$(python3 -c "
import json
idx = json.load(open('$index'))
entries = idx.get('entries', [])
if entries:
    # Sort by modified time, get latest
    latest = max(entries, key=lambda e: e.get('modified', e.get('created', '')))
    print(latest['sessionId'])
")
        fi

        if [[ -z "$session_id" ]]; then
            # Fallback: find newest .jsonl file
            session_jsonl=$(find "$cc_project_dir" -maxdepth 1 -name "*.jsonl" -type f | \
                xargs ls -t 2>/dev/null | head -1)
            if [[ -n "$session_jsonl" ]]; then
                session_id=$(basename "$session_jsonl" .jsonl)
            fi
        fi

        if [[ -z "$session_id" ]]; then
            log_error "No sessions found in $cc_project_dir"
            return 1
        fi

        session_jsonl="$cc_project_dir/$session_id.jsonl"
        if [[ -d "$cc_project_dir/$session_id" ]]; then
            session_dir="$cc_project_dir/$session_id"
        fi
    fi

    # Prepare output
    mkdir -p "$output_dir"

    # Copy main session JSONL
    if [[ -f "$session_jsonl" ]]; then
        cp "$session_jsonl" "$output_dir/"
        log_info "Copied session: $(basename "$session_jsonl")"
    elif [[ -f "$session_dir/$session_id.jsonl" ]]; then
        cp "$session_dir/$session_id.jsonl" "$output_dir/"
        log_info "Copied session: $session_id.jsonl"
    else
        log_error "Session file not found: $session_jsonl"
        return 1
    fi

    # Copy subagents if exist
    if [[ -d "$session_dir/subagents" ]]; then
        cp -r "$session_dir/subagents" "$output_dir/"
        local agent_count
        agent_count=$(find "$output_dir/subagents" -name "*.jsonl" | wc -l | tr -d ' ')
        log_info "Copied $agent_count subagent sessions"
    fi

    # Copy tool results if exist
    if [[ -d "$session_dir/tool-results" ]]; then
        cp -r "$session_dir/tool-results" "$output_dir/"
        log_info "Copied tool results cache"
    fi

    # Save adapter-specific metadata
    python3 -c "
import json
meta = {
    'adapter': 'claude-code',
    'session_id': '$session_id',
    'project_hash': '$project_hash',
    'cc_project_dir': '$cc_project_dir',
}
json.dump(meta, open('$output_dir/adapter_meta.json', 'w'), indent=2)
"

    # Count messages for display
    local msg_count=0
    if [[ -f "$output_dir/$session_id.jsonl" ]]; then
        msg_count=$(wc -l < "$output_dir/$session_id.jsonl" | tr -d ' ')
    fi
    log_info "Session: $session_id ($msg_count messages)"

    echo "$session_id"
}
