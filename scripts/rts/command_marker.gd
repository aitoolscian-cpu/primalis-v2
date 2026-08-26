class_name CommandMarker
extends MeshInstance3D
## Single reusable destination marker: flashes briefly at each valid move order.
## Reused in place, so repeated commands never accumulate nodes.

@export var lifetime := 0.8

var _time_left := 0.0

func flash_at(world_pos: Vector3) -> void:
	global_position = world_pos + Vector3(0.0, 0.06, 0.0)
	_time_left = lifetime
	scale = Vector3.ONE
	visible = true

func _process(delta: float) -> void:
	if not visible:
		return
	_time_left -= delta
	if _time_left <= 0.0:
		visible = false
		scale = Vector3.ONE
		return
	var t := clampf(_time_left / lifetime, 0.0, 1.0)
	scale = Vector3.ONE * lerpf(0.55, 1.0, t)
