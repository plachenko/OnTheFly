"""Make actual window faces emissive; never add floating light geometry.

Run Blender --background --python tools/make_windows_emissive.py -- [building-a.glb ...]
Reads commercial/*.glb and writes commercial_emissive/*.glb and editable .blend
copies. Originals are preserved. Detects named window/glass materials or blue
palette texels on vertical faces. Review detections for other asset palettes.
"""
from pathlib import Path
import sys
import bpy
from mathutils import Vector
sys.path.insert(0, str(Path(__file__).resolve().parent))
from place_car_lights import face_color

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "assets/kenney_city/commercial"
OUTPUT = ROOT / "assets/kenney_city/commercial_emissive"


def process(path):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(path))
    count = 0
    for obj in list(bpy.context.scene.objects):
        if obj.type != "MESH":
            continue
        normal_matrix = obj.matrix_world.to_3x3().inverted().transposed()
        copies = {}
        for face in obj.data.polygons:
            normal = (normal_matrix @ face.normal).normalized()
            original = obj.data.materials[face.material_index] if obj.data.materials else None
            if original is None:
                continue
            r, g, b = face_color(obj, face)
            named = any(word in original.name.lower() for word in ("window", "glass"))
            blue = b > 0.3 and b > g * 1.15 and g > r * 1.15
            if not named and not (blue and abs(normal.z) < 0.25):
                continue
            if original.name not in copies:
                material = original.copy()
                material.name = original.name + "_EmissiveWindows"
                material.use_nodes = True
                shader = next((n for n in material.node_tree.nodes if n.type == "BSDF_PRINCIPLED"), None)
                if shader is None:
                    raise RuntimeError(f"No Principled shader in {original.name}")
                emission = shader.inputs.get("Emission Color") or shader.inputs.get("Emission")
                for link in list(emission.links):
                    material.node_tree.links.remove(link)
                emission.default_value = (1.0, 0.76, 0.38, 1.0)
                shader.inputs["Emission Strength"].default_value = 2.5
                obj.data.materials.append(material)
                copies[original.name] = len(obj.data.materials) - 1
            face.material_index = copies[original.name]
            count += 1
    OUTPUT.mkdir(parents=True, exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=str(OUTPUT / (path.stem + ".blend")))
    bpy.ops.export_scene.gltf(filepath=str(OUTPUT / path.name), export_format="GLB", export_apply=True)
    print(f"{path.name}: {count} actual window faces made emissive")


if __name__ == "__main__":
    sys.path.insert(0, str(Path(__file__).resolve().parent))
    requested = set(sys.argv[sys.argv.index("--") + 1:]) if "--" in sys.argv else set()
    for path in sorted(SOURCE.glob("building-*.glb")):
        if not requested or path.name in requested:
            process(path)
