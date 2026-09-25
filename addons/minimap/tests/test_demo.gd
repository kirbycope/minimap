extends GutTest
## The demo ships inside the addon, so installing the addon brings it. These check it loads, reaches nothing outside
## the addon, and is wired.

const DEMO_PATH: String = "res://addons/minimap/scenes/demo/demo.tscn"


func test_the_demo_is_the_main_scene() -> void:
	assert_eq(ProjectSettings.get_setting("application/run/main_scene") as String, DEMO_PATH)


func test_the_demo_only_references_this_addon() -> void:
	for path: String in [DEMO_PATH, "res://addons/minimap/scenes/demo/demo_map.tscn", "res://addons/minimap/scenes/minimap.tscn"]:
		var source: String = FileAccess.get_file_as_string(path)
		var regex: RegEx = RegEx.create_from_string("path=\"(res://[^\"]+)\"")
		for found: RegExMatch in regex.search_all(source):
			assert_true(found.get_string(1).begins_with("res://addons/minimap/"), "%s reaches %s, outside the addon" % [path, found.get_string(1)])


func test_the_demo_is_wired() -> void:
	var demo: Node3D = (load(DEMO_PATH) as PackedScene).instantiate() as Node3D
	add_child_autofree(demo)
	var minimap: Minimap = demo.get("minimap")
	assert_not_null(minimap, "the minimap is assigned")
	assert_eq(minimap.target, demo.get("walker"), "and follows the walker")
	assert_false(minimap.map_path.is_empty(), "drawing the stripped copy of the village")
	assert_not_null(demo.get("help"))
