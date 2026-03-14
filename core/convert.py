#!/usr/bin/env python3
"""
cc-go-on: session format converter
Converts between Claude Code, Cursor, and Codex JSONL formats.
Format detection and normalization logic derived from claude-replay (MIT, Enrico Santagati).
"""
import json
import sys
import re
import os
from datetime import datetime


# --- Format detection ---

def detect_format(filepath):
    """Detect session format from first parseable JSON line."""
    with open(filepath, 'r') as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            try:
                obj = json.loads(line)
            except json.JSONDecodeError:
                continue
            if obj.get('type') in ('user', 'assistant'):
                return 'claude-code'
            if obj.get('role') in ('user', 'assistant') and 'type' not in obj:
                return 'cursor'
            if obj.get('type') == 'session_meta':
                return 'codex'
            break
    return 'unknown'


# --- Tag cleaning (shared) ---

SYSTEM_TAG_PATTERNS = [
    (re.compile(r'<system-reminder>[\s\S]*?</system-reminder>'), ''),
    (re.compile(r'<local-command-caveat>[\s\S]*?</local-command-caveat>'), ''),
    (re.compile(r'<command-message>[\s\S]*?</command-message>'), ''),
    (re.compile(r'<local-command-stdout>[\s\S]*?</local-command-stdout>'), ''),
    (re.compile(r'<ide_opened_file>[\s\S]*?</ide_opened_file>'), ''),
    (re.compile(r'<command-name>(.*?)</command-name>'), r'\1'),
    (re.compile(r'<command-args>(.*?)</command-args>'), lambda m: m.group(1) if m.group(1).strip() else ''),
    (re.compile(r'<user_query>\n?([\s\S]*?)\n?</user_query>'), r'\1'),
]

def clean_tags(text):
    if not isinstance(text, str):
        return text
    for pattern, repl in SYSTEM_TAG_PATTERNS:
        text = pattern.sub(repl, text)
    return text.strip()


def clean_content_blocks(content):
    """Clean system tags from content (string or array of blocks)."""
    if isinstance(content, str):
        return clean_tags(content)
    if isinstance(content, list):
        result = []
        for block in content:
            if isinstance(block, dict) and block.get('type') == 'text':
                cleaned = clean_tags(block.get('text', ''))
                if cleaned:
                    result.append({**block, 'text': cleaned})
            else:
                result.append(block)
        return result
    return content


# --- Cursor → Claude Code ---

def convert_cursor_to_cc(input_path, output_path):
    """Convert Cursor JSONL to Claude Code format."""
    messages = []
    with open(input_path, 'r') as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            try:
                obj = json.loads(line)
            except json.JSONDecodeError:
                continue

            role = obj.get('role', '')
            msg = obj.get('message', {})
            content = msg.get('content', '')

            content = clean_content_blocks(content)

            cc_entry = {
                'type': role,
                'message': {
                    'role': role,
                    'content': content,
                },
                'timestamp': datetime.utcnow().isoformat() + 'Z',
            }
            messages.append(cc_entry)

    with open(output_path, 'w') as f:
        for msg in messages:
            f.write(json.dumps(msg, ensure_ascii=False) + '\n')

    return len(messages)


# --- Codex → Claude Code ---

CODEX_METADATA_STRIP = re.compile(
    r'^(Chunk ID:.*|Wall time:.*|Process exited with code.*|Original token count:.*|Output:\s*)$',
    re.MULTILINE
)
CODEX_USER_TEXT_MARKER = '## My request for Codex:'

def extract_codex_user_text(text):
    """Extract actual user text from Codex user_message (strip IDE context)."""
    if CODEX_USER_TEXT_MARKER in text:
        return text.split(CODEX_USER_TEXT_MARKER, 1)[1].strip()
    return text

def clean_codex_tool_output(output):
    """Strip Codex metadata lines from tool output."""
    if isinstance(output, str):
        return CODEX_METADATA_STRIP.sub('', output).strip()
    if isinstance(output, dict):
        return clean_codex_tool_output(output.get('output', str(output)))
    return str(output)

def convert_codex_to_cc(input_path, output_path):
    """Convert Codex event-based JSONL to Claude Code format."""
    messages = []
    pending_tool_calls = {}  # call_id -> tool_use block

    with open(input_path, 'r') as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            try:
                obj = json.loads(line)
            except json.JSONDecodeError:
                continue

            timestamp = obj.get('timestamp', datetime.utcnow().isoformat() + 'Z')
            evt_type = obj.get('type', '')
            payload = obj.get('payload', {})

            if evt_type == 'session_meta':
                continue

            if evt_type == 'event_msg':
                msg_type = payload.get('type', '')
                if msg_type == 'user_message':
                    user_text = extract_codex_user_text(payload.get('message', ''))
                    messages.append({
                        'type': 'user',
                        'message': {
                            'role': 'user',
                            'content': user_text,
                        },
                        'timestamp': timestamp,
                    })
                # task_started, task_complete — skip
                continue

            if evt_type == 'response_item':
                item_type = payload.get('type', '')

                if item_type == 'message':
                    content_blocks = []
                    phase = payload.get('phase', '')
                    for block in payload.get('content', []):
                        text = block.get('text', '')
                        if not text:
                            continue
                        if phase == 'commentary':
                            content_blocks.append({'type': 'thinking', 'thinking': text})
                        else:
                            content_blocks.append({'type': 'text', 'text': text})

                    if content_blocks:
                        messages.append({
                            'type': 'assistant',
                            'message': {
                                'role': 'assistant',
                                'content': content_blocks,
                            },
                            'timestamp': timestamp,
                        })

                elif item_type == 'function_call':
                    name = payload.get('name', '')
                    call_id = payload.get('call_id', '')
                    try:
                        args = json.loads(payload.get('arguments', '{}'))
                    except json.JSONDecodeError:
                        args = {'raw': payload.get('arguments', '')}

                    # Normalize tool names
                    cc_name = name
                    cc_input = args
                    if name == 'exec_command':
                        cc_name = 'Bash'
                        cmd = args.get('cmd', '')
                        workdir = args.get('workdir', '')
                        if workdir:
                            cmd = f'cd {workdir} && {cmd}'
                        cc_input = {'command': cmd}
                    elif name == 'apply_patch':
                        cc_name = 'Edit'
                        cc_input = {'patch': payload.get('arguments', args.get('raw', ''))}

                    tool_block = {
                        'type': 'tool_use',
                        'id': call_id,
                        'name': cc_name,
                        'input': cc_input,
                    }
                    pending_tool_calls[call_id] = tool_block

                    messages.append({
                        'type': 'assistant',
                        'message': {
                            'role': 'assistant',
                            'content': [tool_block],
                        },
                        'timestamp': timestamp,
                    })

                elif item_type in ('function_call_output', 'custom_tool_call_output'):
                    call_id = payload.get('call_id', '')
                    output = clean_codex_tool_output(payload.get('output', ''))

                    messages.append({
                        'type': 'user',
                        'message': {
                            'role': 'user',
                            'content': [{
                                'type': 'tool_result',
                                'tool_use_id': call_id,
                                'content': output,
                            }],
                        },
                        'timestamp': timestamp,
                    })

                elif item_type == 'custom_tool_call':
                    # Same as function_call
                    name = payload.get('name', '')
                    call_id = payload.get('call_id', '')
                    raw_input = payload.get('input', '')

                    cc_name = name
                    cc_input = {'raw': raw_input}
                    if name == 'apply_patch':
                        cc_name = 'Edit'
                        cc_input = {'patch': raw_input}

                    tool_block = {
                        'type': 'tool_use',
                        'id': call_id,
                        'name': cc_name,
                        'input': cc_input,
                    }
                    messages.append({
                        'type': 'assistant',
                        'message': {
                            'role': 'assistant',
                            'content': [tool_block],
                        },
                        'timestamp': timestamp,
                    })

    with open(output_path, 'w') as f:
        for msg in messages:
            f.write(json.dumps(msg, ensure_ascii=False) + '\n')

    return len(messages)


# --- Main ---

def convert(input_path, output_path, target_format='claude-code'):
    """Convert any supported format to target format."""
    source_format = detect_format(input_path)

    if source_format == 'unknown':
        print(f'ERROR: Cannot detect format of {input_path}', file=sys.stderr)
        return False

    if source_format == target_format:
        # Same format — just clean tags
        if source_format == 'claude-code':
            # Copy as-is (already in target format)
            import shutil
            shutil.copy2(input_path, output_path)
            print(f'format:{source_format}')
            print(f'action:copy')
            return True

    if target_format != 'claude-code':
        print(f'ERROR: Only claude-code target format is supported', file=sys.stderr)
        return False

    if source_format == 'cursor':
        count = convert_cursor_to_cc(input_path, output_path)
        print(f'format:{source_format}')
        print(f'action:converted')
        print(f'messages:{count}')
        return True

    if source_format == 'codex':
        count = convert_codex_to_cc(input_path, output_path)
        print(f'format:{source_format}')
        print(f'action:converted')
        print(f'messages:{count}')
        return True

    print(f'ERROR: No converter for {source_format} → {target_format}', file=sys.stderr)
    return False


if __name__ == '__main__':
    if len(sys.argv) < 2:
        print('Usage: convert.py <input.jsonl> [output.jsonl] [--target claude-code]')
        print('       convert.py --detect <input.jsonl>')
        sys.exit(1)

    if sys.argv[1] == '--detect':
        fmt = detect_format(sys.argv[2])
        print(f'format:{fmt}')
        sys.exit(0)

    input_file = sys.argv[1]
    output_file = sys.argv[2] if len(sys.argv) > 2 and not sys.argv[2].startswith('--') else input_file + '.converted.jsonl'
    target = 'claude-code'

    for i, arg in enumerate(sys.argv):
        if arg == '--target' and i + 1 < len(sys.argv):
            target = sys.argv[i + 1]

    success = convert(input_file, output_file, target)
    sys.exit(0 if success else 1)
