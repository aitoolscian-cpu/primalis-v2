class_name PrimalisController
extends CharacterBody3D
## Placeholder Child Primalis: navmesh-driven movement with smooth
## acceleration, deceleration near the goal, and smooth facing.

enum State { IDLE, MOVING }

@export var max_speed := 3.5
@export var acceleration := 9.0
@export var deceleration := 12.0
@export var turn_lerp_speed := 8.0
@export var slow_radius := 2.5
@export var gravity := 9.8

var state: State = State.IDLE
var destination := Vector3.ZERO

var _bob_time := 0.0

@onready var _agent: NavigationAgent3D = $NavigationAgent3D
@onready var _selection: PrimalisSelection = $Selection
@onready var _visual: Node3D = $Visual

func command_move_to(target: Vector3) -> void:
	destination = target
	_agent.target_position = target
	state = State.MOVING

func set_selected(selected: bool) -> void:
	_selection.set_selected(selected)

func get_state_name() -> String:
	return "MOVING" if state == State.MOVING else "IDLE"

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta

	var horizontal := Vector3(velocity.x, 0.0, velocity.z)
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
			horizontal = horizontal.move_toward(dir * target_speed, acceleration * delta)
	if state == State.IDLE:
		horizontal = horizontal.move_toward(Vector3.ZERO, deceleration * delta)

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
