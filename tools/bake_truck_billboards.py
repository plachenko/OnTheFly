"""Blender background bake: shared animated rig, 36 directional views per render.
Run blender --background --python tools/bake_truck_billboards.py
Then tools/pack_truck_billboards.py with Python/Pillow. No source truck changes.
"""
import bpy, math, json
from pathlib import Path
from mathutils import Matrix, Vector
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'assets/truck_billboards'; OUT.mkdir(parents=True,exist_ok=True)
RAW=ROOT.parent/'.runtime/truck_billboard_frames'; RAW.mkdir(parents=True,exist_ok=True)
ANGLES=12; ELEVATIONS=[0,25,50]; FRAMES=8; CELL=(256,192); EXTENT=9.8
STATES=['idle','drive','accelerate','brake','lean_left','lean_right','donut','stop']
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(ROOT/'assets/truck_with_doors.glb'))
objects=list(bpy.context.scene.objects)
rig=next(o for o in objects if o.type=='ARMATURE')
roots=[o for o in objects if o.parent is None]
root=bpy.data.objects.new('TruckSpace',None); bpy.context.scene.collection.objects.link(root)
root.rotation_euler.z=math.pi/2
for o in roots: o.parent=root
bpy.context.view_layer.update()
# Match Godot Model's +90 degree Y rotation and 10.5 cm model offset.
root.location.z=.105
bpy.context.view_layer.update()
points=[o.matrix_world@Vector(v) for o in objects if o.type=='MESH' for v in o.bound_box]
lo=Vector(tuple(min(v[a] for v in points) for a in range(3)))
hi=Vector(tuple(max(v[a] for v in points) for a in range(3)))
center=(lo+hi)/2
rest={b.name:b.matrix_local.copy() for b in rig.data.bones}
scene=bpy.context.scene; scene.render.engine='BLENDER_EEVEE'
scene.render.film_transparent=True; scene.render.image_settings.file_format='PNG'
scene.render.image_settings.color_mode='RGBA'; scene.render.image_settings.color_depth='8'
scene.render.resolution_percentage=100
scene.render.resolution_x=CELL[0]*ANGLES; scene.render.resolution_y=CELL[1]*len(ELEVATIONS)
scene.render.fps=12
if hasattr(scene,'eevee') and hasattr(scene.eevee,'taa_render_samples'): scene.eevee.taa_render_samples=8
scene.view_settings.view_transform='Standard'; scene.view_settings.look='None'
scene.view_settings.exposure=0; scene.view_settings.gamma=1
camera_data=bpy.data.cameras.new('AtlasCamera'); camera=bpy.data.objects.new('AtlasCamera',camera_data)
scene.collection.objects.link(camera); scene.camera=camera
camera.location=(0,-100,0); camera.rotation_euler=(Vector((0,0,0))-camera.location).to_track_quat('-Z','Y').to_euler()
camera_data.type='ORTHO'; camera_data.ortho_scale=EXTENT*len(ELEVATIONS)*scene.render.resolution_x/scene.render.resolution_y
camera_data.clip_end=250
# Bake keyframed anticipation, weight transfer and elastic follow-through.
# Suspension roots are counter-transformed so the four tire centres remain planted.
chassis=rig.pose.bones['Chassis']; pivot=rest['Chassis'].translation.copy()
def pose(state,t):
 for b in rig.pose.bones: b.matrix_basis.identity()
 w=2*math.pi*t; pitch=roll=yaw=rise=0
 if state=='idle': rise=.012*math.sin(w*2); roll=.005*math.sin(w)
 elif state=='drive': rise=.018*math.sin(w*2); pitch=.012*math.sin(w)
 elif state=='accelerate': pitch=(-.035*math.exp(-((t-.12)/.1)**2)+.095*math.exp(-((t-.42)/.22)**2)); rise=-.04*math.sin(math.pi*t)
 elif state=='brake': pitch=.025*math.exp(-((t-.08)/.09)**2)-.13*math.exp(-((t-.33)/.17)**2)+.06*math.exp(-((t-.7)/.18)**2); rise=-.045*math.sin(math.pi*t)
 elif state.startswith('lean_'):
  side=1 if state=='lean_left' else -1
  roll=side*.105*math.sin(math.pi*t)**2; yaw=-side*.045*math.sin(math.pi*max(0,t-.15))**2; rise=-.015*math.sin(math.pi*t)
 elif state=='donut': roll=.085*math.sin(w-.5); yaw=.06*math.sin(w-1); pitch=.025*math.sin(w*2); rise=.035*math.sin(w*2)
 elif state=='stop': pitch=-.065*math.sin(w*1.5)*math.exp(-3*t); yaw=.045*math.sin(w*2)*math.exp(-3*t); rise=-.03*math.sin(w)*math.exp(-3*t)
 # Truck-space body motion mapped into the imported armature's space.
 rotation=Matrix.Rotation(pitch,4,'Y')@Matrix.Rotation(roll,4,'X')@Matrix.Rotation(yaw,4,'Z')
 chassis.matrix=Matrix.Translation(pivot+Vector((0,0,rise)))@rotation@Matrix.Translation(-pivot)@rest['Chassis']
 bpy.context.view_layer.update()
 for corner in ['Front_L','Front_R','Rear_L','Rear_R']:
  rig.pose.bones['Suspension_'+corner].matrix=rest['Suspension_'+corner]
  spin=rig.pose.bones['Spin_'+corner]
  spin.rotation_mode='XYZ'; spin.rotation_euler.y=w*2 if state not in ['idle','stop'] else 0
 bpy.context.view_layer.update()
for si,state in enumerate(STATES):
 start=si*FRAMES+1
 scene.timeline_markers.new(state,frame=start)
 for f in range(FRAMES):
  frame=start+f; scene.frame_set(frame); pose(state,f/(FRAMES-1) if state not in ['idle','drive','donut'] else f/FRAMES)
  for b in rig.pose.bones:
   b.keyframe_insert('location',frame=frame); b.keyframe_insert('rotation_quaternion',frame=frame); b.keyframe_insert('rotation_euler',frame=frame); b.keyframe_insert('scale',frame=frame)
scene.frame_end=len(STATES)*FRAMES
# Save the editable animated source before building the render-only multiview stage.
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT.parent/'Truck_Expressive.blend'))
source=bpy.data.collections.new('AnimatedTruck'); scene.collection.children.link(source)
for o in objects+[root]:
 for c in list(o.users_collection): c.objects.unlink(o)
 source.objects.link(o)
scene.collection.children.unlink(source)
width=EXTENT*CELL[0]/CELL[1]
for row,pitch in enumerate(ELEVATIONS):
 for heading in range(ANGLES):
  instance=bpy.data.objects.new('View_%02d_%02d'%(heading,pitch),None)
  instance.instance_type='COLLECTION'; instance.instance_collection=source
  scene.collection.objects.link(instance)
  rotation=Matrix.Rotation(math.radians(pitch),4,'X')@Matrix.Rotation(-heading*2*math.pi/ANGLES,4,'Z')
  location=Vector(((heading-(ANGLES-1)/2)*width,0,((len(ELEVATIONS)-1)/2-row)*EXTENT))
  instance.matrix_world=Matrix.Translation(location)@rotation@Matrix.Translation(-center)
# Preserve texture colours as emission; light the normal atlas in Godot per view.
colour_materials={}; normal_material=bpy.data.materials.new('TruckNormals'); normal_material.use_nodes=True
nodes=normal_material.node_tree.nodes; nodes.clear(); links=normal_material.node_tree.links
geo=nodes.new('ShaderNodeNewGeometry'); transform=nodes.new('ShaderNodeVectorTransform'); transform.vector_type='NORMAL'; transform.convert_from='WORLD'; transform.convert_to='OBJECT'; links.new(geo.outputs['Normal'],transform.inputs['Vector'])
separate=nodes.new('ShaderNodeSeparateXYZ'); links.new(transform.outputs[0],separate.inputs[0])
combine=nodes.new('ShaderNodeCombineXYZ')
for out,source_axis,sign in [('X','Y',-1),('Y','Z',1),('Z','X',-1)]:
 mul=nodes.new('ShaderNodeMath'); mul.operation='MULTIPLY_ADD'; mul.inputs[1].default_value=sign*.5; mul.inputs[2].default_value=.5
 links.new(separate.outputs[source_axis],mul.inputs[0]); links.new(mul.outputs[0],combine.inputs[out])
em=nodes.new('ShaderNodeEmission'); output=nodes.new('ShaderNodeOutputMaterial'); links.new(combine.outputs[0],em.inputs[0]); links.new(em.outputs[0],output.inputs['Surface'])
meshes=[o for o in objects if o.type=='MESH']
for obj in meshes:
 for slot in obj.material_slots:
  original=slot.material
  if original.name not in colour_materials:
   m=original.copy(); m.name=original.name+'_Albedo'; m.use_nodes=True; n=m.node_tree.nodes; l=m.node_tree.links
   bs=next((v for v in n if v.type=='BSDF_PRINCIPLED'),None); out=next(v for v in n if v.type=='OUTPUT_MATERIAL'); em=n.new('ShaderNodeEmission')
   if bs:
    if bs.inputs['Base Color'].is_linked: l.new(bs.inputs['Base Color'].links[0].from_socket,em.inputs[0])
    else: em.inputs[0].default_value=bs.inputs['Base Color'].default_value
   l.new(em.outputs[0],out.inputs['Surface']); colour_materials[original.name]=m
  slot.material=colour_materials[original.name]
slots=[(o,[s.material for s in o.material_slots]) for o in meshes]
metadata={'version':1,'angles':ANGLES,'elevations':ELEVATIONS,'frames':FRAMES,'cell':CELL,'world_height':EXTENT,'center':[center.x,center.z,-center.y],'states':{s:{'duration':FRAMES/12,'loop':s in ['idle','drive','donut'],'atlas':'res://assets/truck_billboards/'+s+'.png','normals':'res://assets/truck_billboards/'+s+'_normals.png'} for s in STATES}}
(OUT/'metadata.json').write_text(json.dumps(metadata,indent=2))
for si,state in enumerate(STATES):
 for f in range(FRAMES):
  scene.frame_set(si*FRAMES+f+1); bpy.context.view_layer.update()
  for normal in [False,True]:
   target=RAW/(state+'_%02d'%f+('_normals' if normal else '')+'.png')
   if target.exists(): continue
   for obj,materials in slots:
    for i,m in enumerate(materials): obj.material_slots[i].material=normal_material if normal else m
   scene.view_settings.view_transform='Raw' if normal else 'Standard'
   scene.render.filepath=str(target); bpy.ops.render.render(write_still=True)
  print('TRUCK_BAKE',state,f,flush=True)
print('TRUCK_BAKE COMPLETE',flush=True)
