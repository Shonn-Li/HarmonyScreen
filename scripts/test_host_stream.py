#!/usr/bin/env python3
"""Check a running local host's real HEVC output without retaining screen content."""
import argparse
import json
import pathlib
import socket
import struct
import subprocess
import tempfile


def verify(port, frame_count):
    with socket.create_connection(('127.0.0.1', port), timeout=8) as connection:
        connection.settimeout(8)

        def read(size):
            result = bytearray()
            while len(result) < size:
                chunk = connection.recv(size - len(result))
                if not chunk:
                    raise RuntimeError('Host ended the stream before the test completed')
                result.extend(chunk)
            return result

        with tempfile.TemporaryDirectory(prefix='harmonyscreen-stream-') as directory:
            video = pathlib.Path(directory) / 'sample.hevc'
            frames = 0
            dimensions = None
            with video.open('wb') as output:
                while frames < frame_count:
                    message = read(1)[0]
                    if message == 1:
                        width, height, transform = struct.unpack('!III', read(12))
                        if not (0 < width <= 8192 and 0 < height <= 8192 and width * height <= 32 * 1024 * 1024):
                            raise RuntimeError('Invalid display dimensions')
                        dimensions = [width, height]
                    elif message in (0, 6):
                        length = struct.unpack('!I', read(4))[0]
                        if not 0 < length <= 16 * 1024 * 1024:
                            raise RuntimeError('Invalid encoded frame size')
                        if message == 6:
                            read(9)
                        output.write(read(length))
                        frames += 1
                    elif message in (5, 13):
                        read(8)
                    elif message == 10:
                        if read(1)[0] != 0:
                            raise RuntimeError('This diagnostic expects HEVC')
                    else:
                        raise RuntimeError(f'Unknown host message: {message}')
            probe = subprocess.run([
                'ffprobe', '-v', 'error', '-count_frames', '-show_entries',
                'stream=codec_name,width,height,nb_read_frames', '-of', 'json', str(video)
            ], check=True, capture_output=True, text=True, timeout=30)
            streams = json.loads(probe.stdout)['streams']
            if len(streams) != 1:
                raise RuntimeError('Expected exactly one video stream')
            stream = streams[0]
            if stream['codec_name'] != 'hevc' or int(stream['nb_read_frames']) != frame_count:
                raise RuntimeError('Could not decode every received HEVC frame')
            if dimensions != [stream['width'], stream['height']]:
                raise RuntimeError('Encoded resolution differs from host configuration')
            return {'passed': True, 'decoded_frames': frame_count, 'resolution': dimensions,
                    'transport': 'Mac localhost', 'phone_playback_verified': False}


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--port', type=int, default=54322)
    parser.add_argument('--frames', type=int, default=60)
    args = parser.parse_args()
    if not 1024 <= args.port <= 65535 or not 1 <= args.frames <= 300:
        parser.error('Use port 1024–65535 and 1–300 frames')
    print(json.dumps(verify(args.port, args.frames), indent=2))
