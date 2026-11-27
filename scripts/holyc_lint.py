#!/usr/bin/env python3
"""Static checks for HolyC source, aimed at errors TempleOS reports badly.

It knows about TempleOS built-in macros from tos/*.HH and flags:
  * game identifiers that collide with built-in macros (the 'eps' bug)
  * function-like macros (unsupported)
  * ?: / continue / struct initializer lists (unsupported)
  * bare uses of known zero-arg built-in functions such as tS
"""
import os
import re
import sys

BASE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(BASE)
TOS = os.path.join(ROOT, 'tos')
DEFINE_RE = re.compile(r'^\s*#\s*define\s+([A-Za-z_]\w*)')
FUNC_MACRO_RE = re.compile(r'^\s*#\s*define\s+([A-Za-z_]\w*)\(')
DECL_RE = re.compile(
    r'^\s*(?:I8|U8|I16|U16|I32|U32|I64|U64|F64|Bool|U0|class|public)\s+([A-Za-z_]\w*)'
)

# Built-in functions that take no arguments and are easy to call by mistake.
ZERO_ARG_FUNCS = ('tS',)


def strip_noncode(text):
    """Remove // and /* */ comments and string literals, preserving newlines."""
    # Replace comment contents with spaces/newlines first, so apostrophes in
    # documentation don't get mistaken for character literals.
    out = []
    i = 0
    n = len(text)
    while i < n:
        if text.startswith('//', i):
            j = text.find('\n', i)
            if j < 0:
                break
            out.append('\n')
            i = j + 1
            continue
        if text.startswith('/*', i):
            j = text.find('*/', i + 2)
            if j < 0:
                j = n - 2
            chunk = text[i:j + 2]
            out.append(''.join('\n' if c == '\n' else ' ' for c in chunk))
            i = j + 2
            continue
        out.append(text[i])
        i += 1
    text = ''.join(out)

    out = []
    i = 0
    n = len(text)
    while i < n:
        c = text[i]
        if c == '"':
            i += 1
            while i < n and text[i] != '"':
                if text[i] == '\\' and i + 1 < n:
                    i += 2
                else:
                    out.append(' ')
                    i += 1
            out.append(' ')
            i += 1
            continue
        out.append(c)
        i += 1
    return ''.join(out)


def builtin_macros():
    names = set()
    if not os.path.isdir(TOS):
        return names
    for fn in os.listdir(TOS):
        if not fn.endswith(('.HH', '.HC')):
            continue
        try:
            lines = open(os.path.join(TOS, fn), errors='replace').read().splitlines()
        except OSError:
            continue
        for line in lines:
            m = DEFINE_RE.match(line)
            if m:
                names.add(m.group(1))
    return names


def lint(path):
    text = open(path, errors='replace').read()
    code = strip_noncode(text)
    lines = code.splitlines()
    macros = builtin_macros()

    game_defines = set()
    game_decls = set()
    issues = []

    for no, line in enumerate(lines, 1):
        m = DEFINE_RE.match(line)
        if m:
            game_defines.add(m.group(1))
            if FUNC_MACRO_RE.match(line):
                issues.append((no, 'error', 'function-like macro %s is not supported by HolyC' % m.group(1)))
        m = DECL_RE.match(line)
        if m:
            game_decls.add(m.group(1))

    collisions = sorted((game_defines | game_decls) & macros)
    for name in collisions:
        issues.append((0, 'error', 'identifier %s collides with a TempleOS built-in macro' % name))

    for no, line in enumerate(lines, 1):
        if '?' in line:
            issues.append((no, 'error', '?: is not supported by HolyC'))
        if re.search(r'\bcontinue\b', line):
            issues.append((no, 'error', 'continue is not supported by HolyC'))
        if re.search(r'=\s*\{', line):
            issues.append((no, 'warning', 'struct initializer lists are not supported by HolyC'))
        for fn in ZERO_ARG_FUNCS:
            for m in re.finditer(r'\b%s\b(?!\s*\()' % re.escape(fn), line):
                if re.search(r'\b(?:U0|F64|I64|U8)\s+%s\b' % re.escape(fn), line):
                    continue  # declaration/definition
                issues.append((no, 'error', 'bare %s: call it as %s()' % (fn, fn)))

    # unique, sorted by line then message
    seen = set()
    unique = []
    for issue in sorted(set(issues)):
        if issue[2] not in seen:
            seen.add(issue[2])
            unique.append(issue)
    return unique


if __name__ == '__main__':
    path = sys.argv[1] if len(sys.argv) > 1 else os.path.join(ROOT, 'src', 'MCRAFT.HC')
    issues = lint(path)
    if not issues:
        print('OK: no HolyC issues found')
        sys.exit(0)
    for no, sev, msg in issues:
        where = '%s:%d' % (os.path.basename(path), no) if no else os.path.basename(path)
        print('%s: %s: %s' % (where, sev, msg))
    sys.exit(1)
