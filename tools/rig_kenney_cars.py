"""Add spring and crumple-zone bones to each Kenney traffic car.

Run with Blender:
  blender --background --python tools/rig_kenney_cars.py --

Original GLBs are preserved. Rigged GLBs go in assets/kenney_city/cars_rigged,
and editable .blend files go in tools/rigged_cars (ignored by Godot).
"""

import argparse
import sys
from pathlib import Path

import bpy
from mathutils import Vector


ROOT = Path(__file__).resolve().parents[1]


def arguments():
    parser = argparse.ArgumentParser()
    parser.add_argument("--source", type=Path, default=ROOT / "assets/kenney_city/cars")
    parser.add_argument("--output", type=Path, default=ROOT / "assets/kenney_city/cars_rigged")
    parser.add_argument("--blend-dir", type=Path, default=ROOT / "tools/rigged_cars")
    return parser.parse_args(sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else [])


def rig_car(source: Path, output: Path, blend_dir: Path):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.context.preferences.filepaths.save_version = 0
    bpy.ops.import_scene.gltf(filepath=str(source))
    meshes = [obj for obj in bpy.context.scene.objects if obj.type == "MESH"]
    if not meshes:
        raise RuntimeError(f"No mesh in {source}")

    points = [obj.matrix_world @ vertex.co for obj in meshes for vertex in obj.data.vertices]
    minimum = Vector((min(p.x for p in points), min(p.y for p in points), min(p.z for p in points)))
    maximum = Vector((max(p.x for p in points), max(p.y for p in points), max(p.z for p in points)))
    center = (minimum + maximum) * 0.5
    span_x = max(0.1, maximum.x - minimum.x)
    span_y = max(0.1, maximum.y - minimum.y)
    low = minimum.z + (maximum.z - minimum.z) * 0.28

    armature_data = bpy.data.armatures.new("CarSpringArmature")
    armature = bpy.data.objects.new("CarSpringRig", armature_data)
    bpy.context.collection.objects.link(armature)
    bpy.context.view_layer.objects.active = armature
    armature.select_set(True)
    bpy.ops.object.mode_set(mode="EDIT")
    chassis = armature_data.edit_bones.new("Chassis")
    chassis.head = (center.x, center.y, low)
    chassis.tail = (center.x, center.y, low + 0.35)
    for label, x_sign, y_sign in [("Spring_FL", -1, -1), ("Spring_FR", 1, -1),
                                    ("Spring_RL", -1, 1), ("Spring_RR", 1, 1)]:
        bone = armature_data.edit_bones.new(label)
        bone.head = (center.x + x_sign * span_x * 0.32,
                     center.y + y_sign * span_y * 0.32, low)
        bone.tail = bone.head + Vector((0, 0, 0.28))
        bone.parent = chassis
    for label, y_sign in (("Crumple_Front", -1), ("Crumple_Rear", 1)):
        bone = armature_data.edit_bones.new(label)
        bone.head = (center.x, center.y + y_sign * span_y * 0.35, low)
        bone.tail = bone.head + Vector((0, 0, 0.28))
        bone.parent = chassis
    bpy.ops.object.mode_set(mode="OBJECT")

    for obj in meshes:
        world = obj.matrix_world.copy()
        obj.parent = armature
        obj.matrix_world = world
        chassis_group = obj.vertex_groups.new(name="Chassis")
        groups = {name: obj.vertex_groups.new(name=name) for name in
                  ("Spring_FL", "Spring_FR", "Spring_RL", "Spring_RR")}
        crumple_groups = {name: obj.vertex_groups.new(name=name) for name in
                          ("Crumple_Front", "Crumple_Rear")}
        wheel_name = obj.name.lower()
        wheel_bone = ""
        if "wheel" in wheel_name:
            wheel_bone = "Spring_" + ("F" if "front" in wheel_name else "R") + ("L" if "left" in wheel_name else "R")
        for vertex in obj.data.vertices:
            if wheel_bone:
                groups[wheel_bone].add([vertex.index], 1.0, "REPLACE")
                continue
            point = obj.matrix_world @ vertex.co
            u = max(0.0, min(1.0, (point.x - minimum.x) / span_x))
            v = max(0.0, min(1.0, (point.y - minimum.y) / span_y))
            front_zone = max(0.0, min(1.0, (0.32 - v) / 0.32))
            rear_zone = max(0.0, min(1.0, (v - 0.68) / 0.32))
            crumple_weight = 0.42 * max(front_zone, rear_zone)
            chassis_group.add([vertex.index], 0.72 - crumple_weight, "REPLACE")
            if front_zone > 0.0001:
                crumple_groups["Crumple_Front"].add([vertex.index], 0.42 * front_zone, "REPLACE")
            if rear_zone > 0.0001:
                crumple_groups["Crumple_Rear"].add([vertex.index], 0.42 * rear_zone, "REPLACE")
            for name, weight in (("Spring_FL", (1-u)*(1-v)),
                                 ("Spring_FR", u*(1-v)),
                                 ("Spring_RL", (1-u)*v),
                                 ("Spring_RR", u*v)):
                if weight > 0.0001:
                    groups[name].add([vertex.index], 0.28 * weight, "REPLACE")
        modifier = obj.modifiers.new("Car spring skin", "ARMATURE")
        modifier.object = armature

    blend_dir.mkdir(parents=True, exist_ok=True)
    output.mkdir(parents=True, exist_ok=True)
    (blend_dir / ".gdignore").touch()
    bpy.ops.wm.save_as_mainfile(filepath=str(blend_dir / f"{source.stem}.blend"))
    bpy.ops.object.select_all(action="DESELECT")
    armature.select_set(True)
    for obj in meshes:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = armature
    bpy.ops.export_scene.gltf(filepath=str(output / source.name), export_format="GLB",
                              use_selection=True, export_apply=False)
    print(f"Rigged {source.name}: {len(meshes)} meshes, {len(points)} vertices")


def main():
    args = arguments()
    for source in sorted(args.source.glob("*.glb")):
        rig_car(source, args.output, args.blend_dir)


if __name__ == "__main__":
    main()
