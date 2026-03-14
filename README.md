# cc-go-on

**Claude Code, go on.** Share & resume AI coding sessions across tools.

Export your AI coding session, encrypt it, share a token with your teammate, and they can pick up right where you left off — in one command.

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
2. Detects your AI tools (Claude Code, Codex, Cursor)
3. For Claude Code: installs `/share` as a skill
4. Creates default config at `~/.cc-go-on/config.json`

### Uninstall

```bash
~/.cc-go-on/install.sh --uninstall
```

## Usage

### Claude Code (via /share skill)

```
# Export current session
/share

# Import a shared session
/share ccgo_aHR0cHM6Ly90cmFuc2Zlci5zaC8...
```

### CLI (any tool)

```bash
# Export
~/.cc-go-on/share.sh export -p "my-secret-passphrase"

# Import
~/.cc-go-on/share.sh import ccgo_aHR0cHM6Ly90... -p "my-secret-passphrase"
```

### Options

| Flag | Description |
|------|-------------|
| `-p, --passphrase` | Encryption passphrase |
| `-s, --session <id>` | Session ID (default: latest) |
| `-a, --adapter <name>` | AI tool: `claude-code`, `codex`, `cursor` |
| `-d, --project <dir>` | Project directory (default: current) |

## How It Works

```
Export:  Session files → tar.gz → AES-256-CBC encrypt → upload → token
Import: token → download → decrypt → path remap → register → resume
```

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

Two modes:

1. **Project key** (team use): Create `.cc-go-on-key` in your project root. Share this file with your team via secure channel. Add it to `.gitignore`.

2. **Passphrase** (ad-hoc): Pass `-p` flag. Share the passphrase separately.

All encryption uses AES-256-CBC with PBKDF2 (100k iterations).

### Path Remapping

When importing, absolute paths in session data are automatically remapped from the sender's machine to yours. For example:

```
/Users/alice/projects/myapp → /Users/bob/workspace/myapp
```

This happens transparently — just import and go.

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

To support a new AI tool, create `adapters/<tool-name>/` with:

- `export.sh` — implement `adapter_export(session_id, project_dir, output_dir)`
- `import.sh` — implement `adapter_import(session_data_dir, target_project_dir, metadata_file)`

See `adapters/claude-code/` for reference. PRs welcome!

## Supported Tools

| Tool | Status | Notes |
|------|--------|-------|
| Claude Code | Supported | Full export/import with `/share` skill |
| Codex | Planned | Contributions welcome |
| Cursor | Planned | Contributions welcome |
| Windsurf | Planned | Contributions welcome |
| Aider | Planned | Contributions welcome |

## Related Projects

These projects focus on Claude Code session viewing and sharing:

- [claudebin.com](https://github.com/wunderlabs-dev/claudebin.com) — Export CC sessions to hosted viewer with resume support
- [claude-code-share-plugin](https://github.com/PostHog/claude-code-share-plugin) — Convert sessions to markdown, push to GitHub
- [claude-replay](https://github.com/es617/claude-replay) — Self-contained HTML replays of CC sessions

**cc-go-on** differs by focusing on **cross-tool portability** and **encrypted team handoff**, not just viewing.

## Dependencies

- `bash` 4+
- `openssl` (for AES encryption)
- `tar`, `curl`
- `python3` (for JSON handling and metadata)
- `git`

All standard on macOS and Linux.

## License

MIT
