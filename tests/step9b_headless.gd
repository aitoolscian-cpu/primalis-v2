extends SceneTree
## Focused Step 9B gauntlet: physical meals, completion-time spending,
## contention/waiting, conservation-safe interruption, and work resumption.

var _failures := PackedStringArray()
var _main: Node
var _villagers: Array[Villager] = []
var _population: PopulationManager
var _resources: SettlementResources
var _source: FoodSource
var _grove: TimberSource
var _feeding: FeedingService
var _selection: SelectionManager
var _modes: ControlModeManager
var _primalis: PrimalisController
var _build: BuildModeController
var _housing: HousingManager
var _den: ConstructionProject

func _initialize() -> void:
	_run()

func _run() -> void:
	Engine.time_scale = 16.0
	Engine.max_physics_steps_per_frame = 240

	# T1: threshold, physical temp-cache trip, spend at completion, exact meal.
	await _load_fresh()
	var mara := _by_id("VIL_TEST_001")
	var mara_ai := mara.get_node("AI") as VillagerAI
	_check(is_equal_approx(mara_ai.meal_threshold, 70.0), "T1 meal threshold is tunable 70")
	mara.set_hunger(69.0)
	for i in 2:
		await physics_frame
	_check(not _is_meal_state(mara), "T1 below threshold continues ordinary work")
	(mara.get_node("Hunger") as VillagerHunger).hunger_rate = 0.0
	mara.set_hunger(70.0)
	var start_position := mara.global_position
	var initial_food := _food_total()
	_check(await _await_state(mara, "GOING_TO_EAT"), "T1 hungry villager enters GOING_TO_EAT")
	var temp_cache := _main.get_node("TestWorld/Anchors/FoodStore") as Node3D
	_check(mara_ai.get_meal_target() == temp_cache and start_position.distance_to(temp_cache.global_position) > 5.0,
		"T1 physically targets temporary Food cache")
	_check(await _await_state(mara, "EATING"), "T1 physically arrives and enters EATING")
	var food_at_eating_start := _resources.get_food()
	for i in 2:
		await physics_frame
	_check(_resources.get_food() == food_at_eating_start, "T1 Food not spent when EATING begins")
	_check(await _await_villager_consumption(1), "T1 meal completes after eating duration")
	_check(_resources.get_food() == food_at_eating_start - 1 and is_equal_approx(mara.get_hunger(), 20.0),
		"T1 exactly 1 Food spent and Hunger reduced exactly 50")
	_check(await _await_not_meal(mara), "T1 assigned Forager job resumes")
	_check(_food_total() == initial_food, "T1 Food conservation exact")

	# T2: no Food, retry, new job persistence, possession/build continuity.
	await _load_fresh()
	mara = _by_id("VIL_TEST_001")
	_set_stored_food(0)
	_source.debug_set_stock(0)
	mara.set_hunger(70.0)
	_check(await _await_state(mara, "WAITING_FOR_FOOD"), "T2 no Food leads to WAITING_FOR_FOOD")
	var waiting_hunger := mara.get_hunger()
	for i in 8:
		await physics_frame
	_check(mara.get_state_name() == "WAITING_FOR_FOOD" and mara.get_hunger() > waiting_hunger,
		"T2 waits without free meal while Hunger continues")
	_population.assign_job(mara, Villager.Job.WOODCUTTER)
	_check(mara.job == Villager.Job.WOODCUTTER and mara.get_state_name() == "WAITING_FOR_FOOD",
		"T2 job changes immediately without cancelling survival behavior")
	var nodes_before := get_node_count()
	_selection.select(_primalis)
	_modes.toggle_possession()
	var before_possession := mara.get_hunger()
	for i in 8:
		await physics_frame
	_check(_modes.is_direct() and mara.get_state_name() == "WAITING_FOR_FOOD"
		and mara.get_hunger() > before_possession, "T2 waiting continues during possession")
	_modes.toggle_possession()
	_den.debug_set_progress(100.0)
	_resources.add_timber(20)
	await physics_frame
	var build_entered := _build.enter_build_mode(BuildModeController.HOUSE_ID)
	for i in 8:
		await physics_frame
	_check(build_entered and mara.get_state_name() == "WAITING_FOR_FOOD",
		"T2 waiting continues during build mode")
	_build.cancel_build_mode()
	_resources.add_food(1)
	_check(await _await_state(mara, "EATING"), "T2 retry notices arriving Food")
	_check(_resources.get_food() == 1, "T2 retry still spends only at completion")
	_check(await _await_villager_consumption(1) and _resources.get_food() == 0,
		"T2 waiting villager consumes arriving Food once")
	_check(await _await_job_route(mara, ["GOING_TO_TIMBER", "CHOPPING"]),
		"T2 resumes newly assigned Woodcutter job")
	_check(get_node_count() == nodes_before, "T2 control modes leave node count stable")

	# T3: one final Food unit is atomically won by one of three waiters.
	await _load_fresh()
	_source.debug_set_stock(0)
	_set_stored_food(1)
	var contention_initial := _food_total()
	for i in 3:
		(_villagers[i].get_node("Hunger") as VillagerHunger).hunger_rate = 0.0
		_villagers[i].set_hunger(70.0)
	_check(await _await_villager_consumption(1), "T3 one contender completes the final meal")
	for i in 20:
		await physics_frame
	var waiting_count := 0
	for i in 3:
		if _villagers[i].get_state_name() == "WAITING_FOR_FOOD":
			waiting_count += 1
	_check(_resources.get_food() == 0 and _population.total_food_consumed_by_villagers == 1
		and waiting_count == 2, "T3 final-unit contention leaves exactly two waiting")
	_check(_food_total() == contention_initial, "T3 contention Food conservation exact")

	# T4: carried Food and Timber are delivered before meal interruption.
	await _load_fresh()
	mara = _by_id("VIL_TEST_001")
	_set_stored_food(2)
	_check(_source.try_harvest(), "T4 setup harvests carried Food conservatively")
	mara.set_carried_food(1)
	(mara.get_node("Hunger") as VillagerHunger).hunger_rate = 0.0
	mara.set_hunger(70.0)
	var carry_food_initial := _food_total()
	_check(await _await_state(mara, "FINISHING_DELIVERY"), "T4 hungry Forager finishes Food delivery")
	_check(await _await_state(mara, "GOING_TO_EAT") and mara.carried_food == 0,
		"T4 Food is deposited before meal trip")
	_check(await _await_villager_consumption(1) and _food_total() == carry_food_initial,
		"T4 carried Food remains exactly conserved")

	await _load_fresh()
	var tomas := _by_id("VIL_TEST_002")
	_population.assign_job(tomas, Villager.Job.WOODCUTTER)
	_check(_grove.try_harvest(), "T4 setup harvests carried Timber conservatively")
	tomas.set_carried_timber(1)
	(tomas.get_node("Hunger") as VillagerHunger).hunger_rate = 0.0
	tomas.set_hunger(70.0)
	var timber_initial := _timber_total()
	_check(await _await_state(tomas, "FINISHING_TIMBER_DELIVERY"),
		"T4 hungry Woodcutter finishes Timber delivery")
	_check(await _await_state(tomas, "GOING_TO_EAT") and tomas.carried_timber == 0,
		"T4 Timber is deposited before meal trip")
	_check(_timber_total() == timber_initial, "T4 carried Timber conservation exact")

	# T5: sole Builder pauses, eats, resumes; completed project is not revisited.
	await _load_fresh()
	_source.debug_set_stock(0)
	var elia := _by_id("VIL_TEST_003")
	var bren := _by_id("VIL_TEST_004")
	_population.assign_job(bren, Villager.Job.FORAGER)
	_check(await _await_state(elia, "BUILDING"), "T5 Builder reaches active project")
	(elia.get_node("Hunger") as VillagerHunger).hunger_rate = 0.0
	elia.set_hunger(70.0)
	_check(await _await_state(elia, "GOING_TO_EAT"), "T5 active Builder interrupts for meal")
	var paused_progress := _den.progress
	for i in 8:
		await physics_frame
	_check(is_equal_approx(_den.progress, paused_progress), "T5 construction contribution pauses without reset")
	_check(await _await_villager_consumption(1), "T5 Builder eats")
	_check(await _await_state(elia, "BUILDING"), "T5 Builder returns to active construction")
	var resumed_progress := _den.progress
	for i in 4:
		await physics_frame
	_check(_den.progress > resumed_progress, "T5 Builder contribution resumes")

	await _load_fresh()
	bren = _by_id("VIL_TEST_004")
	_check(await _await_state(bren, "BUILDING"), "T5 edge Builder starts construction")
	(bren.get_node("Hunger") as VillagerHunger).hunger_rate = 0.0
	bren.set_hunger(70.0)
	_check(await _await_state(bren, "GOING_TO_EAT"), "T5 edge Builder leaves to eat")
	_den.debug_set_progress(100.0)
	_check(await _await_villager_consumption(1), "T5 edge Builder completes meal")
	_check(await _await_state(bren, "IDLE_PROJECT_COMPLETE"),
		"T5 Builder does not return to completed project")

	# T6: completed Storehouse is the meal target and Housing stays stable.
	await _load_fresh()
	_den.debug_set_progress(100.0)
	_resources.add_timber(20)
	await physics_frame
	_check(await _place_and_complete(BuildModeController.STOREHOUSE_ID, Vector3(0, 0, -3)),
		"T6 completed Storehouse setup")
	_check(await _place_and_complete(BuildModeController.HOUSE_ID, Vector3(10, 0, 18)),
		"T6 completed House setup")
	mara = _by_id("VIL_TEST_001")
	var housing_before := mara.get_housing_label()
	(mara.get_node("Hunger") as VillagerHunger).hunger_rate = 0.0
	mara.set_hunger(70.0)
	_check(await _await_state(mara, "GOING_TO_EAT"), "T6 housed villager seeks meal")
	var storehouse := _build.get_storehouse()
	mara_ai = mara.get_node("AI") as VillagerAI
	_check(mara_ai.get_meal_target() == storehouse and mara.get_destination_label() == "Storehouse",
		"T6 completed Storehouse becomes physical meal destination")
	_check(await _await_villager_consumption(1), "T6 Storehouse meal completes")
	_check(mara.get_housing_label() == housing_before and housing_before == "HOUSE 1",
		"T6 housing assignment survives meal")

	_finish()

func _load_fresh() -> void:
	if _main != null and is_instance_valid(_main):
		_main.queue_free()
		for i in 5:
			await physics_frame
	var packed: PackedScene = load("res://scenes/main.tscn")
	_main = packed.instantiate()
	root.add_child(_main)
	for i in 12:
		await physics_frame
	_population = get_first_node_in_group("population_manager") as PopulationManager
	_resources = get_first_node_in_group("settlement_resources") as SettlementResources
	_source = get_first_node_in_group("food_source") as FoodSource
	_grove = get_first_node_in_group("timber_source") as TimberSource
	_feeding = get_first_node_in_group("feeding_service") as FeedingService
	_selection = get_first_node_in_group("selection_manager") as SelectionManager
	_modes = get_first_node_in_group("control_mode_manager") as ControlModeManager
	_primalis = get_first_node_in_group("primalis") as PrimalisController
	_build = get_first_node_in_group("build_mode") as BuildModeController
	_housing = get_first_node_in_group("housing_manager") as HousingManager
	_den = get_first_node_in_group("construction_project") as ConstructionProject
	_villagers.clear()
	for node in get_nodes_in_group("villager"):
		_villagers.append(node as Villager)
	_villagers.sort_custom(func(a: Villager, b: Villager) -> bool:
		return a.villager_id < b.villager_id)

func _by_id(villager_id: String) -> Villager:
	for villager in _villagers:
		if villager.villager_id == villager_id:
			return villager
	return null

func _is_meal_state(villager: Villager) -> bool:
	return villager.get_state_name() in ["GOING_TO_EAT", "EATING", "WAITING_FOR_FOOD"]

func _await_state(villager: Villager, expected: String, max_ticks := 4000) -> bool:
	for i in max_ticks:
		await physics_frame
		if villager.get_state_name() == expected:
			return true
	return false

func _await_not_meal(villager: Villager, max_ticks := 4000) -> bool:
	for i in max_ticks:
		await physics_frame
		if not _is_meal_state(villager):
			return true
	return false

func _await_job_route(villager: Villager, states: Array, max_ticks := 4000) -> bool:
	for i in max_ticks:
		await physics_frame
		if villager.get_state_name() in states:
			return true
	return false

func _await_villager_consumption(expected: int, max_ticks := 4000) -> bool:
	for i in max_ticks:
		await physics_frame
		if _population.total_food_consumed_by_villagers >= expected:
			return true
	return false

func _set_stored_food(amount: int) -> void:
	while _resources.get_food() > amount:
		_resources.try_spend_food(1)
	if _resources.get_food() < amount:
		_resources.add_food(amount - _resources.get_food())

func _place_and_complete(building_id: StringName, position: Vector3) -> bool:
	if not _build.enter_build_mode(building_id):
		return false
	_build.set_ghost_position(position)
	if not _build.is_ghost_valid() or not _build.try_confirm_placement():
		return false
	var site := _build.get_storehouse() if building_id == BuildModeController.STOREHOUSE_ID \
		else _build.get_houses()[-1]
	site.debug_set_progress(100.0)
	for i in 20:
		await physics_frame
	return site.is_complete()

func _food_total() -> int:
	var carried := 0
	for villager in _villagers:
		carried += villager.carried_food
	return _source.get_remaining() + _resources.get_food() + _feeding.total_food_consumed \
		+ _population.total_food_consumed_by_villagers + carried

func _timber_total() -> int:
	var carried := 0
	for villager in _villagers:
		carried += villager.carried_timber
	return _grove.get_remaining() + _resources.get_timber() + _build.total_timber_spent + carried

func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS  ", label)
	else:
		print("FAIL  ", label)
		_failures.append(label)

func _finish() -> void:
	if _failures.is_empty():
		print("STEP9B HEADLESS: ALL PASS")
		quit(0)
	else:
		print("STEP9B HEADLESS: %d FAILURE(S)" % _failures.size())
		quit(1)
