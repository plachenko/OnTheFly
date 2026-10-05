# Directional patron sprite prototype

Patrons use animated billboard quads by default. Start a normal game to try them,
or open `res://scenes/patron_billboard_test.tscn` and press F6 for the comparison
gallery. Left/Right (or A/D) orbits the camera, 1–4 selects Idle/Walk/Run/Dodge,
and B switches between sprites and the original animated models.

For a whole-game comparison launch with `-- --patron-3d`. This loads only the
chosen original character, rather than instantiating four rigs per patron.

Four existing Kenney characters were baked into eight azimuth views at a fixed
camera elevation. Each view has twelve frames for each of four animations,
using the source animation durations. `assets/patron_sprites/variant_*_angle_*`
contains one sheet per viewing angle. Packed runtime atlases put the eight
directional sheets in one texture per character so a shader can select angles
for each camera without changing world transforms. Every patron shares those
textures; changing clothing color or height creates no new texture.

The bake also creates a clothing mask. This prototype selects the torso/leg
region by model height and excludes skin-colored texels; it is approximate and
can be replaced with artist-authored masks. Hair, face and shoes generally keep
their original colors. Six clothing colors and a height of 85–115% are chosen
once at spawn. Colliders and labels follow height. Food preference and existing
AI, avoidance, crossing, ordering, and payment logic are unchanged.

Multiplayer snapshots share variant, color, height, heading, animation state,
and elapsed animation time. Billboard orientation and the viewing-angle lookup
are calculated from the render camera in the shader, including separate views
on the same client. Only actual patron heading is replicated.

Regenerate the sheets with a graphical Godot process:

    godot --path Food_Truck_Drive --script res://tools/bake_patron_sprites.gd

Run `tools/patron_billboard_test.gd` to check frame progression, shared textures,
stable transforms under camera changes, and removal of rigs. A graphical run
saves front/back previews in `.godot/`. Patron avoidance and multiplayer smoke
tests cover the existing gameplay and appearance replication.

This is a visual/animation optimization, not an AI optimization. Eight-angle
changes and the fixed baked elevation can be visible close up. Real-time
character shadows and lighting are not retained in this prototype. Desktop
VRAM compression is enabled on the eight runtime textures; measured compressed
image storage totals 36 MiB for all four characters (versus 144 MiB uncompressed).
Smaller masks or fewer frames are possible follow-ups. PNG file sizes differ
from GPU texture memory.
The gallery supports comparison, but no frame-rate improvement is claimed yet.
