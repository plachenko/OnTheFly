# Saved cities

**Play Saved City** restores the last locally generated city, or the shipped default on a fresh installation. **Generate New City** builds a new random city, saves it, and starts playing. This saves the actual geometry, grass, collision shapes, service bays, and patron spawn positions; it does not merely save a seed. Traffic and gameplay restart normally.

Choose Small or Large in the menu before generating. The multiplayer host chooses the same size in the lobby. Each size has its own local save: `user://cities/current_city_small.res` and `user://cities/current_city.res` (Windows: `%APPDATA%/Godot/app_userdata/OnTheFly/cities/`). The previous file is replaced only after the new snapshot has been saved successfully. Generation settings and a format version validate snapshots; incompatible saves fall back to generation. Increment `CityStore.FORMAT_VERSION` when changing the snapshot format or baked geometry behavior, and update `saved_city.gd`'s default version too.

Shipped cities: `res://generated_city/small_city.res` and `res://generated_city/default_city.res`. Multiplayer uses the shared city for the host's selected size. The default seed is 12054. Multiplayer adopts the shipped snapshot's seed, including a custom city selected for an update.

To rebuild the distributed city, run Godot with `--headless --path Food_Truck_Drive --script res://tools/bake_city.gd`. `Publish_Update.ps1 -Build` does this automatically before exporting, so the generated resource travels inside the Windows game package through the existing updater. Publishing still requires the existing explicit `-Publish` option. This distributes maps through game updates; it does not transfer private maps between multiplayer hosts.

To distribute an existing saved map instead, pass `-CityFile "C:\path\to\current_city.res"` with `-Build` to `Publish_Update.ps1`. The build validates and includes that snapshot. You can also call the bake tool with `-- --city-file "C:/path/to/current_city.res"`. Incompatible files fail the build instead of publishing a broken city.

The cache skips procedural generation and smoothing, and shortens the camera intro to 0.8 seconds. Asset loading, scene instantiation, and initial shader compilation can still take time. Replay capture and runtime frame-rate policy are unchanged.
