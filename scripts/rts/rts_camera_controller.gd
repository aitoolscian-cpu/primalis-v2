class_name RTSCameraController
extends Node3D
## Reusable RTS camera rig.
## Node layout: self (yaw, ground-level pivot) -> Pitch (fixed tilt) -> Camera (zoom = local +Z).

@export var move_speed := 26.0
@export var boost_multiplier := 2.2
@export var rotate_speed_deg := 110.0
@export var zoom_min := 8.0
@export var zoom_max := 70.0
@export var zoom_step := 4.0
@export var zoom_lerp_speed := 9.0
@export var bounds_half_extent := 72.0

var _target_zoom := 32.0

@onready var _camera: Camera3D = $Pitch/Camera

func _ready() -> void:
	_target_zoom = clampf(_camera.position.z, zoom_min, zoom_max)

## Enable/disable this rig's input processing. Yaw and zoom are preserved
## while inactive; reactivating also reclaims the current camera.
func set_active(active: bool) -> void:
	set_process(active)
	set_process_unhandled_input(active)
	if active:
		_camera.make_current()

## Move the rig pivot to a world position (bounds-clamped), keeping yaw/zoom.
func recenter_on(world_pos: Vector3) -> void:
	position = Vector3(
		clampf(world_pos.x, -bounds_half_extent, bounds_half_extent),
		0.0,
		clampf(world_pos.z, -bounds_half_extent, bounds_half_extent))

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("camera_zoom_in"):
		_target_zoom = clampf(_target_zoom - zoom_step, zoom_min, zoom_max)
	elif event.is_action_pressed("camera_zoom_out"):
		_target_zoom = clampf(_target_zoom + zoom_step, zoom_min, zoom_max)

func _process(delta: float) -> void:
	# Pan relative to current yaw; forward is toward the top of the view.
	var pan := Input.get_vector("camera_left", "camera_right", "camera_forward", "camera_backward")
	var speed := move_speed
	if Input.is_action_pressed("camera_speed_boost"):
		speed *= boost_multiplier
	# Scale pan speed with zoom so control feels consistent at every height.
	speed *= clampf(_camera.position.z / 32.0, 0.45, 2.0)
	var dir := basis * Vector3(pan.x, 0.0, pan.y)
	dir.y = 0.0
	position += dir * speed * delta
	position.x = clampf(position.x, -bounds_half_extent, bounds_half_extent)
	position.z = clampf(position.z, -bounds_half_extent, bounds_half_extent)

	var rot_axis := Input.get_axis("camera_rotate_left", "camera_rotate_right")
	rotation.y -= rot_axis * deg_to_rad(rotate_speed_deg) * delta

	_camera.position.z = lerpf(_camera.position.z, _target_zoom, minf(zoom_lerp_speed * delta, 1.0))
