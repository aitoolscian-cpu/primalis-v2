class_name PrimalisController
extends CharacterBody3D
## Placeholder Child Primalis with two movement ownership modes.
## RTS_COMMAND: NavigationAgent3D path following (Step 2 behaviour).
## DIRECT_CONTROL: camera-relative player input (Step 3 possession).
## Exactly one system writes horizontal velocity per physics frame.

enum State { IDLE, MOVING }
enum ControlMode { RTS_COMMAND, DIRECT_CONTROL }

@export_group("RTS Movement")
@export var max_speed := 3.5
@export var acceleration := 9.0
@export var deceleration := 12.0
@export var slow_radius := 2.5

@export_group("Direct Movement")
@export var direct_speed := 3.8
@export var sprint_speed := 6.0
@export var direct_acceleration := 12.0
@export var direct_deceleration := 15.0

@export_group("Shared")
@export var turn_lerp_speed := 8.0
@export var gravity := 9.8

var state: State = State.IDLE
var control_mode: ControlMode = ControlMode.RTS_COMMAND
var destination := Vector3.ZERO

var _bob_time := 0.0
var _direct_camera: PrimalisThirdPersonCamera = null

@onready var _agent: NavigationAgent3D = $NavigationAgent3D
@onready var _selection: PrimalisSelection = $Selection
@onready var _visual: Node3D = $Visual

func command_move_to(target: Vector3) -> void:
	if control_mode != ControlMode.RTS_COMMAND:
		return
	destination = target
	_agent.target_position = target
	state = State.MOVING

func enter_direct_control(camera_rig: PrimalisThirdPersonCamera) -> void:
	control_mode = ControlMode.DIRECT_CONTROL
	_direct_camera = camera_rig
	# The pre-possession RTS command is cancelled, not paused.
	state = State.IDLE
	destination = global_position
	_agent.target_position = global_position

func exit_direct_control() -> void:
	control_mode = ControlMode.RTS_COMMAND
	_direct_camera = null
	state = State.IDLE
	destination = global_position
	_agent.target_position = global_position

func set_selected(selected: bool) -> void:
	_selection.set_selected(selected)

func get_selection_name() -> String:
	return "Primalis"

func get_selection_type() -> String:
	return "primalis"

func get_speed() -> float:
	return Vector2(velocity.x, velocity.z).length()

func is_sprinting() -> bool:
	return control_mode == ControlMode.DIRECT_CONTROL \
		and Input.is_action_pressed("primalis_sprint") \
		and get_speed() > 0.5

func get_state_name() -> String:
	if control_mode == ControlMode.DIRECT_CONTROL:
		if get_speed() <= 0.3:
			return "IDLE"
		return "SPRINTING" if is_sprinting() else "MOVING"
	return "MOVING" if state == State.MOVING else "IDLE"

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta

	var horizontal := Vector3(velocity.x, 0.0, velocity.z)
	if control_mode == ControlMode.DIRECT_CONTROL:
		horizontal = _direct_movement(horizontal, delta)
	else:
		horizontal = _rts_movement(horizontal, delta)

	if horizontal.length_squared() > 0.04:
		var yaw := atan2(-horizontal.x, -horizontal.z)
		rotation.y = lerp_angle(rotation.y, yaw, minf(turn_lerp_speed * delta, 1.0))
		# Tiny locomotion bob so movement reads before real animation exists.
		_bob_time += delta * horizontal.length() * 2.4
		_visual.position.y = absf(sin(_bob_time)) * 0.05
	else:
		_visual.position.y = lerpf(_visual.position.y, 0.0, minf(10.0 * delta, 1.0))

	velocity.x = horizontal.x
	velocity.z = horizontal.z
	move_and_slide()

func _rts_movement(horizontal: Vector3, delta: float) -> Vector3:
	if state == State.MOVING:
		if _agent.is_navigation_finished():
			state = State.IDLE
		else:
			var next := _agent.get_next_path_position()
			var to_next := next - global_position
			to_next.y = 0.0
			var dir := to_next.normalized() if to_next.length() > 0.01 else Vector3.ZERO
			var target_speed := max_speed
			var remaining := Vector2(destination.x - global_position.x, destination.z - global_position.z).length()
			if remaining < slow_radius:
				target_speed = maxf(max_speed * remaining / slow_radius, 0.6)
			return horizontal.move_toward(dir * target_speed, acceleration * delta)
	return horizontal.move_toward(Vector3.ZERO, deceleration * delta)

func _direct_movement(horizontal: Vector3, delta: float) -> Vector3:
	var input := Input.get_vector(
		"primalis_move_left", "primalis_move_right",
		"primalis_move_forward", "primalis_move_backward")
	if input == Vector2.ZERO:
		return horizontal.move_toward(Vector3.ZERO, direct_deceleration * delta)
	var yaw_basis := Basis.IDENTITY
	if _direct_camera != null:
		yaw_basis = _direct_camera.get_yaw_basis()
	var dir := yaw_basis * Vector3(input.x, 0.0, input.y)
	dir.y = 0.0
	dir = dir.normalized() if dir.length() > 0.01 else Vector3.ZERO
	var target_speed := sprint_speed if Input.is_action_pressed("primalis_sprint") else direct_speed
	return horizontal.move_toward(dir * target_speed, direct_acceleration * delta)
