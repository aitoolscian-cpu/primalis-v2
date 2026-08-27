class_name PopulationManager
extends Node
## Knows the settlement's villagers, reports counts by job, and owns the
## job-assignment API. Deliberately small — not a civilization manager.

signal jobs_changed

var total_food_consumed_by_villagers := 0
var _villagers: Array[Villager] = []

func _ready() -> void:
	for node in get_tree().get_nodes_in_group("villager"):
		var villager := node as Villager
		if villager != null:
			_villagers.append(villager)

func get_population() -> int:
	return _villagers.size()

func get_villagers() -> Array[Villager]:
	return _villagers

func get_job_count(job: Villager.Job) -> int:
	var count := 0
	for villager in _villagers:
		if villager.job == job:
			count += 1
	return count

func get_hungry_count() -> int:
	var count := 0
	for villager in _villagers:
		if villager.is_hungry():
			count += 1
	return count

func record_villager_food_consumed(amount: int) -> void:
	if amount > 0:
		total_food_consumed_by_villagers += amount

func assign_job(villager: Villager, job: Villager.Job) -> void:
	if villager == null or villager.job == job:
		return
	villager.assign_job(job)
	jobs_changed.emit()
