class_name HousingManager
extends Node
## Step 8 housing only: completed Houses, stable ID-ordered assignments,
## and the physical outdoor home anchor used by each resident.

signal housing_changed

var _population: PopulationManager
var _build: BuildModeController
var _completed_houses: Array[ConstructionProject] = []
var _assignments: Dictionary = {} # villager_id -> {house, anchor, label}

func _ready() -> void:
	_population = get_tree().get_first_node_in_group("population_manager") as PopulationManager
	_build = get_tree().get_first_node_in_group("build_mode") as BuildModeController
	if _build != null:
		_build.building_completed.connect(_on_building_completed)
		for house in _build.get_completed_houses():
			_register_house(house)

func get_housed_count() -> int:
	return _assignments.size()

func get_capacity() -> int:
	var total := 0
	for house in _completed_houses:
		if is_instance_valid(house):
			total += house.housing_capacity
	return total

func get_completed_house_count() -> int:
	return _completed_houses.size()

func is_housed(villager: Villager) -> bool:
	return villager != null and _assignments.has(villager.villager_id)

func get_housing_label(villager: Villager) -> String:
	if not is_housed(villager):
		return "TEMP CAMP"
	return str((_assignments[villager.villager_id] as Dictionary).label)

func get_home_target(villager: Villager) -> Node3D:
	if not is_housed(villager):
		return null
	return (_assignments[villager.villager_id] as Dictionary).anchor as Node3D

func get_assigned_house(villager: Villager) -> ConstructionProject:
	if not is_housed(villager):
		return null
	return (_assignments[villager.villager_id] as Dictionary).house as ConstructionProject

func get_assignment_snapshot() -> Dictionary:
	var snapshot := {}
	for villager_id in _assignments:
		snapshot[villager_id] = (_assignments[villager_id] as Dictionary).label
	return snapshot

func _on_building_completed(definition: BuildingDefinition, site: ConstructionProject) -> void:
	if definition.housing_capacity > 0:
		_register_house(site)

func _register_house(house: ConstructionProject) -> void:
	if house == null or not house.is_complete() or house in _completed_houses:
		return
	_completed_houses.append(house)
	_assign_available_slots(house)
	housing_changed.emit()

func _assign_available_slots(house: ConstructionProject) -> void:
	if _population == null:
		return
	var villagers: Array[Villager] = _population.get_villagers().duplicate()
	villagers.sort_custom(func(a: Villager, b: Villager) -> bool:
		return a.villager_id < b.villager_id)
	var slot := 0
	for villager in villagers:
		if _assignments.has(villager.villager_id):
			continue
		if slot >= house.housing_capacity:
			break
		var anchor := house.get_home_anchor(slot)
		if anchor == null:
			break
		var label := "%s %d" % [house.project_name, house.instance_number]
		_assignments[villager.villager_id] = {
			"house": house,
			"anchor": anchor,
			"label": label,
		}
		villager.assign_home(anchor, label)
		slot += 1
