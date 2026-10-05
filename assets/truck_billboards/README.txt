Prototype status: parked. Gameplay uses the original 3D truck by default.
Enable use_driving_billboard on a truck only to opt into this experiment.
The Blender source and baked sheets are retained for future work.

Driving truck billboard assets

Source: ../../../Truck_Expressive.blend (editable armature animation).
Bake: Blender --background --python tools/bake_truck_billboards.py
Pack: Python tools/pack_truck_billboards.py (Pillow).
The bake source reuses truck_with_doors.glb, preserves the production model,
and keyframes chassis anticipation, delayed lean, rebound and follow-through.
Suspension roots are counter-transformed to keep tires planted.

Eight states: idle, drive, accelerate, brake, lean_left, lean_right, donut, stop.
Each atlas holds eight frames, 12 headings and three elevations (0/25/50 degrees).
Frame cells are 256x192. Each frame contains three elevation rows; headings
run horizontally. Atlas colours are unlit albedo; matching object-space normal
atlases receive the game's lights. Alpha gutters and cell UV clamps avoid seams.
The PNG imports use VRAM compression, mipmaps and full RGB normals.

Runtime uses existing truck acceleration, braking, lateral acceleration, yaw,
speed, slope attitude and the existing four wheel contact heights. It adds no physics queries. 3D collision, suspension,
tire effects and driving remain authoritative. Direction is selected per camera
in the shader. Atlases stream asynchronously and share references between trucks;
3D remains visible until the first sheet is ready. Complementary screen-space
dithering transitions between billboard and retained 3D materials. Kitchen,
loading/menu cinematics and free camera use 3D, including existing cutaway shaders.

Handling lab: Sprite exaggeration, Sprite animation pace, Kitchen lean delay,
Visual blend time. They save in the existing per-truck JSON/default/.tres profiles.
Animation strength controls the blend from a clip's resting pose to its full
exaggerated pose; timing does not alter driving physics.

Tests: tools/truck_billboard_test.gd and tools/menu_comic_test.gd.
