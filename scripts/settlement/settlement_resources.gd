class_name SettlementResources
extends Node
## First settlement resource manager. Step 5 scope: FOOD only.
## Owned node in Main (not an autoload). Food can never go negative.

signal food_changed(new_amount: int)

@export var starting_food := 3

var _food := 0

func _ready() -> void:
	_food = maxi(starting_food, 0)
	food_changed.emit(_food)

func get_food() -> int:
	return _food

func add_food(amount: int) -> void:
	if amount <= 0:
		return
	_food += amount
	food_changed.emit(_food)

func can_spend_food(amount: int) -> bool:
	return amount > 0 and _food >= amount

func try_spend_food(amount: int) -> bool:
	if not can_spend_food(amount):
		return false
	_food -= amount
	food_changed.emit(_food)
	return true
