class_name FoodSource
extends Node3D
## Finite wild food source. One unit per harvest, no regeneration (Step 5).

signal stock_changed(remaining: int)

@export var starting_stock := 20

var _stock := 0

func _ready() -> void:
	_stock = maxi(starting_stock, 0)
	stock_changed.emit(_stock)

func get_remaining() -> int:
	return _stock

func is_empty() -> bool:
	return _stock <= 0

## Removes exactly one unit. Returns false when the source is exhausted.
func try_harvest() -> bool:
	if _stock <= 0:
		return false
	_stock -= 1
	stock_changed.emit(_stock)
	return true
