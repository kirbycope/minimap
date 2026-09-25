@tool
@icon("res://addons/minimap/assets/icons/minimap_icon.svg")
class_name Minimap
extends Control
## A round HUD minimap, the Zelda and Mario Kart way: a live top-down orthographic view rendered in a
## [SubViewport], masked to a circle with a ring, north marked on the ring, and the [member target] an arrow at the
## centre that turns the way it faces.
##
## Mario Kart draws its minimap from a model of the course of its own, not from the world the race is in, and Mario
## Kart World renders that live from above with no karts in it. Set [member map_path] and this does the same: the
## scene is loaded into a [World3D] of its own, which the SubViewport draws, and stripped to what a map needs ([method strip]): every shadow
## off; its lights, cameras, environments, sounds, particles, HUDs and networking taken out, with anything in
## [member hide_groups] (the players, the NPCs); rigid bodies frozen; and every script dropped but those of the
## classes in [member keep_scripts] (a terrain that draws itself by script), so none of the level's gameplay runs a
## second time. The minimap's own flat, shadowless [member sun] lights it instead. It may be the very scene the game is
## playing, which is why it is a path: a scene cannot hold a reference to itself. [member map_transform] places it
## where the game places it. Left empty, the view is of the game's own world, as the Breath of the Wild HUD this came
## from drew it, shadows, players and all. The map is not loaded in the editor. The copy lives outside the game's scene,
## under the root window ([method get_level]), so nothing that searches the game ever finds it.
##
## North is up unless [member rotate_with_target], which turns the map so the target always faces up and walks the
## north marker round the ring instead.

## Who is at the centre: the Player, usually.
@export var target: Node3D
## What the arrow turns with; the target when empty. A Player's own body does not turn, its model does.
@export var facing: Node3D
## The facing node looks along +Z rather than Godot's -Z, as a Mixamo model does.
@export var facing_plus_z: bool = false
## The scene to draw the map from, loaded into a world of its own and stripped; empty draws the game's own world.
@export_file("*.tscn", "*.scn") var map_path: String = "":
	set(value):
		map_path = value
		if is_node_ready():
			load_map()
## Nodes in these groups are left out of the map: whatever moves about in the game (players, NPCs) would only stand
## frozen where the scene put it.
@export var hide_groups: PackedStringArray = PackedStringArray()
## The global classes whose scripts stay on in the map, because they are what draw it (a script terrain: "HTerrain").
## Every other script is dropped.
@export var keep_scripts: PackedStringArray = PackedStringArray()
## Where [member map_path] goes in its world: where the game places that level, so the two line up.
@export var map_transform: Transform3D = Transform3D.IDENTITY:
	set(value):
		map_transform = value
		if is_node_ready() and _level != null and is_instance_valid(_level):
			_level.transform = value
## Metres of ground across the map.
@export_range(5.0, 2000.0, 1.0, "suffix:m") var view_size: float = 40.0:
	set(value):
		view_size = value
		if is_node_ready():
			camera.size = value
## How far above the target the camera looks down from; it sees everything below it to the ground.
@export_range(5.0, 2000.0, 1.0, "suffix:m") var height: float = 100.0
## Turn the map so the target always faces up, rather than keeping north up.
@export var rotate_with_target: bool = false
## Layers the camera draws. In the game's own world, leave out the layers of anything the map should not show.
@export_flags_3d_render var cull_mask: int = 0xFFFFF:
	set(value):
		cull_mask = value
		if is_node_ready():
			camera.cull_mask = value

@onready var viewport: SubViewport = $SubViewport
@onready var camera: Camera3D = $SubViewport/Camera
@onready var map_root: Node3D = $SubViewport/Map
## The loaded map's own light, flat and shadowless; off while the view is of the game's world, which has its own.
@onready var sun: DirectionalLight3D = $SubViewport/Map/Sun
@onready var display: TextureRect = $Display
@onready var north: Control = $North
@onready var arrow: Control = $Arrow

## The loaded map scene's root, or null.
var _level: Node = null
## The world a map scene is drawn in. Given to the SubViewport rather than switching its own_world_3d, which the
## engine does not take back cleanly on a live viewport.
var _map_world: World3D = World3D.new()
## Where the map's copy of the level lives: a SubViewport of its own under the root window, sharing [member _map_world]
## but drawing nothing itself, so the copy is outside the game's scene and no search of it (find_child by name, even
## unowned) ever lands on the map's copy of a tree instead of the real one. Its [member _eye] follows the minimap's
## camera, for anything in the level that picks its detail from the camera of its own viewport (a terrain).
var _holder: SubViewport = null
var _eye: Camera3D = null


func _exit_tree() -> void:
	if _holder != null and is_instance_valid(_holder):
		if _holder.is_inside_tree():
			_holder.queue_free()
		else:
			_holder.free() # never attached: nothing else will
	_holder = null
	_level = null


## The loaded copy of the map scene, or null.
func get_level() -> Node:
	return _level if _level != null and is_instance_valid(_level) else null


func _ready() -> void:
	display.texture = viewport.get_texture()
	camera.size = view_size
	camera.cull_mask = cull_mask
	resized.connect(_fit_viewport)
	_fit_viewport()
	load_map()


## (Re)loads [member map_path] into the minimap's own world, stripped; without one, the view is of the game's world.
func load_map() -> void:
	if _level != null and is_instance_valid(_level):
		_level.queue_free()
	_level = null
	var scene: PackedScene = null
	if not map_path.is_empty() and not Engine.is_editor_hint():
		scene = load(map_path) as PackedScene
	viewport.world_3d = _map_world if scene != null else null
	sun.visible = scene != null
	if scene == null:
		return
	_level = scene.instantiate()
	strip(_level, hide_groups, keep_scripts)
	if _level is Node3D:
		(_level as Node3D).transform = map_transform
	_hold().add_child(_level)


func _hold() -> SubViewport:
	if _holder == null or not is_instance_valid(_holder):
		_holder = SubViewport.new()
		_holder.name = "MinimapMap"
		_holder.world_3d = _map_world
		_holder.size = Vector2i(2, 2)
		_holder.render_target_update_mode = SubViewport.UPDATE_DISABLED
		_eye = Camera3D.new()
		_eye.projection = Camera3D.PROJECTION_ORTHOGONAL
		_eye.current = true
		_holder.add_child(_eye)
		# The root is busy while the scene that holds this minimap is still entering it. Deferred on this node, so the
		# call is dropped if the minimap is gone first, and _exit_tree frees the holder instead.
		_attach_holder.call_deferred()
	return _holder


func _attach_holder() -> void:
	if is_inside_tree() and _holder != null and is_instance_valid(_holder) and not _holder.is_inside_tree():
		get_tree().root.add_child(_holder)


## Strips [param root] to what a map needs, before it enters a tree. Every shadow goes off. Removed: lights,
## cameras, environments, sounds, particles, anything 2D or on a canvas layer (a HUD), multiplayer spawners and
## synchronizers, other viewports, and every node in [param hidden_groups]. Rigid bodies are frozen, and every node
## leaves its groups, so no group lookup in the game finds the map's copy of something. Every script is
## dropped, so the level's gameplay (spawners, saves, AI, weather) never runs in the map, except those whose global
## class, or a class it extends, is in [param keep_classes]. Returns how many nodes it removed.
static func strip(root: Node, hidden_groups: PackedStringArray = PackedStringArray(), keep_classes: PackedStringArray = PackedStringArray()) -> int:
	var removed: int = 0
	var nodes: Array[Node] = [root]
	nodes.append_array(root.find_children("*", "", true, false))
	for node: Node in nodes:
		if not is_instance_valid(node):
			continue
		if node != root and (_not_for_a_map(node) or _in_any(node, hidden_groups)):
			node.get_parent().remove_child(node)
			node.free()
			removed += 1
			continue
		var script: Script = node.get_script() as Script
		if script != null and not _kept(script, keep_classes):
			node.set_script(null)
		# Out of every group, so a group lookup in the game (its checkpoints, its water) never lands on the map's copy.
		# Owners stay: a unique-name path (%GeneralSkeleton) resolves through them.
		for group: StringName in node.get_groups():
			node.remove_from_group(group)
		if node is GeometryInstance3D:
			(node as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if node is RigidBody3D:
			(node as RigidBody3D).freeze = true
	return removed


## True when [param node] is in one of [param groups].
static func _in_any(node: Node, groups: PackedStringArray) -> bool:
	for group: String in groups:
		if node.is_in_group(group):
			return true
	return false


## True for a node a map has no use for.
static func _not_for_a_map(node: Node) -> bool:
	return node is Light3D or node is Camera3D or node is WorldEnvironment or node is AudioStreamPlayer \
			or node is AudioStreamPlayer3D or node is GPUParticles3D or node is CPUParticles3D or node is CanvasItem \
			or node is CanvasLayer or node is MultiplayerSpawner or node is MultiplayerSynchronizer or node is Viewport


## True when [param script], or a script it extends, declares one of [param classes] as its global class.
static func _kept(script: Script, classes: PackedStringArray) -> bool:
	var at: Script = script
	while at != null:
		if String(at.get_global_name()) in classes:
			return true
		at = at.get_base_script()
	return false


func _fit_viewport() -> void:
	var side: int = maxi(int(minf(size.x, size.y)), 16)
	viewport.size = Vector2i(side, side)


## The direction the target faces, on the ground, or north when there is nothing to face.
func heading() -> Vector3:
	var node: Node3D = facing if facing != null else target
	if node == null or not is_instance_valid(node):
		return Vector3.FORWARD
	var forward: Vector3 = node.global_basis.z if facing_plus_z else -node.global_basis.z
	forward.y = 0.0
	return forward.normalized() if forward.length_squared() > 1e-6 else Vector3.FORWARD


## The heading as a yaw in radians: 0 facing north (-Z), growing anticlockwise seen from above, as Godot's own is.
func heading_yaw() -> float:
	var forward: Vector3 = heading()
	return atan2(-forward.x, -forward.z)


func _process(_delta: float) -> void:
	var centre: Vector3 = target.global_position if target != null and is_instance_valid(target) else Vector3.ZERO
	camera.far = height + 1000.0
	var yaw: float = heading_yaw() if rotate_with_target else 0.0
	# Looking straight down with north (-Z) at the top of the picture, then turned so the target faces up.
	camera.global_transform = Transform3D(Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, -PI * 0.5), centre + Vector3.UP * height)
	# Screen rotation is clockwise; a yaw anticlockwise from above turns the arrow the other way.
	arrow.rotation = 0.0 if rotate_with_target else -heading_yaw()
	_place_north(yaw)
	if _eye != null and is_instance_valid(_eye) and _eye.is_inside_tree():
		_eye.global_transform = camera.global_transform
		_eye.size = camera.size
		_eye.far = camera.far


## Puts the north marker on the ring where north is: the top, or turned with the map.
func _place_north(yaw: float) -> void:
	var middle: Vector2 = size * 0.5
	var ring: float = minf(size.x, size.y) * 0.5
	var at: Vector2 = middle + Vector2(0.0, -ring).rotated(yaw)
	north.position = at - north.size * 0.5
