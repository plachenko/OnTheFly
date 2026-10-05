# Camera reference work

When the user supplies a reference screenshot and its `.camera.json`, preserve
the recorded camera angle, truck-relative position, FOV, lens offsets and viewport
aspect ratio while evaluating visual changes. Use `game.gd`'s
`restore_camera_view(state, true)` and `set_camera_reference_lock(true)` to restore
truck-relative framing; use `restore_camera_view(state)` for an explicitly fixed
world view. Do not change the reference framing unless the user requests it.
Match the recorded scene, map seed and lighting when comparing scenery.

For a supplied `onthefly.camera_timeline` JSON, preserve key timestamps and
coordinate space. `camera_timeline.gd` imports and samples this format, including
quaternion interpolation for rotation. This records camera motion, not gameplay
actor motion. Compare screenshots at the same timeline times after edits.

Relevant checks are `tools/camera_timeline_test.gd` for restoration and timing,
`tools/screenshot_button_test.gd` for UI visibility, and
`tools/camera_capture_render_test.gd` for actual rendered capture and metadata.
