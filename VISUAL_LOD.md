# Distant cars and buildings

This rendering experiment is enabled by default. F3 opens the debug menu; **Distant car sprites / building boxes** switches it off for a comparison. The existing **Nearby traffic simulation** toggle controls CPU simulation independently. Performance captures include frame timing, draw calls, submitted primitives and active/distant traffic counts.

## Cars

All eight rigged Kenney traffic models have baked color and normal atlases: sixteen headings at four camera elevations (0, 20, 40 and 60 degrees). These are still images, with no distant wheel or skeleton animation. They were baked from the imported models in Godot, so no Blender installation is required. Rebuild with `--script res://tools/bake_car_impostors.gd`, then import the resulting textures. Texture imports enable mipmaps and VRAM compression.

`traffic_visual_lod.gd` attaches the visual representation independently of route state. Each camera chooses its own view of the atlas in the shader. Godot visibility ranges draw the full meshes within approximately 64 metres and the billboard farther away, with a four metre hysteresis margin and a 260 metre outer limit. Normal atlases let distant cars respond to the current scene lights rather than retaining daylight baked into the picture. GPU frustum culling handles objects behind the camera. Visual orientation and detail selection are not replicated over the network.

The existing route controller continues at a coarse 0.2 second tick when far from every player. The billboard predicts motion between these ticks to avoid five-frame-per-second jumps. Traffic near any player restores collisions and full route/hybrid interaction updates regardless of which way that player is facing. Default wake radius is 64 metres, with an 80 metre sleep threshold. Collisions, impacts, rollover and wrecks use the existing 3D physics path. Impact reactions force full visuals immediately.

This pass retains the frozen physics wrapper and cached model resources to preserve collision and network identities. It does not stream meshes out of memory or replace the traffic actor itself with a wholly empty Node3D. That further CPU/memory optimization would require migrating snapshot and interaction code to stable lightweight agents; the rendering and simulation switches here can measure whether that work is worthwhile.

## Buildings

`building_visual_lod.gd` replaces detailed city building models and the nearby skyline with one box per building past 96 metres, with a five metre hysteresis margin. Bounds include the model's position, rotation and scale. Building collisions, foundations and camera occluders remain intact. Box silhouettes are deliberately simple; roof details and windows disappear at distance. Existing saved cities receive this runtime detail setup when loaded, so regeneration is unnecessary. Newly generated snapshots are saved before the runtime helpers are attached.

Boxes avoid the transparency, viewing-angle and memory costs of large building image atlases. A later facade texture or block-wide merged mesh could improve their appearance or reduce draw calls further. Current models and proxy meshes remain resident in memory.

## Measurements and verification

`tools/visual_lod_test.gd` renders the same car from two simultaneous cameras, checks continued distant motion and nearby collisions, forces a wreck back to 3D, and verifies building colliders survive. It also compares both rendering modes from a fixed camera in the shipped large city. Screenshots and measurements go to `res://.godot/`.

The initial fixed-view check on the Compatibility renderer measured 2,152 visible primitives for the nearby test car and 2 for its distant billboard. The city view fell from approximately 1.14 million to 0.91 million submitted primitives and from 2,975 to 2,722 draw calls (about 20% and 9%). These are rendering workload measurements, not a guaranteed frame-rate improvement. Grass, roads, shadows and other objects remain substantial workloads. Compare representative driving routes on target devices using the debug toggle and performance capture.

The rendering checks, multiplayer proximity/snapshot checks, saved-city round trip and packaged-resource checks passed. The older `hybrid_traffic_test.gd` rollover assertion at 80 ticks fails for the sedan with both rendering and simulation optimizations disabled as well; it remains an existing failing check. The new test verifies that impacts restore full 3D visuals and collision behavior without changing the rollover controller.

The shader has four elevation samples, so very high free-camera views approximate the nearest baked elevation. Lighting, steep-road tilt, silhouettes and angle quantization can still produce visible transitions. Distant buildings currently sacrifice detail for speed. Unsupported custom car models retain their full meshes until an atlas is baked for them.
