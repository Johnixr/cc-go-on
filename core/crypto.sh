#!/usr/bin/env bash
# cc-go-on: encryption and decryption
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

encrypt_file() {
    local input="$1"
    local output="$2"
    local passphrase="${3:-}"
    local key_file="${4:-}"

    if [[ -n "$key_file" && -f "$key_file" ]]; then
        openssl enc -aes-256-cbc -pbkdf2 -iter 100000 \
            -in "$input" -out "$output" \
            -pass "file:$key_file" 2>/dev/null
    elif [[ -n "$passphrase" ]]; then
        openssl enc -aes-256-cbc -pbkdf2 -iter 100000 \
            -in "$input" -out "$output" \
            -pass "pass:$passphrase" 2>/dev/null
    else
        log_error "No passphrase or key file provided"
        return 1
    fi
}

decrypt_file() {
    local input="$1"
    local output="$2"
    local passphrase="${3:-}"
    local key_file="${4:-}"

    if [[ -n "$key_file" && -f "$key_file" ]]; then
        openssl enc -aes-256-cbc -pbkdf2 -iter 100000 -d \
            -in "$input" -out "$output" \
            -pass "file:$key_file" 2>/dev/null
    elif [[ -n "$passphrase" ]]; then
        openssl enc -aes-256-cbc -pbkdf2 -iter 100000 -d \
            -in "$input" -out "$output" \
            -pass "pass:$passphrase" 2>/dev/null
    else
        log_error "No passphrase or key file provided"
        return 1
    fi
}
