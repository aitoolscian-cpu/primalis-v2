class_name TimberSource
extends Node3D
## Finite timber grove. One unit per chop, no regeneration (Step 7).

signal stock_changed(remaining: int)

@export var starting_stock := 30

var _stock := 0

func _ready() -> void:
	_stock = maxi(starting_stock, 0)
	stock_changed.emit(_stock)

func get_remaining() -> int:
	return _stock

func is_empty() -> bool:
	return _stock <= 0

## Test/debug helper: set remaining stock directly (callers must account
## for the change in any conservation bookkeeping).
func debug_set_stock(value: int) -> void:
	_stock = maxi(value, 0)
	stock_changed.emit(_stock)

## Removes exactly one unit. Returns false when the grove is exhausted.
func try_harvest() -> bool:
	if _stock <= 0:
		return false
	_stock -= 1
	stock_changed.emit(_stock)
	return true
