"""Export named real XCUITest captures, preserving native device dimensions."""
import json
from pathlib import Path
import re
import subprocess
import sys

kind = sys.argv[1]
source = Path('build/screenshot-results') / f'{kind}-attachments'
target = Path('build/screenshots') / ('iPhone-medium' if kind == 'iphone' else 'iPad-13-inch')
target.mkdir(parents=True, exist_ok=True)
records = json.loads((source / 'manifest.json').read_text())
count = 0
for record in records:
    for attachment in record.get('attachments', []):
        name = attachment.get('suggestedHumanReadableName', '')
        match = re.match(r'(0[1-7]-[a-z-]+)', name)
        exported = attachment.get('exportedFileName', '')
        if not match or not exported.lower().endswith('.png'):
            continue
        original = source / exported
        destination = target / (match.group(1) + '.jpg')
        # JPEG removes screenshot alpha without changing content or dimensions.
        subprocess.run(['sips', '-s', 'format', 'jpeg', '-s', 'formatOptions', '95', str(original), '--out', str(destination)], check=True, stdout=subprocess.DEVNULL)
        dimensions = subprocess.check_output(['sips', '-g', 'pixelWidth', '-g', 'pixelHeight', str(destination)], text=True)
        width = int(re.search(r'pixelWidth:\s*(\d+)', dimensions).group(1))
        height = int(re.search(r'pixelHeight:\s*(\d+)', dimensions).group(1))
        valid = {(1179, 2556), (1206, 2622)} if kind == 'iphone' else {(2064, 2752), (2048, 2732)}
        if (width, height) not in valid:
            raise SystemExit(f'Unexpected screenshot dimensions: {destination} {width}x{height}')
        print(f'Exported {destination.name}: {width} x {height}')
        count += 1
if count != 7:
    raise SystemExit(f'Expected seven genuine {kind} captures, found {count}. Inspect the UI test log.')
(target / 'README.txt').write_text('Real native Rajya simulator screenshots. No user account or private data was used.\nUpload the numbered JPG images in this folder to the matching App Store Connect device category.\n', encoding='utf-8')
