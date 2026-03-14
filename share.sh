#!/usr/bin/env bash
# cc-go-on — Share & resume AI coding sessions across tools
# Usage:
#   share.sh export [--session <id>] [--adapter claude-code] [--passphrase <pass>] [--project <dir>]
#   share.sh import <token_or_url> [--adapter claude-code] [--passphrase <pass>] [--project <dir>]
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
    echo "  --passphrase, -p <pass> Encryption passphrase"
    echo "  --project, -d <dir>     Project directory (default: current)"
    echo ""
    echo "Adapters: claude-code, codex, cursor (community)"
    echo ""
    echo "Examples:"
    echo "  share.sh export -p mysecret"
    echo "  share.sh import ccgo_aHR0cHM... -p mysecret"
}

# Auto-detect adapter from current environment
detect_current_adapter() {
    # Check if we're inside a Claude Code session
    if [[ -n "${CLAUDE_SESSION_ID:-}" ]] || [[ -n "${CLAUDE_CODE:-}" ]]; then
        echo "claude-code"
        return
    fi
    # Check for Codex
    if [[ -n "${CODEX_SESSION:-}" ]]; then
        echo "codex"
        return
    fi
    # Default: check what's installed
    local adapters
    adapters=$(detect_adapters)
    echo "${adapters%% *}"  # first one
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
            local passphrase=""
            local project_dir="."

            while [[ $# -gt 0 ]]; do
                case "$1" in
                    -s|--session)    session_id="$2"; shift 2 ;;
                    -a|--adapter)    adapter="$2"; shift 2 ;;
                    -p|--passphrase) passphrase="$2"; shift 2 ;;
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

            # Call adapter export
            local adapter_export="$SCRIPT_DIR/adapters/$adapter/export.sh"
            if [[ ! -f "$adapter_export" ]]; then
                log_error "Adapter not found: $adapter"
                exit 1
            fi

            ensure_temp
            local session_dir="$CCGO_TEMP/session_data"
            mkdir -p "$session_dir"

            source "$adapter_export"
            adapter_export "$session_id" "$project_dir" "$session_dir"

            # Now package and upload
            source "$SCRIPT_DIR/core/export.sh"
            export_session "$adapter" "$session_dir" "$project_dir" "$passphrase"
            ;;

        import)
            if [[ $# -lt 1 ]]; then
                log_error "Usage: share.sh import <token_or_url> [options]"
                exit 1
            fi

            local token="$1"
            shift

            local adapter=""
            local passphrase=""
            local project_dir="."

            while [[ $# -gt 0 ]]; do
                case "$1" in
                    -a|--adapter)    adapter="$2"; shift 2 ;;
                    -p|--passphrase) passphrase="$2"; shift 2 ;;
                    -d|--project)    project_dir="$2"; shift 2 ;;
                    *) log_error "Unknown option: $1"; exit 1 ;;
                esac
            done

            if [[ -z "$adapter" ]]; then
                adapter=$(detect_current_adapter)
            fi
            if [[ -z "$adapter" ]]; then
                adapter="claude-code"  # reasonable default
            fi

            log_info "Adapter: $adapter"

            source "$SCRIPT_DIR/core/import.sh"
            import_session "$token" "$adapter" "$project_dir" "$passphrase"
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

        version)
            echo "cc-go-on v$CCGO_VERSION"
            ;;

        *)
            # If first arg looks like a token, treat as import
            if [[ "$command" == ccgo_* || "$command" == http* ]]; then
                main import "$command" "$@"
            else
                usage
                exit 1
            fi
            ;;
    esac
}

main "$@"
