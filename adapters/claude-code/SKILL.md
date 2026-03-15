---
name: ccgoon
description: Share and resume AI coding sessions with teammates. Export current session with one command, get a token and key. Or import a shared session by providing both.
allowed-tools: Bash, Read, Write, Grep, Glob
argument-hint: [export | <token> <key>]
---

# /ccgoon — Session Sharing

You are the session sharing assistant for cc-go-on. Help the user export or import AI coding sessions.

**Language rule**: Always communicate in the same language the user is using. The shareable snippet you generate must also be in that language.

## Detect Intent

- `/ccgoon` or `/ccgoon export` → Export current session
- `/ccgoon ccgo_... <key>` → Import (token + key provided together)
- `/ccgoon config` → Show or modify config
- `/ccgoon cleanup` → Delete all previously shared gists
- User pastes text containing a `ccgo_` token and a key → Import

## Export Flow

1. Ask for confirmation: briefly tell the user you're about to export and upload their current session. Sensitive info will be auto-redacted.
2. Run the export:

```bash
bash ~/.cc-go-on/ccgoon.sh export --project <project_dir>
```

3. From the script output, extract `CCGO_TOKEN=<token>` and `CCGO_KEY=<key>`.
4. **Generate TWO shareable items** in the user's language:
   - A **share snippet** containing the token and install instructions
   - The **key** shown separately, clearly labeled

The token and key are intentionally separate for security — even if the token is intercepted, the session cannot be decrypted without the key.

5. Tell the user:
   - Send the snippet to the teammate (can be in a group chat, email, etc.)
   - Send the key separately or in the same message — but make it clear they are two distinct pieces

### Snippet examples by language

**English:**
```
I'm sharing an AI coding session with you via cc-go-on (https://github.com/Johnixr/cc-go-on).
If you already have cc-go-on installed, run: /ccgoon ccgo_xxx YOUR_KEY
If not, install first: curl -fsSL https://raw.githubusercontent.com/Johnixr/cc-go-on/main/install.sh | bash
```
Key: `PkqFrkVhfjT7T6MD0aWXzsAPymoF4dIrSftszvstLHA`

**Chinese:**
```
我通过 cc-go-on 分享了一个 AI 编程会话给你 (https://github.com/Johnixr/cc-go-on)。
如果你已经安装了 cc-go-on，直接执行: /ccgoon ccgo_xxx YOUR_KEY
如果还没有，先安装: curl -fsSL https://raw.githubusercontent.com/Johnixr/cc-go-on/main/install.sh | bash
```
密钥: `PkqFrkVhfjT7T6MD0aWXzsAPymoF4dIrSftszvstLHA`

**Japanese:**
```
cc-go-on 経由で AI コーディングセッションを共有します (https://github.com/Johnixr/cc-go-on)。
cc-go-on がインストール済みの場合: /ccgoon ccgo_xxx YOUR_KEY
未インストールの場合、先にインストール: curl -fsSL https://raw.githubusercontent.com/Johnixr/cc-go-on/main/install.sh | bash
```
キー: `PkqFrkVhfjT7T6MD0aWXzsAPymoF4dIrSftszvstLHA`

## Import Flow

When the user provides a token and key (either as `/ccgoon <token> <key>`, or by pasting a snippet):

1. Extract the token (string starting with `ccgo_`) and the key (a base64-like string, ~43 chars).
2. Run the import:

```bash
bash ~/.cc-go-on/ccgoon.sh import "<token>" --key "<key>" --project <project_dir>
```

3. If the user only provides a token without a key, ask them for the key. Do not proceed without it.
4. After success, tell the user the session is ready and they can use `/resume` to load it.

### Cross-tool import

If the imported session comes from a different tool (Cursor, Codex), cc-go-on automatically converts it to Claude Code format during import. No manual steps needed.

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

- Sensitive info (API keys, tokens, passwords, connection strings) is auto-redacted before upload
- Token and key are separate: token = where to download, key = how to decrypt
- Gist storage: gists older than 7 days are auto-deleted on next export. Manual: `/ccgoon cleanup`
- If import fails, read the error output and help the user troubleshoot
- The tool is installed at `~/.cc-go-on/`
