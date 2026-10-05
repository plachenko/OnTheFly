# Automated profiler route v1

Scene: `res://scenes/profiler_route.tscn`. Open it and press F6 in Godot.
The scene starts automatically and repeats; no keyboard, controller, saved
balance, procedural city, random seed, patrons or traffic affect its route.

For an automated debug run, launch the Godot editor executable from a terminal:

```powershell
godot --path "C:\Users\Shadow\Documents\OnTheFly\Food_Truck_Drive" -- --profile-route --profile-once
```

Use your installed Godot executable path in place of `godot` if it is not on
PATH. Omit `--profile-once` for continuous laps. For a release export:

```powershell
.\OnTheFly.exe -- --profile-route --profile-once
```

The first 120 physics ticks (2 seconds) settle the truck. Each measured lap is
3,600 ticks (60 simulated seconds) at 60 Hz:

| Lap seconds | Action |
| --- | --- |
| 0–12 | Drive north from (-30, 30) to bay A at (-30, -30) |
| 12–18 | Stop, open the kitchen, close it, turn toward bay B |
| 18–30 | Drive east to bay B at (30, -30) |
| 30–36 | Stop, open the kitchen, close it, turn to reverse |
| 36–42 | Reverse south to (30, -18) |
| 42–44 | Stop and turn |
| 44–58 | Follow the fixed curved return path to the start |
| 58–60 | Stop and restore the starting heading |

Positions use (x, z) metres. One fixed truck, nine fixed building instances,
the roads, daylight, shadows and follow camera repeat identically. Motion is
a scripted kinematic route with smooth acceleration at destinations. It uses
the production truck mesh, collision queries, ground sampling, suspension,
wheels, lights and kitchen bones. This measures that workload rather than
driver input, route-finding AI, patron simulation or traffic simulation.

`PROFILE_ROUTE_READY`, `PROFILE_ROUTE_PHASE` and `PROFILE_ROUTE_COMPLETE`
log route version, fixed tick boundaries, build/render settings, samples and a
pose checksum. Compare builds using the same route version, Godot version,
renderer, resolution, graphics/VSync settings, build type and machine. Begin
measurement at the first phase marker after warmup. A lap is measured in
simulation ticks; wall-clock duration can grow if the machine falls behind.
Use Godot's profiler or an external profiler for CPU/GPU measurements.

Debug runs keep their existing render cap; this level never sets max_fps,
VSync, physics rate or replay settings. Release standalone exports alone set
`Engine.max_fps = 30` and `Engine.physics_ticks_per_second = 60` through
`RuntimePolicy`. The scene rejects a non-60-Hz physics configuration.

Replay remains off unless a **debug build** opts in with
`--debug-replay-capture` or `debug/replay_capture/enabled=true`. This level does
not enable it. The Windows Desktop preset still excludes
`debug_replay_recorder.gd` and its UID; screenshots remain available.

For correctness checks only, adding `--headless --fixed-fps 60` before `--`
allows a fast, fixed-step run. Do not use that mode for render performance
comparisons: headless rendering omits the GPU workload, and fixed-fps changes
real-time pacing.
