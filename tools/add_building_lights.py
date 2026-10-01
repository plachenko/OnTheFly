"""Generate editable window-light companion GLBs for the Kenney buildings.

Run with Blender:
  blender --background --python tools/add_building_lights.py --

Each output GLB contains separate WindowLight_* meshes in the source building's
coordinate space. Godot attaches it to the matching building and randomly
shows the windows at night. Original Kenney files are not modified.
"""

from pathlib import Path
import sys

import bpy
from mathutils import Vector


ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "assets/kenney_city/commercial"
OUTPUT = ROOT / "assets/kenney_city/commercial_lights"


def make_window(name, center, size, material):
    bpy.ops.mesh.primitive_cube_add(size=1, location=center)
    window = bpy.context.object
    window.name = name
    window.dimensions = size
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    window.data.materials.append(material)
    return window


def export_lights(source):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(source))
    meshes = [obj for obj in bpy.context.scene.objects if obj.type == "MESH"]
    if not meshes:
        return 0
    bounds = [obj.matrix_world @ Vector(corner) for obj in meshes for corner in obj.bound_box]
    minimum = Vector((min(v.x for v in bounds), min(v.y for v in bounds), min(v.z for v in bounds)))
    maximum = Vector((max(v.x for v in bounds), max(v.y for v in bounds), max(v.z for v in bounds)))
    width, depth, height = maximum.x-minimum.x, maximum.y-minimum.y, maximum.z-minimum.z
    if min(width, depth, height) <= 0:
        return 0
    warm = bpy.data.materials.new("WarmWindowGlow")
    warm.diffuse_color = (1.0, 0.76, 0.38, 1.0)
    warm.use_nodes = True
    shader = warm.node_tree.nodes.get("Principled BSDF")
    shader.inputs["Base Color"].default_value = warm.diffuse_color
    shader.inputs["Emission Color"].default_value = (1.0, 0.66, 0.25, 1.0)
    shader.inputs["Emission Strength"].default_value = 2.5
    # Hide imported geometry in the output; it only supplies the dimensions.
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    count = 0
    columns = 3
    rows = 2
    for side in ("front", "back", "left", "right"):
        horizontal = width if side in ("front", "back") else depth
        lamp_width = min(horizontal * 0.17, height * 0.18)
        lamp_height = min(height * 0.12, lamp_width * 1.4)
        if lamp_width <= 0.01 or lamp_height <= 0.01:
            continue
        for row in range(rows):
            z = minimum.z + height * (0.34 + row * 0.36)
            for column in range(columns):
                across = (column + 1.0) / (columns + 1.0)
                if side in ("front", "back"):
                    x = minimum.x + width * across
                    y = minimum.y - 0.008 if side == "front" else maximum.y + 0.008
                    size = (lamp_width, 0.014, lamp_height)
                else:
                    x = minimum.x - 0.008 if side == "left" else maximum.x + 0.008
                    y = minimum.y + depth * across
                    size = (0.014, lamp_width, lamp_height)
                make_window(f"WindowLight_{side}_{row}_{column}", (x, y, z), size, warm)
                count += 1
    OUTPUT.mkdir(parents=True, exist_ok=True)
    bpy.ops.export_scene.gltf(filepath=str(OUTPUT / source.name), export_format="GLB", export_apply=True)
    return count


def main():
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    requested = set(args)
    paths = sorted(path for path in SOURCE.glob("building-*.glb") if not requested or path.name in requested)
    for path in paths:
        print(f"{path.name}: {export_lights(path)} window lights")


if __name__ == "__main__":
    main()
