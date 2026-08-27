extends SceneTree
## Focused Step 9C integration coverage: Primalis and villagers contend for
## one authoritative Food pool, settle atomically, conserve exactly, and can
## recover through ordinary Forager work when at least one worker can operate.

var _failures := PackedStringArray()
var _main: Node
var _villagers: Array[Villager] = []
var _population: PopulationManager
var _resources: SettlementResources
var _source: FoodSource
var _feeding: FeedingService
var _selection: SelectionManager
var _modes: ControlModeManager
var _primalis: PrimalisController
var _food_store: Node3D
var _feeding_spot: Node3D

func _initialize() -> void:
	_run()

func _run() -> void:
	Engine.time_scale = 8.0
	Engine.max_physics_steps_per_frame = 240

	# T1: both consumers reference one authoritative pool; Primalis may take
	# the last three Food while a hungry villager is already approaching it.
	await _load_fresh()
	var mara := _by_id("VIL_TEST_001")
	_set_stored_food(3)
	_source.debug_set_stock(0)
	var initial := _food_total()
	mara.set_hunger(70.0)
	_check(await _await_state(mara, "GOING_TO_EAT"),
		"T1 hungry villager is approaching shared Food")
	_place_primalis_at_feeding_spot()
	_check(_feeding.get("_resources") == _resources
		and (mara.get_node("AI") as VillagerAI).get("_resources") == _resources,
		"T1 Primalis and villager use the same SettlementResources instance")
	_check(_feeding.feed_cost == 3 and _feeding.request_feed(),
		"T1 Primalis feed request accepts the last 3 Food")
	_check(await _await_primalis_consumption(3), "T1 Primalis feed completes")
	_check(await _await_state(mara, "WAITING_FOR_FOOD"),
		"T1 villager cannot reuse Food consumed by Primalis")
	_check(_resources.get_food() == 0 and _feeding.total_food_consumed == 3
		and _population.total_food_consumed_by_villagers == 0
		and mara.get_hunger() >= 70.0,
		"T1 last-3 result is exact with hungry villager still waiting")
	_conservation(initial, "T1")

	# T2: a villager finishes first. The already-started Primalis transaction
	# revalidates at completion, fails wholly, and never partially spends.
	await _load_fresh()
	mara = _by_id("VIL_TEST_001")
	_set_stored_food(3)
	_source.debug_set_stock(0)
	initial = _food_total()
	_place_at_food_store(mara, Vector3.ZERO)
	mara.set_hunger(70.0)
	_check(await _await_state(mara, "EATING"), "T2 villager begins actual meal")
	_place_primalis_at_feeding_spot()
	_check(_feeding.request_feed() and await _await_primalis_state("FEEDING"),
		"T2 Primalis feed starts while 3 Food are available")
	(mara.get_node("AI") as VillagerAI).set("_timer", 0.05)
	_primalis.set("_feed_timer", 0.75)
	_check(await _await_villager_consumption(1), "T2 villager atomically spends first")
	_check(await _await_primalis_state("IDLE"), "T2 Primalis transaction finishes cleanly")
	_check(_resources.get_food() == 2 and _feeding.total_food_consumed == 0
		and _population.total_food_consumed_by_villagers == 1
		and is_equal_approx(_primalis.get_hunger(), 60.0),
		"T2 villager leaves 2; Primalis feed has no partial spend or benefit")
	_conservation(initial, "T2")

	# T3: reverse near-completion race, followed by the four-Food/two-villager
	# ordering. Only transactions that can pay in full report success.
	await _load_fresh()
	mara = _by_id("VIL_TEST_001")
	_set_stored_food(3)
	_source.debug_set_stock(0)
	initial = _food_total()
	_place_at_food_store(mara, Vector3.ZERO)
	mara.set_hunger(70.0)
	_check(await _await_state(mara, "EATING"), "T3A villager meal is nearly complete")
	_place_primalis_at_feeding_spot()
	_check(_feeding.request_feed() and await _await_primalis_state("FEEDING"),
		"T3A Primalis feed is also nearly complete")
	_primalis.set("_feed_timer", 0.05)
	(mara.get_node("AI") as VillagerAI).set("_timer", 0.75)
	_check(await _await_primalis_consumption(3), "T3A Primalis wins completion ordering")
	_check(await _await_state(mara, "WAITING_FOR_FOOD"),
		"T3A losing villager reports no phantom meal")
	_check(_resources.get_food() == 0 and _feeding.total_food_consumed == 3
		and _population.total_food_consumed_by_villagers == 0,
		"T3A final stock and accounting are exact")
	_conservation(initial, "T3A")

	await _load_fresh()
	mara = _by_id("VIL_TEST_001")
	var tomas := _by_id("VIL_TEST_002")
	_set_stored_food(4)
	_source.debug_set_stock(0)
	initial = _food_total()
	_place_at_food_store(mara, Vector3(-0.25, 0.0, 0.0))
	_place_at_food_store(tomas, Vector3(0.25, 0.0, 0.0))
	mara.set_hunger(70.0)
	tomas.set_hunger(70.0)
	_check(await _await_state(mara, "EATING") and await _await_state(tomas, "EATING"),
		"T3B two hungry villagers contend with Primalis")
	_place_primalis_at_feeding_spot()
	_check(_feeding.request_feed() and await _await_primalis_state("FEEDING"),
		"T3B Primalis joins four-Food contention")
	(mara.get_node("AI") as VillagerAI).set("_timer", 0.05)
	_primalis.set("_feed_timer", 0.45)
	(tomas.get_node("AI") as VillagerAI).set("_timer", 0.85)
	_check(await _await_villager_consumption(1), "T3B first villager spends one Food")
	_check(await _await_primalis_consumption(3), "T3B Primalis then spends the remaining three")
	_check(await _await_state(tomas, "WAITING_FOR_FOOD"),
		"T3B second villager loses safely")
	_check(_resources.get_food() == 0 and _feeding.total_food_consumed == 3
		and _population.total_food_consumed_by_villagers == 1,
		"T3B no negative stock, duplicate spend, or phantom success")
	_conservation(initial, "T3B")

	# T4: scarcity recovers naturally while Primalis is possessed, provided
	# one non-hungry Forager remains able to perform the ordinary job loop.
	await _load_fresh()
	_source.debug_set_stock(3)
	_set_stored_food(0)
	initial = _food_total()
	mara = _by_id("VIL_TEST_001")
	var waiters: Array[Villager] = []
	for villager in _villagers:
		if villager != mara:
			villager.set_hunger(70.0)
			waiters.append(villager)
	_check(await _await_waiting_count(3), "T4 three villagers wait at Food=0")
	var saw_positive_deposit := [false]
	_resources.food_changed.connect(func(amount: int) -> void:
		if amount > 0:
			saw_positive_deposit[0] = true)
	var nodes_before := get_node_count()
	_selection.select(_primalis)
	_modes.toggle_possession()
	_check(_modes.is_direct(), "T4 Primalis possession active during scarcity")
	_check(await _await_villager_consumption(1, 6000),
		"T4 actual Forager deposit lets a waiting villager eat")
	var resumed := false
	for villager in waiters:
		if await _await_not_meal(villager, 1200):
			resumed = true
			break
	_check(saw_positive_deposit[0], "T4 new Food arrived through ordinary Forager behavior")
	_check(resumed, "T4 fed worker returns to the assigned job")
	_check(_modes.is_direct() and get_node_count() == nodes_before,
		"T4 settlement simulation and node count remain stable during possession")
	_conservation(initial, "T4")
	_modes.toggle_possession()

	# T5: report the real edge case without adding rescue rules. If everyone
	# is already waiting, changing a waiter's job cannot make that worker eat.
	await _load_fresh()
	_source.debug_set_stock(3)
	_set_stored_food(0)
	for villager in _villagers:
		_population.assign_job(villager, Villager.Job.BUILDER)
		villager.set_hunger(70.0)
	_check(_population.get_job_count(Villager.Job.FORAGER) == 0
		and await _await_waiting_count(4), "T5 zero-Forager village reaches all-waiting state")
	var source_locked := _source.get_remaining()
	for i in 120:
		await physics_frame
	_check(_resources.get_food() == 0 and _source.get_remaining() == source_locked,
		"T5 no Food appears while every villager waits")
	mara = _by_id("VIL_TEST_001")
	_population.assign_job(mara, Villager.Job.FORAGER)
	for i in 120:
		await physics_frame
	_check(mara.job == Villager.Job.FORAGER and mara.get_state_name() == "WAITING_FOR_FOOD"
		and _resources.get_food() == 0 and _source.get_remaining() == source_locked,
		"T5 reassignment alone cannot break the complete hungry-village lock")
	_conservation(source_locked, "T5")

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
	_feeding = get_first_node_in_group("feeding_service") as FeedingService
	_selection = get_first_node_in_group("selection_manager") as SelectionManager
	_modes = get_first_node_in_group("control_mode_manager") as ControlModeManager
	_primalis = get_first_node_in_group("primalis") as PrimalisController
	_food_store = _main.get_node("TestWorld/Anchors/FoodStore") as Node3D
	_feeding_spot = _main.get_node("TestWorld/Anchors/FeedingSpot") as Node3D
	_villagers.clear()
	for node in get_nodes_in_group("villager"):
		_villagers.append(node as Villager)
	_villagers.sort_custom(func(a: Villager, b: Villager) -> bool:
		return a.villager_id < b.villager_id)
	for villager in _villagers:
		(villager.get_node("Hunger") as VillagerHunger).hunger_rate = 0.0
		villager.set_hunger(0.0)
	var primalis_hunger := _primalis.get_hunger_node()
	primalis_hunger.rate_per_second = 0.0
	primalis_hunger.hunger = 60.0

func _by_id(villager_id: String) -> Villager:
	for villager in _villagers:
		if villager.villager_id == villager_id:
			return villager
	return null

func _place_at_food_store(villager: Villager, offset: Vector3) -> void:
	villager.global_position = _food_store.global_position + offset
	villager.velocity = Vector3.ZERO

func _place_primalis_at_feeding_spot() -> void:
	_primalis.global_position = _feeding_spot.global_position
	_primalis.velocity = Vector3.ZERO

func _await_state(villager: Villager, expected: String, max_ticks := 4000) -> bool:
	for i in max_ticks:
		await physics_frame
		if villager.get_state_name() == expected:
			return true
	return false

func _await_not_meal(villager: Villager, max_ticks := 4000) -> bool:
	for i in max_ticks:
		await physics_frame
		if villager.get_state_name() not in ["GOING_TO_EAT", "EATING", "WAITING_FOR_FOOD"]:
			return true
	return false

func _await_waiting_count(expected: int, max_ticks := 4000) -> bool:
	for i in max_ticks:
		await physics_frame
		var count := 0
		for villager in _villagers:
			if villager.get_state_name() == "WAITING_FOR_FOOD":
				count += 1
		if count >= expected:
			return true
	return false

func _await_primalis_state(expected: String, max_ticks := 4000) -> bool:
	for i in max_ticks:
		await physics_frame
		if _primalis.get_state_name() == expected:
			return true
	return false

func _await_primalis_consumption(expected: int, max_ticks := 4000) -> bool:
	for i in max_ticks:
		await physics_frame
		if _feeding.total_food_consumed >= expected:
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

func _carried_food_total() -> int:
	var total := 0
	for villager in _villagers:
		total += villager.carried_food
	return total

func _food_total() -> int:
	return _source.get_remaining() + _resources.get_food() \
		+ _feeding.total_food_consumed \
		+ _population.total_food_consumed_by_villagers + _carried_food_total()

func _conservation(expected: int, label: String) -> void:
	var actual := _food_total()
	_check(actual == expected,
		"%s exact Food conservation: source+stored+Primalis+villagers+carried == %d (got %d)" % [
			label, expected, actual])

func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS  ", label)
	else:
		print("FAIL  ", label)
		_failures.append(label)

func _finish() -> void:
	if _failures.is_empty():
		print("STEP9C HEADLESS: ALL PASS")
		quit(0)
	else:
		print("STEP9C HEADLESS: %d FAILURE(S)" % _failures.size())
		quit(1)
