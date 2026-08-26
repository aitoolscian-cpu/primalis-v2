class_name VillagerAI
extends Node
## Forager routine for one villager:
## AT_HOME -> GOING_TO_SOURCE -> GATHERING -> GOING_TO_STORE -> DEPOSITING
## -> GOING_TO_REST -> RESTING -> GOING_HOME -> repeat.
## When the wild source is exhausted she enters IDLE_NO_WORK at home.
## Demonstration loop only — no needs, no world clock, no reassignment.

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
}

@export var home_duration := 4.0
@export var gather_duration := 5.0
@export var deposit_duration := 0.8
@export var rest_duration := 4.0

const TRAVEL_GRACE := 0.3  # agent needs a beat before is_navigation_finished is meaningful

var state: State = State.AT_HOME

var _timer := 0.0
var _home: Node3D
var _source: FoodSource
var _store: Node3D
var _rest_point: Node3D
var _resources: SettlementResources

@onready var _villager: Villager = get_parent() as Villager

func _ready() -> void:
	_home = _villager.get_node_or_null(_villager.home_path) as Node3D
	_source = _villager.get_node_or_null(_villager.source_path) as FoodSource
	_store = _villager.get_node_or_null(_villager.store_path) as Node3D
	_rest_point = _villager.get_node_or_null(_villager.rest_point_path) as Node3D
	_resources = get_tree().get_first_node_in_group("settlement_resources") as SettlementResources
	_timer = home_duration

func get_state_name() -> String:
	return State.keys()[state]

func get_destination_label() -> String:
	match state:
		State.GOING_TO_SOURCE:
			return "Food Source"
		State.GOING_TO_STORE:
			return "Food Store"
		State.GOING_TO_REST:
			return "Rest Point"
		State.GOING_HOME:
			return "Home"
	return "-"

func _physics_process(delta: float) -> void:
	_timer -= delta
	match state:
		State.AT_HOME:
			if _timer <= 0.0:
				if _source == null or _source.is_empty():
					_enter_station(State.IDLE_NO_WORK, 0.0)
				else:
					_start_travel(State.GOING_TO_SOURCE, _source)
		State.GOING_TO_SOURCE:
			if _timer <= 0.0 and _villager.is_travel_finished():
				_enter_station(State.GATHERING, gather_duration)
				_villager.set_working_motion(true)
		State.GATHERING:
			if _timer <= 0.0:
				_villager.set_working_motion(false)
				if _source != null and _source.try_harvest():
					_villager.set_carried_food(1)
					_start_travel(State.GOING_TO_STORE, _store)
				else:
					# Source ran dry mid-approach: nothing gathered.
					_start_travel(State.GOING_TO_REST, _rest_point)
		State.GOING_TO_STORE:
			if _timer <= 0.0 and _villager.is_travel_finished():
				_enter_station(State.DEPOSITING, deposit_duration)
		State.DEPOSITING:
			if _timer <= 0.0:
				if _villager.carried_food > 0 and _resources != null:
					_resources.add_food(_villager.carried_food)
				_villager.set_carried_food(0)
				_start_travel(State.GOING_TO_REST, _rest_point)
		State.GOING_TO_REST:
			if _timer <= 0.0 and _villager.is_travel_finished():
				_enter_station(State.RESTING, rest_duration)
		State.RESTING:
			if _timer <= 0.0:
				_start_travel(State.GOING_HOME, _home)
		State.GOING_HOME:
			if _timer <= 0.0 and _villager.is_travel_finished():
				_enter_station(State.AT_HOME, home_duration)
		State.IDLE_NO_WORK:
			pass  # Clear terminal state until future work systems exist.

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
