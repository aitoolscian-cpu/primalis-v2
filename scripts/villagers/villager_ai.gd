class_name VillagerAI
extends Node
## Tiny explicit routine loop for one villager:
## AT_HOME -> GOING_TO_WORK -> WORKING -> GOING_TO_REST -> RESTING ->
## GOING_HOME -> AT_HOME -> repeat.
## Demonstration loop only — no needs, no world clock, no schedules.

enum State { AT_HOME, GOING_TO_WORK, WORKING, GOING_TO_REST, RESTING, GOING_HOME }

@export var home_duration := 4.0
@export var work_duration := 8.0
@export var rest_duration := 4.0

const TRAVEL_GRACE := 0.3  # agent needs a beat before is_navigation_finished is meaningful

var state: State = State.AT_HOME

var _timer := 0.0
var _home: Node3D
var _worksite: Node3D
var _rest_point: Node3D

@onready var _villager: Villager = get_parent() as Villager

func _ready() -> void:
	_home = _villager.get_node_or_null(_villager.home_path) as Node3D
	_worksite = _villager.get_node_or_null(_villager.worksite_path) as Node3D
	_rest_point = _villager.get_node_or_null(_villager.rest_point_path) as Node3D
	_timer = home_duration

func get_state_name() -> String:
	return State.keys()[state]

func get_destination_label() -> String:
	match state:
		State.GOING_TO_WORK:
			return "Worksite"
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
				_start_travel(State.GOING_TO_WORK, _worksite)
		State.GOING_TO_WORK:
			if _timer <= 0.0 and _villager.is_travel_finished():
				_enter_station(State.WORKING, work_duration)
				_villager.set_working_motion(true)
		State.WORKING:
			if _timer <= 0.0:
				_villager.set_working_motion(false)
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

func _start_travel(next_state: State, anchor: Node3D) -> void:
	if anchor == null:
		# No anchor wired: stay put rather than erroring.
		_enter_station(State.AT_HOME, home_duration)
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
