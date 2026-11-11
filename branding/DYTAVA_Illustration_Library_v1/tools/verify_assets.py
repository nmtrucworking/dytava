from pathlib import Path
from xml.etree import ElementTree as ET
import json, hashlib, zipfile
from PIL import Image
root=Path(__file__).resolve().parents[1]
a=root/'mobile/assets/dytava/illustrations'
m=json.loads((a/'manifest.json').read_text(encoding='utf8'))
for item in m['items']:
 ET.parse(root/item['svg'])
 with Image.open(root/item['png_4k']) as im:
  assert im.mode=='RGBA',(item['id'],im.mode)
  assert im.size==(item['width'],item['height']),(item['id'],im.size)
  assert im.getpixel((0,0))[3]==0,item['id']
 assert (root/item['preview']).is_file(),item['id']
assert len(set(x['id'] for x in m['items']))==len(m['items'])
with (root/'SHA256SUMS.txt').open(encoding='utf8') as f:
 for line in f:
  digest,path=line.rstrip('\n').split('  ',1)
  got=hashlib.sha256((root/path).read_bytes()).hexdigest()
  assert got==digest,path
print(f'PASS: {len(m["items"])} vector + 4K PNG illustrations; all checksums OK')
