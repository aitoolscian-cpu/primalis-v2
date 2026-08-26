class_name Villager
extends CharacterBody3D
## Placeholder autonomous villager. Identity + physical movement live here;
## the routine state machine lives in the child VillagerAI node.
## Villagers are selectable and inspectable but NOT player-commandable.

const PROXIMITY_LOOK_RANGE := 6.0

@export_group("Identity")
@export var villager_id := "VIL_TEST_001"
@export var display_name := "Mara"  # [TESTING] placeholder identity, not canon.
@export var job := "Builder"

@export_group("Activity Anchors")
@export var home_path: NodePath
@export var worksite_path: NodePath
@export var rest_point_path: NodePath

@export_group("Movement")
@export var max_speed := 2.2
@export var acceleration := 8.0
@export var deceleration := 10.0
@export var turn_lerp_speed := 8.0
@export var slow_radius := 1.5
@export var gravity := 9.8

var _bob_time := 0.0
var _working_motion := false
var _primalis: Node3D = null

@onready var _agent: NavigationAgent3D = $NavigationAgent3D
@onready var _selection: PrimalisSelection = $Selection
@onready var _visual: Node3D = $Visual
@onready var _ai: VillagerAI = $AI

func _ready() -> void:
	_primalis = get_tree().get_first_node_in_group("primalis") as Node3D

func move_to(target: Vector3) -> void:
	var map: RID = get_world_3d().navigation_map
	_agent.target_position = NavigationServer3D.map_get_closest_point(map, target)

func is_travel_finished() -> bool:
	return _agent.is_navigation_finished()

func set_working_motion(on: bool) -> void:
	_working_motion = on

## --- Selection contract (shared with PrimalisController) ---
func set_selected(selected: bool) -> void:
	_selection.set_selected(selected)

func get_selection_name() -> String:
	return display_name

func get_selection_type() -> String:
	return "villager"

## --- Inspection ---
func get_state_name() -> String:
	return _ai.get_state_name()

func get_destination_label() -> String:
	return _ai.get_destination_label()

func get_speed() -> float:
	return Vector2(velocity.x, velocity.z).length()

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta

	var horizontal := Vector3(velocity.x, 0.0, velocity.z)
	if not _agent.is_navigation_finished():
		var next := _agent.get_next_path_position()
		var to_next := next - global_position
		to_next.y = 0.0
		var dir := to_next.normalized() if to_next.length() > 0.01 else Vector3.ZERO
		var target_speed := max_speed
		var remaining := _agent.distance_to_target()
		if remaining < slow_radius:
			target_speed = maxf(max_speed * remaining / slow_radius, 0.5)
		horizontal = horizontal.move_toward(dir * target_speed, acceleration * delta)
	else:
		horizontal = horizontal.move_toward(Vector3.ZERO, deceleration * delta)

	if horizontal.length_squared() > 0.03:
		var yaw := atan2(-horizontal.x, -horizontal.z)
		rotation.y = lerp_angle(rotation.y, yaw, minf(turn_lerp_speed * delta, 1.0))
		_bob_time += delta * horizontal.length() * 3.0
		_visual.position.y = absf(sin(_bob_time)) * 0.035
		_visual.rotation.x = 0.0
	else:
		_visual.position.y = lerpf(_visual.position.y, 0.0, minf(10.0 * delta, 1.0))
		_stationary_motion(delta)

	velocity.x = horizontal.x
	velocity.z = horizontal.z
	move_and_slide()

## Tiny cosmetic behaviour while standing: a work lean at the worksite, and
## turning to watch Primalis when he is close. No animation architecture.
func _stationary_motion(delta: float) -> void:
	if _working_motion:
		_bob_time += delta * 4.5
		_visual.rotation.x = sin(_bob_time) * 0.07
	else:
		_visual.rotation.x = lerpf(_visual.rotation.x, 0.0, minf(8.0 * delta, 1.0))
	if _primalis != null:
		var to_primalis := _primalis.global_position - global_position
		to_primalis.y = 0.0
		if to_primalis.length() < PROXIMITY_LOOK_RANGE and to_primalis.length() > 0.5:
			var yaw := atan2(-to_primalis.x, -to_primalis.z)
			rotation.y = lerp_angle(rotation.y, yaw, minf(4.0 * delta, 1.0))
