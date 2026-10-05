from pathlib import Path
import json
from PIL import Image
root=Path(__file__).resolve().parents[1]; output=root/'assets/truck_billboards'; raw=root.parent/'.runtime/truck_billboard_frames'
metadata=json.loads((output/'metadata.json').read_text())
w=metadata['cell'][0]*metadata['angles']; h=metadata['cell'][1]*len(metadata['elevations'])
for state in metadata['states']:
 for suffix in ['', '_normals']:
  atlas=Image.new('RGBA',(w,h*metadata['frames']))
  for frame in range(metadata['frames']):
   image=Image.open(raw/(state+'_%02d'%frame+suffix+'.png')).convert('RGBA')
   assert image.size==(w,h)
   atlas.paste(image,(0,h*frame))
  atlas.save(output/(state+suffix+'.png'),optimize=True)
 print('PACKED',state,flush=True)
