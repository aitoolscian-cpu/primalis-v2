class_name SettlementResources
extends Node
## Settlement resource manager. Step 7 scope: FOOD and TIMBER.
## Owned node in Main (not an autoload). Resources can never go negative.

signal food_changed(new_amount: int)
signal timber_changed(new_amount: int)

@export var starting_food := 3
@export var starting_timber := 0

var _food := 0
var _timber := 0

func _ready() -> void:
	_food = maxi(starting_food, 0)
	_timber = maxi(starting_timber, 0)
	food_changed.emit(_food)
	timber_changed.emit(_timber)

func get_timber() -> int:
	return _timber

func add_timber(amount: int) -> void:
	if amount <= 0:
		return
	_timber += amount
	timber_changed.emit(_timber)

func can_spend_timber(amount: int) -> bool:
	return amount > 0 and _timber >= amount

func try_spend_timber(amount: int) -> bool:
	if not can_spend_timber(amount):
		return false
	_timber -= amount
	timber_changed.emit(_timber)
	return true

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
