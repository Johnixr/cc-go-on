# Session Format Reference

This document describes how different AI coding tools store their sessions.
Used by adapters and SKILL.md to guide format-aware import/export.

## Claude Code

**Storage**: `~/.claude/projects/<project-path-hash>/<session-id>.jsonl`
- Subagents: `<session-id>/subagents/agent-<id>.jsonl`
- Tool results: `<session-id>/tool-results/<hash>.txt`
- Index: `sessions-index.json`

**JSONL format** — each line:
```json
{"type":"user","message":{"role":"user","content":"text or array"},"uuid":"...","timestamp":"ISO8601","sessionId":"...","cwd":"...","gitBranch":"..."}
{"type":"assistant","message":{"role":"assistant","content":[blocks]},"uuid":"...","timestamp":"ISO8601"}
```

**Content block types**:
- `{"type":"text","text":"..."}` — plain text
- `{"type":"thinking","thinking":"..."}` — model reasoning
- `{"type":"tool_use","id":"...","name":"Bash","input":{...}}` — tool call
- `{"type":"tool_result","tool_use_id":"...","content":"..."}` — tool output (in user messages)

**System tags in user messages** (should be cleaned on display):
- `<system-reminder>` — injected system context
- `<local-command-caveat>`, `<command-name>`, `<command-message>`, `<command-args>`, `<local-command-stdout>`

---

## Cursor

**Storage**: `~/.cursor/projects/<project>/agent-transcripts/<id>/transcript.jsonl`
- Fallback: `<id>/<id>.jsonl`

**JSONL format** — each line:
```json
{"role":"user","message":{"content":[{"type":"text","text":"<user_query>\n...\n</user_query>"}]}}
{"role":"assistant","message":{"content":[{"type":"text","text":"..."}]}}
```

**Key differences from Claude Code**:
- Top-level key is `role` (not `type`)
- No `timestamp` field
- User text is wrapped in `<user_query>` tags
- No `thinking` block type; multiple assistant messages per turn, all but last are reasoning
- No `<ide_opened_file>` tags (Cursor-specific context)

---

## Codex (OpenAI)

**Storage**: `~/.codex/sessions/<YYYY>/<MM>/<DD>/rollout-<timestamp>-<uuid>.jsonl`

**JSONL format** — event-based, each line:
```json
{"timestamp":"...","type":"session_meta","payload":{"id":"...","model_provider":"openai"}}
{"timestamp":"...","type":"event_msg","payload":{"type":"user_message","message":"..."}}
{"timestamp":"...","type":"response_item","payload":{"type":"message","role":"assistant","content":[{"type":"output_text","text":"..."}],"phase":"commentary|final_answer"}}
{"timestamp":"...","type":"response_item","payload":{"type":"function_call","name":"exec_command","arguments":"{\"cmd\":\"ls\"}"}}
{"timestamp":"...","type":"response_item","payload":{"type":"function_call_output","call_id":"...","output":"..."}}
{"timestamp":"...","type":"event_msg","payload":{"type":"task_complete"}}
```

**Key differences**:
- Event-based, not message-based
- First line is always `session_meta`
- Turns bounded by `task_started` / `task_complete` events
- User text follows marker `"## My request for Codex:"` (strip IDE context before it)
- `phase: "commentary"` = thinking, `phase: "final_answer"` = output
- `type: "reasoning"` events are encrypted and should be skipped
- `exec_command` = Bash, `apply_patch` = file edit
- Tool output has metadata lines to strip: `Chunk ID:`, `Wall time:`, `Process exited with code N`

---

## Format Detection

Auto-detect by reading the first parseable JSON line:

| Condition | Format |
|-----------|--------|
| `obj.type === "user"` or `obj.type === "assistant"` | Claude Code |
| `obj.role === "user"` or `obj.role === "assistant"` (no `type`) | Cursor |
| `obj.type === "session_meta"` | Codex |
