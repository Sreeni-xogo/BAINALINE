#!/usr/bin/env python3
"""
Search a Claude Code JSONL session file for a keyword.
Usage: python3 search-jsonl.py <file.jsonl> <keyword>
"""
import json
import sys
import os


def extract_text(content):
    if isinstance(content, list):
        parts = []
        for block in content:
            if isinstance(block, dict):
                if block.get('type') == 'text':
                    parts.append(block.get('text', ''))
                elif block.get('type') == 'thinking':
                    parts.append('[THINKING] ' + block.get('thinking', '')[:100])
        return ' '.join(parts)
    return str(content) if content else ''


def search_jsonl(jsonl_file, keyword):
    keyword_lower = keyword.lower()
    matches = []

    with open(jsonl_file, 'r', encoding='utf-8') as f:
        lines = f.readlines()

    for i, raw_line in enumerate(lines):
        try:
            obj = json.loads(raw_line)
        except json.JSONDecodeError:
            continue

        msg_type = obj.get('type')
        if msg_type not in ('assistant', 'user'):
            continue

        msg = obj.get('message', {})
        role = msg.get('role', msg_type)
        content = msg.get('content', '')
        text = extract_text(content)

        if keyword_lower in text.lower():
            matches.append({
                'line': i + 1,
                'role': role,
                'text': text,
                'timestamp': obj.get('timestamp', ''),
            })

    return matches, len(lines)


def main():
    if len(sys.argv) < 3:
        print('Usage: search-jsonl.py <file.jsonl> <keyword>')
        sys.exit(1)

    jsonl_file = sys.argv[1]
    keyword = ' '.join(sys.argv[2:])

    if not os.path.exists(jsonl_file):
        print(f'File not found: {jsonl_file}')
        sys.exit(1)

    matches, total_lines = search_jsonl(jsonl_file, keyword)

    print(f'File: {jsonl_file}')
    print(f'Total lines: {total_lines}')
    print(f"Keyword: '{keyword}'")
    print(f'Matches found: {len(matches)}')
    print('=' * 60)

    for m in matches:
        ts = m['timestamp'][:19].replace('T', ' ') if m['timestamp'] else ''
        print(f"\n[Line {m['line']}] ({m['role']}) {ts}")
        print(m['text'][:400])
        print('-' * 40)


if __name__ == '__main__':
    main()
