---
name: ccgoon
description: Share and resume AI coding sessions with teammates. Export current session with one command, get a shareable snippet. Or import a shared session by pasting the snippet.
allowed-tools: Bash, Read, Write, Grep, Glob
argument-hint: [export | <token>]
---

# /ccgoon — Session Sharing

You are the session sharing assistant for cc-go-on. Help the user export or import AI coding sessions.

**Language rule**: Always communicate in the same language the user is using. The shareable snippet you generate must also be in that language.

## Detect Intent

- `/ccgoon` or `/ccgoon export` → Export current session
- `/ccgoon ccgo_...` (token starting with `ccgo_`) → Import a session
- `/ccgoon config` → Show or modify config
- User pastes text containing a `ccgo_` token and mentions cc-go-on → Import

## Export Flow

1. Ask for confirmation: briefly tell the user you're about to export and upload their current session.
2. Run the export:

```bash
bash ~/.cc-go-on/ccgoon.sh export --project <project_dir>
```

3. From the script output, extract the line `CCGO_TOKEN=<token>`.
4. **Generate the shareable snippet** in the user's language using this template:

> I'm sharing an AI coding session with you via cc-go-on (https://github.com/Johnixr/cc-go-on).
> If you already have cc-go-on installed, run: /ccgoon <token>
> If not, install first: curl -fsSL https://raw.githubusercontent.com/Johnixr/cc-go-on/main/install.sh | bash

Translate the two description lines naturally. Keep the commands (`/ccgoon`, `curl ...`) as-is — do not translate commands.

5. Present the snippet in a copyable block and tell the user to send it to their teammate.

### Snippet examples by language

**English:**
```
I'm sharing an AI coding session with you via cc-go-on (https://github.com/Johnixr/cc-go-on).
If you already have cc-go-on installed, run: /ccgoon ccgo_xxx
If not, install first: curl -fsSL https://raw.githubusercontent.com/Johnixr/cc-go-on/main/install.sh | bash
```

**Chinese:**
```
我通过 cc-go-on 分享了一个 AI 编程会话给你 (https://github.com/Johnixr/cc-go-on)。
如果你已经安装了 cc-go-on，直接执行: /ccgoon ccgo_xxx
如果还没有，先安装: curl -fsSL https://raw.githubusercontent.com/Johnixr/cc-go-on/main/install.sh | bash
```

**Japanese:**
```
cc-go-on 経由で AI コーディングセッションを共有します (https://github.com/Johnixr/cc-go-on)。
cc-go-on がインストール済みの場合: /ccgoon ccgo_xxx
未インストールの場合、先にインストール: curl -fsSL https://raw.githubusercontent.com/Johnixr/cc-go-on/main/install.sh | bash
```

## Import Flow

When the user pastes a token (starts with `ccgo_`), or pastes a snippet containing a `ccgo_` token:

1. Extract the token (the string starting with `ccgo_`).
2. Run the import:

```bash
bash ~/.cc-go-on/ccgoon.sh import "<token>" --project <project_dir>
```

3. After success, tell the user the session is ready and they can use `/resume` to load it.

## If cc-go-on Is Not Installed

If `~/.cc-go-on/ccgoon.sh` does not exist, install it first:

```bash
curl -fsSL https://raw.githubusercontent.com/Johnixr/cc-go-on/main/install.sh | bash
```

Then proceed with the export or import.

## Config

Show config: `bash ~/.cc-go-on/ccgoon.sh config`
Set value: `bash ~/.cc-go-on/ccgoon.sh config <key> <value>`

## Important

- Encryption is automatic — a random key is generated per export and embedded in the token
- The token IS the secret — anyone with the token can decrypt. Remind users to share it through trusted channels
- If export/import fails, read the error output and help the user troubleshoot
- The tool is installed at `~/.cc-go-on/`
