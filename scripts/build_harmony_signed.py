#!/usr/bin/env python3
"""Build with a private DevEco profile in a temporary copy, never in Git source."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parent.parent


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--profile', required=True, type=Path,
                        help='Private JSON build profile saved after DevEco automatic signing')
    parser.add_argument('--output', required=True, type=Path,
                        help='New private destination for the device-specific signed HAP')
    args = parser.parse_args()
    if args.output.exists():
        parser.error('Choose a new output path; existing packages are preserved.')
    private = json.loads(args.profile.read_text())
    configs = private['app'].get('signingConfigs', [])
    if len(configs) != 1 or configs[0].get('type') != 'HarmonyOS':
        parser.error('The private profile must contain exactly one HarmonyOS signing config.')
    for field in ('certpath', 'profile', 'storeFile'):
        if not Path(configs[0]['material'][field]).is_file():
            parser.error(f'Missing private signing input: {field}')

    # Private keys stay in their original location. Only configuration is copied.
    # mkdtemp is owner-only; all temporary signing configuration is removed on exit.
    with tempfile.TemporaryDirectory(prefix='harmonyscreen-sign-') as temporary:
        staged = Path(temporary) / 'HarmonyClient'
        shutil.copytree(ROOT / 'HarmonyClient', staged, ignore=shutil.ignore_patterns(
            'build', 'oh_modules', '.hvigor', '.cxx', '.idea', '.clangd', '.clang-tidy',
            'local.properties'))
        profile_path = staged / 'build-profile.json5'
        public = json.loads(profile_path.read_text())
        public['app']['signingConfigs'] = configs
        for product in public['app']['products']:
            product['signingConfig'] = configs[0]['name']
        profile_path.write_text(json.dumps(public, indent=2) + '\n')
        profile_path.chmod(0o600)
        environment = dict(os.environ, HARMONY_CLIENT_DIR=str(staged))
        subprocess.run([str(ROOT / 'scripts/build_harmony.sh')], env=environment, check=True)
        signed = staged / 'entry/build/default/outputs/default/entry-default-signed.hap'
        if not signed.is_file():
            raise RuntimeError('Build did not produce the signed HAP.')
        args.output.parent.mkdir(parents=True, exist_ok=True)
        # Exclusive creation prevents a concurrent run from replacing another package.
        descriptor = os.open(args.output, os.O_CREAT | os.O_EXCL | os.O_WRONLY, 0o600)
        with os.fdopen(descriptor, 'wb') as destination:
            with signed.open('rb') as source:
                shutil.copyfileobj(source, destination)
    print('Signed HAP saved privately. Debug profiles may restrict it to registered devices.')
    print('SHA256: ' + hashlib.sha256(args.output.read_bytes()).hexdigest())


if __name__ == '__main__':
    main()
