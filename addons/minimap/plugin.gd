@tool
extends EditorPlugin
## Puts the Minimap in the Create New Node dialog.
##
## Every preload here is written relative to this file, which is exactly the kind a search for "res://"
## never finds, so tests/test_editor_plugin.gd checks each one resolves.


func _enter_tree() -> void:
	add_custom_type("Minimap", "Control", preload("scripts/minimap.gd"), preload("assets/icons/minimap_icon.svg"))


func _exit_tree() -> void:
	remove_custom_type("Minimap")
