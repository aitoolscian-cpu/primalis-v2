class_name PrimalisHunger
extends Node
## Primalis hunger: 0 = fed, 100 = extremely hungry. Pure simulation state —
## it rises in every control mode and never pauses with UI or possession.

@export var hunger := 45.0
@export var rate_per_second := 0.35

var shelter_multiplier := 1.0  # completed Den applies 0.9 (-10% growth)

func _physics_process(delta: float) -> void:
	hunger = clampf(hunger + get_effective_rate() * delta, 0.0, 100.0)

func get_effective_rate() -> float:
	return rate_per_second * shelter_multiplier

func has_shelter_bonus() -> bool:
	return shelter_multiplier < 1.0

func apply_shelter_bonus(multiplier: float) -> void:
	shelter_multiplier = multiplier

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
