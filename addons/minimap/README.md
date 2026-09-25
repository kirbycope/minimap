# Minimap

A round HUD minimap, the Zelda and Mario Kart way. A `Minimap` (`scenes/minimap.tscn`, a `Control`) renders a
live, top-down, orthographic view in a `SubViewport` and shows it through a round lens with a ring
(`assets/shaders/minimap.gdshader`), a dark disc behind it, an N on the ring where north is, and the target an
arrow at the centre pointing the way it faces. It came from the Breath of the Wild project's HUD.

## Drawing a map scene, not the game

Mario Kart has always drawn its minimap from a model of the course of its own, a simplified copy shown from above
in a corner of the screen, and Mario Kart World renders it live in 3D from above with no karts in it. Set
`map_scene` and the Minimap does the same: the scene is loaded into the SubViewport's own `World3D` and stripped to
what a map needs by `Minimap.strip()`:

- every `GeometryInstance3D` stops casting shadows;
- lights, cameras, `WorldEnvironment`s, sound players and particles are removed;
- every script that is not a `@tool` is dropped, so none of the level's gameplay (spawners, saves, AI) runs a
  second time. A tool script stays, since tool scripts are what draw things like terrain (HTerrain) and are
  written to run anywhere.

The minimap's own `Sun` lights it instead, from high up and without shadows, and its `MapLook` environment gives it a
flat background and bright ambient light, so the map reads flat and clean. Give it the level's art scene (terrain,
buildings, roads) rather than the whole game scene, and `map_transform` to place it where the game places that level,
so the two line up.

Leave `map_scene` empty and the view is of the game's own world, as the Breath of the Wild HUD drew it, shadows,
players and all; `cull_mask` leaves out layers that should not show.

## Setting it up

Instance `scenes/minimap.tscn` in the HUD, anchored to a corner (the demo puts it bottom right, 180 px), and set:

| Export | What it does |
|---|---|
| `target` | Who is at the centre: the Player. |
| `facing` / `facing_plus_z` | What the arrow turns with, when that is not the target: a Player whose body does not turn but whose model does. A Mixamo model looks along +Z, so tick `facing_plus_z`. |
| `map_scene` / `map_transform` | The level's art scene and where the game puts it. Empty draws the game's world. |
| `view_size` | Metres of ground across the map (40). |
| `height` | How far above the target the camera looks down from (100 m); it sees everything below it. |
| `rotate_with_target` | Turn the map so the target always faces up, and walk the N round the ring, rather than keep north up. |
| `cull_mask` | Layers the camera draws. |

The SubViewport is kept square and as large as the minimap, however it is sized.

## Demo

`scenes/demo/demo.tscn`: a walker loops round a village (`demo_map.tscn`, which has a shadow-casting sun and a sky)
with the minimap in the corner drawing a stripped copy of the same village. M turns the map with the walker or keeps
north up; L swaps between the stripped map scene and the game's own world, shadows and all.

## Tests

`tests/` (GUT): stripping (lights, camera, sky, sound, particles out, shadows off, gameplay scripts dropped, tool
scripts kept); a map scene in a world of its own and none in the game's; the map placed by `map_transform`; the camera
straight above the target, north up, orthographic, `view_size` across; the arrow turning with the target, including a
+Z model; the map turning with the target and north moving round the ring; the picture sized to the minimap; the demo
wired and reaching nothing outside the addon; and the editor plugin compiling. Run them from the repository root:

```
godot --headless --audio-driver Dummy --path . -s addons/gut/gut_cmdln.gd -gconfig=res://.gutconfig.json -gexit
```

Credits are in `CREDITS.md`.
