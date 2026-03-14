# Cursor Adapter

**Status**: Stub — contributions welcome!

## Session Location

```
~/.cursor/projects/<project>/agent-transcripts/<id>/transcript.jsonl
```

## Format

See [session-formats.md](../../docs/session-formats.md#cursor) for details.

Key differences from Claude Code:
- Top-level key is `role` instead of `type`
- No timestamps
- User text wrapped in `<user_query>` tags
- No explicit thinking blocks

## What Needs to Be Implemented

- `export.sh` — find and copy Cursor session files
- `import.sh` — write session data into Cursor's storage and register it

## References

- Format details derived from [claude-replay](https://github.com/es617/claude-replay) (MIT License, Enrico Santagati)
