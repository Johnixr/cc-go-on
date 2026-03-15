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
- `/ccgoon` with text containing both `ccgo_` token and a key → Import
- `/ccgoon config` → Show or modify config
- `/ccgoon cleanup` → Delete all previously shared gists
- User pastes text containing `[ccgo-token]` and `[ccgo-key]` → Import

## Export Flow

1. Ask for confirmation: briefly tell the user you're about to export and upload their current session. Sensitive info will be auto-redacted.
2. Run the export:

```bash
bash ~/.cc-go-on/ccgoon.sh export --project <project_dir>
```

3. From the script output, extract `CCGO_TOKEN=<token>` and `CCGO_KEY=<key>`.
4. **Generate the shareable snippet** in the user's language. Token and key MUST be on separate labeled lines using the exact format below — this ensures any AI tool can parse them unambiguously:

### Snippet examples by language

**English:**
```
I'm sharing an AI coding session with you via cc-go-on (https://github.com/Johnixr/cc-go-on).
If not installed: curl -fsSL https://raw.githubusercontent.com/Johnixr/cc-go-on/main/install.sh | bash
[ccgo-token] ccgo_eyJ1IjoiZ2lzdDovLzBl...
[ccgo-key] PkqFrkVhfjT7T6MD0aWXzsAPymoF4dIrSftszvstLHA
```

**Chinese:**
```
我通过 cc-go-on 分享了一个 AI 编程会话给你 (https://github.com/Johnixr/cc-go-on)。
如果还没有安装: curl -fsSL https://raw.githubusercontent.com/Johnixr/cc-go-on/main/install.sh | bash
[ccgo-token] ccgo_eyJ1IjoiZ2lzdDovLzBl...
[ccgo-key] PkqFrkVhfjT7T6MD0aWXzsAPymoF4dIrSftszvstLHA
```

**Japanese:**
```
cc-go-on 経由で AI コーディングセッションを共有します (https://github.com/Johnixr/cc-go-on)。
未インストールの場合: curl -fsSL https://raw.githubusercontent.com/Johnixr/cc-go-on/main/install.sh | bash
[ccgo-token] ccgo_eyJ1IjoiZ2lzdDovLzBl...
[ccgo-key] PkqFrkVhfjT7T6MD0aWXzsAPymoF4dIrSftszvstLHA
```

**Critical**: Always use the `[ccgo-token]` and `[ccgo-key]` labels exactly as shown. These are machine-readable markers that any AI tool can parse reliably.

5. Present the snippet in a copyable block and tell the user to send it to their teammate.

## Import Flow

When the user pastes text containing a session share:

1. **Parse the structured fields**:
   - Find the line starting with `[ccgo-token]` → extract the `ccgo_...` string after it
   - Find the line starting with `[ccgo-key]` → extract the key string after it
2. Run the import with `--key`. The `--project` must be the **recipient's current working directory** (where they are running Claude Code), NOT the sender's original path:

```bash
bash ~/.cc-go-on/ccgoon.sh import "<token>" --key "<key>" --project "$(pwd)"
```

3. **CRITICAL**: The `--key` parameter is REQUIRED. Never pass the key as part of the token string. They are two separate values:
   - Token (`ccgo_...`): ~80 chars, starts with `ccgo_`
   - Key: ~43 chars, base64 string (letters, numbers, +, /)

4. If the user only provides a token without a key, ask them for the key. Do not proceed without it.
5. After success, tell the user the session is ready and they can use `/resume` to load it.

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
