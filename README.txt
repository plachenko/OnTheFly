OnTheFly

Run OnTheFly_Windows/OnTheFly.exe, or import project.godot into Godot 4.7.2 and press F6/F5.

HILLY CITY SCENE
Choose Hilly city on the main menu, or open procedural_city.tscn in Godot.
The scene creates a new hilly, collision-enabled landscape each time it loads,
then places Kenney roads and commercial buildings on a drivable city plateau.
The truck, serving pads, patrons, timer, money, and HUD remain playable.
Select the ProceduralCity node in the editor to adjust terrain size, hill
height, road tile size, building count, model paths, or turn off randomization
and set a fixed seed. Roads and buildings are generated scene objects at run
time; their templates and licenses are in assets/kenney_city. The original
flat playground remains available through Single player.
To package source changes later, run ../Update_Project_Zip.ps1 in PowerShell.
It rebuilds the project ZIP without Godot's generated .godot cache.

W / Up: accelerate
S / Down: brake into reverse
A D / Left Right: steer
Space: brake
E: open or close the serving awning and counter (stop first)
R: reset the truck
Right mouse drag: orbit the camera
Mouse wheel: zoom
Start / Escape: pause menu (Resume, Options, Quit game)

JOYPAD (MCON / standard XInput gamepad)
RT: analog acceleration
LT: analog braking (does not reverse)
Left stick: steer
Right stick: orbit camera
A: open / close kitchen
B: reverse
X: handbrake
Y: reset position / tow disabled truck (preserves damage)
View / Back or keyboard Tab: controller settings (pauses driving)
Settings include stick deadzone, trigger deadzone, steering sensitivity,
and impact vibration. Input bindings are saved in Project Settings > Input Map.
HUD controller settings defaults are editable in scenes/hud.tscn.

VEHICLE LIGHTS
H / D-pad Up toggles truck headlights. J / D-pad Left and L / D-pad Right
toggle directionals; K / D-pad Down toggles hazards. A signal cancels after
a completed turn when steering returns to center. Brake and reverse lights
follow the truck's driving state automatically. Kenney traffic cars use the
same reusable scenes/vehicle_lights.tscn rig, brake while yielding, and signal
before their occasional intersection turns. A disabled car flashes hazards.
The VehicleLights node in each vehicle scene exposes sizes, beam settings,
and blink timing in the Inspector. To enable a police car's red/blue bar from
game code, call traffic_car.set_police_lights_enabled(true); pass false to
switch it off. Police flashers start off by default.

TRUCK DAMAGE AND PARKING CAMERA
Hard impacts with solid obstacles damage the truck; the damage meter fills
as health is lost. Light contacts and ground contact do not cause damage.
At 100% damage the truck is disabled. R / Y tows it to the repair pad;
repairs cost money. Position resets preserve damage.
Select the truck root to tune max health, impact threshold, and damage scale.
Low static obstacles can be climbed while driving forward or backward.
The truck's Climbing Obstacles Inspector section controls maximum climb
height (0.65 m), climb damage (2), and damage cooldown (0.8 seconds).
Climbing damage varies slightly with obstacle height and driving speed.
Taller objects still block the truck and cause normal impact damage;
physical cones remain pushable. Full collision-shape checks enforce
headroom, forward clearance, and a walkable landing surface.
Opening the kitchen while stopped on a marked parking pad moves the camera
to the serving window. Closing it restores the driving view. Accelerating
with the kitchen open automatically packs it up, then drives away. Leaving
the parking zone also restores the driving camera.
ParkingPads contains four editable Area3D zones. Their camera offset,
focus offset, and transition speed are adjustable in the Inspector.

An arcade driving scene with a plaza, a garden island, parking bays,
picnic tables, trees, and solid curbs. Deploying the kitchen parks the
truck; close the panels before driving away.

The truck is the original Blender model, exported to assets/truck.glb.
main.tscn contains the saved environment, lights, road markings, scenery,
cone instances, truck instance, camera, and HUD instance. The vehicle light
rig creates its lamp visuals at runtime from Inspector settings.

EDITOR WORKFLOW
Open main.tscn to select, move, duplicate, or attach scripts to objects.
EnvironmentGeometry, RoadMarkings, Scenery, and Cones organize the level.
Open scenes/truck.tscn to edit its model and collision shape. Select its
root to tune driving and suspension settings in the Inspector. Reset
returns the truck to the starting transform you set in the editor.
Open scenes/cone.tscn to edit the cone mesh, collision, mass, friction,
and damping. The cones use RigidBody3D and react to truck impacts.
Open scenes/hud.tscn to edit the UI. Select the level root to tune the
follow camera, and use Project Settings > Input Map to change controls.
For nested prefab children, right-click an instance and enable Editable
Children, or open that prefab scene directly.

game.gd handles camera movement and HUD updates. truck.gd handles driving,
wheel motion, suspension, cone impulses, and the food-truck transformation.

RIG AND SUSPENSION
The rig has 16 bones: Root, Chassis, Awning, Counter, and four sets of
Suspension, Steer, and Spin bones. Each mesh uses rigid bone weights.
The Blender source is Food_Truck_Rigged.blend. Frames 1-180 show the
food-truck conversion; frames 200-390 demonstrate suspension poses.

The Godot controller calculates longitudinal and lateral weight transfer
from vehicle mass, acceleration, center-of-mass height, wheelbase, and
track width. Four damped springs drive chassis pitch/roll and individual
wheel suspension bones. Wheel raycasts maintain tire contact with the
ground. Acceleration compresses the rear; braking compresses the front;
turning compresses the outside wheels. The HUD shows axle and side loads.

Tuning in truck.gd: vehicle_mass (2400 kg), center_of_mass_height (1.45 m),
spring_stiffness (42000 N/m), spring_damping (6500 N*s/m), and
suspension_travel (0.20 m). Driving uses CharacterBody3D with a procedural
spring/load model; this is an arcade controller rather than a full rigid-body
vehicle simulation.
Visible axle links, dampers, coil springs, and raised wheel arches connect
each wheel to the chassis. Link endpoints are weighted separately to the
chassis and suspension bones so they remain attached during body motion.


LEVEL TIMER, MONEY, AND REPAIRS
Select the level root to set level_duration_seconds (180), starting_money
(200), starting_luck_range (10), and repair_pad_path. Starting money is
$200 plus a random integer from -$10 to +$10. Time-up stops driving and
opens the round summary; N or the New Round button restarts.
Controller settings pause the timer; the repair menu does not.

Damage reduces top speed and acceleration, down to 30% performance near
zero health. Below 25% health the truck loses 0.7 health per second.
Select the truck root to tune damaged_speed_floor, critical_health_ratio,
and critical_health_drain.

Stop at the orange REPAIR pad (ParkingPads/ParkingPad_04) to buy repairs.
Full fix restores all remaining damage at $1.60 per health (minimum $12).
Good fix restores half remaining damage at $2.20 per health (minimum $8).
Mid fix restores a quarter remaining damage at $3 per health (minimum $5).
Prices round up to whole dollars. Full repairs cost more now but offer the
best value per health point. Each purchase uses the current remaining
damage, checks available money, and cannot spend at full health.
Repair rates and minimum prices are editable on the repair-pad root.
scenes/repair_pad.tscn is reusable, including its zone and repair sign.
D-pad/arrows select an option; A/Enter buys; driving away closes the menu.

UPGRADES
Stop at the orange repair pad and choose the Upgrades tab.
Booster $60: installs an empty boost tank. Canisters $20: refill 50%.
Hold RB / Shift with acceleration to boost. Full tank lasts 4 seconds;
boost gives 1.6x top speed and 2.2x acceleration. Braking stops boost.
Drifting $70: brake + steer, with throttle to power through the slide;
release brake to accelerate out. Boost does not activate while braking.
Lift kit $80: raises the chassis and increases obstacle clearance from
0.65m to 1.1m. Hit trees at driving speed to knock them down for 2 health
before armor; standing trees still block a truck without the lift kit.
Armor $65: reduces impact, curb, and tree damage by 45%. Critical health
continues to drain. Purchases use round money and persist after reset/tow.
New rounds reset upgrades and fuel. Full tanks and installed upgrades
cannot be bought again; canisters require the booster first.
Prices and canister refill amount are editable on the level root.
Boost, lift, and armor effects are editable on the FoodTruck root.
HUD shop tabs and meter are saved nodes in scenes/hud.tscn. Trees are
editable instances of scenes/breakable_tree.tscn, with physical collision
shapes and frozen rigid bodies that release when hit by a lifted truck.
With Drifting installed, hold brake + steering + throttle from rest to pivot in place. The front axle holds position while the rear swings around it, and wheel rolling stays locked until you release brake; release brake to accelerate out.

BOOST SMASH
Boost into cones, benches, or the wooden crates on the east road to break
through them. Impact must reach 8 m/s and the object's longest dimension
must be at most 3 m. Normal driving and low-speed boost bumps do not break
props. Each successful smash causes 1.5 health damage before armor.
The truck root exposes boost_break_max_size and boost_break_damage.
Props have a saved BoostBreakable child with enabled, visual_root, and
minimum_impact_speed properties, plus editable Debris particles. Size is
measured from the target meshes and includes object scaling. Attach the
scenes/boost_breakable.tscn component under a physics body to opt another
prop in; set visual_root to that prop's mesh/root. Buildings, ground, and
curbs remain solid. New rounds restore broken props.


MAIN MENU AND ROUND RESULTS
The game opens on main_menu.tscn, with a slow side-on truck camera pan.
New game starts a fresh level. Options changes controller settings that
carry across menus and rounds for this session. Quit exits the game.

Earn $150 before the three-minute timer ends to win. Starting cash and
luck do not count; purchases do not reduce earned-income progress.
Stop on a serving pad (not the orange repair pad) and open the kitchen
with E / A. Nearby interested patrons approach, order, and pay after being served.
The HUD tracks earned money against the goal. Reaching the goal opens
Success immediately; running out of time first opens Game Over.
Both result menus offer New round, Main menu, and Quit. Disabled trucks
can still use the existing tow/repair system while time remains.

Edit earnings_target, food_menu, and
level_duration_seconds on the main.tscn root. The main menu camera
origin, focus, pan_distance, and pan_speed are exported on its root.
Menu buttons, display truck, camera, result panel, and options controls
are saved scene nodes and can be moved or edited in the Godot editor.


LIVE MENU CAMERA AND CONTROLLER SELECTION
The main menu renders the actual Level/FoodTruck through MenuCamera.
New game or A on its focused button starts a two-second camera orbit
from the truck side to FollowCamera. The same truck and level continue
into play; the round timer and driving start after the camera arrives.
The level is a saved instance in main_menu.tscn; edit its camera_origin,
camera_focus, pan_distance, pan_speed, and transition_duration properties.
A activates focused buttons in the main menu, options, shops, and results.
Stationary drift rotation is controlled by stationary_drift_turn_speed
on FoodTruck (2.5 radians/second by default). Brake + steer + throttle
from rest anchors the front axle with no wheel rolling; releasing brake drives
out in the direction the truck is facing. Moving drifts remain available.

Stationary drift pivots around the midpoint of the front wheel bones. Rear swing stops at solid obstacles.

REVERSE DRIFT
With Drifting installed, hold reverse + brake + steering. Keyboard:
S / Down + Space + A/D. It works while reversing and from a standstill.
From rest, the front axle stays planted and the rear swings in the
reverse steering direction. Release brake while holding reverse to
accelerate backward out of the drift. Reverse speed limits still apply.


HUNGRY PATRONS
Up to 12 rigged Kenney patrons spawn at three editable PatronSpawns markers,
with a limit of 4 per point. They wander near their home point, starting
with 65-100% interest and $18-$32 budgets. Each marker exposes its count,
spawn interval, wander radius, starting interest range, and budget range.
The PatronManager node sets the global cap and uses the reusable
scenes/hungry_patron.tscn character, visuals, collider, and status label.
Each patron randomly uses one of four Kenney character skins. Idle and Jump
come from the Kenney pack; Walk, Run, and Dodge are CMU motion capture BVH
clips baked onto the same rig. Wandering uses Walk, approaching the truck
uses Run, and avoiding a truck uses Dodge. Set character_variant to 0-3 to
choose a skin, or leave it at -1 for random selection. The capsule shape
is only an invisible physics collider; the visible model is editable under
VisualVariants in the patron scene. The Kenney asset license is in
assets/kenney/License.txt (CC0).
The motion capture is from the CMU Graphics Lab Motion Capture Database,
BVH conversion by Bruce Hahne. Both permit use without restrictions. See
../Motion_Sources/CMU/Terms.txt and ../Motion_Sources/README.txt in the
OnTheFly project for source clips and Blender retargeting instructions.

Green pads attract at most 4 interested patrons within 18 meters while
the truck is stopped inside their area and its kitchen is fully open.
Each patron orders up to 3 items, depending on interest and budget.
Default menu: Taco $6, Burger $10, Drink $3. Change the level's food_menu
resource array or assets/menu_*.tres to change names, prices, or choices.
Orders take 1.2 seconds per item once the patron reaches the counter.
Completed orders add their actual total to cash and earned-goal progress.
There is no automatic income without paying customers.

After eating, interest drops to 20% of its previous value and patrons
have a 25-second cooldown, then interest slowly recovers. Their remaining
budget still limits future orders. Closing the shop or leaving cancels
unfinished orders without charging anyone. Labels show interest/orders;
the HUD shows population, fed count, menu, pad time, and the latest sale.

A pad's 45-second serving window starts the first time its kitchen opens.
The countdown continues after closing or leaving. At zero it turns red,
stops attracting patrons, and cancels unfinished orders. Other green pads
remain available; new rounds reset them. Edit serving_duration,
attraction_radius, and patron_capacity on each serving Area3D.
The orange repair pad remains a repair and upgrade station.

Patrons predict approaching truck movement and dodge sideways out of its
path, including when reversing. Their walk, dodge, jump, and interest
recovery settings are exposed on the patron scene. The wider kitchen
camera keeps the serving window and nearby patrons visible together.


PAUSE, VIDEO AND AUDIO OPTIONS
Press controller Start / keyboard Escape, or click Pause / Start on the
HUD to open Resume, Options, and Quit game. Pausing freezes the level
timer, truck, and patrons. Start resumes from the pause menu. Options
opened from pause returns to that menu using Back. View / Tab still
opens Options directly. Start no longer restarts a finished round; use
N or select the New round button with A / Enter.

Options is shared by the main menu and pause menu. Video settings:
fullscreen, window size (1280x800, 1440x900, 1600x1000), V-Sync, and
anti-aliasing (off, 2x, 4x). Window size applies in windowed mode.
Master volume controls the Master audio bus; 0% mutes it. Test sound
plays a short tone at the selected level. Settings apply immediately
and carry across scenes for the current session.
The editable UI is scenes/options_panel.tscn; pause buttons are saved
in scenes/hud.tscn. Audio preview is assets/volume_test.tres.


PARKING METER, RED PAD FEE, AND ROUND BALANCE
Each green serving pad has a live meter above it. The meter is a saved
camera-facing Sprite3D driven by an editable SubViewport/ProgressBar.
It starts at 45 seconds. Opening the kitchen on that pad starts its timer;
the meter continues draining after closing or driving away.

While the kitchen is open on a pad, its 3D meter hides and an enlarged
progress bar appears below the timer in the screen HUD. Closing restores
the world meter. When time runs out, the pad and meter turn red.
Serving on a red pad charges $5 immediately and another $5 for every
5 seconds the kitchen remains open there. Closing stops the fee timer;
reopening continues it. Money cannot fall below $0. The red HUD shows
the fee and the total paid that round. Expired pads do not take orders.
Select any green ParkingPad in the level to change serving_duration,
expired_fee, and expired_fee_interval in the Inspector.

Money earned and unspent from sales, after repairs, upgrades, and fees,
carries into the next round when selecting New round / N. The timer,
earnings goal, pads, and patrons reset. New game from the main menu
starts a fresh run with $200 plus starting luck. Balance is kept while
the game is open; quitting the application ends that run.


PERFORMANCE DIAGNOSTICS
F3 or controller View opens a frame-time graph and FPS/p95/worst-frame timings.
The green budget lines are 16.7 ms (60 FPS) and 33.3 ms (30 FPS); red spikes
exceed 33.3 ms. Engine process/physics and script timings measure CPU work,
not GPU time. Draw calls/primitives help identify rendering-heavy views.
Capture frame timings records 20 seconds to user://performance as CSV. Click
Open performance captures to find the files. Start a capture before loading
Hilly City to include its loading-stage names and stalls in the recording.
Disable Nearby traffic simulation or Optimized multiplayer snapshots to
compare performance under the same view. Snapshot comparisons run on the host.
Distant traffic keeps following routes at 5 Hz without collision participation,
suspension, lights or truck avoidance. Cars wake within 90 metres of any player
and sleep beyond 115 metres. Pursuing police and dynamic wrecks stay active.
Car meshes hide beyond 240 metres; bay displays update only while visible and
only when their displayed state changes. Clients use host traffic snapshots.

MULTIPLAYER PROTOTYPE
GITHUB RELEASE UPDATES
The Windows distribution includes Launch_OnTheFly.cmd and Update_Game.ps1
for stable release updates from plachenko/OnTheFly. The in-game Updates button
opens this launcher after exiting the game. See tools/updater/UPDATE_GUIDE.txt.
Prepare a new release with tools/Publish_Update.ps1 -Version 0.4.1 -Build;
use -Publish with GH_TOKEN or GITHUB_TOKEN set to upload the tested package.

Service bays now run synchronized 45-second service waves with 30-second
repair/restock breaks. Opening shop does not restart a bay's timer. Closed
waves do not charge expired-bay fees. The flat map starts with six service bays
and customer spawns on both sides. One used bay retires each wave until the
count reaches lobby size minus one (minimum one). That count holds for one
wave, then loses one bay per wave until one remains. Open shops are exclusive
and ignore opposing truck collisions until they pack up, including breaks.
The Game Inspector's Service Waves section controls service_window_seconds,
service_pause_seconds, and service_final_hold_waves. The default round length
is now 900 seconds to allow the dwindling-bay endgame; earnings goals remain.

Host multiplayer / Join multiplayer enters a lobby with up to four trucks.
Choose a truck color and click preset message buttons; messages rise as speech
bubbles for one second, then fade out. Guests toggle Ready (red/green lights).
Ready guests can drive around the shared lobby playground while waiting.
The host can click Drive lobby. Lobby Menu reopens the menu without changing
readiness; Unready stops the truck and reopens the menu. Driving-mode preset
messages appear above the sender's truck in world space, rising and fading.
Lobby driving does not consume match time, start service waves, or earn money.
Only the host can select Plaza or Hilly City and Start Session after all
guests are ready. Changing the level clears guest readiness. Each truck keeps
separate earnings. The shared Hilly City uses a fixed synchronized map seed.
Offline Single player
and Hilly city still work. For two game instances on one PC, host on UDP 24567
and join 127.0.0.1:24567. On a LAN, join the host computer's IPv4 address.
The Windows prototype is ../OnTheFly_Windows/OnTheFly.exe;
see that folder's README.txt for connection instructions and prototype limits.
Steam transport is not yet included.

NetworkSession owns connection/lifecycle, MultiplayerGame reuses the existing
Game rules with independent player accounts, and MultiplayerPatrons routes
shared customer orders to the owning truck. The host simulates physics and
validates sales and shop actions. Clients interpolate full-state snapshots.
Use --headless -- --multiplayer-smoke-test --mp-host / --mp-client to test the
packaged executable's real host/client paths. Add --mp-four to run four instances.

CITY ROAD RULES
Most city and diagonal roads use double solid yellow lines. Selected city
roads at x=64 and z=-80 widen on one side with a broken yellow passing-side
line. Approaches split into left-only and through lanes; combined straight/left
arrows appear where the left turn enters two lanes. The x=-64 avenue runs
only +Z; the z=112 street runs only -X, with two lanes, white separators and
direction signs. Traffic follows one-way signs and lane arrows, and reserves
passing for permitted streets. Curbs, signals and poles move with wider edges.
Road paint is batched rather than spawning a mesh for every dash.

STREET NAVIGATION HUD
Past, current and next streets remain visible in one row. Crossings grow toward the middle as you approach, take the center when reached, and travel left afterward. Backing up brings the past crossing toward the middle. A U-turn rotates and swaps the past and next cards. Each player follows their own truck.

PARKING CLEARANCE AND TICKS
City bays default to 10 metres long and use short side ticks with 0.2-metre gaps,
without a filled box or continuous outline. Generated service zones match these
footprints and show colored ticks. Placement computes a valid range per lane:
the leading painted bay edge stays at least one full bay length before the
nearest stop line or directional arrow, and the rear stays clear of crosswalks.
An empty valid range produces no bay. Short blocks no longer use three-bay rows.
In Street Parking, parking_stop_line_clearance_lengths increases the reserved
gap; parking_marker_gap controls the small gaps between painted ticks.

PERFORMANCE LAB
Open Performance Lab from the main menu for an empty plane and fly camera.
Hold RMB and use WASD/QE; Shift speeds up, wheel changes speed, Tab hides panels.
Click the plane to choose a spawn origin. Instance cubes, cars, truck models,
props, buildings or a custom res:// scene. Choose batch size, spacing and scale;
compare a single-frame batch against spawning spread across frames. Render-only,
scene physics, static bounds and dynamic bounds isolate rendering/physics costs.
Prop scripts are optional. Clear cancels spawning and restores the empty baseline.
Live frame graph, load/spawn timings and post-spawn frame peaks help find hitches.
Record a 20-second CSV capture with item load/spawn/clear timings for comparison.


PATRON DODGES
Patrons are 20% larger, including colliders and raised status labels. Random
avoidance is 90% grounded running with occasional low hops. Escape directions
vary sideways/diagonally while clearing the truck laterally. 60% favor progress
toward the current queue, crosswalk or wandering destination. Walls are checked
before dodging; a blocked route does not trigger an in-place jump. Crowd steering
does not cancel an active escape. dodge_hop_chance and destination_dodge_chance
are adjustable in patron.gd alongside dodge speeds and forced avoidance styles.
ROAD-FIRST CITY SURFACES
Roads reserve their footprint first, including one-sided widened lanes and
finite diagonal streets. Terrain beneath roads is recessed; asphalt has its
own matching collision surface. Grass and park paths are polygon-clipped out
of road/sidewalk corridors rather than hidden beneath asphalt. Rounded block
sidewalks are also clipped where diagonals cross. Grass islands have matching
collision, preventing patrons from dropping into the recessed road bed.
Lamp posts sit beyond the sidewalk on small gravel pads, batched into one mesh.
Grass tufts avoid the road, sidewalk and lamp gravel footprint.

VISIBLE PEDESTRIAN ISLANDS
Diagonal road connections sit 16 metres farther along the blocks. Affected
blocks use closed rounded pavement islands with raised curb faces and complete
light curb outlines. Grass centers sit within those borders; partial curb
fragments and overlapping diagonal sidewalk strips have been removed.
Three zebra crossings connect the enclosed island sections, with physical curb
ramps at both ends and pedestrian WAIT/WALK timing. Patrons use the actual
crossing endpoints. Asphalt shoulders close the gutter gap at island borders.

CONTINUOUS ROADS AND PARKING MARKINGS (0.4.12)
Grid and diagonal streets share one terrain-aligned asphalt mesh and collider.
Crosswalk paint, parking paint and island ramps follow the same terrain facets.
Road contacts do not cause crash damage; walls and vehicles still do.
Single parking bays have solid white boxes. Adjacent ordinary bays use curbside
row brackets. Service bays have colored diagonal hatching and dashed colored
borders inside their white outline; service availability still controls color.

Saved city loading
------------------
Shipped maps and newly saved maps use spatial scene sections. Terrain, roads,
traffic controls, parking/service data and the truck's initial neighborhood load
first. Remaining buildings, parks and street scenery are added one section per
frame, prioritizing proximity to the truck. Background loading pauses with the
game, and an incomplete streamed map cannot overwrite the city save.
The menu chooses an approach inside the loaded neighborhood and keeps its saved
camera framing. Multiplayer loads the complete map before starting.
Generating a brand-new map still builds the whole city once; subsequent saved
loads use sections. Legacy private saves load fully once and are then upgraded
to sections for future loads; the existing save is replaced only after success.
CityStore.progressive_loading can disable streaming for diagnostics. The city
metadata streaming_city, stream_loaded_sections and stream_total_sections report
background progress. tools/city_stream_test.gd verifies the four shipped variants.

Camera references and animation
------------------------------
The menu holds the exact low rear-quarter screenshot reference without terrain
collision, height clamping, automatic reframing or camera shake. MenuGroundFill
colors rendered scenery below truck height minus 0.6 units a solid road color;
menu_ground_fill_offset and menu_ground_fill_color are editable on the menu.
The fill is menu-only and is removed when starting gameplay. Gameplay uses
an elevated chase camera, smoothly tightening to 12.5 units at slow speed and
easing out to 14.5 units with a wider FOV at full speed.
Camera controls and telemetry appear only in camera mode, including paused
playback. Camera mode hides menu and gameplay UI; exiting restores their prior
visibility. C, F10 or right-stick click toggles camera mode. LB always captures
without UI; F9 captures too unless debug replay is enabled.
WASD flies, Q/E changes height, mouse
or arrow keys looks, Shift moves faster, and F focuses the truck. With a controller,
left stick flies, right stick looks, and LT/RT moves down/up.

Each screenshot saves a matching .camera.json with the rendered camera's world
transform, truck-relative transform, orbit yaw/pitch/range, FOV, viewport size,
map seed and lighting. Lock angle and position to truck preserves this relative
pose as the truck moves. Restore last screenshot angle reapplies the last pose
relative to the current truck, with its lens settings, and enables the lock.

In camera mode, Bake current view as startup menu saves the active camera's
truck-relative position, rotation and lens to user://startup_menu.camera.json.
The menu uses it on subsequent launches. Load baked startup camera restores
that saved view around the current truck; Load camera JSON imports a screenshot
sidecar for preview. Bake an imported view to make it the startup menu default.
Saving affects the menu camera only; gameplay keeps its chase camera.

Double-tap LB and hold the second press to record camera movement. Release it
to stop recording, pause gameplay and open the camera timeline. Resume game
restores the previous pause state. The first press still takes a clean screenshot.
Record, Stop, Play and Resume are also available in the timeline panel.

The camera timeline reuses the exaggeration lab's scrubber, key selection and
key retiming. Drag the playhead to scrub; drag key diamonds to retime. Add key
captures the current pose at the playhead; duration sets the timeline length.
The graph shows orbit pitch and camera roll. Relative to truck preserves truck
framing; disable it to replay the recorded world positions.

Export JSON writes an onthefly.camera_timeline version 1 document. Import JSON
recreates it. keys[].time contains seconds from the start; keys[].pose contains
both camera transforms and lens settings. Samples record at up to 30 Hz with
actual timestamps; playback interpolates positions and lens settings linearly
and rotations with quaternion interpolation. The file includes reference map,
truck and camera context. Send the exported JSON along with reference screenshots
to recreate the framing and timing. A matching map/scene must be available for
matching scenery; the timeline does not replay or rewind gameplay actors.

Google Drive screenshot export (Windows)
---------------------------------------
In Camera Tools, choose a Google Drive synced folder, then use Save to Google
Drive folder after taking a screenshot. The game remembers the folder and copies
the latest PNG and its matching .camera.json without changing their contents.
Google Drive for desktop must be installed, signed in and syncing that folder;
the game reports the local copy, not confirmation of a completed cloud upload.
Use Choose Google Drive folder to change the destination. An unavailable folder
opens the folder picker again. Different existing files are never overwritten.
