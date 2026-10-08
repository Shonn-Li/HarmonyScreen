#!/usr/bin/env python3
"""Test the installed Mac host's real idle/connect/disconnect display lifecycle.

Run with the host waiting and no viewer attached. Temporarily creates a display
using a local protocol client, independently decodes its HEVC, then checks that
the display disappears without stopping the listener. No screen content is kept.
"""
import json
import socket
import subprocess
import time
from test_host_stream import verify


def display_present():
    result = subprocess.run(['system_profiler', 'SPDisplaysDataType', '-json'],
                            check=True, capture_output=True, text=True, timeout=10)
    def contains(value):
        if isinstance(value, dict):
            return value.get('_name') == 'HarmonyScreen' or any(contains(v) for v in value.values())
        if isinstance(value, list):
            return any(contains(v) for v in value)
        return False
    return contains(json.loads(result.stdout))


def wait_for_removal():
    start = time.monotonic()
    while time.monotonic() - start < 12:
        if not display_present():
            return round(time.monotonic() - start, 2)
        time.sleep(0.5)
    raise RuntimeError('The disconnected display did not disappear')


if display_present():
    raise SystemExit('Host must be waiting with no viewer and no HarmonyScreen display')

results = []
for cycle in range(2):
    video = verify(54322, 15)
    if not display_present():
        raise RuntimeError('Display vanished before the reconnect grace period')
    results.append({'cycle': cycle + 1, 'video': video,
                    'display_removed_after_seconds': wait_for_removal()})

# The peer can close while asynchronous display setup is still in progress.
with socket.create_connection(('127.0.0.1', 54322), timeout=5):
    time.sleep(0.2)
time.sleep(1)
wait_for_removal()
time.sleep(1)
if display_present():
    raise RuntimeError('Cancelled preparation resurrected an unused display')
print(json.dumps({'passed': True, 'cycles': results,
                  'closed_during_preparation': 'display absent',
                  'phone_playback_verified': False}, indent=2))
