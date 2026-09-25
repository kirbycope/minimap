# Minimap for Godot 4.8+

A round HUD minimap, the Zelda and Mario Kart way: a live top-down view of the game's world drawn without light or
shadow, or of a map scene of its own, with a north marker on the ring and the player an arrow at the centre.

**[Read the full documentation](addons/minimap/README.md)**, which ships with the addon so it is there however
you installed it.

## This repository

It uses the layout the [Godot Asset Library](https://docs.godotengine.org/en/stable/community/asset_library/submitting_to_assetlib.html) expects, so it is both the addon and a
project you can open and edit it in:

```
project.godot       the demo project, which is this repository
addons/minimap/     the addon itself, demo scene included
```

The tests need GUT, which is not committed: `python tools/pull_addons.py` fetches it after cloning, pinned in
`tools/addons.json`, and CI runs the same pull before the tests and the web export.

Clone it, run the pull, open `project.godot` in Godot, and press play. M turns the map with the walker or keeps
north up; L swaps between the live world and a stripped copy of the village.
