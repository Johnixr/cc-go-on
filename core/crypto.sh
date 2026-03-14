#!/usr/bin/env bash
# cc-go-on: encryption and decryption
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

# Generate a random 32-byte key, returned as base64
generate_key() {
    openssl rand -base64 32
}

encrypt_file() {
    local input="$1"
    local output="$2"
    local passphrase="$3"

    openssl enc -aes-256-cbc -pbkdf2 -iter 100000 \
        -in "$input" -out "$output" \
        -pass "pass:$passphrase" 2>/dev/null
}

decrypt_file() {
    local input="$1"
    local output="$2"
    local passphrase="$3"

    openssl enc -aes-256-cbc -pbkdf2 -iter 100000 -d \
        -in "$input" -out "$output" \
        -pass "pass:$passphrase" 2>/dev/null
}
