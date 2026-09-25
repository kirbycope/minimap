extends GutTest
## The minimap: it loads a map scene into a world of its own stripped of shadows and gameplay, or draws the game's
## own world without one; it follows its target from straight above; north is up unless it turns with the target;
## the arrow points the way the target faces; and the picture is as large as the minimap.

const MINIMAP_SCENE: PackedScene = preload("res://addons/minimap/scenes/minimap.tscn")
const MAP_PATH: String = "res://addons/minimap/scenes/demo/demo_map.tscn"

var minimap: Minimap
var walker: Node3D


func before_each() -> void:
	walker = Node3D.new()
	add_child_autofree(walker)
	minimap = MINIMAP_SCENE.instantiate()
	minimap.target = walker
	add_child_autofree(minimap)


## A level the way a game has one: lit, shadowed, with a camera, a sky, sound, particles, a HUD, a spawner, a player,
## a ball, a script running it and a terrain drawn by script.
func _level() -> Node3D:
	var level := Node3D.new()
	var mesh := MeshInstance3D.new()
	mesh.name = "House"
	mesh.mesh = BoxMesh.new()
	level.add_child(mesh)
	for extra: Node in [DirectionalLight3D.new(), OmniLight3D.new(), Camera3D.new(), WorldEnvironment.new(), AudioStreamPlayer3D.new(), GPUParticles3D.new(), CanvasLayer.new(), MultiplayerSpawner.new()]:
		level.add_child(extra)
	var hud := Control.new()
	hud.add_child(Label.new())
	level.add_child(hud)
	var player := Node3D.new()
	player.add_to_group(&"Player")
	player.add_child(MeshInstance3D.new())
	level.add_child(player)
	var ball := RigidBody3D.new()
	ball.name = "Ball"
	level.add_child(ball)
	var gameplay := Node.new()
	gameplay.name = "Spawner"
	gameplay.set_script(_script("extends Node\n"))
	level.add_child(gameplay)
	var weather := Node.new()
	weather.name = "Weather"
	weather.set_script(_script("@tool\nextends Node\n"))
	level.add_child(weather)
	var terrain := Node3D.new()
	terrain.name = "Terrain"
	terrain.set_script(_script("class_name MinimapTestTerrain\nextends Node3D\n"))
	level.add_child(terrain)
	return level


func _script(source: String) -> GDScript:
	var script := GDScript.new()
	script.source_code = source
	script.reload()
	return script


func test_stripping_leaves_a_shadowless_map_with_no_gameplay() -> void:
	var level: Node3D = autofree(_level())
	assert_eq(Minimap.strip(level, PackedStringArray(["Player"]), PackedStringArray(["MinimapTestTerrain"])), 10, "The lights, the camera, the sky, the sound, the particles, the HUDs, the spawner and the player go")
	assert_eq(level.get_child_count(), 5, "leaving the house, the ball, the spawner, the weather and the terrain")
	assert_eq((level.get_node("House") as MeshInstance3D).cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "The house casts no shadow")
	assert_true((level.get_node("Ball") as RigidBody3D).freeze, "The ball is frozen where it lies")
	assert_null(level.get_node("Spawner").get_script(), "A gameplay script is dropped, so it never runs a second time")
	assert_null(level.get_node("Weather").get_script(), "a tool script too, which would run its weather again")
	assert_not_null(level.get_node("Terrain").get_script(), "but a class named to keep stays: a terrain that draws itself")


func test_the_game_never_finds_the_maps_copies() -> void:
	var level: Node3D = _level()
	var house: Node = level.get_node("House")
	house.owner = level
	house.add_to_group(&"Checkpoint", true)
	Minimap.strip(level)
	assert_false(house.is_in_group(&"Checkpoint"), "The copy leaves its groups, so a group lookup finds only the real one")
	assert_eq(house.owner, level, "and keeps its owner, which unique-name paths resolve through")
	level.free()


func test_a_map_scene_loads_into_a_world_of_its_own_and_none_draws_the_game_world() -> void:
	assert_eq(minimap.viewport.find_world_3d(), get_viewport().find_world_3d(), "No map scene: the game's own world")
	assert_false(minimap.sun.visible, "lit by its own light, not the minimap's")
	minimap.map_path = MAP_PATH
	assert_ne(minimap.viewport.find_world_3d(), get_viewport().find_world_3d(), "A map scene is drawn in a world of its own")
	assert_true(minimap.sun.visible, "under the minimap's flat light")
	var level: Node = minimap.get_level()
	assert_not_null(level, "The copy is loaded")
	assert_false(is_ancestor_of(level), "outside the game's scene, where no search of the game finds it")
	await wait_process_frames(2)
	assert_eq(level.get_viewport().find_world_3d(), minimap.viewport.find_world_3d(), "in the world the minimap draws")
	assert_eq(level.find_children("*", "DirectionalLight3D", true, false).size(), 0, "without the level's own sun")
	for mesh: Node in level.find_children("*", "GeometryInstance3D", true, false):
		assert_eq((mesh as GeometryInstance3D).cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "%s casts no shadow" % mesh.name)
	minimap.map_path = ""
	assert_eq(minimap.viewport.find_world_3d(), get_viewport().find_world_3d(), "and cleared, it is back to the game's world")


func test_the_map_scene_goes_where_the_game_puts_it() -> void:
	minimap.map_transform = Transform3D(Basis(), Vector3(-176.0, -23.7, -280.0))
	minimap.map_path = MAP_PATH
	var level: Node3D = minimap.get_level() as Node3D
	assert_eq(level.position, Vector3(-176.0, -23.7, -280.0))


func test_it_looks_straight_down_over_the_target_north_up() -> void:
	walker.global_position = Vector3(5.0, 2.0, -7.0)
	minimap.view_size = 60.0
	await wait_process_frames(2)
	assert_almost_eq(minimap.camera.global_position, Vector3(5.0, 2.0 + minimap.height, -7.0), Vector3.ONE * 0.001, "Above the target")
	assert_almost_eq(-minimap.camera.global_basis.z, Vector3.DOWN, Vector3.ONE * 0.001, "looking straight down")
	assert_almost_eq(minimap.camera.global_basis.y, Vector3.FORWARD, Vector3.ONE * 0.001, "with north at the top")
	assert_eq(minimap.camera.projection, Camera3D.PROJECTION_ORTHOGONAL, "flat, as a map is")
	assert_eq(minimap.camera.size, 60.0, "view_size metres across")


func test_the_arrow_points_the_way_the_target_faces() -> void:
	walker.global_basis = Basis(Vector3.UP, PI * 0.5) # facing west
	await wait_process_frames(2)
	assert_almost_eq(minimap.arrow.rotation, -PI * 0.5, 0.001, "North up, facing west points the arrow left")
	minimap.facing_plus_z = true
	await wait_process_frames(2)
	assert_almost_eq(absf(minimap.arrow.rotation), PI * 0.5, 0.001, "and a model that looks along +Z faces east")


func test_turning_with_the_target_keeps_the_arrow_up_and_moves_north() -> void:
	walker.global_basis = Basis(Vector3.UP, PI * 0.5) # facing west
	minimap.rotate_with_target = true
	await wait_process_frames(2)
	assert_eq(minimap.arrow.rotation, 0.0, "The target always faces up")
	assert_almost_eq(minimap.camera.global_basis.y, Vector3.LEFT, Vector3.ONE * 0.001, "with west at the top")
	var middle: Vector2 = minimap.size * 0.5
	var north_at: Vector2 = minimap.north.position + minimap.north.size * 0.5
	assert_gt(north_at.x, middle.x + 10.0, "Facing west, north is on the right of the ring")


func test_the_picture_is_as_large_as_the_minimap() -> void:
	minimap.size = Vector2(240.0, 240.0)
	await wait_process_frames(1)
	assert_eq(minimap.viewport.size, Vector2i(240, 240))


func test_the_live_world_is_drawn_unshaded_so_the_map_has_no_shadows() -> void:
	assert_eq(minimap.viewport.find_world_3d(), get_viewport().find_world_3d(), "By default the map is the game's own world, live")
	assert_eq(minimap.viewport.debug_draw, Viewport.DEBUG_DRAW_UNSHADED, "drawn without light or shadow")
	assert_eq(get_viewport().debug_draw, Viewport.DEBUG_DRAW_DISABLED, "while the game's own view keeps its lighting")
	minimap.unshaded = false
	assert_eq(minimap.viewport.debug_draw, Viewport.DEBUG_DRAW_DISABLED, "and it can be drawn lit")
