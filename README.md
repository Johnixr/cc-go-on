# cc-go-on

**Share & resume AI coding sessions across tools.**

Export your AI coding session, encrypt it, share a token — your teammate picks up right where you left off. Works with **any AI coding assistant**: Claude Code, Codex, Cursor, Windsurf, Droid, and more.

> **cc-go-on** is not tied to any single AI tool. It's a universal session-sharing layer. Claude Code is the first supported adapter — others are open for community contribution.

[中文文档](README_CN.md)

## Why

You're halfway through a complex task with your AI coding assistant. You need to hand it off to a colleague, or switch to a different machine, or even a different AI tool. Today, that means copying files, explaining context, and losing the conversation thread.

**cc-go-on** makes it a one-liner: export, share a token, import, continue.

## Install

```bash
curl -fsSL https://raw.githubusercontent.com/Johnixr/cc-go-on/main/install.sh | bash
```

Or paste this to your AI assistant:
> Please install cc-go-on for session sharing: `curl -fsSL https://raw.githubusercontent.com/Johnixr/cc-go-on/main/install.sh | bash`

### What it does

1. Clones to `~/.cc-go-on/`
2. Detects your AI tools (Claude Code, Codex, Cursor, etc.)
3. For supported tools: installs native integration (e.g. `/ccgoon` skill for Claude Code)
4. Creates default config at `~/.cc-go-on/config.json`

### Uninstall

```bash
~/.cc-go-on/install.sh --uninstall
```

## Usage

### Claude Code (via /ccgoon skill)

```
/ccgoon                                   # Export current session
/ccgoonccgo_aHR0cHM6Ly90cmFuc2Zlci5zaC8...  # Import a shared session
```

### CLI (works with any tool)

```bash
# Export — generates a shareable snippet with embedded key
~/.cc-go-on/ccgoon.sh export

# Import
~/.cc-go-on/ccgoon.sh import ccgo_eyJ1Ijoi...
```

No passphrase needed. A random encryption key is auto-generated and embedded in the token.

### Options

| Flag | Description |
|------|-------------|
| `-s, --session <id>` | Session ID (default: latest) |
| `-a, --adapter <name>` | AI tool adapter (default: auto-detect) |
| `-d, --project <dir>` | Project directory (default: current) |

## How It Works

```
Export:  Session files → tar.gz → random key → AES-256 encrypt → upload → token (with key)
Import: token → extract key & URL → download → decrypt → path remap → register → resume
```

After export, cc-go-on generates a shareable snippet you can copy-paste to your teammate:

```
I'm sharing an AI coding session with you via cc-go-on.
Install (if first time): curl -fsSL https://raw.githubusercontent.com/Johnixr/cc-go-on/main/install.sh | bash
Then load the session: /ccgoonccgo_eyJ1IjoiaHR0cHM6Ly90cmFuc2Zlci5zaC8...
```

Your teammate pastes this into their AI tool — it handles install, download, decrypt, and import automatically.

### Storage

Default: **GitHub Gist** — zero config if you have `gh` CLI authenticated. Encrypted file uploaded as a secret (unlisted) gist, accessible only via the token.

| Backend | Config | Notes |
|---------|--------|-------|
| **GitHub Gist** | default | Zero config, requires `gh` CLI |
| **Aliyun OSS** | `ccgoon.sh config storage oss` | Recommended for China |
| **S3-compatible** | `ccgoon.sh config storage s3` | AWS S3, Cloudflare R2, MinIO |
| **Local file** | `ccgoon.sh config storage local` | Manual transfer (AirDrop, IM) |

**Aliyun OSS**:
```bash
~/.cc-go-on/ccgoon.sh config storage oss
~/.cc-go-on/ccgoon.sh config storage_options.oss.bucket my-bucket
~/.cc-go-on/ccgoon.sh config storage_options.oss.endpoint oss-cn-hangzhou.aliyuncs.com
```

**S3-compatible** (Cloudflare R2, AWS S3, MinIO):
```bash
~/.cc-go-on/ccgoon.sh config storage s3
~/.cc-go-on/ccgoon.sh config storage_options.s3.endpoint https://xxx.r2.cloudflarestorage.com
~/.cc-go-on/ccgoon.sh config storage_options.s3.bucket my-bucket
```

### Encryption

Every export auto-generates a random AES-256 key. The key is embedded in the token — no passwords to remember or share separately.

The token IS the secret. Share it through trusted channels (DM, Slack, etc). Anyone with the token can decrypt the session.

### Path Remapping

When importing, absolute paths in session data are automatically remapped from the sender's machine to yours:

```
/Users/alice/projects/myapp → /Users/bob/workspace/myapp
```

This happens transparently — just import and go.

## Supported Tools

| Tool | Status | Notes |
|------|--------|-------|
| **Claude Code** | Supported | Full export/import with `/ccgoon` skill |
| **Codex** | Planned | Contributions welcome |
| **Cursor** | Planned | Contributions welcome |
| **Windsurf** | Planned | Contributions welcome |
| **Droid** | Planned | Contributions welcome |

The adapter interface is simple — see [Adding an Adapter](#adding-an-adapter) to contribute.

## Architecture

```
cc-go-on/
├── ccgoon.sh                 # CLI entry point
├── core/
│   ├── common.sh            # Config, utils, dependency checks
│   ├── crypto.sh            # AES-256-CBC encrypt/decrypt
│   ├── redact.sh            # Sensitive info redaction (API keys, tokens, etc.)
│   ├── export.sh            # Package → redact → encrypt → upload
│   ├── import.sh            # Download → decrypt → path remap → install
│   └── storage/
│       ├── gist.sh          # GitHub Gist (default)
│       ├── oss.sh           # Aliyun OSS
│       ├── s3.sh            # S3-compatible (AWS, R2, MinIO)
│       ├── local.sh         # Local file
│       └── transfer_sh.sh   # transfer.sh
├── adapters/
│   ├── claude-code/         # Claude Code adapter
│   │   ├── SKILL.md         # /ccgoon skill definition
│   │   ├── export.sh        # Read CC session data
│   │   └── import.sh        # Write CC session data + register
│   ├── cursor/              # Cursor adapter (stub)
│   └── codex/               # Codex adapter (stub)
├── docs/
│   └── session-formats.md   # CC/Cursor/Codex JSONL format reference
├── config/
│   └── default.json         # Default configuration
└── install.sh               # One-click installer
```

### Adding an Adapter

To support a new AI tool, create `adapters/<tool-name>/` with two files:

- `export.sh` — implement `adapter_export(session_id, project_dir, output_dir)`
- `import.sh` — implement `adapter_import(session_data_dir, target_project_dir, metadata_file)`

See `adapters/claude-code/` for a complete reference. PRs welcome!

## Comparison

|  | cc-go-on | [claudebin](https://github.com/wunderlabs-dev/claudebin.com) | [claude-replay](https://github.com/es617/claude-replay) | [ccshare](https://github.com/insomenia/ccshare) |
|--|---------|-----------|--------------|---------|
| **Encryption** | AES-256, auto random key | None | None | None |
| **Secret redaction** | Auto (API keys, tokens, creds) | Path stripping only | Regex-based, opt-out | None |
| **Cross-tool** | CC + Cursor + Codex (adapter) | CC only | CC + Cursor + Codex (read) | CC only |
| **Resume session** | Yes (import + /resume) | No | No | Partial |
| **Requires server** | No (transfer.sh default) | Supabase | No | ccshare.cc |
| **Output** | Encrypted file + token | Hosted URL | Self-contained HTML | Hosted URL |
| **Install** | `curl \| bash` + auto SKILL | CLI plugin | `npx` | `npx` |

cc-go-on focuses on **encrypted team handoff** and **cross-tool portability** — not viewing.

## Security

### Sensitive Information Redaction

Before upload, cc-go-on automatically scans and redacts:

- Private keys (PEM: RSA, EC, DSA, OpenSSH)
- AWS access key IDs (`AKIA...`)
- API keys (`sk-ant-...`, `sk-...`, `key-...`)
- Bearer tokens
- JWT tokens
- Database connection strings (postgres, mysql, mongodb, redis, amqp)
- Key-value secrets (`api_key=...`, `SECRET_KEY: "..."`, etc.)
- Environment variable assignments (`PASSWORD=...`, `TOKEN=...`)

This is on by default — no configuration needed.

## Related Projects & Credits

- [claude-replay](https://github.com/es617/claude-replay) (MIT, Enrico Santagati) — Session format parsing and secret redaction patterns in cc-go-on are derived from this project's research. Excellent tool for generating self-contained HTML replays.
- [claudebin.com](https://github.com/wunderlabs-dev/claudebin.com) (MIT, Wunderlabs) — Hosted session viewer with syntax highlighting and tool call rendering. Great for public sharing.
- [claude-code-share-plugin](https://github.com/PostHog/claude-code-share-plugin) — Convert sessions to markdown and push to GitHub repo.

## Dependencies

- `bash` 4+, `openssl`, `tar`, `curl`, `python3`, `git`
- All standard on macOS and Linux.

## License

MIT
