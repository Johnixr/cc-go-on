#!/usr/bin/env bash
# cc-go-on — Share & resume AI coding sessions across tools
# Usage:
#   share.sh export [--session <id>] [--adapter claude-code] [--project <dir>]
#   share.sh import <token> [--adapter claude-code] [--project <dir>]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/core/common.sh"

usage() {
    echo "cc-go-on v$CCGO_VERSION — Share AI coding sessions across tools"
    echo ""
    echo "Usage:"
    echo "  share.sh export [options]        Export current session"
    echo "  share.sh import <token> [options] Import a shared session"
    echo "  share.sh config [key] [value]    View or set config"
    echo "  share.sh version                 Show version"
    echo ""
    echo "Options:"
    echo "  --session, -s <id>      Session ID (default: latest)"
    echo "  --adapter, -a <name>    AI tool adapter (default: auto-detect)"
    echo "  --project, -d <dir>     Project directory (default: current)"
    echo ""
    echo "Adapters: claude-code, codex, cursor (community)"
    echo ""
    echo "Examples:"
    echo "  share.sh export"
    echo "  share.sh import ccgo_eyJ1Ijoi..."
}

# Auto-detect adapter from current environment
detect_current_adapter() {
    if [[ -n "${CLAUDE_SESSION_ID:-}" ]] || [[ -n "${CLAUDE_CODE:-}" ]]; then
        echo "claude-code"
        return
    fi
    if [[ -n "${CODEX_SESSION:-}" ]]; then
        echo "codex"
        return
    fi
    local adapters
    adapters=$(detect_adapters)
    echo "${adapters%% *}"
}

main() {
    if [[ $# -lt 1 ]]; then
        usage
        exit 1
    fi

    local command="$1"
    shift

    case "$command" in
        export)
            local session_id="latest"
            local adapter=""
            local project_dir="."

            while [[ $# -gt 0 ]]; do
                case "$1" in
                    -s|--session)    session_id="$2"; shift 2 ;;
                    -a|--adapter)    adapter="$2"; shift 2 ;;
                    -d|--project)    project_dir="$2"; shift 2 ;;
                    *) log_error "Unknown option: $1"; exit 1 ;;
                esac
            done

            if [[ -z "$adapter" ]]; then
                adapter=$(detect_current_adapter)
            fi
            if [[ -z "$adapter" ]]; then
                log_error "Cannot detect AI tool. Use --adapter to specify."
                exit 1
            fi

            log_info "Adapter: $adapter"

            local adapter_export="$SCRIPT_DIR/adapters/$adapter/export.sh"
            if [[ ! -f "$adapter_export" ]]; then
                log_error "Adapter not found: $adapter"
                exit 1
            fi

            ensure_temp
            local session_dir="$CCGO_TEMP/session_data"
            mkdir -p "$session_dir"

            local ccgo_root="$SCRIPT_DIR"

            source "$adapter_export"
            adapter_export "$session_id" "$project_dir" "$session_dir"

            source "$ccgo_root/core/export.sh"
            export_session "$adapter" "$session_dir" "$project_dir"
            ;;

        import)
            if [[ $# -lt 1 ]]; then
                log_error "Usage: ccgoon.sh import <token> [options]"
                exit 1
            fi

            local token="$1"
            shift

            local adapter=""
            local project_dir="."

            while [[ $# -gt 0 ]]; do
                case "$1" in
                    -a|--adapter)    adapter="$2"; shift 2 ;;
                    -d|--project)    project_dir="$2"; shift 2 ;;
                    *) log_error "Unknown option: $1"; exit 1 ;;
                esac
            done

            if [[ -z "$adapter" ]]; then
                adapter=$(detect_current_adapter)
            fi
            if [[ -z "$adapter" ]]; then
                adapter="claude-code"
            fi

            log_info "Adapter: $adapter"

            source "$SCRIPT_DIR/core/import.sh"
            import_session "$token" "$adapter" "$project_dir"
            ;;

        config)
            ensure_config
            if [[ $# -eq 0 ]]; then
                cat "$CCGO_CONFIG"
            elif [[ $# -eq 1 ]]; then
                config_get "$1"
            else
                config_set "$1" "$2"
                log_info "Set $1 = $2"
            fi
            ;;

        cleanup)
            local history_file="$HOME/.cc-go-on/gist_history.jsonl"
            if [[ ! -f "$history_file" ]]; then
                log_info "No shared gists to clean up"
                exit 0
            fi

            if ! command -v gh &>/dev/null; then
                log_error "gh CLI required for cleanup"
                exit 1
            fi

            local deleted=0
            local failed=0
            while IFS= read -r line; do
                local gist_id
                gist_id=$(echo "$line" | python3 -c "import json,sys; print(json.load(sys.stdin).get('gist_id',''))")
                if [[ -n "$gist_id" ]]; then
                    if gh gist delete "$gist_id" 2>/dev/null; then
                        deleted=$((deleted + 1))
                    else
                        failed=$((failed + 1))
                    fi
                fi
            done < "$history_file"

            # Clear history
            > "$history_file"

            log_info "Cleanup done: $deleted deleted, $failed already gone"
            ;;

        version)
            echo "cc-go-on v$CCGO_VERSION"
            ;;

        *)
            if [[ "$command" == ccgo_* ]]; then
                main import "$command" "$@"
            else
                usage
                exit 1
            fi
            ;;
    esac
}

main "$@"
