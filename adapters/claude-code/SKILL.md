---
name: share
description: Share and resume AI coding sessions with teammates. Export current session with one command, get a shareable snippet. Or import a shared session by pasting the snippet.
allowed-tools: Bash, Read, Write, Grep, Glob
argument-hint: [export | <token>]
---

# /share — Session Sharing

You are the session sharing assistant for cc-go-on. Help the user export or import AI coding sessions.

## Detect Intent

- `/share` or `/share export` → Export current session
- `/share ccgo_...` (token starting with `ccgo_`) → Import a session
- `/share config` → Show or modify config
- User pastes a message containing `ccgo_` token and mentions cc-go-on → Import

## Export Flow

1. Determine the current project directory (use `$CWD` or git root)
2. Run the export (no passphrase needed — a random key is auto-generated and embedded in the token):

```bash
bash ~/.cc-go-on/share.sh export --project <project_dir>
```

3. The script outputs a shareable snippet between the dashed lines. Show it to the user and tell them:
   "Copy the text above and send it to your teammate. They just paste it into their AI tool and it handles the rest — install, download, decrypt, everything."

## Import Flow

When the user pastes a token (starts with `ccgo_`), or pastes a snippet that contains a `ccgo_` token:

1. Extract the token from the pasted text (find the string starting with `ccgo_`)
2. Run the import:

```bash
bash ~/.cc-go-on/share.sh import "<token>" --project <project_dir>
```

3. After success, tell the user the session is ready and they can use `/resume` to load it.

## If cc-go-on Is Not Installed

If `~/.cc-go-on/share.sh` does not exist, install it first:

```bash
curl -fsSL https://raw.githubusercontent.com/Johnixr/cc-go-on/main/install.sh | bash
```

Then proceed with the export or import.

## Config

Show config: `bash ~/.cc-go-on/share.sh config`
Set value: `bash ~/.cc-go-on/share.sh config <key> <value>`

## Important

- ALWAYS ask for confirmation before exporting (the user should know what's being shared)
- Encryption is automatic — a random key is generated per export and embedded in the token
- The token IS the secret — anyone with the token can decrypt. Remind users to share it through trusted channels
- If export/import fails, read the error output and help troubleshoot
- The tool is installed at `~/.cc-go-on/`
