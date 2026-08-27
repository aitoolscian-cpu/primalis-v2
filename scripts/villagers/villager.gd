class_name Villager
extends CharacterBody3D
## Placeholder autonomous villager. Identity + physical movement live here;
## the job/routine state machine lives in the child VillagerAI node.
## Villagers are selectable and inspectable but NOT player-commandable.
## One reusable scene: per-instance identity, job, tunic color, offsets.

enum Job { FORAGER, BUILDER, WOODCUTTER }

const PROXIMITY_LOOK_RANGE := 6.0

@export_group("Identity")
@export var villager_id := "VIL_TEST_001"
@export var display_name := "Mara"  # [TESTING] placeholder identity, not canon.
@export var job: Job = Job.FORAGER
@export var tunic_color := Color(0.541, 0.404, 0.247)  # default: soil brown
## Small deterministic offset applied at stations so villagers don't stack.
@export var station_offset := Vector3.ZERO

@export_group("Activity Anchors")
@export var home_path: NodePath
@export var source_path: NodePath
@export var store_path: NodePath
@export var rest_point_path: NodePath
@export var den_path: NodePath
@export var timber_source_path: NodePath
@export var material_yard_path: NodePath

@export_group("Movement")
@export var max_speed := 2.2
@export var acceleration := 8.0
@export var deceleration := 10.0
@export var turn_lerp_speed := 8.0
@export var slow_radius := 1.5
@export var gravity := 9.8

var carried_food := 0
var carried_timber := 0
var _assigned_home: Node3D = null
var _housing_label := "TEMP CAMP"

var _bob_time := 0.0
var _working_motion := false
var _primalis: Node3D = null
var _temporary_home: Node3D = null

@onready var _agent: NavigationAgent3D = $NavigationAgent3D
@onready var _selection: PrimalisSelection = $Selection
@onready var _visual: Node3D = $Visual
@onready var _carry_prop: MeshInstance3D = $Visual/CarryBasket
@onready var _log_prop: MeshInstance3D = $Visual/CarryLog
@onready var _ai: VillagerAI = $AI

func _ready() -> void:
	_primalis = get_tree().get_first_node_in_group("primalis") as Node3D
	_temporary_home = get_node_or_null(home_path) as Node3D
	_apply_tunic_color()

func _apply_tunic_color() -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = tunic_color
	mat.roughness = 1.0
	for part in ["Torso", "ArmL", "ArmR"]:
		var mesh := _visual.get_node(part) as MeshInstance3D
		mesh.set_surface_override_material(0, mat)

func move_to(target: Vector3) -> void:
	var map: RID = get_world_3d().navigation_map
	_agent.target_position = NavigationServer3D.map_get_closest_point(map, target + station_offset)

## Target a spot on a ring around a build site rather than its centre, so
## workers stand clear of the footprint the finished building will occupy.
func move_to_perimeter(center: Vector3, radius: float) -> void:
	var dir := Vector3(station_offset.x, 0.0, station_offset.z)
	if dir.length() < 0.01:
		dir = Vector3(1, 0, 0)
	dir = dir.normalized()
	var map: RID = get_world_3d().navigation_map
	_agent.target_position = NavigationServer3D.map_get_closest_point(map, center + dir * radius)

func is_travel_finished() -> bool:
	return _agent.is_navigation_finished()

func set_working_motion(on: bool) -> void:
	_working_motion = on

func set_carried_food(amount: int) -> void:
	carried_food = clampi(amount, 0, 1)
	_carry_prop.visible = carried_food > 0

func set_carried_timber(amount: int) -> void:
	carried_timber = clampi(amount, 0, 1)
	_log_prop.visible = carried_timber > 0

## Player job assignment. The job label switches immediately; behavior may
## pass through a conservation-safe transition (FINISHING_DELIVERY) first.
func assign_job(new_job: Job) -> void:
	if new_job == job:
		return
	job = new_job
	_ai.on_job_changed(new_job)

func get_job_name() -> String:
	return Job.keys()[job]

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

func assign_home(home_anchor: Node3D, housing_label: String) -> void:
	_assigned_home = home_anchor
	_housing_label = housing_label
	_ai.on_home_changed()

func get_home_target(temporary_home: Node3D) -> Node3D:
	if _assigned_home != null and is_instance_valid(_assigned_home):
		return _assigned_home
	return temporary_home if temporary_home != null else _temporary_home

func get_housing_label() -> String:
	return _housing_label

func get_home_position(temporary_home: Node3D = null) -> Vector3:
	var target := get_home_target(temporary_home)
	return target.global_position if target != null else Vector3.ZERO

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

## Tiny cosmetic behaviour while standing: a work lean at stations, and
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
