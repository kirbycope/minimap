extends Node3D
## The minimap demo: a walker loops round the village with the minimap in the corner, drawing the live world
## unshaded. M turns the map with the walker or keeps north up; L swaps to a stripped copy of the village loaded into
## the minimap's own world, Mario Kart style, and back.

@export var minimap: Minimap ## The HUD's minimap.
@export var walker: Node3D ## Who walks the loop, and whom the minimap follows.
@export var help: Label ## Says which keys do what, and how the map is being drawn.
@export_range(1.0, 60.0, 0.5, "suffix:m") var loop_radius: float = 17.5
@export_range(0.1, 20.0, 0.1, "suffix:m/s") var walk_speed: float = 3.0

var _angle: float = 0.0
const MAP_PATH: String = "res://addons/minimap/scenes/demo/demo_map.tscn"


func _ready() -> void:
	_describe()


func _physics_process(delta: float) -> void:
	_angle += walk_speed / loop_radius * delta
	var at: Vector3 = Vector3(cos(_angle), 0.0, sin(_angle)) * loop_radius
	var ahead: Vector3 = Vector3(-sin(_angle), 0.0, cos(_angle)) # the way round the loop
	walker.global_transform = Transform3D(Basis.looking_at(ahead, Vector3.UP), at)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_M:
			minimap.rotate_with_target = not minimap.rotate_with_target
		elif event.keycode == KEY_L:
			minimap.map_path = "" if not minimap.map_path.is_empty() else MAP_PATH
		else:
			return
		_describe()


func _describe() -> void:
	help.text = "M: %s    L: %s" % [
		"map turns with the walker" if minimap.rotate_with_target else "north up",
		"a stripped copy of the village" if not minimap.map_path.is_empty() else "the live world, unshaded",
	]
