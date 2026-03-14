# Codex Adapter

**Status**: Stub — contributions welcome!

## Session Location

```
~/.codex/sessions/<YYYY>/<MM>/<DD>/rollout-<timestamp>-<uuid>.jsonl
```

## Format

See [session-formats.md](../../docs/session-formats.md#codex-openai) for details.

Key differences from Claude Code:
- Event-based format with `session_meta`, `event_msg`, `response_item` types
- Turns bounded by `task_started` / `task_complete` events
- `exec_command` = Bash tool, `apply_patch` = file edit
- `phase: "commentary"` = thinking, `phase: "final_answer"` = output

## What Needs to Be Implemented

- `export.sh` — find and copy Codex session files
- `import.sh` — write session data into Codex's storage

## References

- Format details derived from [claude-replay](https://github.com/es617/claude-replay) (MIT License, Enrico Santagati)
