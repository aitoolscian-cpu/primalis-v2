class_name PrimalisSelection
extends Node3D
## Toggles the ground selection ring for this unit.

@onready var _ring: MeshInstance3D = $SelectionRing

func set_selected(selected: bool) -> void:
	_ring.visible = selected
