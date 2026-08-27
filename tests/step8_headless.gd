extends SceneTree
## Step 8 gauntlet: reusable Storehouse/House catalog, single-project
## placement, physical construction, deterministic housing, home routing,
## order independence, navigation, continuity, and exact conservation.

var _failures := PackedStringArray()
var _main: Node
var _primalis: PrimalisController
var _selection: SelectionManager
var _modes: ControlModeManager
var _resources: SettlementResources
var _feeding: FeedingService
var _source: FoodSource
var _grove: TimberSource
var _population: PopulationManager
var _housing: HousingManager
var _den: ConstructionProject
var _build: BuildModeController
var _villagers: Array[Villager] = []
var _initial_food := 0
var _initial_timber := 0

func _initialize() -> void:
	_run()

func _run() -> void:
	Engine.time_scale = 8.0
	Engine.max_physics_steps_per_frame = 240
	await _load_fresh_main()

	# T0: catalog is exactly Storehouse + House A, with tunable data.
	var definitions := _build.get_building_definitions()
	var storehouse_def := _build.get_definition(BuildModeController.STOREHOUSE_ID)
	var house_def := _build.get_definition(BuildModeController.HOUSE_ID)
	_check(definitions.size() == 2, "T0 catalog contains exactly two definitions")
	_check(storehouse_def != null and storehouse_def.display_name == "STOREHOUSE", "T0 Storehouse identity preserved")
	_check(storehouse_def.timber_cost == 8 and storehouse_def.max_instances == 1, "T0 Storehouse cost/limit preserved")
	_check(house_def != null and house_def.building_id == &"BLD_002", "T0 House A identity")
	_check(house_def.timber_cost == 6 and house_def.max_instances == 2, "T0 House cost 6 / max 2")
	_check(house_def.footprint == Vector3(5, 2, 4) and house_def.housing_capacity == 2, "T0 House footprint/capacity data")

	# T1: Den gate applies independently to both choices.
	_check(_build.get_unavailable_reason(BuildModeController.STOREHOUSE_ID) == "COMPLETE PRIMALIS DEN FIRST", "T1 Storehouse den gate")
	_check(_build.get_unavailable_reason(BuildModeController.HOUSE_ID) == "COMPLETE PRIMALIS DEN FIRST", "T1 House den gate")
	_check(not _build.enter_build_mode(BuildModeController.HOUSE_ID), "T1 House refused before Den")
	_den.debug_set_progress(100.0)
	await physics_frame
	_add_timber(40)
	_check(_build.get_unavailable_reason(BuildModeController.HOUSE_ID) == "", "T1 House unlocked without Storehouse prerequisite")
	_check(_build.get_unavailable_reason(BuildModeController.STOREHOUSE_ID) == "", "T1 Storehouse independently unlocked")

	# T2: one shared ghost handles House validity and all rotations.
	_check(_build.enter_build_mode(BuildModeController.HOUSE_ID), "T2 House build selection")
	_check(_build.get_selected_definition() == house_def, "T2 selected definition stored")
	_build.set_ghost_position(Vector3(10, 0, 18))
	_check(_build.is_ghost_valid(), "T2 valid House ghost")
	for expected in [90, 180, 270, 0]:
		_build.rotate_ghost()
		_check(_build.get_ghost_rotation_degrees() == expected, "T2 rotation %d" % expected)
	_build.set_ghost_position(Vector3(8, 0, -4))
	_check(not _build.is_ghost_valid(), "T2 rock overlap invalid")
	_build.set_ghost_position(Vector3(-10, 0, 16))
	_check(not _build.is_ghost_valid(), "T2 Den overlap invalid")
	_build.set_ghost_position(Vector3(18, 0, 2))
	_check(not _build.is_ghost_valid(), "T2 Food Source overlap invalid")
	_build.set_ghost_position(Vector3(-24, 0, 0))
	_check(not _build.is_ghost_valid(), "T2 Timber Grove overlap invalid")
	_build.set_ghost_position(Vector3(-2, 0, 10))
	_check(not _build.is_ghost_valid(), "T2 Feeding Spot overlap invalid")
	_build.set_ghost_position(Vector3(-8, 0, -12))
	_check(not _build.is_ghost_valid(), "T2 temporary cache overlap invalid")
	_build.set_ghost_position(Vector3(60, 0, 60))
	_check(not _build.is_ghost_valid(), "T2 bounds invalid")
	var timber_before_invalid := _resources.get_timber()
	_check(not _build.try_confirm_placement(), "T2 invalid confirmation refused")
	_check(_resources.get_timber() == timber_before_invalid, "T2 invalid costs zero")
	_build.cancel_build_mode()

	# T3: 30 enter/cancel cycles leak neither nodes nor Timber/input ownership.
	var nodes_before_cancel := get_node_count()
	var timber_before_cancel := _resources.get_timber()
	for i in 30:
		_check_quiet(_build.enter_build_mode(BuildModeController.HOUSE_ID))
		_build.set_ghost_position(Vector3(10, 0, 18))
		_build.cancel_build_mode()
		await physics_frame
	_check(get_node_count() == nodes_before_cancel, "T3 cancel soak node stable")
	_check(_resources.get_timber() == timber_before_cancel, "T3 cancel soak zero spend")
	_check(_selection.is_processing_unhandled_input() and _modes.is_processing_unhandled_input(), "T3 RTS/possession input restored")

	# T4: simulation remains live while House placement owns input.
	await _set_jobs([Villager.Job.FORAGER, Villager.Job.WOODCUTTER, Villager.Job.BUILDER, Villager.Job.BUILDER])
	var hunger_before := _primalis.get_hunger()
	var source_before := _source.get_remaining()
	var grove_before := _grove.get_remaining()
	_check(_build.enter_build_mode(BuildModeController.HOUSE_ID), "T4 enter House placement")
	var start_frame := Engine.get_physics_frames()
	while _game_seconds_since(start_frame) < 30.0:
		await physics_frame
	_check(_primalis.get_hunger() > hunger_before, "T4 Hunger advances during build mode")
	_check(_source.get_remaining() < source_before or _carried_food_total() > 0, "T4 Food work advances during build mode")
	_check(_grove.get_remaining() < grove_before or _carried_timber_total() > 0, "T4 Timber work advances during build mode")
	_build.cancel_build_mode()
	_conservation("T4")

	# T5: House-first placement spends once and locks every other project.
	var house1_pos := Vector3(10, 0, 18)
	_check(_build.enter_build_mode(BuildModeController.HOUSE_ID), "T5 enter first House")
	_build.rotate_ghost()
	_build.set_ghost_position(house1_pos)
	_check(_build.is_ghost_valid(), "T5 first House position valid")
	var timber_before_house := _resources.get_timber()
	_check(_build.try_confirm_placement(), "T5 first House confirmed")
	_check(_resources.get_timber() == timber_before_house - 6, "T5 exactly 6 Timber spent")
	_check(_build.total_timber_spent == 6, "T5 building-spend accounting +6")
	_check(not _build.try_confirm_placement(), "T5 rapid duplicate confirmation refused")
	_check(_build.get_building_count(BuildModeController.HOUSE_ID) == 1, "T5 one House site only")
	var house1 := _build.get_houses()[0]
	_check(roundi(rad_to_deg(house1.rotation.y)) == 90, "T5 final House rotation stored")
	_check(_build.get_active_project() == house1, "T5 House is sole active project")
	_check(_build.get_unavailable_reason(BuildModeController.STOREHOUSE_ID) == "CONSTRUCTION IN PROGRESS", "T5 Storehouse locked by House construction")
	_check(_build.get_unavailable_reason(BuildModeController.HOUSE_ID) == "CONSTRUCTION IN PROGRESS", "T5 second House locked by House construction")
	_check(not _build.enter_build_mode(BuildModeController.STOREHOUSE_ID), "T5 cannot start Storehouse concurrently")
	_check(not _build.enter_build_mode(BuildModeController.HOUSE_ID), "T5 cannot start House concurrently")

	# T6: Builders physically construct the shared project; completion houses 2.
	var reached_building := await _await_any_builder_building(4800)
	_check(reached_building, "T6 Builders physically reach House")
	var progress_before := house1.progress
	for i in 120:
		await physics_frame
	_check(house1.progress > progress_before, "T6 active Builders advance House")
	house1.debug_set_progress(100.0)
	for i in 20:
		await physics_frame
	_check(house1.is_complete() and house1.get_percent() == 100, "T6 House completes")
	_check((house1.get_node("Roof") as Node3D).visible, "T6 finished House visuals visible")
	_check(not (house1.get_node("Obstacle/Shape") as CollisionShape3D).disabled, "T6 House collider enabled")
	_check(_housing.get_capacity() == 2 and _housing.get_housed_count() == 2, "T6 housing becomes 2 / 4")
	var first_snapshot := _housing.get_assignment_snapshot()
	_check(first_snapshot.get("VIL_TEST_001") == "HOUSE 1" and first_snapshot.get("VIL_TEST_002") == "HOUSE 1", "T6 first two stable IDs assigned House 1")
	_check(not first_snapshot.has("VIL_TEST_003") and not first_snapshot.has("VIL_TEST_004"), "T6 remaining villagers use temp camp")
	var mara := _by_id("VIL_TEST_001")
	var tomas := _by_id("VIL_TEST_002")
	var elia := _by_id("VIL_TEST_003")
	_check(mara.get_housing_label() == "HOUSE 1" and tomas.get_housing_label() == "HOUSE 1", "T6 resident inspection labels")
	_check(elia.get_housing_label() == "TEMP CAMP", "T6 temporary-home fallback label")
	_check(mara.get_home_position().distance_to(tomas.get_home_position()) > 0.5, "T6 two distinct exterior home anchors")

	# T7: completed House changes the real GOING_HOME trip and arrival.
	var reached_home := await _await_home_arrival(mara, 12000)
	_check(reached_home, "T7 housed villager physically returns to House")
	_check(mara.global_position.distance_to(mara.get_home_position()) < 2.0, "T7 resident arrives at assigned House anchor")
	var temp_home := _main.get_node("TestWorld/Anchors/VillagerHome") as Node3D
	_check(mara.get_home_position().distance_to(temp_home.global_position) > 10.0, "T7 home target no longer temporary camp")

	# T8: completed/constructing House footprints block overlap, no spend.
	_check(_build.enter_build_mode(BuildModeController.HOUSE_ID), "T8 enter second House placement")
	_build.set_ghost_position(house1.global_position)
	_check(not _build.is_ghost_valid(), "T8 overlapping House invalid")
	var overlap_timber := _resources.get_timber()
	_check(not _build.try_confirm_placement(), "T8 overlapping House confirmation refused")
	_check(_resources.get_timber() == overlap_timber, "T8 overlap spends zero")
	_build.cancel_build_mode()

	# T9: House-before-Storehouse keeps temp logistics, then Storehouse switches it.
	_check(_completed_storehouse() == null, "T9 House-first has no Storehouse")
	_check(_build.enter_build_mode(BuildModeController.STOREHOUSE_ID), "T9 Storehouse available after House")
	_build.set_ghost_position(Vector3(0, 0, -3))
	_check(_build.is_ghost_valid(), "T9 Storehouse position remains valid")
	_check(_build.try_confirm_placement(), "T9 Storehouse placed after House")
	var storehouse := _build.get_storehouse()
	_check(storehouse != null and not storehouse.is_complete(), "T9 Storehouse site exists")
	storehouse.debug_set_progress(100.0)
	for i in 30:
		await physics_frame
	_check(_completed_storehouse() == storehouse, "T9 completed Storehouse becomes logistics destination")
	_check(_build.total_timber_spent == 14, "T9 House + Storehouse spend = 14")
	var deposits := await _observe_storehouse_deposits(storehouse, 18000)
	_check(deposits[0] and deposits[1], "T9 Food and Timber physically deposit at Storehouse")
	_conservation("T9")

	# T10: second House fills remaining IDs; first assignments remain stable.
	var house2_pos := Vector3(-36, 0, -8)
	_check(_build.enter_build_mode(BuildModeController.HOUSE_ID), "T10 enter second House")
	_build.set_ghost_position(house2_pos)
	_check(_build.is_ghost_valid(), "T10 far House valid")
	var second_timber := _resources.get_timber()
	_check(_build.try_confirm_placement(), "T10 second House confirmed")
	_check(_resources.get_timber() == second_timber - 6, "T10 second House costs 6")
	var house2 := _build.get_houses()[1]
	house2.debug_set_progress(100.0)
	for i in 30:
		await physics_frame
	_check(_build.get_building_count(BuildModeController.HOUSE_ID) == 2, "T10 House count 2")
	_check(_housing.get_capacity() == 4 and _housing.get_housed_count() == 4, "T10 housing 4 / 4")
	var all_snapshot := _housing.get_assignment_snapshot()
	_check(all_snapshot.get("VIL_TEST_001") == first_snapshot.get("VIL_TEST_001") \
		and all_snapshot.get("VIL_TEST_002") == first_snapshot.get("VIL_TEST_002"), "T10 first assignments unchanged")
	_check(all_snapshot.get("VIL_TEST_003") == "HOUSE 2" and all_snapshot.get("VIL_TEST_004") == "HOUSE 2", "T10 remaining IDs fill House 2")
	_check(_build.total_timber_spent == 20, "T10 two Houses account for 12 Timber")

	# T11: natural spatial effect is measured from real navmesh route lengths.
	var map := _primalis.get_world_3d().navigation_map
	var rest := (_main.get_node("TestWorld/Anchors/VillagerRestPoint") as Node3D).global_position
	var near_length := _path_len(map, rest, house1.get_home_anchor(0).global_position)
	var far_length := _path_len(map, rest, house2.get_home_anchor(0).global_position)
	_check(near_length + 15.0 < far_length, "T11 physical near/far commute differs (%.1f vs %.1f)" % [near_length, far_length])

	# T12: maximum blocks a third ghost and leaves resources/registry unchanged.
	var third_timber := _resources.get_timber()
	_check(_build.get_unavailable_reason(BuildModeController.HOUSE_ID) == "MAX BUILT", "T12 House control says MAX BUILT")
	_check(not _build.enter_build_mode(BuildModeController.HOUSE_ID), "T12 third House rejected before ghost")
	_check(_resources.get_timber() == third_timber and _build.get_houses().size() == 2, "T12 third House spends/adds nothing")

	# T13: assignments survive minutes and possession while simulation runs.
	var stable_snapshot := _housing.get_assignment_snapshot()
	_selection.select(_primalis)
	_modes.toggle_possession()
	var possession_start := Engine.get_physics_frames()
	var hunger_possession := _primalis.get_hunger()
	while _game_seconds_since(possession_start) < 180.0:
		await physics_frame
	_check(_modes.is_direct(), "T13 Primalis possession active")
	_check(_primalis.get_hunger() > hunger_possession, "T13 simulation continues during possession")
	_check(_housing.get_assignment_snapshot() == stable_snapshot, "T13 housing assignments stable for minutes")
	_modes.toggle_possession()
	await physics_frame
	_conservation("T13")

	# T14: a clean second world proves Storehouse-first then House works too.
	await _load_fresh_main()
	_den.debug_set_progress(100.0)
	await physics_frame
	_add_timber(20)
	_check(await _place_and_complete(BuildModeController.STOREHOUSE_ID, Vector3(0, 0, -3)), "T14 Storehouse-first completes")
	_check(_completed_storehouse() != null, "T14 Storehouse logistics active first")
	_check(await _place_and_complete(BuildModeController.HOUSE_ID, Vector3(10, 0, 18)), "T14 House completes after Storehouse")
	_check(_housing.get_housed_count() == 2, "T14 Storehouse-first housing works")
	_conservation("T14")

	_finish()

func _load_fresh_main() -> void:
	if _main != null and is_instance_valid(_main):
		_main.queue_free()
		for i in 5:
			await physics_frame
	var packed: PackedScene = load("res://scenes/main.tscn")
	_main = packed.instantiate()
	root.add_child(_main)
	for i in 12:
		await physics_frame
	_primalis = get_first_node_in_group("primalis") as PrimalisController
	_selection = get_first_node_in_group("selection_manager") as SelectionManager
	_modes = get_first_node_in_group("control_mode_manager") as ControlModeManager
	_resources = get_first_node_in_group("settlement_resources") as SettlementResources
	_feeding = get_first_node_in_group("feeding_service") as FeedingService
	_source = get_first_node_in_group("food_source") as FoodSource
	_grove = get_first_node_in_group("timber_source") as TimberSource
	_population = get_first_node_in_group("population_manager") as PopulationManager
	_housing = get_first_node_in_group("housing_manager") as HousingManager
	_den = get_first_node_in_group("construction_project") as ConstructionProject
	_build = get_first_node_in_group("build_mode") as BuildModeController
	_villagers.clear()
	for node in get_nodes_in_group("villager"):
		_villagers.append(node as Villager)
	_initial_food = _source.get_remaining() + _resources.get_food()
	_initial_timber = _grove.get_remaining() + _resources.get_timber()

func _place_and_complete(building_id: StringName, position: Vector3) -> bool:
	if not _build.enter_build_mode(building_id):
		return false
	_build.set_ghost_position(position)
	if not _build.is_ghost_valid() or not _build.try_confirm_placement():
		return false
	var site := _build.get_storehouse() if building_id == BuildModeController.STOREHOUSE_ID else _build.get_houses()[-1]
	site.debug_set_progress(100.0)
	for i in 20:
		await physics_frame
	return site.is_complete()

func _await_any_builder_building(max_ticks: int) -> bool:
	for i in max_ticks:
		await physics_frame
		for villager in _villagers:
			if villager.job == Villager.Job.BUILDER and villager.get_state_name() == "BUILDING":
				return true
	return false

func _await_home_arrival(villager: Villager, max_ticks: int) -> bool:
	var saw_home_trip := false
	for i in max_ticks:
		await physics_frame
		if villager.get_state_name() == "GOING_HOME":
			saw_home_trip = true
		if saw_home_trip and villager.get_state_name() == "AT_HOME":
			return true
	return false

func _observe_storehouse_deposits(storehouse: ConstructionProject, max_ticks: int) -> Array[bool]:
	_reset_sources(12, 12)
	await _set_jobs([Villager.Job.FORAGER, Villager.Job.WOODCUTTER, Villager.Job.FORAGER, Villager.Job.WOODCUTTER])
	var food_seen := false
	var timber_seen := false
	var previous_states := {}
	for i in max_ticks:
		await physics_frame
		for villager in _villagers:
			var state_name := villager.get_state_name()
			if previous_states.get(villager, "") != state_name:
				var distance := Vector2(villager.global_position.x - storehouse.global_position.x,
					villager.global_position.z - storehouse.global_position.z).length()
				if state_name == "DEPOSITING" and distance < 6.5:
					food_seen = true
				if state_name == "DEPOSITING_TIMBER" and distance < 6.5:
					timber_seen = true
				previous_states[villager] = state_name
		if food_seen and timber_seen:
			break
	return [food_seen, timber_seen]

func _set_jobs(jobs: Array) -> void:
	for i in _villagers.size():
		_population.assign_job(_villagers[i], jobs[i])
	await physics_frame

func _by_id(villager_id: String) -> Villager:
	for villager in _villagers:
		if villager.villager_id == villager_id:
			return villager
	return null

func _completed_storehouse() -> ConstructionProject:
	var storehouse := get_first_node_in_group("storehouse") as ConstructionProject
	return storehouse if storehouse != null and storehouse.is_complete() else null

func _add_timber(amount: int) -> void:
	_resources.add_timber(amount)
	_initial_timber += amount

func _reset_sources(food: int, timber: int) -> void:
	_initial_food += food - _source.get_remaining()
	_initial_timber += timber - _grove.get_remaining()
	_source.debug_set_stock(food)
	_grove.debug_set_stock(timber)

func _carried_food_total() -> int:
	var total := 0
	for villager in _villagers:
		total += villager.carried_food
	return total

func _carried_timber_total() -> int:
	var total := 0
	for villager in _villagers:
		total += villager.carried_timber
	return total

func _conservation(label: String) -> void:
	var food_total := _source.get_remaining() + _resources.get_food() \
		+ _feeding.total_food_consumed + _population.total_food_consumed_by_villagers \
		+ _carried_food_total()
	var timber_total := _grove.get_remaining() + _resources.get_timber() \
		+ _build.total_timber_spent + _carried_timber_total()
	_check(food_total == _initial_food, "%s Food conservation %d == %d" % [label, food_total, _initial_food])
	_check(timber_total == _initial_timber, "%s Timber conservation %d == %d" % [label, timber_total, _initial_timber])

func _path_len(map: RID, from: Vector3, to: Vector3) -> float:
	var path := NavigationServer3D.map_get_path(map, from, to, true)
	var length := 0.0
	for i in range(1, path.size()):
		length += path[i - 1].distance_to(path[i])
	return length

func _game_seconds_since(start_frame: int) -> float:
	return (Engine.get_physics_frames() - start_frame) * Engine.time_scale / 60.0

func _check_quiet(condition: bool) -> void:
	if not condition:
		_failures.append("quiet check failed")
		print("FAIL  quiet check")

func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS  ", label)
	else:
		print("FAIL  ", label)
		_failures.append(label)

func _finish() -> void:
	if _failures.is_empty():
		print("STEP8 HEADLESS: ALL PASS")
		quit(0)
	else:
		print("STEP8 HEADLESS: %d FAILURE(S)" % _failures.size())
		quit(1)
