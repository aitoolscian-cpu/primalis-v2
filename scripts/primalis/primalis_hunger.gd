class_name PrimalisHunger
extends Node
## Primalis hunger: 0 = fed, 100 = extremely hungry. Pure simulation state —
## it rises in every control mode and never pauses with UI or possession.

@export var hunger := 45.0
@export var rate_per_second := 0.35

func _physics_process(delta: float) -> void:
	hunger = clampf(hunger + rate_per_second * delta, 0.0, 100.0)

func reduce(amount: float) -> void:
	hunger = clampf(hunger - amount, 0.0, 100.0)

func get_label() -> String:
	if hunger < 25.0:
		return "FED"
	if hunger < 50.0:
		return "PECKISH"
	if hunger < 75.0:
		return "HUNGRY"
	return "VERY HUNGRY"
