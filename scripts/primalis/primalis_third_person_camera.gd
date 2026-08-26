class_name PrimalisThirdPersonCamera
extends Node3D
## Reusable third-person rig: follows a target, mouse-orbits yaw/pitch,
## SpringArm3D keeps the camera out of world geometry (layer 1).
## Tuned for Child Primalis; distances and pivot height are exports so the
## rig can scale with later life stages.

@export var mouse_sensitivity := 0.003
@export var pitch_min_deg := -60.0
@export var pitch_max_deg := 25.0
@export var default_pitch_deg := -15.0
@export var follow_lerp_speed := 12.0

var _active := false
var _target: Node3D = null

@onready var _yaw: Node3D = $YawPivot
@onready var _pitch: Node3D = $YawPivot/PitchPivot
@onready var _camera: Camera3D = $YawPivot/PitchPivot/SpringArm3D/Camera

func _ready() -> void:
	set_process(false)
	set_process_unhandled_input(false)

func activate(target: Node3D, initial_yaw: float) -> void:
	_target = target
	global_position = target.global_position
	_yaw.rotation.y = initial_yaw
	_pitch.rotation.x = deg_to_rad(default_pitch_deg)
	_active = true
	set_process(true)
	set_process_unhandled_input(true)
	_camera.make_current()

func deactivate() -> void:
	_active = false
	_target = null
	set_process(false)
	set_process_unhandled_input(false)

func get_yaw_basis() -> Basis:
	return _yaw.global_transform.basis

func get_camera() -> Camera3D:
	return _camera

func _unhandled_input(event: InputEvent) -> void:
	if not _active:
		return
	if event is InputEventMouseMotion:
		var motion := event as InputEventMouseMotion
		_yaw.rotation.y -= motion.relative.x * mouse_sensitivity
		_pitch.rotation.x = clampf(
			_pitch.rotation.x - motion.relative.y * mouse_sensitivity,
			deg_to_rad(pitch_min_deg),
			deg_to_rad(pitch_max_deg))

func _process(delta: float) -> void:
	if _target == null:
		return
	global_position = global_position.lerp(_target.global_position, minf(follow_lerp_speed * delta, 1.0))
