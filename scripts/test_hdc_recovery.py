#!/usr/bin/env python3
"""Hardware regression: a running host must restore a dropped USB tunnel.

Keep HarmonyScreen running (including Wireless mode) and one authorized phone
connected. This briefly removes only its streaming tunnel; failure cleanup
restores it. Does not change the selected mode or restart either app.
"""
import argparse
import json
import os
import pathlib
import shutil
import subprocess
import time

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--port', type=int, default=54322)
parser.add_argument('--timeout', type=float, default=15)
args = parser.parse_args()
if not 1024 <= args.port <= 65535 or not 0 < args.timeout <= 60:
    parser.error('Use a valid port and a timeout of at most 60 seconds')
hdc = os.environ.get('HARMONYSCREEN_HDC') or shutil.which('hdc') or str(pathlib.Path.home()/'.local/bin/hdc')

def command(*arguments):
    result = subprocess.run([hdc, *arguments], capture_output=True, text=True, timeout=8)
    if result.returncode or '[Fail]' in result.stdout:
        raise RuntimeError('HDC command failed')
    return result.stdout

targets = [line.strip() for line in command('list', 'targets').splitlines()
           if line.strip() and not line.startswith('[') and ':' not in line]
if len(targets) != 1:
    raise SystemExit('Connect exactly one authorized USB device')
device = targets[0]
endpoint = f'tcp:{args.port}'

def configured():
    return any(line.split() == [device, endpoint, endpoint, '[Reverse]']
               for line in command('-t', device, 'fport', 'ls').splitlines())

if not configured():
    raise SystemExit('Start the host with its USB tunnel established before this test')
restored = False
try:
    command('-t', device, 'fport', 'rm', endpoint, endpoint)
    started = time.monotonic()
    while time.monotonic() - started < args.timeout:
        if configured():
            restored = True
            break
        time.sleep(0.5)
    print(json.dumps({'automatically_restored': restored,
                      'elapsed_seconds': round(time.monotonic() - started, 2)}))
finally:
    if not restored:
        command('-t', device, 'rport', endpoint, endpoint)
        if not configured():
            raise RuntimeError('Failed to restore the original USB tunnel after the test')
raise SystemExit(0 if restored else 1)
