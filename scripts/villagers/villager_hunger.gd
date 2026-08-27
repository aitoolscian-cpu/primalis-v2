class_name VillagerHunger
extends Node
## Step 9A individual hunger data only. This component deliberately has no
## knowledge of jobs, food stores, movement, health, or eating behavior.

signal hunger_changed(value: float)
signal status_changed(status: String)

const MIN_HUNGER := 0.0
const MAX_HUNGER := 100.0

@export var hunger_rate := 0.12

var _hunger := 0.0
var _status := "FED"

func _physics_process(delta: float) -> void:
	set_hunger(_hunger + hunger_rate * delta)

func set_hunger(value: float) -> void:
	var next_hunger := clampf(value, MIN_HUNGER, MAX_HUNGER)
	if is_equal_approx(next_hunger, _hunger):
		return
	var previous_status := _status
	_hunger = next_hunger
	_status = _status_for(_hunger)
	hunger_changed.emit(_hunger)
	if _status != previous_status:
		status_changed.emit(_status)

func get_hunger() -> float:
	return _hunger

func get_hunger_status() -> String:
	return _status

func is_hungry() -> bool:
	return _hunger >= 50.0

func _status_for(value: float) -> String:
	if value >= 90.0:
		return "STARVING"
	if value >= 70.0:
		return "VERY HUNGRY"
	if value >= 50.0:
		return "HUNGRY"
	if value >= 25.0:
		return "PECKISH"
	return "FED"
