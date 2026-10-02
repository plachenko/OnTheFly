"""Move body spring weights to Chassis in generated traffic GLBs. Idempotent.
Wheel and crumple weights remain intact. Run with Python after rig_kenney_cars.py.
"""
import json
import struct
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

def fix(path):
    raw = bytearray(path.read_bytes())
    length = struct.unpack_from('<I', raw, 12)[0]
    model = json.loads(raw[20:20 + length])
    binary = 28 + length
    skin = model['skins'][0]
    chassis = next(i for i, node in enumerate(skin['joints']) if model['nodes'][node].get('name') == 'Chassis')
    springs = {i for i, node in enumerate(skin['joints']) if model['nodes'][node].get('name', '').startswith('Spring_')}
    def layout(index):
        accessor = model['accessors'][index]
        view = model['bufferViews'][accessor['bufferView']]
        fmt = {5121: 'B', 5123: 'H', 5126: 'f'}[accessor['componentType']]
        return binary + view.get('byteOffset', 0) + accessor.get('byteOffset', 0), view.get('byteStride', struct.calcsize(fmt) * 4), fmt, accessor['count']
    for mesh in model['meshes']:
        if 'wheel' in mesh.get('name', '').lower():
            continue
        for primitive in mesh['primitives']:
            attributes = primitive['attributes']
            if 'JOINTS_0' not in attributes:
                continue
            jo, js, jf, count = layout(attributes['JOINTS_0'])
            wo, ws, wf, _ = layout(attributes['WEIGHTS_0'])
            for vertex in range(count):
                joints = struct.unpack_from('<' + jf * 4, raw, jo + vertex * js)
                weights = struct.unpack_from('<' + wf * 4, raw, wo + vertex * ws)
                merged = {}
                for joint, weight in zip(joints, weights):
                    joint = chassis if joint in springs else joint
                    merged[joint] = merged.get(joint, 0.0) + weight
                entries = list(merged.items())
                entries += [(chassis, 0.0)] * (4 - len(entries))
                struct.pack_into('<' + jf * 4, raw, jo + vertex * js, *(j for j, _ in entries))
                struct.pack_into('<' + wf * 4, raw, wo + vertex * ws, *(w for _, w in entries))
    path.write_bytes(raw)
    print('Fixed chassis weights:', path.name)

if __name__ == '__main__':
    for path in sorted((ROOT / 'assets/kenney_city/cars_rigged').glob('*.glb')):
        fix(path)
