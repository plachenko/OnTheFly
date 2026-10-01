"""Move the food truck's serving side to the opposite side in Blender.

Run from the project directory:
  blender --background --python tools/move_truck_serving_side.py

The original assets/truck.glb stays untouched. The output is
assets/truck_opposite_side.glb, used by scenes/truck.tscn.
"""

from pathlib import Path

import bpy
import bmesh


ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "assets/truck.glb"
OUTPUT = ROOT / "assets/truck_opposite_side.glb"

MIRROR_PREFIXES = (
    "Awning cream stripe", "Cabinet door", "Cabinet pull",
    "Counter stainless inside", "Extractor hood", "Far side wall",
    "Folding service counter", "Griddle", "Hotplate",
    "Kitchen cabinet", "Kitchen worktop", "Lifting upper side panel",
    "Menu board", "Paper cup", "Side front pillar", "Side lower sill",
    "Side rear pillar", "Side upper fascia", "Sink basin", "Sink rim",
    "Tap", "Window edge trim",
)
TEXT_PREFIXES = ("Truck branding", "Lower logo", "Menu items", "Menu title")


def flip_mesh(obj, keep_text_readable=False):
    center_x = sum(vertex.co.x for vertex in obj.data.vertices) / len(obj.data.vertices)
    for vertex in obj.data.vertices:
        vertex.co.y = -vertex.co.y
        if keep_text_readable:
            # A half-turn around the vertical axis moves the label to the
            # opposite facade while preserving its readable orientation.
            vertex.co.x = 2.0 * center_x - vertex.co.x
    if not keep_text_readable:
        mesh = bmesh.new()
        mesh.from_mesh(obj.data)
        bmesh.ops.reverse_faces(mesh, faces=mesh.faces)
        mesh.to_mesh(obj.data)
        mesh.free()
    obj.data.update()


def main():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(SOURCE))
    mirrored = []
    for obj in bpy.data.objects:
        if obj.type != "MESH":
            continue
        if obj.name.startswith(TEXT_PREFIXES):
            flip_mesh(obj, True)
            mirrored.append(obj.name)
        elif obj.name.startswith(MIRROR_PREFIXES):
            flip_mesh(obj)
            mirrored.append(obj.name)
    for armature in (obj for obj in bpy.data.objects if obj.type == "ARMATURE"):
        bpy.context.view_layer.objects.active = armature
        bpy.ops.object.mode_set(mode="EDIT")
        for name in ("Awning", "Counter"):
            bone = armature.data.edit_bones.get(name)
            if bone:
                head = bone.head.copy()
                tail = bone.tail.copy()
                head.y = -head.y
                tail.y = -tail.y
                bone.head = head
                bone.tail = tail
                bone.roll = -bone.roll
        bpy.ops.object.mode_set(mode="OBJECT")
    bpy.ops.export_scene.gltf(filepath=str(OUTPUT), export_format="GLB", export_apply=True)
    print(f"Moved serving side in {len(mirrored)} meshes: {OUTPUT}")


if __name__ == "__main__":
    main()
