#!/usr/bin/env python3
"""Real USB round-trip: Mac -> HDC forward -> phone -> HDC reverse -> Mac.
Does not capture the screen or record a device identifier in the report.
"""
import os, pathlib, socket, subprocess, threading, hashlib, json, shutil
hdc = os.environ.get('HARMONYSCREEN_HDC') or shutil.which('hdc') or str(pathlib.Path.home()/'.local/bin/hdc')
def command(*args):
    r = subprocess.run([hdc,*args],capture_output=True,text=True,timeout=10)
    if r.returncode or '[Fail]' in r.stdout: raise RuntimeError(r.stdout.strip() or r.stderr.strip())
    return r.stdout.strip()
targets = [s.strip() for s in command('list','targets').splitlines() if s.strip() and not s.startswith('[')]
if len(targets)!=1: raise SystemExit('Connect exactly one authorized Huawei device')
device=targets[0]
listener=socket.socket(); listener.bind(('127.0.0.1',0)); listener.listen(1); listener.settimeout(10)
host_port=listener.getsockname()[1]
# Reserve a free local forwarding port. HDC itself reports any subsequent collision.
s=socket.socket(); s.bind(('127.0.0.1',0)); forward_port=s.getsockname()[1]; s.close()
phone_port=54329
payload=os.urandom(1024*1024)
result={}
def echo():
    try:
        with listener.accept()[0] as conn:
            conn.settimeout(10)
            while True:
                chunk=conn.recv(65536)
                if not chunk: break
                conn.sendall(chunk)
    except Exception as e: result['server_error']=str(e)
created=[]
try:
    command('-t',device,'rport',f'tcp:{phone_port}',f'tcp:{host_port}'); created.append((phone_port,host_port))
    command('-t',device,'fport',f'tcp:{forward_port}',f'tcp:{phone_port}'); created.append((forward_port,phone_port))
    thread=threading.Thread(target=echo,daemon=True); thread.start()
    with socket.create_connection(('127.0.0.1',forward_port),timeout=10) as conn:
        received=bytearray()
        # Request/reply chunks avoid filling both directions' TCP windows.
        for pos in range(0,len(payload),32768):
            chunk=payload[pos:pos+32768]; conn.sendall(chunk)
            remaining=len(chunk)
            while remaining:
                part=conn.recv(remaining)
                if not part: raise RuntimeError('Unexpected end of HDC stream')
                received.extend(part); remaining-=len(part)
    thread.join(timeout=2)
    assert received==payload,'USB round-trip payload differs'
    result.update(bytes_verified=len(payload),sha256=hashlib.sha256(received).hexdigest(),transport='HDC USB forward + reverse',passed=True)
    print(json.dumps(result,indent=2))
finally:
    listener.close()
    for local,remote in reversed(created):
        try: command('-t',device,'fport','rm',f'tcp:{local}',f'tcp:{remote}')
        except Exception: pass
