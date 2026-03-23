#!/usr/bin/env python3
"""Pattern 4: Fine-grained progress bar with true color gradient"""
# https://nyosegawa.com/posts/claude-code-statusline-rate-limits/
import json, subprocess, sys
from datetime import datetime, timezone, timedelta

JST = timezone(timedelta(hours=9))

data = json.load(sys.stdin)

BLOCKS = ' ▏▎▍▌▋▊▉█'
R = '\033[0m'
DIM = '\033[2m'

def gradient(pct):
    if pct < 50:
        r = int(pct * 5.1)
        return f'\033[38;2;{r};200;80m'
    else:
        g = int(200 - (pct - 50) * 4)
        return f'\033[38;2;255;{max(g,0)};60m'

def bar(pct, width=10):
    pct = min(max(pct, 0), 100)
    filled = pct * width / 100
    full = int(filled)
    frac = int((filled - full) * 8)
    b = '█' * full
    if full < width:
        b += BLOCKS[frac]
        b += '░' * (width - full - 1)
    return b

def reset_text(resets_at, short):
    if resets_at is None:
        return ''
    dt = datetime.fromtimestamp(resets_at, tz=JST)
    if short == 'h':
        h = dt.strftime('%I').lstrip('0') + dt.strftime('%p').lower()
        return f' {DIM}→{h}{R}'
    return f' {DIM}→{dt.month}/{dt.day}{R}'

def fmt(label, pct, resets_at=None, short='h'):
    p = round(pct)
    return f'{label} {gradient(pct)}{bar(pct)} {p}%{reset_text(resets_at, short)}{R}'

model = data.get('model', {}).get('display_name', 'Claude')
parts = [model]

try:
    branch = subprocess.run(
        ['git', 'branch', '--show-current'],
        capture_output=True, text=True, timeout=2
    ).stdout.strip()
except Exception:
    branch = ''
if branch:
    parts.append(branch)

ctx = data.get('context_window', {}).get('used_percentage')
if ctx is not None:
    parts.append(fmt('ctx', ctx))

five_hour = data.get('rate_limits', {}).get('five_hour', {})
five = five_hour.get('used_percentage')
if five is not None:
    parts.append(fmt('5h', five, five_hour.get('resets_at'), 'h'))

seven_day = data.get('rate_limits', {}).get('seven_day', {})
week = seven_day.get('used_percentage')
if week is not None:
    parts.append(fmt('7d', week, seven_day.get('resets_at'), 'd'))

print(f'{DIM}│{R}'.join(f' {p} ' for p in parts), end='')
