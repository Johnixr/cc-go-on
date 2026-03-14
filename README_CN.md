# cc-go-on

**跨工具的 AI 编程会话分享与接力。**

一行命令导出你的 AI 编程会话，加密分享给同事，对方一行命令导入，直接继续。支持 **Claude Code、Codex、Cursor、Windsurf、Droid** 等任意 AI 编程工具。

> cc-go-on 不绑定任何特定 AI 工具。它是一个通用的 session 分享层。Claude Code 是第一个支持的适配器，其他工具欢迎社区贡献。

## 解决什么问题

你正在用 AI 编程助手处理一个复杂任务：

- 做到一半，需要交给同事继续
- 想换一台电脑接着干
- 想把工作从 Claude Code 转到 Codex，或者反过来
- 想把和 AI 的对话过程分享给新同事，让他学习你的工作方式

现在你只能手动导出、复制文件、解释上下文，对话线索全部丢失。

**cc-go-on** 一行命令搞定：导出 → 分享 token → 导入 → 继续。

## 安装

```bash
curl -fsSL https://raw.githubusercontent.com/Johnixr/cc-go-on/main/install.sh | bash
```

或者直接把下面这句话粘贴给你的 AI 助手：

> 请帮我安装 cc-go-on 会话分享工具：`curl -fsSL https://raw.githubusercontent.com/Johnixr/cc-go-on/main/install.sh | bash`

安装脚本会：

1. 克隆到 `~/.cc-go-on/`
2. 自动检测已安装的 AI 工具（Claude Code、Codex、Cursor 等）
3. 为支持的工具安装原生集成（如 Claude Code 的 `/ccgoon` 命令）
4. 生成默认配置 `~/.cc-go-on/config.json`

## 使用方法

### Claude Code（通过 /ccgoon 命令）

```
/ccgoon                                      # 导出当前会话
/ccgoonccgo_aHR0cHM6Ly90cmFuc2Zlci5zaC8...   # 导入同事分享的会话
```

### 命令行（适用于任何工具）

```bash
# 导出 — 自动生成加密密钥，输出可分享的文字片段
~/.cc-go-on/ccgoon.sh export

# 导入
~/.cc-go-on/ccgoon.sh import ccgo_eyJ1Ijoi...
```

不需要设置密码。每次导出自动生成随机密钥，嵌入 token 中。

### 参数说明

| 参数 | 说明 |
|------|------|
| `-s, --session <id>` | 会话 ID（默认：最新的） |
| `-a, --adapter <name>` | AI 工具适配器（默认：自动检测） |
| `-d, --project <dir>` | 项目目录（默认：当前目录） |

## 工作原理

```
导出：Session 文件 → tar.gz 压缩 → 随机密钥 → AES-256 加密 → 上传 → token（含密钥）
导入：token → 提取密钥和 URL → 下载 → 解密 → 路径重映射 → 注册 → 继续对话
```

导出后会生成一段可直接复制的分享文字：

```
I'm sharing an AI coding session with you via cc-go-on.
Install (if first time): curl -fsSL https://raw.githubusercontent.com/Johnixr/cc-go-on/main/install.sh | bash
Then load the session: /ccgoonccgo_eyJ1IjoiaHR0cHM6Ly90cmFuc2Zlci5zaC8...
```

把这段文字发给同事，对方粘贴到 AI 工具里，自动完成安装、下载、解密、导入。

### 存储

默认使用 [transfer.sh](https://transfer.sh)，开箱即用，无需注册账号，文件 7 天后自动过期。

也支持切换为其他存储：

**S3 兼容存储**（Cloudflare R2、AWS S3、MinIO 等）：

```bash
~/.cc-go-on/ccgoon.sh config storage s3
~/.cc-go-on/ccgoon.sh config storage_options.s3.endpoint https://xxx.r2.cloudflarestorage.com
~/.cc-go-on/ccgoon.sh config storage_options.s3.bucket my-bucket
```

**自建 transfer.sh 服务**：

```bash
~/.cc-go-on/ccgoon.sh config storage_options.transfer_sh.host https://your-server.com
```

### 加密

每次导出自动生成随机 AES-256 密钥，嵌入 token 中。不需要记密码，也不需要单独传密钥。

Token 就是密钥——拿到 token 就能解密。请通过可信渠道（私信、Slack 等）分享 token。

### 路径重映射

导入时自动将发送方的绝对路径替换为本机路径：

```
/Users/alice/projects/myapp → /Users/bob/workspace/myapp
```

完全透明，无需手动处理。

## 支持的工具

| 工具 | 状态 | 说明 |
|------|------|------|
| **Claude Code** | 已支持 | 完整的导出/导入 + `/ccgoon` 命令 |
| **Codex** | 计划中 | 欢迎贡献 |
| **Cursor** | 计划中 | 欢迎贡献 |
| **Windsurf** | 计划中 | 欢迎贡献 |
| **Droid** | 计划中 | 欢迎贡献 |

## 项目结构

```
cc-go-on/
├── ccgoon.sh                 # CLI 入口
├── core/
│   ├── common.sh            # 配置、工具函数、依赖检查
│   ├── crypto.sh            # AES-256-CBC 加密/解密
│   ├── export.sh            # 打包 → 加密 → 上传
│   ├── import.sh            # 下载 → 解密 → 安装
│   └── storage/
│       ├── transfer_sh.sh   # transfer.sh 存储后端（默认）
│       └── s3.sh            # S3 兼容存储后端
├── adapters/
│   └── claude-code/         # Claude Code 适配器
│       ├── SKILL.md         # /ccgoon 命令定义
│       ├── export.sh        # 读取 CC 会话数据
│       └── import.sh        # 写入 CC 会话数据并注册
├── config/
│   └── default.json         # 默认配置
└── install.sh               # 一键安装脚本
```

### 贡献适配器

为新工具添加支持非常简单——只需在 `adapters/<工具名>/` 下实现两个函数：

- `adapter_export(session_id, project_dir, output_dir)` — 读取工具的 session 数据
- `adapter_import(session_data_dir, target_project_dir, metadata_file)` — 将 session 写入工具并注册

参考 `adapters/claude-code/` 的实现。欢迎提交 PR！

## 相关项目

以下项目专注于 Claude Code 会话的查看和分享：

- [claudebin.com](https://github.com/wunderlabs-dev/claudebin.com) — 导出会话到托管 Viewer，支持 resume
- [claude-code-share-plugin](https://github.com/PostHog/claude-code-share-plugin) — 转为 Markdown 并推送到 GitHub
- [claude-replay](https://github.com/es617/claude-replay) — 自包含的 HTML 回放

**cc-go-on** 的不同之处在于：专注**跨工具可移植性**和**加密团队交接**，而不仅仅是查看。

## 依赖

- `bash` 4+、`openssl`、`tar`、`curl`、`python3`、`git`
- macOS 和 Linux 上均为标准工具，无需额外安装

## 卸载

```bash
~/.cc-go-on/install.sh --uninstall
```

## 许可证

MIT
