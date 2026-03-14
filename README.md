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
3. For supported tools: installs native integration (e.g. `/share` skill for Claude Code)
4. Creates default config at `~/.cc-go-on/config.json`

### Uninstall

```bash
~/.cc-go-on/install.sh --uninstall
```

## Usage

### Claude Code (via /share skill)

```
/share                                    # Export current session
/share ccgo_aHR0cHM6Ly90cmFuc2Zlci5zaC8...  # Import a shared session
```

### CLI (works with any tool)

```bash
# Export — generates a shareable snippet with embedded key
~/.cc-go-on/share.sh export

# Import
~/.cc-go-on/share.sh import ccgo_eyJ1Ijoi...
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
Then load the session: /share ccgo_eyJ1IjoiaHR0cHM6Ly90cmFuc2Zlci5zaC8...
```

Your teammate pastes this into their AI tool — it handles install, download, decrypt, and import automatically.

### Storage

Default: [transfer.sh](https://transfer.sh) — zero config, files auto-expire in 7 days.

You can switch to S3-compatible storage (Cloudflare R2, AWS S3, MinIO, etc.):

```bash
~/.cc-go-on/share.sh config storage s3
~/.cc-go-on/share.sh config storage_options.s3.endpoint https://xxx.r2.cloudflarestorage.com
~/.cc-go-on/share.sh config storage_options.s3.bucket my-bucket
```

Or self-host transfer.sh:
```bash
~/.cc-go-on/share.sh config storage_options.transfer_sh.host https://your-server.com
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
| **Claude Code** | Supported | Full export/import with `/share` skill |
| **Codex** | Planned | Contributions welcome |
| **Cursor** | Planned | Contributions welcome |
| **Windsurf** | Planned | Contributions welcome |
| **Droid** | Planned | Contributions welcome |

The adapter interface is simple — see [Adding an Adapter](#adding-an-adapter) to contribute.

## Architecture

```
cc-go-on/
├── share.sh                 # CLI entry point
├── core/
│   ├── common.sh            # Config, utils, dependency checks
│   ├── crypto.sh            # AES-256-CBC encrypt/decrypt
│   ├── export.sh            # Package → encrypt → upload
│   ├── import.sh            # Download → decrypt → install
│   └── storage/
│       ├── transfer_sh.sh   # transfer.sh backend (default)
│       └── s3.sh            # S3-compatible backend
├── adapters/
│   └── claude-code/         # Claude Code adapter
│       ├── SKILL.md         # /share skill definition
│       ├── export.sh        # Read CC session data
│       └── import.sh        # Write CC session data + register
├── config/
│   └── default.json         # Default configuration
└── install.sh               # One-click installer
```

### Adding an Adapter

To support a new AI tool, create `adapters/<tool-name>/` with two files:

- `export.sh` — implement `adapter_export(session_id, project_dir, output_dir)`
- `import.sh` — implement `adapter_import(session_data_dir, target_project_dir, metadata_file)`

See `adapters/claude-code/` for a complete reference. PRs welcome!

## Related Projects

These projects focus on Claude Code session viewing and sharing:

- [claudebin.com](https://github.com/wunderlabs-dev/claudebin.com) — Export sessions to hosted viewer with resume support
- [claude-code-share-plugin](https://github.com/PostHog/claude-code-share-plugin) — Convert sessions to markdown, push to GitHub
- [claude-replay](https://github.com/es617/claude-replay) — Self-contained HTML replays

**cc-go-on** differs by focusing on **cross-tool portability** and **encrypted team handoff**, not just viewing.

## Dependencies

- `bash` 4+, `openssl`, `tar`, `curl`, `python3`, `git`
- All standard on macOS and Linux.

## License

MIT
