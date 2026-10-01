"""Detect lamp faces and attach Blender lights to every traffic car.

blender --background --python tools/place_car_lights.py --

Defaults read tools/rigged_cars/*.blend; originals are never overwritten.
Writes editable blends, GLBs with punctual lights, and a Godot placement JSON
under assets/kenney_city/car_lights. Blender: X sideways, -Y front, +Z up.
Material colors, UV palette textures, and vertex colors are supported.
Missing lamp faces fail that car instead of inventing a bounding-box position.
"""
import argparse
import json
import math
import sys
from pathlib import Path

import bpy
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[1]
PIXELS = {}


def texture_color(image, uv):
    if image.name not in PIXELS:
        PIXELS[image.name] = list(image.pixels)
    w, h = image.size
    x = min(w - 1, max(0, int((uv.x % 1.0) * w)))
    y = min(h - 1, max(0, int((uv.y % 1.0) * h)))
    offset = (y * w + x) * image.channels
    return PIXELS[image.name][offset:offset + 3]


def face_color(obj, face):
    material = obj.data.materials[face.material_index] if obj.data.materials else None
    if not material:
        return (0.0, 0.0, 0.0)
    color = material.diffuse_color[:3]
    if material.use_nodes:
        shader = next((n for n in material.node_tree.nodes if n.type == 'BSDF_PRINCIPLED'), None)
        if shader:
            base = shader.inputs['Base Color']
            color = base.default_value[:3]
            if base.is_linked:
                node = base.links[0].from_node
                if node.type == 'TEX_IMAGE' and node.image and obj.data.uv_layers.active:
                    uv_data = obj.data.uv_layers.active.data
                    # Include triangle corners and centroid to avoid sampling only a palette boundary.
                    uvs = [uv_data[i].uv for i in face.loop_indices]
                    centroid = sum(uvs, Vector((0.0, 0.0))) / len(uvs)
                    samples = [texture_color(node.image, uv.lerp(centroid, 0.15)) for uv in uvs]
                    color = tuple(sum(c[k] for c in samples) / len(samples) for k in range(3))
                elif node.type == 'VERTEX_COLOR':
                    attribute = obj.data.color_attributes.get(node.layer_name)
                    if attribute:
                        indices = face.loop_indices if attribute.domain == 'CORNER' else face.vertices
                        samples = [attribute.data[i].color for i in indices]
                        color = tuple(sum(c[k] for c in samples) / len(samples) for k in range(3))
    return color


def color_kind(color):
    r, g, b = color
    if r > 0.35 and g > 0.25 and min(r, g) > b * 1.5 and abs(r - g) < 0.5:
        return 'yellow'
    if r > 0.3 and r > g * 1.8 and r > b * 1.5:
        return 'red'
    if b > 0.3 and b > r * 1.5 and b > g * 1.25:
        return 'blue'
    return ''


def components(faces):
    """Join adjacent triangles into one physical lens, never one light per triangle."""
    pending = {entry['face'].index: entry for entry in faces}
    by_vertex = {}
    for entry in faces:
        for vertex in entry['face'].vertices:
            by_vertex.setdefault(vertex, set()).add(entry['face'].index)
    result = []
    while pending:
        stack = [next(iter(pending))]
        group = []
        while stack:
            entry = pending.pop(stack.pop(), None)
            if entry is None:
                continue
            group.append(entry)
            for vertex in entry['face'].vertices:
                stack.extend(by_vertex[vertex] & pending.keys())
        result.append(group)
    return result


def process(source, output, args):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    PIXELS.clear()
    if source.suffix == '.blend':
        bpy.ops.wm.open_mainfile(filepath=str(source))
    else:
        bpy.ops.import_scene.gltf(filepath=str(source))
    for obj in list(bpy.context.scene.objects):
        if obj.get('detected_car_lamp'):
            bpy.data.objects.remove(obj, do_unlink=True)
    meshes = [o for o in bpy.context.scene.objects if o.type == 'MESH' and 'wheel' not in o.name.lower()]
    points = [o.matrix_world @ v.co for o in meshes for v in o.data.vertices]
    if not points:
        raise RuntimeError('No body geometry')
    lo = Vector(tuple(min(p[i] for p in points) for i in range(3)))
    hi = Vector(tuple(max(p[i] for p in points) for i in range(3)))
    front = Vector((0, args.front_sign, 0))
    projections = [p.dot(front) for p in points]
    front_cut = max(projections) - (max(projections) - min(projections)) * args.end_band
    rear_cut = min(projections) + (max(projections) - min(projections)) * args.end_band
    roof_cut = lo.z + (hi.z - lo.z) * args.roof_band
    police = 'police' in source.stem.lower()
    records = []
    counts = {'Headlight': 0, 'Brake': 0, 'Police': 0}
    for obj in meshes:
        normal_matrix = obj.matrix_world.to_3x3().inverted().transposed()
        buckets = {}
        for face in obj.data.polygons:
            center = obj.matrix_world @ face.center
            normal = (normal_matrix @ face.normal).normalized()
            kind = color_kind(face_color(obj, face))
            category = ''
            if kind == 'yellow' and center.dot(front) >= front_cut and normal.dot(front) > 0.45:
                category = 'Headlight'
            elif kind == 'red' and center.dot(front) <= rear_cut and normal.dot(-front) > 0.45:
                category = 'Brake'
            elif police and kind in ('red', 'blue') and center.z >= roof_cut:
                category = 'Police'
            if category:
                buckets.setdefault((category, kind), []).append({'face': face, 'center': center, 'normal': normal})
        for (category, kind), entries in buckets.items():
            for group in components(entries):
                weights = [max(e['face'].area, 1e-8) for e in group]
                total = sum(weights)
                center = sum((e['center'] * w for e, w in zip(group, weights)), Vector()) / total
                normal = sum((e['normal'] * w for e, w in zip(group, weights)), Vector())
                normal = normal.normalized() if normal.length > 1e-6 else Vector((0, 0, 1))
                position = center + normal * args.surface_offset
                counts[category] += 1
                name = f'{category}_{kind}_{counts[category]:02d}'
                data = bpy.data.lights.new(name, 'SPOT' if category == 'Headlight' else 'POINT')
                data.color = {'yellow': (1.0, 0.9, 0.5), 'red': (1.0, 0.03, 0.01), 'blue': (0.03, 0.15, 1.0)}[kind]
                data.energy = 40.0 if category == 'Headlight' else 5.0
                data.shadow_soft_size = 0.05
                if data.type == 'SPOT':
                    data.spot_size = math.radians(65)
                light = bpy.data.objects.new(name, data)
                bpy.context.collection.objects.link(light)
                light.location = position
                light.rotation_euler = normal.to_track_quat('-Z', 'Y').to_euler()
                bpy.context.view_layer.update()
                light['detected_car_lamp'] = True
                light['source_mesh'] = obj.name
                light['source_faces'] = ','.join(str(e['face'].index) for e in group)
                # A bone parent keeps the light attached to the deforming car frame.
                rig = next((m.object for m in obj.modifiers if m.type == 'ARMATURE' and m.object), None)
                if rig and rig.data.bones.get('Chassis'):
                    world = light.matrix_world.copy()
                    light.parent = rig
                    light.parent_type = 'BONE'
                    light.parent_bone = 'Chassis'
                    light.matrix_world = world
                elif obj:
                    world = light.matrix_world.copy()
                    light.parent = obj
                    light.matrix_world = world
                bpy.context.view_layer.update()
                records.append({'name': name, 'category': category, 'color': kind,
                                'position': [position.x, position.z, -position.y],
                                'normal': [normal.x, normal.z, -normal.y],
                                'mesh': obj.name, 'faces': [e['face'].index for e in group]})
    if not counts['Headlight'] or not counts['Brake'] or (police and not counts['Police']):
        raise RuntimeError(f'Missing lamp faces: {counts}; inspect axis/color thresholds')
    output.mkdir(parents=True, exist_ok=True)
    blend_dir = output / 'blends'
    blend_dir.mkdir(exist_ok=True)
    (blend_dir / '.gdignore').touch()
    bpy.context.preferences.filepaths.save_version = 0
    bpy.ops.wm.save_as_mainfile(filepath=str(blend_dir / (source.stem + '.blend')))
    bpy.ops.export_scene.gltf(filepath=str(output / (source.stem + '.glb')), export_format='GLB', export_lights=True)
    (output / (source.stem + '.json')).write_text(json.dumps({'model': source.stem, 'lamps': records}, indent=2))
    print(f'LIGHTS {source.stem}: {counts}')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source', type=Path, default=ROOT / 'tools/rigged_cars')
    parser.add_argument('--output', type=Path, default=ROOT / 'assets/kenney_city/car_lights')
    parser.add_argument('--front-sign', type=int, choices=(-1, 1), default=-1)
    parser.add_argument('--end-band', type=float, default=0.25)
    parser.add_argument('--roof-band', type=float, default=0.8)
    parser.add_argument('--surface-offset', type=float, default=0.015)
    args = parser.parse_args(sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else [])
    files = sorted(args.source.glob('*.blend')) or sorted(args.source.glob('*.glb'))
    if not files:
        raise SystemExit(f'No .blend or .glb cars found in {args.source}')
    if args.source.resolve() == args.output.resolve():
        raise SystemExit('Output must differ from source to preserve original models')
    failures = []
    for source in files:
        try:
            process(source, args.output, args)
        except Exception as exc:
            failures.append(f'{source.name}: {exc}')
    if failures:
        raise SystemExit('\n'.join(failures))


if __name__ == '__main__':
    main()
