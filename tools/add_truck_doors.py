"""Refine the existing skinned truck with modeled doors, without external deps.

Run: python tools/add_truck_doors.py
Preserves truck_opposite_side.glb; writes truck_with_doors.glb. Coordinates
in its mesh accessors are X longitudinal (front negative), Y up, Z sideways.
New meshes use the existing Chassis joint and palette materials.
"""
import json
import struct
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'assets/truck_opposite_side.glb'
OUTPUT = ROOT / 'assets/truck_with_doors.glb'


def main():
    raw = SOURCE.read_bytes()
    json_length = struct.unpack_from('<I', raw, 12)[0]
    model = json.loads(raw[20:20 + json_length])
    binary_offset = 20 + json_length
    binary_length = struct.unpack_from('<I', raw, binary_offset)[0]
    binary = bytearray(raw[binary_offset + 8:binary_offset + 8 + binary_length])
    rig = next(n for n in model['nodes'] if n.get('name') == 'Truck_Rig')
    chassis = next(i for i, n in enumerate(model['nodes']) if n.get('name') == 'Chassis')
    joint = model['skins'][0]['joints'].index(chassis)
    materials = {m['name']: i for i, m in enumerate(model['materials'])}

    def accessor(values, kind, component=5126, bounds=False):
        width = {'SCALAR': 1, 'VEC3': 3, 'VEC4': 4}[kind]
        while len(binary) % 4:
            binary.append(0)
        offset = len(binary)
        code = {5126: 'f', 5123: 'H'}[component]
        flat = [v for row in values for v in row] if width > 1 else values
        binary.extend(struct.pack('<' + code * len(flat), *flat))
        view = len(model['bufferViews'])
        model['bufferViews'].append({'buffer': 0, 'byteOffset': offset, 'byteLength': len(binary) - offset})
        entry = {'bufferView': view, 'componentType': component, 'count': len(values), 'type': kind}
        if bounds:
            entry['min'] = [min(v[k] for v in values) for k in range(width)]
            entry['max'] = [max(v[k] for v in values) for k in range(width)]
        index = len(model['accessors'])
        model['accessors'].append(entry)
        return index

    def box(name, center, size, material):
        positions, normals, indices = [], [], []
        # Face-local corners give hard normals and outward counterclockwise faces.
        for normal, u, v in [((1,0,0),(0,1,0),(0,0,1)), ((-1,0,0),(0,0,1),(0,1,0)),
                             ((0,1,0),(0,0,1),(1,0,0)), ((0,-1,0),(1,0,0),(0,0,1)),
                             ((0,0,1),(1,0,0),(0,1,0)), ((0,0,-1),(0,1,0),(1,0,0))]:
            base = len(positions)
            for a, b in [(-1,-1),(1,-1),(1,1),(-1,1)]:
                positions.append(tuple(center[k] + size[k] * 0.5 * (normal[k] + a*u[k] + b*v[k]) for k in range(3)))
                normals.append(normal)
            indices.extend([base, base+1, base+2, base, base+2, base+3])
        primitive = {'attributes': {'POSITION': accessor(positions, 'VEC3', bounds=True),
                                   'NORMAL': accessor(normals, 'VEC3'),
                                   'JOINTS_0': accessor([(joint,0,0,0)] * 24, 'VEC4', 5123),
                                   'WEIGHTS_0': accessor([(1,0,0,0)] * 24, 'VEC4')},
                     'indices': accessor(indices, 'SCALAR', 5123), 'material': materials[material]}
        mesh = len(model['meshes'])
        model['meshes'].append({'name': name, 'primitives': [primitive]})
        node = len(model['nodes'])
        model['nodes'].append({'name': name, 'mesh': mesh, 'skin': 0})
        rig['children'].append(node)

    # Remove solid walls and old handles from the scene, retaining their data.
    replaced = {'Rear wall', 'Front cargo wall', 'Door handle', 'Door handle.001'}
    rig['children'] = [i for i in rig['children'] if model['nodes'][i].get('name') not in replaced]
    for side, label in [(1, 'Driver'), (-1, 'Passenger')]:
        z = side * 1.187
        # Recessed outline around each cab door, above the front wheel arch.
        for x in [-3.22, -1.57]:
            box(label + ' door vertical seam', (x, 2.015, z), (0.024, 1.57, 0.024), 'Rubber and chassis')
        for y in [1.23, 2.80]:
            box(label + ' door horizontal seam', (-2.395, y, z), (1.67, 0.024, 0.024), 'Rubber and chassis')
        box(label + ' door lower panel', (-2.395, 1.52, z), (1.58, 0.53, 0.018), 'Deep teal enamel')
        box(label + ' window belt trim', (-2.395, 1.94, side * 1.195), (1.62, 0.035, 0.026), 'Brushed stainless steel')
        box(label + ' door handle recess', (-1.88, 1.81, side * 1.21), (0.31, 0.10, 0.025), 'Rubber and chassis')
        box(label + ' door handle', (-1.88, 1.82, side * 1.24), (0.24, 0.045, 0.045), 'Brushed stainless steel')
        for y in [1.45, 2.32]:
            box(label + ' cab door hinge', (-3.20, y, side * 1.215), (0.065, 0.16, 0.055), 'Brushed stainless steel')

    # Rear frame and two distinct leaves, with a central seam and locking bars.
    for z in [-1.16, 1.16]:
        box('Rear door jamb', (3.36, 2.30, z), (0.14, 2.45, 0.08), 'Warm ivory')
    for y in [1.12, 3.48]:
        box('Rear door cross frame', (3.36, y, 0), (0.14, 0.09, 2.4), 'Warm ivory')
    for side, label in [(-1, 'Left'), (1, 'Right')]:
        z = side * 0.565
        box('Rear ' + label + ' double door', (3.37, 2.30, z), (0.105, 2.27, 1.08), 'Deep teal enamel')
        box('Rear ' + label + ' upper inset', (3.432, 2.92, z), (0.018, 0.75, 0.91), 'Warm ivory')
        box('Rear ' + label + ' lower inset', (3.432, 1.69, z), (0.018, 0.72, 0.91), 'Deep teal enamel')
        box('Rear ' + label + ' lock bar', (3.465, 2.27, side * 0.29), (0.045, 1.87, 0.045), 'Brushed stainless steel')
        box('Rear ' + label + ' latch handle', (3.49, 2.13, side * 0.29), (0.045, 0.06, 0.22), 'Brushed stainless steel')
        for y in [1.46, 2.30, 3.15]:
            box('Rear ' + label + ' hinge', (3.455, y, side * 1.09), (0.07, 0.16, 0.10), 'Brushed stainless steel')
    box('Rear center door seal', (3.43, 2.30, 0), (0.04, 2.28, 0.035), 'Rubber and chassis')

    # Passenger-side passage through the cab/kitchen partition.
    # Clear doorway spans Z -1.05 .. -0.15 and Y 1.18 .. 3.18.
    box('Cab kitchen partition driver side', (-1.36, 2.30, 0.525), (0.12, 2.45, 1.35), 'Deep teal enamel')
    box('Cab kitchen partition passenger jamb', (-1.36, 2.30, -1.125), (0.12, 2.45, 0.15), 'Deep teal enamel')
    box('Cab kitchen doorway lintel', (-1.36, 3.35, -0.60), (0.12, 0.34, 0.9), 'Deep teal enamel')
    box('Cab kitchen doorway threshold', (-1.36, 1.125, -0.60), (0.12, 0.105, 0.9), 'Brushed stainless steel')
    box('Passenger kitchen access door', (-1.355, 2.18, -0.60), (0.07, 1.94, 0.84), 'Warm ivory')
    box('Kitchen access door window', (-1.31, 2.70, -0.60), (0.025, 0.42, 0.55), 'Blue tinted windows')
    for x in [-1.405, -1.30]:
        box('Kitchen passage handle', (x, 2.10, -0.29), (0.05, 0.045, 0.13), 'Brushed stainless steel')
    for y in [1.50, 2.88]:
        box('Kitchen passage hinge', (-1.30, y, -1.015), (0.07, 0.12, 0.05), 'Brushed stainless steel')

    while len(binary) % 4:
        binary.append(0)
    model['buffers'][0]['byteLength'] = len(binary)
    json_bytes = json.dumps(model, separators=(',', ':')).encode()
    json_bytes += b' ' * (-len(json_bytes) % 4)
    length = 12 + 8 + len(json_bytes) + 8 + len(binary)
    OUTPUT.write_bytes(struct.pack('<III', 0x46546C67, 2, length) + struct.pack('<II', len(json_bytes), 0x4E4F534A) + json_bytes + struct.pack('<II', len(binary), 0x004E4942) + binary)
    print(f'Added rigged cab doors, rear double doors and passenger kitchen passage: {OUTPUT}')


if __name__ == '__main__':
    main()
