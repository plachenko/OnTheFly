# Controller navigation in the Godot editor

The project enables this plugin automatically. Reopen the project if it was
already open when the plugin was added, or enable **MCON Viewport Navigation**
under **Project > Project Settings > Plugins**.

Connect the MCON to Windows and open the **3D** workspace. Select the controller
in the 3D toolbar, then click **Controller fly** (or press Menu).

Click **Controller mapping…** in the main editor toolbar to change button and
axis assignments for viewport navigation, selection, orbit, UI navigation,
panel docking, and the run/stop chord. Each role can use any listed input or be
disabled. Axes also have an invert option. **Restore defaults** resets the form;
**Save mapping** applies and saves it. Cancel leaves your bindings unchanged.
The tables below describe the default bindings. Assignments are shared across
controllers and saved locally per project in `.godot/mcon_controller.cfg`;
they do not change the game's Input Map. Navigation pauses while this dialog
is open. Duplicate bindings activate both roles when used in the same mode.

| Control | Action |
| --- | --- |
| Left stick | Fly forward/backward and strafe |
| Right stick | Look |
| LB / RB | Descend / ascend |
| LT / RT | Slow / fast |
| Y | Frame the selected Node3D nodes |
| A | Raycast select the nearest mesh at the viewport center |
| X | Toggle orbit around the selected 3D object |
| Menu | Toggle controller flight |
| View + Menu together | Run the project / stop the running game |
| View + Y | Open the scene picker |
| View + B | Open the selected instance's source scene |
| View + LB / RB | Switch to the previous / next open scene |
| D-pad up / down (viewport mode) | Select parent / first child |
| D-pad left / right (viewport mode) | Select previous / next sibling |

Directional node selection works while **Controller fly** is active, and pauses
when an editor dock, text field, tree or menu has focus. With no selection it
starts at the scene root. Sibling traversal wraps;
holding a direction repeats. It selects editable scene-tree nodes, including
non-3D nodes, while excluding runtime helpers and locked imported internals.
Multi-select / R3 accumulates nodes during traversal. UI mode keeps its usual
directional menu navigation. Selecting a UI node disables viewport control and
lets Godot open its normal editor; it no longer forces the 3D workspace.
Use mapped **Y** to frame selected 3D nodes.

**Open selected scene** also opens the source of the selected scene instance
(or the containing instance when an internal child is selected). It opens a
new tab or switches to the existing tab. Ordinary nodes without a source scene
show a hint. In multi-selection, it uses the node last reached by the selector,
or the last selected node. The shortcut respects your View/B mappings.

The **Scenes…** toolbar button opens a searchable scene list with open tabs
first, followed by the project's `.tscn` and `.scn` files. Use the D-pad or left
stick to browse, **A** to open or switch, **B** to cancel, and **X** to show only
open scenes. A keyboard can type in the search field; mouse users can double-click
a result. Toolbar **‹ / ›** buttons also switch open tabs. Camera navigation
stops when switching scenes. Scene shortcuts use the corresponding remapped
View, Y, LB/RB and picker controls from **Controller mapping…**.

The toolbar also has a **Run game / Stop game** button. View + Menu starts the
project's main scene (the game menu), just like F5. Press the chord again to
stop. Release both buttons between presses. Navigation is suspended during play.

Speed and deadzone are adjustable in the toolbar. Click a split viewport to
choose which view to fly. Flight works only while the editor's 3D workspace
has focus and no game is running. No scene nodes or scene cameras are changed.

**Ray select** and **Orbit selected** also have toolbar buttons.

While controller flight is active, a center crosshair shows the selection ray.
It turns green over a selectable mesh, which gets a green bounding outline and
an object-name preview. Press your mapped ray-select button to select it. The
preview appears only in the active split viewport and does not modify materials,
scene nodes, or the current selection. It disappears when flight is disabled.

Enable **Multi select** in the 3D toolbar, or hold the mapped **R3** while pressing
ray select, to add objects without clearing the selection. Select an already
selected object in this mode to remove it. The hover label shows **Add / Remove**
before you press the button. Normal selection replaces the current selection.

**Above ground** is enabled by default. A vertical mesh raycast keeps controller
flight, focus, and orbit at least 0.8 m above surfaces, including meshes without
physics colliders. It also recovers a camera already below the ground. Selection
preserves the controller's camera pose. Disable the toggle for underground work.

Selection tests
mesh triangles, so collision shapes are not required. Imported scene internals
select their editable instance root. In orbit mode the right stick rotates around
the object, left/right circles it, and forward/back changes distance. The camera
keeps facing the object and follows its position. Toggle orbit off to resume flight.

While controller flight is active, its camera pose overrides normal mouse
navigation. Disable flight before using normal viewport editing; Godot returns
to its native editor camera position. Controller button labels use Godot's
standard gamepad layout. The actual connected MCON hardware must be tested
locally; software tests cover the navigation math and editor plugin loading.

## Editor controls and panel layout

## Manipulation and context menus

Select one or more 3D objects, then press **View + X** or click **Manipulate**.
Use **D-pad left / up / right** to choose move / rotate / scale. In move mode,
the left stick moves across the ground relative to the camera and LB/RB changes
height. In rotate mode, the left stick controls yaw/pitch and right-stick X
controls roll. In scale mode, left-stick up/down scales uniformly. LT/RT slows
or speeds translation. **A** confirms one undoable action; **B** cancels and
restores the original transforms. D-pad down or the toggle also confirms.
Nested selections transform their selected parent once. No files are auto-saved.

**View + A** or **Context menu** opens the native node menu through the Scene
dock for the selected viewport object. When an editor control is focused, the
shortcut opens that control's native context menu instead. **X** remains the
context-menu shortcut in Controller UI mode. Shortcuts use your mapped inputs.

Press **L3** (left stick click), or click **Controller UI** in the main toolbar,
to navigate editor controls. Flight mode is disabled while navigating the UI.

| Control | Action |
| --- | --- |
| D-pad / left stick | Navigate menus, trees, and properties |
| A / B | Select / back |
| LB / RB | Previous / next focusable control |
| X | Keyboard context menu (Shift+F10) |
| Y | Inspect the selected scene node |
| View + left / right | Cycle editor panels (including hidden panels) |
| Hold RT + up | Float the focused dock |
| Hold RT + down | Return the floating dock to its saved slot |
| Hold RT + left / right | Move the focused dock to the left / right side |

Dock commands target the panel containing the focused control. Godot's native
dock menu performs the move, keeping layout ownership inside the editor. Floating
uses Godot's multi-window support; if disabled, the toolbar shows the native
reason instead. Native keyboard navigation determines which properties and
dialogs are reachable. These commands support EditorDock panels, not arbitrary
modal dialogs or the central 3D workspace.

## Right-click controller action bindings

Right-click an editor button, Scene/FileSystem tree item, or list item. If Godot
opens its normal context menu, choose **Controller binding** from that menu;
otherwise the binding menu opens directly. You can also right-click a highlighted
command inside an open menu.

Choose **Listen for controller press…** or **Listen for controller sequence…**.
Release any held buttons, press the desired physical controller button(s), then
click **Save binding**. Sequences contain up to eight ordered presses, including
repeated buttons; allow no more than one second between presses when invoking.
Esc or Cancel discards the recording. Use the same right-click menu to remove a
binding. Saving replaces that item's old binding and any identical sequence.

These bindings use the controller selected in the viewport toolbar and are saved
locally for this project in `.godot/mcon_ui_actions.cfg`. Assigned buttons take
priority over the plugin's default navigation shortcuts. A single-button binding
that is also the start of a longer sequence waits one second to disambiguate.
Bindings pause while the editor is unfocused, a game is running, or the regular
controller mapping dialog is open. Buttons invoke their action; tree/list items
select and activate the item. Disabled, missing, or ambiguous rebuilt controls are
not invoked. Rebind an item if its name or editor layout has changed substantially.

Verification: launch Godot with `--headless --editor --path <project> --
--controller-actions-check` to exercise context menus, recording, persistence,
sequence matching, and action invocation without a physical controller.
