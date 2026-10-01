# OnTheFly — Street Kitchen

A Godot 4.7.2 food-truck driving game. The main menu offers the original
playground and a procedurally generated hilly city with traffic, serving pads,
patrons, vehicle upgrades, and day/night lighting.

## Open and run

1. Import `project.godot` in Godot 4.7.2.
2. Let Godot import the included GLB and texture assets.
3. Run the project. Choose **Hilly city** for the procedural map.

`procedural_city.tscn` runs the city directly; `night_city.tscn` forces its
night variant. The editable `ProceduralCity` node controls terrain, traffic,
parking, buildings, and time-of-day generation. The truck, HUD, parking pads,
and repair pad remain scene objects with Inspector properties.

The main menu controls are shown in-game. On a controller, RT accelerates,
LT reverses, the left stick steers, A opens the kitchen while stopped, and
D-pad Down toggles hazards. After buying Full Self Driving, pressing D-pad
Down twice quickly drives to the nearest available serving pad. Keyboard K
performs the same double press.

Green SERVE and orange REPAIR / SHOP guides below the round HUD point toward
the nearest available serving pad and the repair shop. Their arrows rotate
with the camera and truck movement, including destinations behind the view;
the labels show horizontal distance in meters or HERE when inside the pad.
The serving guide follows the active FSD destination while driving itself
and switches away from expired pads. Guides hide during pause, repairs, and
the round-end menu, and scale with the HUD on touch devices.

## Video replay

A five-second rolling video buffer runs while the game is open. Tap and release
the left shoulder (LB / L1) for a screenshot. Hold it for half a second to start
video recording with that buffer included, then release to save. F9 provides
the same tap/hold keyboard control. Holding does not also take a screenshot.
The console reports when video recording starts, its buffered duration, and
the saved file path when recording ends.
Clips save under `user://videos` beside `user://screenshots`; on Windows this
is `%APPDATA%/Godot/app_userdata/Street Kitchen — Truck Playground/videos`.
The on-screen REC indicator shows total clip duration. Closing the game normally
also finalizes an active clip. Immediately after launch, only the available
buffer is included. Recording continues through pauses and scene changes.

Clips are silent MJPEG AVI at 640×360 and 15 fps, with letterboxing when needed.
No external encoder is required. The buffer holds at most 75 compressed frames;
active recordings stream to disk and automatically save at 1 GiB. Headless
runs disable viewport capture. Hardware-dependent capture overhead should be
checked on the target device; abrupt process termination cannot finalize a clip.

## Mobile controls

Touch devices automatically show multitouch buttons: hold LEFT/RIGHT to steer,
DRIVE or REVERSE for the pedals, and BRAKE to stop (brake + steer to drift).
KITCHEN opens/closes the serving panels; BOOST uses a purchased booster;
TOW recovers the truck. The top row controls signals, lights, and hazards.
Tap HAZARDS twice quickly to engage purchased Full Self Driving.
Swipe the uncovered play area to orbit the camera. The existing Pause button,
repair shop, and round-end menu also accept taps. Controls release when paused
or the app loses focus. Keyboard and gamepad mappings remain available.

For desktop testing, run a map with `-- --touch-controls`. The HUD scales to
fit narrow screens; landscape gives the largest menus and play area.

Traffic continues along its route when the truck partly enters the road,
without proximity-based yielding. Crosswalk stops, spacing behind other cars,
and the existing impact and disabled-car behavior still apply.

## Assets and source files


The `assets/` directory contains the runtime GLBs and textures needed to run
the game from a fresh clone. Kenney license notices remain beside the relevant
assets. `tools/` contains Blender scripts for building facades, building
lights, vehicle rigs, and the truck serving-side variant. The generated `.blend`
working files and Godot's `.godot/` cache are excluded from Git; run the
Blender scripts if you need to regenerate their GLB outputs.

Additional source archives, motion-capture files, Blender originals, and a
Windows export live beside this project in the local `OnTheFly` folder. They
are optional for opening this Godot project and are intended for the separate
Google Drive `OnTheFly` asset archive. The existing
`../Update_Project_Zip.ps1` is the user-run way to refresh the project ZIP.

`README.txt` contains older detailed gameplay notes and may lag newer changes.
