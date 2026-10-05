Truck exaggeration lab

Scene: res://scenes/truck_exaggeration_lab.tscn
Menu: Performance lab -> Truck exaggeration lab.
Open the scene in Godot and press F6 to run it directly.

Choose an acceleration, braking, turn, donut, stop or idle clip.
The starter timeline has Rest, Anticipation, Peak, Rebound and Settle poses.
Click a diamond to select it; drag it horizontally to change its timing.
Click the timeline to scrub. Add/delete keys and edit their labels, timing,
pitch, roll, yaw and vertical heave. The curves show pitch and roll.
Drag the gold handle on the truck to shape the selected key: pitch+roll,
lift/bounce, or yaw/twist. Right-drag orbits; the wheel zooms the camera.
Play the clip, or enable Replay actual physics to preview real turns,
powerslides and donuts. Disable Apply exaggeration layer to compare the base.

Save JSON writes to the path shown in the lab. The default location is:
user://truck_exaggeration/food_truck.json
A new truck with handling_id="food_truck" automatically reads that file.
Different handling IDs use their own JSON filenames. Existing trucks can
call reload_exaggeration_profile() to reload saved changes during a run.
The lab applies edits immediately without needing to save first.

For a shipped profile, use Save as, place the JSON under
res://assets/truck_exaggeration/, and set the truck's exported
exaggeration_profile_path to that resource path. These JSONs are included in
Windows and Android exports. example.json is an editable starter, not an
active global default. If no profile is assigned or saved, gameplay keeps
its existing physics-driven motion.

JSON schema version 1:
  version, truck_id, name, strength (0..2), clips
  clips.<state>: duration (0.1..5 seconds), loop (boolean), keys
  keys: time (seconds), label, pitch/roll/yaw (degrees), heave (meters)
Angles are limited to +/-30 degrees per key, heave to +/-0.75 meters.
The engine uses smooth interpolation through the explicit authored peaks
and rebounds. Malformed JSON is rejected; unknown channels are ignored.

The layer runs after the base suspension and before wheel compensation.
It changes the chassis bone only. Collision, steering, traction, mass and
world movement remain driven by the original calculations. It uses existing
telemetry and adds no ground probes or other physics queries.
