# cc-go-on

**Share & resume AI coding sessions across tools.**

Export your AI coding session, encrypt it, share a token — your teammate picks up right where you left off. Works with **any AI coding assistant**: Claude Code, Codex, Cursor, Windsurf, Aider, and more.

> **cc-go-on** is not tied to any single AI tool. It's a universal session-sharing layer. Claude Code is the first supported adapter — others are open for community contribution.

[English](#why) | [中文](#为什么需要-cc-go-on)

---

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
# Export
~/.cc-go-on/share.sh export -a claude-code -p "my-secret"

# Import
~/.cc-go-on/share.sh import ccgo_aHR0cHM6Ly90... -a claude-code -p "my-secret"
```

The `-a` flag specifies the adapter. Use `claude-code`, `codex`, `cursor`, or any community adapter.

### Options

| Flag | Description |
|------|-------------|
| `-p, --passphrase` | Encryption passphrase |
| `-s, --session <id>` | Session ID (default: latest) |
| `-a, --adapter <name>` | AI tool adapter (default: auto-detect) |
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
| **Aider** | Planned | Contributions welcome |

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

---

# 中文说明

## 为什么需要 cc-go-on

你正在用 AI 编程助手处理一个复杂任务，做到一半需要交给同事继续、换一台电脑、甚至换一个 AI 工具。现在你只能手动复制文件、解释上下文，对话线索全部丢失。

**cc-go-on** 一行命令搞定：导出、分享 token、导入、继续。

> cc-go-on 不绑定任何特定 AI 工具。它是一个通用的 session 分享层。Claude Code 是第一个支持的适配器，其他工具（Codex、Cursor、Windsurf、Aider 等）欢迎社区贡献。

## 安装

```bash
curl -fsSL https://raw.githubusercontent.com/Johnixr/cc-go-on/main/install.sh | bash
```

或者直接把下面这句话粘贴给你的 AI 助手：
> 请帮我安装 cc-go-on 会话分享工具：`curl -fsSL https://raw.githubusercontent.com/Johnixr/cc-go-on/main/install.sh | bash`

安装脚本会：
1. 克隆到 `~/.cc-go-on/`
2. 自动检测已安装的 AI 工具（Claude Code、Codex、Cursor 等）
3. 为支持的工具安装原生集成（如 Claude Code 的 `/share` 命令）
4. 生成默认配置

## 使用方法

### Claude Code（通过 /share 命令）

```
/share                                       # 导出当前会话
/share ccgo_aHR0cHM6Ly90cmFuc2Zlci5zaC8...   # 导入同事分享的会话
```

### 命令行（适用于任何工具）

```bash
# 导出
~/.cc-go-on/share.sh export -a claude-code -p "我的密码"

# 导入
~/.cc-go-on/share.sh import ccgo_aHR0cHM6Ly90... -a claude-code -p "我的密码"
```

`-a` 参数指定适配器：`claude-code`、`codex`、`cursor`，或任何社区适配器。

## 工作原理

```
导出：Session 文件 → tar.gz 压缩 → AES-256-CBC 加密 → 上传 → 生成 token
导入：token → 下载 → 解密 → 路径重映射 → 注册到本地 → 继续对话
```

### 存储

默认使用 [transfer.sh](https://transfer.sh)，开箱即用，文件 7 天后自动过期。

也可以切换为 S3 兼容存储（Cloudflare R2、AWS S3、MinIO 等），或自建 transfer.sh 服务。详见英文文档 [Storage](#storage) 部分。

### 加密

- **项目密钥**（团队使用）：在项目根目录创建 `.cc-go-on-key` 文件，团队成员共享此文件
- **手动密码**（临时使用）：通过 `-p` 参数传入，密码需另行告知对方

所有加密使用 AES-256-CBC + PBKDF2（10 万次迭代）。

### 路径重映射

导入时自动将发送方的绝对路径替换为本机路径，无需手动处理。

## 支持的工具

| 工具 | 状态 | 说明 |
|------|------|------|
| **Claude Code** | 已支持 | 完整的导出/导入 + `/share` 命令 |
| **Codex** | 计划中 | 欢迎贡献 |
| **Cursor** | 计划中 | 欢迎贡献 |
| **Windsurf** | 计划中 | 欢迎贡献 |
| **Aider** | 计划中 | 欢迎贡献 |

### 贡献适配器

为新工具添加支持非常简单——只需在 `adapters/<工具名>/` 下实现两个函数：

- `adapter_export(session_id, project_dir, output_dir)` — 读取工具的 session 数据
- `adapter_import(session_data_dir, target_project_dir, metadata_file)` — 将 session 写入工具

参考 `adapters/claude-code/` 的实现。欢迎提交 PR！

## 卸载

```bash
~/.cc-go-on/install.sh --uninstall
```
