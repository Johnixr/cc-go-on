#!/usr/bin/env bash
# cc-go-on installer
# Usage: curl -fsSL https://raw.githubusercontent.com/Johnixr/cc-go-on/main/install.sh | bash
set -euo pipefail

REPO="https://github.com/Johnixr/cc-go-on.git"
INSTALL_DIR="$HOME/.cc-go-on"
VERSION="main"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

log_info()  { echo -e "${GREEN}[cc-go-on]${NC} $*"; }
log_warn()  { echo -e "${YELLOW}[cc-go-on]${NC} $*"; }
log_error() { echo -e "${RED}[cc-go-on]${NC} $*" >&2; }

check_deps() {
    local missing=()
    for cmd in git openssl tar curl python3; do
        command -v "$cmd" &>/dev/null || missing+=("$cmd")
    done
    if [[ ${#missing[@]} -gt 0 ]]; then
        log_error "Missing required tools: ${missing[*]}"
        log_error "Please install them and try again."
        exit 1
    fi
}

install() {
    echo ""
    echo -e "${CYAN}cc-go-on${NC} — Share AI coding sessions across tools"
    echo ""

    check_deps

    # Clone or update
    if [[ -d "$INSTALL_DIR/.git" ]]; then
        log_info "Updating existing installation..."
        cd "$INSTALL_DIR"
        git pull --quiet origin "$VERSION"
    else
        if [[ -d "$INSTALL_DIR" ]]; then
            log_warn "Removing old installation at $INSTALL_DIR"
            rm -rf "$INSTALL_DIR"
        fi
        log_info "Installing to $INSTALL_DIR ..."
        git clone --quiet --depth 1 -b "$VERSION" "$REPO" "$INSTALL_DIR"
    fi

    # Make scripts executable
    chmod +x "$INSTALL_DIR/ccgoon.sh"
    find "$INSTALL_DIR/core" -name "*.sh" -exec chmod +x {} \;
    find "$INSTALL_DIR/adapters" -name "*.sh" -exec chmod +x {} \;

    # Create default config if not exists
    if [[ ! -f "$HOME/.cc-go-on/config.json" ]]; then
        cp "$INSTALL_DIR/config/default.json" "$INSTALL_DIR/config.json"
        log_info "Created default config"
    fi

    # Detect and setup adapters
    echo ""
    log_info "Detecting AI coding tools..."

    local installed_any=false

    # Claude Code
    if [[ -d "$HOME/.claude" ]]; then
        local skill_dir="$HOME/.claude/skills/ccgoon"
        mkdir -p "$HOME/.claude/skills"
        # Remove old /share skill if exists
        rm -f "$HOME/.claude/skills/share" 2>/dev/null || true
        # Symlink the skill
        if [[ -L "$skill_dir" ]]; then
            rm "$skill_dir"
        elif [[ -d "$skill_dir" ]]; then
            log_warn "Existing skill at $skill_dir — backing up"
            mv "$skill_dir" "${skill_dir}.bak.$(date +%s)"
        fi
        ln -s "$INSTALL_DIR/adapters/claude-code" "$skill_dir"
        log_info "  Claude Code: installed /ccgoon skill"
        installed_any=true
    fi

    # Codex
    if command -v codex &>/dev/null || [[ -d "$HOME/.codex" ]]; then
        log_info "  Codex: detected (adapter coming soon)"
        installed_any=true
    fi

    # Cursor
    if [[ -d "$HOME/.cursor" ]] || [[ -d "$HOME/Library/Application Support/Cursor" ]]; then
        log_info "  Cursor: detected (adapter coming soon)"
        installed_any=true
    fi

    if [[ "$installed_any" == false ]]; then
        log_warn "No supported AI tools detected"
        log_warn "You can still use ccgoon.sh directly from the command line"
    fi

    echo ""
    log_info "Installation complete!"
    echo ""
    echo -e "  ${CYAN}CLI usage:${NC}"
    echo "    ~/.cc-go-on/ccgoon.sh export"
    echo "    ~/.cc-go-on/ccgoon.sh import <token>"
    echo ""
    if [[ -d "$HOME/.claude" ]]; then
        echo -e "  ${CYAN}Claude Code:${NC}"
        echo "    /ccgoon            Export current session"
        echo "    /ccgoon <token>    Import a shared session"
        echo ""
    fi
    echo -e "  ${CYAN}Config:${NC}  ~/.cc-go-on/config.json"
    echo -e "  ${CYAN}Docs:${NC}    https://github.com/Johnixr/cc-go-on"
    echo ""
}

# Handle --uninstall
if [[ "${1:-}" == "--uninstall" ]]; then
    log_info "Uninstalling cc-go-on..."
    rm -f "$HOME/.claude/skills/ccgoon" 2>/dev/null || true
    rm -f "$HOME/.claude/skills/share" 2>/dev/null || true
    rm -rf "$INSTALL_DIR"
    log_info "Uninstalled successfully"
    exit 0
fi

install
