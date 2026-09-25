@tool
@icon("res://addons/minimap/assets/icons/minimap_icon.svg")
class_name Minimap
extends Control
## A round HUD minimap, the Zelda and Mario Kart way: a live top-down orthographic view rendered in a
## [SubViewport], masked to a circle with a ring, north marked on the ring, and the [member target] an arrow at the
## centre that turns the way it faces.
##
## Mario Kart draws its minimap from a model of the course of its own, not from the world the race is in, and Mario
## Kart World renders that live from above with no karts in it. Set [member map_scene] and this does the same: the
## scene is loaded into the SubViewport's own [World3D] and stripped to what a map needs ([method strip]): every shadow
## off, its lights, cameras, environments, sounds and particles taken out, and every script that is not a
## [code]@tool[/code] dropped, so none of the level's gameplay runs a second time; the minimap's own flat, shadowless
## [member sun] lights it instead. Give it the level's art scene (terrain, buildings), placed by
## [member map_transform] where the game places it. Left empty, the view is of the game's own world, as the
## Breath of the Wild HUD this came from drew it, shadows, players and all.
##
## North is up unless [member rotate_with_target], which turns the map so the target always faces up and walks the
## north marker round the ring instead.

## Who is at the centre: the Player, usually.
@export var target: Node3D
## What the arrow turns with; the target when empty. A Player's own body does not turn, its model does.
@export var facing: Node3D
## The facing node looks along +Z rather than Godot's -Z, as a Mixamo model does.
@export var facing_plus_z: bool = false
## The map to draw, loaded into a world of its own and stripped of shadows; empty draws the game's own world.
@export var map_scene: PackedScene = null:
	set(value):
		map_scene = value
		if is_node_ready():
			load_map()
## Where [member map_scene] goes in its world: where the game places that level, so the two line up.
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


func _ready() -> void:
	display.texture = viewport.get_texture()
	camera.size = view_size
	camera.cull_mask = cull_mask
	resized.connect(_fit_viewport)
	_fit_viewport()
	load_map()


## (Re)loads [member map_scene] into the minimap's own world, stripped; without one, the view is of the game's world.
func load_map() -> void:
	if _level != null and is_instance_valid(_level):
		_level.queue_free()
	_level = null
	viewport.world_3d = _map_world if map_scene != null else null
	sun.visible = map_scene != null
	if map_scene == null:
		return
	_level = map_scene.instantiate()
	strip(_level)
	if _level is Node3D:
		(_level as Node3D).transform = map_transform
	map_root.add_child(_level)


## Strips [param root] to what a map needs, before it enters a tree: every shadow off; lights, cameras,
## environments, sounds and particles removed; and every script that is not a [code]@tool[/code] dropped, so the
## level's gameplay (spawners, saves, AI) never runs in the map. A tool script stays, since tool scripts are what
## draw things like terrain and are written to run anywhere. Returns how many nodes it removed.
static func strip(root: Node) -> int:
	var removed: int = 0
	var nodes: Array[Node] = [root]
	nodes.append_array(root.find_children("*", "", true, false))
	for node: Node in nodes:
		if not is_instance_valid(node):
			continue
		if node != root and (node is Light3D or node is Camera3D or node is WorldEnvironment or node is AudioStreamPlayer
				or node is AudioStreamPlayer3D or node is GPUParticles3D or node is CPUParticles3D):
			node.get_parent().remove_child(node)
			node.free()
			removed += 1
			continue
		var script: Script = node.get_script() as Script
		if script != null and not script.is_tool():
			node.set_script(null)
		if node is GeometryInstance3D:
			(node as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return removed


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


## Puts the north marker on the ring where north is: the top, or turned with the map.
func _place_north(yaw: float) -> void:
	var middle: Vector2 = size * 0.5
	var ring: float = minf(size.x, size.y) * 0.5
	var at: Vector2 = middle + Vector2(0.0, -ring).rotated(yaw)
	north.position = at - north.size * 0.5
