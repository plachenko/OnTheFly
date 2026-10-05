# OnTheFly

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

City generation joins some neighboring blocks into spans of two or three,
favoring the outer ring. Internal streets, sidewalks, road paint, parking and
traffic routes follow those joins. Each map chooses 3–5 highway exits using
spaced selection; other highway approaches are barricaded. The map seed repeats
both the block layout and exit choices.

Road surfaces, curbs and paint receive a curved render mesh after generation.
The original terrain and road collision shapes stay coarse. Visual displacement
is limited to 18 cm, and wheel visuals and tire marks follow the rendered height.

The main menu controls are shown in-game. On a controller, push the left stick
up for Drive or down for Reverse; the gear stays selected when released.
RT accelerates in that gear, LT brakes (double-tap within 350 ms and hold LT to accelerate in Reverse), left-stick X steers, and clicking
the left stick (L3) honks. In Reverse, hold the right stick back to snap the
camera to the front of the truck looking rearward. Release it to return to
the follow camera. A opens the kitchen while stopped, and
D-pad Down toggles hazards. After buying Full Self Driving, pressing D-pad
Down twice quickly drives to the nearest available serving pad. Keyboard K
performs the same double press.

After double-tap-and-hold brake reverse, pressing RT (or keyboard acceleration)
automatically shifts back to Drive. The held brake stays ignored until released;
the next brake press brakes normally.

Hold acceleration and brake together while steering to do donuts without a drift
upgrade (RT + LT + left-stick steering on a controller). Tire marks and smoke
increase with wheel slip and surface friction; marks fade after 12–20 seconds.

Green SERVE and orange REPAIR / SHOP guides below the round HUD point toward
the nearest available serving pad and the repair shop. Their arrows rotate
with the camera and truck movement, including destinations behind the view;
the labels show horizontal distance in meters or HERE when inside the pad.
The serving guide follows the active FSD destination while driving itself
and switches away from expired pads. Guides hide during pause, repairs, and
the round-end menu, and scale with the HUD on touch devices.

## Automated profiler route

Open `scenes/profiler_route.tscn` and press F6, or launch with
`-- --profile-route --profile-once`. It runs a two-second warmup, then a
60-second fixed truck route with two kitchen stops and a reverse section.
No patrons, traffic or random choices are included. See `PROFILER_ROUTE.md`
for launch commands, the tick schedule, comparison controls and limitations.
Debug runs keep their existing frame rate. Release standalone exports alone
cap rendering at 30 FPS while physics remains at 60 Hz.

## Feeding traffic and patrons

Between feeding windows, up to three ambient patrons spawn at slower intervals.
Idle crowds thin away from players when service closes. City traffic starts at
35% density (8 of the default 22 moving cars), ramps toward full density during
the last 12 seconds before feeding, and stays busy through the service window.
Cars enter and leave away from every player, with parked cars, wrecks and active
pursuits preserved. Multiplayer density changes are controlled by the host and
replicated to clients.

## Police test scene

During police pursuit, empty parking bays that are not active service or repair
areas glow yellow with dashed yellow borders. Signal toward a highlighted bay
within 24 metres (J: left / L: right, or controller D-pad left/right) to
automatically pull over and park. Police wait during the
maneuver; blocked or occupied bays cancel it safely. Parking charges up to $25
from available funds, shows a five-second popup, ends the pursuit and restores
green cop circles. The police sandbox includes six marked bays, three on each
side, to test it. Permanent white markings remain visible before pursuit;
eligible bays gain the yellow glow during pursuit. Use P to start a pursuit
and J/L or controller D-pad left/right to signal toward a bay.

Open `scenes/police_test.tscn` and press F6, like the hybrid collision demo.
Starts with one truck and one cop. Tab switches between driving the truck and
the selected cop; C adds cops and V cycles the selected cop. W/S drive, A/D
steer, Space brakes (standard driving controller inputs also work). P triggers
a pursuit, O toggles selected police lights, and R resets to the initial pair.
Unselected cops join pursuit using production AI. In truck mode, stop off the
road for two seconds to test voluntary surrender. The HUD shows pursuit,
infractions, stop time, money and health. Test economics and dispatch state are
restored when leaving the sandbox.

During pursuit, cops' red zones expand and the truck receives a red escape
ring. Six spinning blue arcs merge into a street-width guide as you approach
a road; it chooses a heading away from the cops. Travel at least 12 metres
along that heading and stay outside all active red zones for one second to
evade. Reverse travel counts too. Cop contact interrupts escape progress.
After four seconds, being inside a red zone drains 2 health per second.
Successful escape turns the player ring green and fades it over 1.8 seconds,
then the cops' green rings grow outward from their centers. Escape charges
no fine and preserves your driving speed. These escape rules run in the
police sandbox; the standard maps retain their existing pursuit rules.

## Video replay

A five-second rolling video buffer runs while the game is open. Tap and release
the left shoulder (LB / L1) for a screenshot. Hold it for half a second to start
video recording with that buffer included, then release to save. F9 provides
the same tap/hold keyboard control. Holding does not also take a screenshot.
The console reports when video recording starts, its buffered duration, and
the saved file path when recording ends.
Clips save under `user://videos` beside `user://screenshots`; on Windows this
is `%APPDATA%/Godot/app_userdata/OnTheFly/videos`.
The on-screen REC indicator shows total clip duration. Closing the game normally
also finalizes an active clip. Immediately after launch, only the available
buffer is included. Recording continues through pauses and scene changes.

Clips are silent MJPEG AVI at 640×360 and 15 fps, with letterboxing when needed.
Each clip also saves a matching `.performance.json`: share both files for hitch
analysis. It contains frame timings, CPU/physics monitors, render counts, loading
stages, measured script sections, and likely-cause hints for frames over 33 ms.
Video frame timestamps map playback to real capture time, including repeated
frames during stalls. These hints show correlations; GPU time is not measured.
The top-right FPS counter shifts from green toward red below the configured
frame cap (60 FPS when uncapped), and shows the latest frame duration.
Open **Debug** from the title menu or **Start/Pause → Debug menu** in game
(F3 / controller View also works). Compare one switch at a time: disable traffic,
use building blocks, or hide grass, street furniture, pedestrians, particles,
shadows, and local lights. Rendering switches keep gameplay and collisions;
disable traffic also freezes cars and removes their collisions. Switches persist
across scenes for this session, restore previous states, and are included in
each recording's performance JSON. The debug panel scrolls with controller focus.

**Disable traffic logic only** freezes traffic physics and stops car script
physics updates while keeping car meshes and collision layers unchanged. Leave
the full traffic-disable switch unchecked when comparing logic cost. Its state
is recorded as `traffic_logic_enabled` in the performance JSON.

The debug menu uses positive feature labels: checked means enabled. Uncheck
**Pedestrian logic and spawning** to stop movement, avoidance, animations,
service management, and new spawns while retaining visuals. Recording samples include `pedestrian_logic_enabled` and
`patron_count` so crowd growth can be compared with frame time.

Patrons now spawn one at a time every four seconds from three fixed building
entrances selected near the map's original spawn anchors. The crowd is capped
at 12 (four per building). On maps without city buildings, the original three
spawn anchors provide the fallback. Patrons walk briefly and wait for service;
served patrons walk away for four seconds, fade for two seconds, then despawn.
There are no per-patron crowd scans, dodge probes, or crosswalk decisions.
Performance captures include the measured `Patrons` script section.

**All baseline features** enables/disables all baseline simulation and rendering
features, including detailed buildings (unchecked uses blocks). It shows the
number enabled. Optional comparisons are separate: full-distance traffic,
full-detail distant rendering, and unoptimized multiplayer snapshots. Checked
enables the named comparison; these default off and are unaffected by baseline
toggle-all. Their states are included in the performance JSON.
In debug builds, pressing LB/L1 activates video capture automatically: tap for
a screenshot, hold for 0.5 seconds to record, release to save. The first hold
includes only the buffer collected since activation. Release exports retain
the screenshot/camera-timeline controls and do not include the video recorder.
No external encoder is required. The buffer holds at most 75 compressed frames;
active recordings stream to disk and automatically save at 1 GiB. Headless
runs disable viewport capture. Hardware-dependent capture overhead should be
checked on the target device; abrupt process termination cannot finalize a clip.

## Mobile controls

The main menu's **Share** button shows QR codes for the latest GitHub release
and its Android APK. Hosts can choose **Share lobby QR**, select a LAN adapter,
or enable **Use public IP** to detect their external IPv4 address via ipify.
The QR contains the IP and the actual hosting port. In Android's **Join
multiplayer** menu, **Scan QR** opens the camera and fills both fields; tap
**Join game** to connect. Desktop players can paste a copied connection code.
Public-IP hosting requires UDP port forwarding and a reachable public address;
the toggle does not configure the router or bypass carrier NAT.

Android QR scanning uses the bundled MIT-licensed NativeCamera and QR plugins.
Android exports require a Godot Android build template and Gradle build enabled.
Install the build template through Project > Install Android Build Template
before exporting from a fresh checkout. Camera permission is requested on scan.

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

Distant city blocks use baked render cards with eight directions and three
elevations. Views blend as the camera moves, and the cards fade away between
110 and 80 metres from the block's bounds, revealing the real buildings
underneath. Pending streamed blocks retain their cards until the geometry is
ready, followed by a 0.4-second handoff. Building collisions remain active.
The rendering LOD option reveals the full geometry once it is loaded.

All four shipped saved maps include these textures. Newly generated maps and
older caches bake their cards in the background after loading finishes, then
save them for subsequent starts. A rendering backend is required; headless
runs retain existing cards but cannot generate new ones. The cards approximate
distant perspective and add texture memory; nearby buildings use their full
geometry. The separate outer skyline still uses its existing LOD.

Render cards adjust their brightness and color using the live scene's sun and
ambient light, including its blue night lighting. Bake lighting is stored with
the atlas so already dark night captures are not darkened twice. Older cards
use their original day/night bake settings as the reference. This is an overall
lighting match; individual headlights and local shadows are not projected onto
the flat image.

To regenerate a shipped map's cards, run Godot with a rendering backend:
`GodotExport.exe --path . --script res://tools/bake_block_cards.gd -- res://generated_city/default_city.res`.
Pass additional map paths to bake them in the same run. The baker replaces each
saved map only after its completed resource saves successfully.
`tools/block_card_test.gd` checks pending coverage, distance fades, loaded-model
lookup, LOD disabling, and actual rendering when run with a graphics backend.


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
