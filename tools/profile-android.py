"""Measure Android activity launch to scene readiness and three rendered frames."""
import argparse
import json
import queue
import re
import subprocess
import threading
import time
from pathlib import Path

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('report', type=Path)
parser.add_argument('--apk', type=Path)
parser.add_argument('--device', default='emulator-5554')
parser.add_argument('--ready-only', action='store_true', help='Measure setup only; leave the app running for visual checks')
args = parser.parse_args()
adb = ['adb', '-s', args.device]
def run(*commands):
    return subprocess.run(adb + list(commands), check=True, capture_output=True, text=True, encoding='utf-8').stdout
if args.apk:
    print(run('install', '-r', str(args.apk)), flush=True)
run('shell', 'am', 'force-stop', 'tw.aquariuslang.pbr')
run('logcat', '-c')
run('shell', 'log', '-t', 'Aquarius', 'AQUARIUS_BENCHMARK_START')
process = subprocess.Popen(adb + ['logcat', '-v', 'epoch', '-s', 'Aquarius:I', 'AndroidRuntime:E', 'libc:F'], stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, encoding='utf-8')
lines = queue.Queue()
def read():
    for line in process.stdout:
        lines.put(line)
threading.Thread(target=read, daemon=True).start()
print(run('shell', 'am', 'start', '-W', '-n', 'tw.aquariuslang.pbr/org.aquariuslang.android.AquariusActivity', '--ei', 'frames', '3'), flush=True)
result = {'device':args.device, 'log':[]}
deadline = time.monotonic() + 240
try:
    while time.monotonic() < deadline:
        try:
            line = lines.get(timeout=1)
        except queue.Empty:
            continue
        result['log'].append(line.rstrip())
        match = re.match(r'\s*(\d+\.\d+)\s+', line)
        if not match:
            continue
        stamp = float(match[1])
        if 'AQUARIUS_BENCHMARK_START' in line:
            result['startEpoch'] = stamp
        if 'PBR 場景就緒' in line:
            result['readySeconds'] = stamp - result['startEpoch']
            print(f"Scene ready: {result['readySeconds']:.3f} s", flush=True)
            if args.ready_only:
                result['passed'] = True
                break
        if 'AQUARIUS_ANDROID_ERROR' in line or 'FATAL EXCEPTION' in line or 'Fatal signal' in line:
            raise RuntimeError(line)
        if 'AQUARIUS_ANDROID_OK' in line:
            result['threeFramesSeconds'] = stamp - result['startEpoch']
            result['passed'] = True
            break
    else:
        raise TimeoutError('Android startup did not finish within 240 seconds')
finally:
    process.terminate()
    process.wait(timeout=10)
    args.report.parent.mkdir(parents=True, exist_ok=True)
    args.report.write_text(json.dumps(result, indent=2, ensure_ascii=False), encoding='utf-8')
print(json.dumps(result, indent=2))
