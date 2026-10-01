"""Mark the most detailed Kenney facade and write Godot-facing orientation data.

Run in Blender:
  blender --background --python tools/annotate_kenney_buildings.py --

The script keeps the original GLBs untouched. It saves annotated .blend files
under tools/kenney_outward_faces and writes the Godot orientation manifest under
assets/kenney_city/commercial/outward_faces.json. The .blend files contain an
OutwardFace vertex group on each mesh that contributes to the chosen facade.

Without Blender, `python tools/annotate_kenney_buildings.py -- --manifest-only`
can regenerate the manifest but cannot create Blender vertex groups.
"""

from __future__ import annotations

import argparse
import json
import math
import struct
import sys
from pathlib import Path

try:
    import bpy
    from mathutils import Vector
except ImportError:
    bpy = None
    Vector = None


SIDES = {"+X": (1.0, 0.0, 0.0), "-X": (-1.0, 0.0, 0.0),
         "+Z": (0.0, 0.0, 1.0), "-Z": (0.0, 0.0, -1.0)}
COMPONENTS = {5121: "B", 5123: "H", 5125: "I", 5126: "f"}
WIDTHS = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4}


def argument_parser() -> argparse.Namespace:
    arguments = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else sys.argv[1:]
    parser = argparse.ArgumentParser(description=__doc__)
    root = Path(__file__).resolve().parents[1]
    parser.add_argument("--source", type=Path, default=root / "assets/kenney_city/commercial")
    parser.add_argument("--manifest", type=Path, default=root / "assets/kenney_city/commercial/outward_faces.json")
    parser.add_argument("--blend-dir", type=Path, default=root / "tools/kenney_outward_faces")
    parser.add_argument("--manifest-only", action="store_true")
    return parser.parse_args(arguments)


def mat_multiply(left, right):
    return tuple(tuple(sum(left[i][k] * right[k][j] for k in range(4)) for j in range(4)) for i in range(4))


IDENTITY = ((1.0, 0.0, 0.0, 0.0), (0.0, 1.0, 0.0, 0.0),
            (0.0, 0.0, 1.0, 0.0), (0.0, 0.0, 0.0, 1.0))


def node_matrix(node):
    if "matrix" in node:
        values = node["matrix"]  # glTF stores columns first.
        return tuple(tuple(values[column * 4 + row] for column in range(4)) for row in range(4))
    x, y, z, w = node.get("rotation", (0.0, 0.0, 0.0, 1.0))
    sx, sy, sz = node.get("scale", (1.0, 1.0, 1.0))
    tx, ty, tz = node.get("translation", (0.0, 0.0, 0.0))
    return ((sx * (1 - 2 * (y*y + z*z)), sy * 2 * (x*y - z*w), sz * 2 * (x*z + y*w), tx),
            (sx * 2 * (x*y + z*w), sy * (1 - 2 * (x*x + z*z)), sz * 2 * (y*z - x*w), ty),
            (sx * 2 * (x*z - y*w), sy * 2 * (y*z + x*w), sz * (1 - 2 * (x*x + y*y)), tz),
            (0.0, 0.0, 0.0, 1.0))


def transform(matrix, point):
    return tuple(sum(matrix[row][column] * point[column] for column in range(3)) + matrix[row][3] for row in range(3))


def read_glb(path: Path):
    raw = path.read_bytes()
    if raw[:4] != b"glTF":
        raise ValueError(f"Not a binary glTF file: {path}")
    offset = 12
    document = None
    binary = None
    while offset < len(raw):
        length, kind = struct.unpack_from("<II", raw, offset)
        payload = raw[offset + 8:offset + 8 + length]
        if kind == 0x4E4F534A:
            document = json.loads(payload)
        elif kind == 0x004E4942:
            binary = payload
        offset += 8 + length
    if document is None or binary is None:
        raise ValueError(f"Missing JSON or BIN chunk: {path}")

    def accessor(index):
        entry = document["accessors"][index]
        view = document["bufferViews"][entry["bufferView"]]
        component = COMPONENTS[entry["componentType"]]
        width = WIDTHS[entry["type"]]
        fmt = "<" + component * width
        stride = view.get("byteStride", struct.calcsize(fmt))
        start = view.get("byteOffset", 0) + entry.get("byteOffset", 0)
        result = [struct.unpack_from(fmt, binary, start + row * stride) for row in range(entry["count"])]
        return [item[0] for item in result] if width == 1 else result

    triangles = []
    all_points = []
    nodes = document["nodes"]
    children = {child for node in nodes for child in node.get("children", [])}
    roots = document.get("scenes", [{}])[document.get("scene", 0)].get("nodes", []) or [i for i in range(len(nodes)) if i not in children]

    def visit(index, parent):
        node = nodes[index]
        matrix = mat_multiply(parent, node_matrix(node))
        if "mesh" in node:
            for primitive in document["meshes"][node["mesh"]]["primitives"]:
                if primitive.get("mode", 4) != 4:
                    continue
                points = [transform(matrix, point) for point in accessor(primitive["attributes"]["POSITION"])]
                all_points.extend(points)
                indices = accessor(primitive["indices"]) if "indices" in primitive else list(range(len(points)))
                for start in range(0, len(indices) - 2, 3):
                    triangles.append((points[indices[start]], points[indices[start + 1]], points[indices[start + 2]]))
        for child in node.get("children", []):
            visit(child, matrix)

    for root in roots:
        visit(root, IDENTITY)
    if not triangles:
        raise ValueError(f"No triangle geometry found in {path}")
    return triangles, all_points


def face_measurement(triangle):
    a, b, c = triangle
    ab = (b[0]-a[0], b[1]-a[1], b[2]-a[2])
    ac = (c[0]-a[0], c[1]-a[1], c[2]-a[2])
    cross = (ab[1]*ac[2]-ab[2]*ac[1], ab[2]*ac[0]-ab[0]*ac[2], ab[0]*ac[1]-ab[1]*ac[0])
    magnitude = math.sqrt(sum(value*value for value in cross))
    if magnitude < 1e-10:
        return None
    return (tuple(sum(vertex[axis] for vertex in triangle)/3.0 for axis in range(3)),
            tuple(value/magnitude for value in cross), magnitude*0.5)


def analyze(triangles, points):
    measured = [face_measurement(triangle) for triangle in triangles]
    measured = [face for face in measured if face is not None]
    scores = {}
    slabs = {}
    for label, direction in SIDES.items():
        projection = lambda point: sum(point[axis]*direction[axis] for axis in range(3))
        furthest = max(projection(point) for point in points)
        nearest = min(projection(point) for point in points)
        span = max(0.001, furthest-nearest)
        slab = max(0.035, span*0.28)
        candidates = []
        normal_bins = set()
        depth_bins = set()
        for center, normal, area in measured:
            depth = projection(center)
            forward = projection(normal)
            if furthest-depth > slab or abs(normal[1]) > 0.78 or forward < -0.25:
                continue
            candidates.append((forward, area))
            normal_bins.add(tuple(round(component*4.0) for component in normal))
            depth_bins.add(round((furthest-depth)/max(slab,0.001)*8.0))
        # Recesses and doors create many small faces, normal changes and depth bands.
        detail = sum(1.0 + max(0.0,1.0-abs(forward))*1.8 for forward, _ in candidates)
        scores[label] = round(detail + len(normal_bins)*3.0 + len(depth_bins)*1.5, 3)
        slabs[label] = slab
    chosen = max(SIDES, key=lambda label: scores[label])
    ordered = sorted(scores.values(), reverse=True)
    confidence = (ordered[0]-ordered[1])/max(ordered[0],1.0)
    return chosen, scores, slabs[chosen], round(confidence, 3)


def mark_blender_vertices(path: Path, label: str, slab: float, output_dir: Path):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(path))
    objects = [obj for obj in bpy.context.scene.objects if obj.type == "MESH"]
    if not objects:
        raise ValueError(f"Blender imported no mesh objects from {path}")
    godot_direction = SIDES[label]
    direction = Vector((godot_direction[0], -godot_direction[2], 0.0))  # glTF Y-up to Blender Z-up.
    furthest = max((obj.matrix_world @ vertex.co).dot(direction) for obj in objects for vertex in obj.data.vertices)
    marked = 0
    for obj in objects:
        group = obj.vertex_groups.get("OutwardFace") or obj.vertex_groups.new(name="OutwardFace")
        normal_matrix = obj.matrix_world.to_3x3().inverted().transposed()
        indices = set()
        for polygon in obj.data.polygons:
            center = obj.matrix_world @ polygon.center
            normal = (normal_matrix @ polygon.normal).normalized()
            if (furthest-center.dot(direction) <= slab and abs(normal.z) < 0.78
                    and normal.dot(direction) >= -0.25):
                indices.update(polygon.vertices)
        if indices:
            group.add(sorted(indices), 1.0, "REPLACE")
            marked += len(indices)
        obj["outward_face_normal_godot"] = list(godot_direction)
    output_dir.mkdir(parents=True, exist_ok=True)
    (output_dir / ".gdignore").touch()
    bpy.context.scene["outward_face_normal_godot"] = list(godot_direction)
    bpy.ops.wm.save_as_mainfile(filepath=str(output_dir / f"{path.stem}.blend"))
    return marked


def main():
    args = argument_parser()
    paths = sorted(args.source.glob("building-*.glb"))
    if not paths:
        raise SystemExit(f"No Kenney building GLBs found in {args.source}")
    manifest = {}
    for path in paths:
        triangles, points = read_glb(path)
        label, scores, slab, confidence = analyze(triangles, points)
        marked = None
        if bpy is not None and not args.manifest_only:
            marked = mark_blender_vertices(path, label, slab, args.blend_dir)
        manifest[path.name] = {"outward_face": label,
                               "outward_normal": list(SIDES[label]),
                               "vertex_group": "OutwardFace",
                               "confidence": confidence,
                               "scores": scores}
        print(f"{path.name}: {label} (confidence {confidence:.2f}, marked vertices {marked})")
    args.manifest.parent.mkdir(parents=True, exist_ok=True)
    args.manifest.write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(f"Wrote {args.manifest}")
    if bpy is None and not args.manifest_only:
        print("Blender is unavailable here; run this script with Blender to create the vertex groups and .blend files.")


if __name__ == "__main__":
    main()
