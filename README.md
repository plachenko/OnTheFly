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
