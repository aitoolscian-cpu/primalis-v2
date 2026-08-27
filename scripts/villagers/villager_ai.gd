class_name VillagerAI
extends Node
## Job-driven routine for one villager.
##
## FORAGER:    AT_HOME -> GOING_TO_SOURCE -> GATHERING -> GOING_TO_STORE ->
##             DEPOSITING -> GOING_TO_REST -> RESTING -> GOING_HOME -> repeat.
## WOODCUTTER: AT_HOME -> GOING_TO_TIMBER -> CHOPPING -> GOING_TO_TIMBER_DROP
##             -> DEPOSITING_TIMBER -> GOING_TO_REST -> ... -> repeat.
## BUILDER:    GOING_TO_BUILD -> BUILDING on the settlement's ACTIVE project
##             (Den first, then the player-placed Storehouse);
##             IDLE_PROJECT_COMPLETE while no active project exists — and it
##             polls, so a newly placed site wakes idle builders.
##
## Logistics destinations are dynamic: before the player-built Storehouse
## completes, Food goes to the temp cache and Timber to the temp yard;
## afterwards both go to the Storehouse. A worker already travelling keeps
## its issued destination and retargets next cycle (least brittle option).
##
## Job change while carrying passes through FINISHING_DELIVERY (food) or
## FINISHING_TIMBER_DELIVERY (timber) — conservation stays exact.

enum State {
	AT_HOME,
	GOING_TO_SOURCE,
	GATHERING,
	GOING_TO_STORE,
	DEPOSITING,
	GOING_TO_REST,
	RESTING,
	GOING_HOME,
	IDLE_NO_WORK,
	FINISHING_DELIVERY,
	GOING_TO_BUILD,
	BUILDING,
	IDLE_PROJECT_COMPLETE,
	GOING_TO_TIMBER,
	CHOPPING,
	GOING_TO_TIMBER_DROP,
	DEPOSITING_TIMBER,
	FINISHING_TIMBER_DELIVERY,
	GOING_TO_EAT,
	EATING,
	WAITING_FOR_FOOD,
}

@export var home_duration := 4.0
@export var gather_duration := 5.0
@export var chop_duration := 5.0
@export var deposit_duration := 0.8
@export var rest_duration := 4.0
@export var meal_threshold := 70.0
@export var eating_duration := 1.5
@export var food_retry_interval := 1.0
@export var meal_hunger_reduction := 50.0
## Workers stand on this ring around a build site, clear of the footprint
## that the completed building's collider will occupy.
@export var build_perimeter_radius := 4.6

const TRAVEL_GRACE := 0.3  # agent needs a beat before is_navigation_finished is meaningful

var state: State = State.AT_HOME

var _timer := 0.0
var _home: Node3D
var _source: FoodSource
var _store: Node3D
var _rest_point: Node3D
var _grove: TimberSource
var _yard: Node3D
var _resources: SettlementResources
var _population: PopulationManager
var _build_director: Node
var _current_project: ConstructionProject
var _meal_target: Node3D

@onready var _villager: Villager = get_parent() as Villager

func _ready() -> void:
	_home = _villager.get_node_or_null(_villager.home_path) as Node3D
	_source = _villager.get_node_or_null(_villager.source_path) as FoodSource
	_store = _villager.get_node_or_null(_villager.store_path) as Node3D
	_rest_point = _villager.get_node_or_null(_villager.rest_point_path) as Node3D
	_grove = _villager.get_node_or_null(_villager.timber_source_path) as TimberSource
	_yard = _villager.get_node_or_null(_villager.material_yard_path) as Node3D
	_resources = get_tree().get_first_node_in_group("settlement_resources") as SettlementResources
	_population = get_tree().get_first_node_in_group("population_manager") as PopulationManager
	_build_director = get_tree().get_first_node_in_group("build_mode")
	_timer = home_duration  # everyone settles at home briefly, then their job routes them

func get_state_name() -> String:
	return State.keys()[state]

func get_destination_label() -> String:
	match state:
		State.GOING_TO_SOURCE:
			return "Food Source"
		State.GOING_TO_STORE, State.FINISHING_DELIVERY:
			return "Storehouse" if _completed_storehouse() != null else "Food Cache"
		State.GOING_TO_TIMBER:
			return "Timber Grove"
		State.GOING_TO_TIMBER_DROP, State.FINISHING_TIMBER_DELIVERY:
			return "Storehouse" if _completed_storehouse() != null else "Material Yard"
		State.GOING_TO_REST:
			return "Rest Point"
		State.GOING_HOME:
			return _villager.get_housing_label()
		State.GOING_TO_BUILD:
			if _current_project != null and is_instance_valid(_current_project):
				return _current_project.project_name
			return "Build Site"
		State.GOING_TO_EAT, State.EATING, State.WAITING_FOR_FOOD:
			return _meal_destination_label()
	return "-"

func get_meal_target() -> Node3D:
	return _meal_target

## --- Dynamic logistics -------------------------------------------------

func _completed_storehouse() -> ConstructionProject:
	var sh := get_tree().get_first_node_in_group("storehouse") as ConstructionProject
	if sh != null and sh.is_complete():
		return sh
	return null

func _food_drop() -> Node3D:
	var sh := _completed_storehouse()
	return sh if sh != null else _store

func _timber_drop() -> Node3D:
	var sh := _completed_storehouse()
	return sh if sh != null else _yard

func _active_project() -> ConstructionProject:
	if _build_director != null and _build_director.has_method("get_active_project"):
		return _build_director.get_active_project()
	return null

## --- Job change --------------------------------------------------------

## Called by Villager.assign_job after the job field has changed.
func on_job_changed(_new_job: Villager.Job) -> void:
	_villager.set_working_motion(false)
	if _is_meal_state():
		return
	var food_drop := _food_drop()
	var timber_drop := _timber_drop()
	if _villager.carried_food > 0 and food_drop != null:
		# Conservation-safe: deliver the carried food before switching duties.
		_log_transition(State.FINISHING_DELIVERY)
		state = State.FINISHING_DELIVERY
		_timer = TRAVEL_GRACE
		_villager.move_to(food_drop.global_position)
	elif _villager.carried_timber > 0 and timber_drop != null:
		_log_transition(State.FINISHING_TIMBER_DELIVERY)
		state = State.FINISHING_TIMBER_DELIVERY
		_timer = TRAVEL_GRACE
		_villager.move_to(timber_drop.global_position)
	else:
		_route_to_job()

## Send this villager to the start of its current job's loop.
func _route_to_job() -> void:
	match _villager.job:
		Villager.Job.FORAGER:
			if _source == null or _source.is_empty():
				_enter_station(State.IDLE_NO_WORK, 0.0)
			else:
				_start_travel(State.GOING_TO_SOURCE, _source)
		Villager.Job.WOODCUTTER:
			if _grove == null or _grove.is_empty():
				_enter_station(State.IDLE_NO_WORK, 0.0)
			else:
				_start_travel(State.GOING_TO_TIMBER, _grove)
		Villager.Job.BUILDER:
			_current_project = _active_project()
			if _current_project == null:
				_enter_station(State.IDLE_PROJECT_COMPLETE, 0.0)
			else:
				_start_travel(State.GOING_TO_BUILD, _current_project)

func _physics_process(delta: float) -> void:
	_timer -= delta
	_interrupt_for_meal_if_needed()
	match state:
		State.AT_HOME:
			if _timer <= 0.0:
				_route_to_job()
		State.GOING_TO_SOURCE:
			if _timer <= 0.0 and _villager.is_travel_finished():
				_enter_station(State.GATHERING, gather_duration)
				_villager.set_working_motion(true)
		State.GATHERING:
			if _timer <= 0.0:
				_villager.set_working_motion(false)
				if _source != null and _source.try_harvest():
					_villager.set_carried_food(1)
					_start_travel(State.GOING_TO_STORE, _food_drop())
				else:
					_start_travel(State.GOING_TO_REST, _rest_point)
		State.GOING_TO_STORE:
			if _timer <= 0.0 and _villager.is_travel_finished():
				_enter_station(State.DEPOSITING, deposit_duration)
		State.DEPOSITING:
			if _timer <= 0.0:
				_deposit_carried_food()
				_after_delivery(false)
		State.GOING_TO_TIMBER:
			if _timer <= 0.0 and _villager.is_travel_finished():
				_enter_station(State.CHOPPING, chop_duration)
				_villager.set_working_motion(true)
		State.CHOPPING:
			if _timer <= 0.0:
				_villager.set_working_motion(false)
				if _grove != null and _grove.try_harvest():
					_villager.set_carried_timber(1)
					_start_travel(State.GOING_TO_TIMBER_DROP, _timber_drop())
				else:
					_start_travel(State.GOING_TO_REST, _rest_point)
		State.GOING_TO_TIMBER_DROP:
			if _timer <= 0.0 and _villager.is_travel_finished():
				_enter_station(State.DEPOSITING_TIMBER, deposit_duration)
		State.DEPOSITING_TIMBER:
			if _timer <= 0.0:
				_deposit_carried_timber()
				_after_delivery(false)
		State.GOING_TO_REST:
			if _timer <= 0.0 and _villager.is_travel_finished():
				_enter_station(State.RESTING, rest_duration)
		State.RESTING:
			if _timer <= 0.0:
				_start_travel(State.GOING_HOME, _current_home())
		State.GOING_HOME:
			if _timer <= 0.0 and _villager.is_travel_finished():
				_enter_station(State.AT_HOME, home_duration)
		State.IDLE_NO_WORK:
			# Terminal until reassignment (or the job's source is refilled).
			pass
		State.FINISHING_DELIVERY:
			if _timer <= 0.0 and _villager.is_travel_finished():
				_deposit_carried_food()
				_after_delivery(true)
		State.FINISHING_TIMBER_DELIVERY:
			if _timer <= 0.0 and _villager.is_travel_finished():
				_deposit_carried_timber()
				_after_delivery(true)
		State.GOING_TO_BUILD:
			if _current_project == null or not is_instance_valid(_current_project):
				_route_to_job()
			elif _timer <= 0.0 and _villager.is_travel_finished():
				if _current_project.is_complete():
					_route_to_job()
				else:
					_enter_station(State.BUILDING, 0.0)
					_villager.set_working_motion(true)
		State.BUILDING:
			if _current_project == null or not is_instance_valid(_current_project) \
					or _current_project.is_complete():
				_villager.set_working_motion(false)
				_route_to_job()
			else:
				_current_project.contribute(delta)
		State.IDLE_PROJECT_COMPLETE:
			# Still a Builder; wake up when a new active project appears.
			if _active_project() != null:
				_route_to_job()
		State.GOING_TO_EAT:
			if _timer <= 0.0 and _villager.is_travel_finished():
				if _resources != null and _resources.can_spend_food(1):
					_enter_station(State.EATING, eating_duration)
				else:
					_enter_station(State.WAITING_FOR_FOOD, food_retry_interval)
		State.EATING:
			if _timer <= 0.0:
				_complete_meal()
		State.WAITING_FOR_FOOD:
			if _timer <= 0.0:
				var current_target := _food_drop()
				if current_target != _meal_target:
					_start_meal_trip()
				elif _resources != null and _resources.can_spend_food(1):
					_enter_station(State.EATING, eating_duration)
				else:
					_timer = food_retry_interval

func _interrupt_for_meal_if_needed() -> void:
	if _is_meal_state() or _villager.get_hunger() < meal_threshold:
		return
	if _villager.carried_food > 0:
		if state not in [State.GOING_TO_STORE, State.DEPOSITING, State.FINISHING_DELIVERY]:
			_villager.set_working_motion(false)
			_start_travel(State.FINISHING_DELIVERY, _food_drop())
		return
	if _villager.carried_timber > 0:
		if state not in [State.GOING_TO_TIMBER_DROP, State.DEPOSITING_TIMBER,
				State.FINISHING_TIMBER_DELIVERY]:
			_villager.set_working_motion(false)
			_start_travel(State.FINISHING_TIMBER_DELIVERY, _timber_drop())
		return
	_villager.set_working_motion(false)
	_start_meal_trip()

func _is_meal_state() -> bool:
	return state in [State.GOING_TO_EAT, State.EATING, State.WAITING_FOR_FOOD]

func _start_meal_trip() -> void:
	_meal_target = _food_drop()
	_start_travel(State.GOING_TO_EAT, _meal_target)

func _after_delivery(route_job_directly: bool) -> void:
	if _villager.get_hunger() >= meal_threshold:
		_start_meal_trip()
	elif route_job_directly:
		_route_to_job()
	else:
		_start_travel(State.GOING_TO_REST, _rest_point)

func _complete_meal() -> void:
	# Atomic spend at completion resolves final-unit contention safely.
	if _resources != null and _resources.try_spend_food(1):
		if _population != null:
			_population.record_villager_food_consumed(1)
		_villager.set_hunger(_villager.get_hunger() - meal_hunger_reduction)
		_route_to_job()
	else:
		_enter_station(State.WAITING_FOR_FOOD, food_retry_interval)

func _meal_destination_label() -> String:
	var storehouse := _completed_storehouse()
	return "Storehouse" if storehouse != null and _meal_target == storehouse else "Food Cache"

func _deposit_carried_food() -> void:
	if _villager.carried_food > 0 and _resources != null:
		_resources.add_food(_villager.carried_food)
	_villager.set_carried_food(0)

func _deposit_carried_timber() -> void:
	if _villager.carried_timber > 0 and _resources != null:
		_resources.add_timber(_villager.carried_timber)
	_villager.set_carried_timber(0)

func _current_home() -> Node3D:
	return _villager.get_home_target(_home)

func on_home_changed() -> void:
	if state == State.GOING_HOME:
		_villager.move_to(_current_home().global_position)

func _start_travel(next_state: State, anchor: Node3D) -> void:
	if anchor == null:
		_enter_station(State.IDLE_NO_WORK, 0.0)
		return
	_log_transition(next_state)
	state = next_state
	_timer = TRAVEL_GRACE
	_villager.move_to(anchor.global_position)

func _enter_station(next_state: State, duration: float) -> void:
	_log_transition(next_state)
	state = next_state
	_timer = duration

func _log_transition(next_state: State) -> void:
	if OS.is_debug_build():
		print("%s: %s -> %s" % [_villager.display_name, State.keys()[state], State.keys()[next_state]])
