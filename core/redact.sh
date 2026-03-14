#!/usr/bin/env bash
# cc-go-on: sensitive information redaction
# Patterns referenced from claude-replay (MIT, Enrico Santagati)
set -euo pipefail

REDACTED="[REDACTED]"

# Redact sensitive patterns from a file in-place
redact_file() {
    local file="$1"

    python3 << 'PYEOF' "$file"
import re, sys

REDACTED = "[REDACTED]"

PATTERNS = [
    # PEM private keys
    (r'-----BEGIN (?:RSA |EC |DSA |OPENSSH )?PRIVATE KEY-----[\s\S]*?-----END (?:RSA |EC |DSA |OPENSSH )?PRIVATE KEY-----', REDACTED),
    # AWS access key IDs
    (r'AKIA[0-9A-Z]{16}', REDACTED),
    # Anthropic API keys
    (r'sk-ant-[a-zA-Z0-9\-]{20,}', REDACTED),
    # OpenAI-style sk- keys
    (r'sk-[a-zA-Z0-9]{20,}', REDACTED),
    # Generic key- prefixed tokens
    (r'key-[a-zA-Z0-9]{20,}', REDACTED),
    # Bearer tokens
    (r'Bearer [A-Za-z0-9_.~+/=\-]{20,}', REDACTED),
    # JWT tokens
    (r'eyJ[A-Za-z0-9_\-]{10,}\.eyJ[A-Za-z0-9_\-]{10,}\.[A-Za-z0-9_\-]+', REDACTED),
    # Database/MQ connection strings
    (r'(?:mongodb|postgres|mysql|redis|amqp|mssql)://[^\s"\']+', REDACTED),
    # Key-value pairs (api_key=xxx, SECRET_KEY: "xxx")
    (r'(?:api[_\-]?key|api[_\-]?secret|secret[_\-]?key|access[_\-]?key|auth[_\-]?token|bearer)\s*[:=]\s*["\']?[^\s"\'`,]{8,}["\']?', REDACTED),
    # Environment variable assignments
    (r'(?:PASSWORD|TOKEN|SECRET|CREDENTIAL|PRIVATE_KEY)=[^\s]+', REDACTED),
]

filepath = sys.argv[1]
with open(filepath, 'r') as f:
    content = f.read()

count = 0
for pattern, replacement in PATTERNS:
    content, n = re.subn(pattern, replacement, content, flags=re.IGNORECASE if 'api' in pattern.lower() else 0)
    count += n

with open(filepath, 'w') as f:
    f.write(content)

if count > 0:
    print(f"redacted:{count}")
PYEOF
}

# Redact all session files in a directory
redact_session_dir() {
    local dir="$1"
    local total=0

    while IFS= read -r -d '' file; do
        local result
        result=$(redact_file "$file" 2>/dev/null || true)
        if [[ "$result" == redacted:* ]]; then
            local n="${result#redacted:}"
            total=$((total + n))
        fi
    done < <(find "$dir" -type f \( -name "*.jsonl" -o -name "*.json" -o -name "*.txt" \) -print0)

    echo "$total"
}
