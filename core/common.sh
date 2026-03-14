#!/usr/bin/env bash
# cc-go-on: common utilities and config management
set -euo pipefail

CCGO_VERSION="0.1.0"
CCGO_HOME="${CCGO_HOME:-$HOME/.cc-go-on}"
CCGO_CONFIG="$CCGO_HOME/config.json"
CCGO_TEMP="${TMPDIR:-/tmp}/cc-go-on-$$"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

log_info()  { echo -e "${GREEN}[cc-go-on]${NC} $*"; }
log_warn()  { echo -e "${YELLOW}[cc-go-on]${NC} $*" >&2; }
log_error() { echo -e "${RED}[cc-go-on]${NC} $*" >&2; }

cleanup() { rm -rf "$CCGO_TEMP" 2>/dev/null || true; }
trap cleanup EXIT

ensure_temp() { mkdir -p "$CCGO_TEMP"; }

# --- Config ---

config_get() {
    local key="$1"
    local default="${2:-}"
    if [[ -f "$CCGO_CONFIG" ]]; then
        local val
        val=$(python3 -c "
import json, sys
try:
    c = json.load(open('$CCGO_CONFIG'))
    keys = '$key'.split('.')
    v = c
    for k in keys:
        v = v[k]
    print(v)
except:
    print('$default')
" 2>/dev/null)
        echo "${val:-$default}"
    else
        echo "$default"
    fi
}

config_set() {
    local key="$1"
    local value="$2"
    mkdir -p "$CCGO_HOME"
    if [[ ! -f "$CCGO_CONFIG" ]]; then
        echo '{}' > "$CCGO_CONFIG"
    fi
    python3 -c "
import json
c = json.load(open('$CCGO_CONFIG'))
keys = '$key'.split('.')
d = c
for k in keys[:-1]:
    d = d.setdefault(k, {})
d[keys[-1]] = '$value'
json.dump(c, open('$CCGO_CONFIG', 'w'), indent=2)
"
}

ensure_config() {
    if [[ ! -f "$CCGO_CONFIG" ]]; then
        local script_dir
        script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
        mkdir -p "$CCGO_HOME"
        cp "$script_dir/config/default.json" "$CCGO_CONFIG"
        log_info "Created default config at $CCGO_CONFIG"
    fi
}

# --- Dependency checks ---

check_deps() {
    local missing=()
    for cmd in openssl tar curl python3 git; do
        command -v "$cmd" &>/dev/null || missing+=("$cmd")
    done
    if [[ ${#missing[@]} -gt 0 ]]; then
        log_error "Missing dependencies: ${missing[*]}"
        return 1
    fi
}

# --- Git helpers ---

git_info() {
    local project_dir="${1:-.}"
    python3 -c "
import subprocess, json, os
os.chdir('$project_dir')
def run(cmd):
    try:
        return subprocess.check_output(cmd, shell=True, stderr=subprocess.DEVNULL).decode().strip()
    except:
        return ''
info = {
    'branch': run('git rev-parse --abbrev-ref HEAD'),
    'commit': run('git rev-parse --short HEAD'),
    'remote': run('git remote get-url origin'),
    'root': run('git rev-parse --show-toplevel'),
}
print(json.dumps(info))
"
}

# --- Project key ---

find_project_key() {
    local dir="${1:-.}"
    # Walk up from dir looking for .cc-go-on-key
    local current
    current="$(cd "$dir" && pwd)"
    while [[ "$current" != "/" ]]; do
        if [[ -f "$current/.cc-go-on-key" ]]; then
            echo "$current/.cc-go-on-key"
            return 0
        fi
        current="$(dirname "$current")"
    done
    return 1
}

# --- Adapter detection ---

detect_adapters() {
    local adapters=()
    # Claude Code
    if [[ -d "$HOME/.claude" ]]; then
        adapters+=("claude-code")
    fi
    # Codex (OpenAI)
    if command -v codex &>/dev/null || [[ -d "$HOME/.codex" ]]; then
        adapters+=("codex")
    fi
    # Cursor
    if [[ -d "$HOME/.cursor" ]] || [[ -d "$HOME/Library/Application Support/Cursor" ]]; then
        adapters+=("cursor")
    fi
    echo "${adapters[@]}"
}
