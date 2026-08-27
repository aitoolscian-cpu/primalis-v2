extends SceneTree
## Focused Step 9A coverage: individual data, time-based growth, status bands,
## aggregate query, control-mode continuity, and deliberate AI non-integration.

var _failures := PackedStringArray()
var _main: Node
var _villagers: Array[Villager] = []
var _population: PopulationManager
var _selection: SelectionManager
var _modes: ControlModeManager
var _primalis: PrimalisController
var _build: BuildModeController
var _den: ConstructionProject
var _resources: SettlementResources

func _initialize() -> void:
	_run()

func _run() -> void:
	paused = true
	var packed: PackedScene = load("res://scenes/main.tscn")
	_main = packed.instantiate()
	root.add_child(_main)
	await process_frame
	_collect_nodes()

	var expected := {
		"VIL_TEST_001": 35.0,
		"VIL_TEST_002": 42.0,
		"VIL_TEST_003": 28.0,
		"VIL_TEST_004": 48.0,
	}
	var starts_match := _villagers.size() == 4
	for villager in _villagers:
		starts_match = starts_match and is_equal_approx(
			villager.get_hunger(), float(expected.get(villager.villager_id, -1.0)))
	_check(starts_match, "T1 four deterministic starting Hunger values")

	paused = false
	Engine.time_scale = 8.0
	Engine.max_physics_steps_per_frame = 240
	var mara := _by_id("VIL_TEST_001")
	mara.set_hunger(10.0)
	var start_frame := Engine.get_physics_frames()
	for i in 30:
		await physics_frame
	var elapsed := (Engine.get_physics_frames() - start_frame) * Engine.time_scale \
		/ float(Engine.physics_ticks_per_second)
	var expected_hunger := 10.0 + 0.12 * elapsed
	_check(absf(mara.get_hunger() - expected_hunger) < 0.03,
		"T2 Hunger rises at approximately 0.12 per simulation second")

	mara.set_hunger(150.0)
	_check(is_equal_approx(mara.get_hunger(), 100.0), "T3 Hunger clamps at 100")
	mara.set_hunger(-20.0)
	_check(is_equal_approx(mara.get_hunger(), 0.0), "T3 Hunger clamps at 0")

	var bands := {
		0.0: "FED", 24.0: "FED", 25.0: "PECKISH", 49.0: "PECKISH",
		50.0: "HUNGRY", 69.0: "HUNGRY", 70.0: "VERY HUNGRY",
		89.0: "VERY HUNGRY", 90.0: "STARVING", 100.0: "STARVING",
	}
	var bands_match := true
	for boundary in bands:
		mara.set_hunger(boundary)
		bands_match = bands_match and mara.get_hunger_status() == bands[boundary]
	_check(bands_match, "T4 all Hunger status boundaries")

	var count_values := [49.9, 50.0, 69.0, 100.0]
	for i in _villagers.size():
		_villagers[i].set_hunger(count_values[i])
	_check(_population.get_hungry_count() == 3, "T5 Hungry count uses Hunger >= 50")

	var jobs := {}
	for villager in _villagers:
		jobs[villager.villager_id] = villager.job
		villager.set_hunger(100.0)
	for i in 30:
		await physics_frame
	var jobs_unchanged := true
	for villager in _villagers:
		jobs_unchanged = jobs_unchanged and villager.job == jobs[villager.villager_id]
	_check(jobs_unchanged, "T6 Hunger 100 does not change villager jobs")

	for villager in _villagers:
		villager.set_hunger(10.0)
	var nodes_before := get_node_count()
	_selection.select(_primalis)
	_modes.toggle_possession()
	var direct_before := mara.get_hunger()
	for i in 30:
		await physics_frame
	_check(_modes.is_direct() and mara.get_hunger() > direct_before,
		"T7 Hunger advances during Primalis direct control")
	_modes.toggle_possession()

	_den.debug_set_progress(100.0)
	_resources.add_timber(20)
	await physics_frame
	var build_entered := _build.enter_build_mode(BuildModeController.HOUSE_ID)
	var build_before := mara.get_hunger()
	for i in 30:
		await physics_frame
	_check(build_entered and _build.placing and mara.get_hunger() > build_before,
		"T8 Hunger advances during build mode")
	_build.cancel_build_mode()
	await physics_frame
	_check(get_node_count() == nodes_before, "T9 control-mode soak leaves node count stable")

	_finish()

func _collect_nodes() -> void:
	_population = _main.get_node("PopulationManager") as PopulationManager
	_selection = _main.get_node("SelectionManager") as SelectionManager
	_modes = _main.get_node("ControlModeManager") as ControlModeManager
	_primalis = _main.get_node("TestWorld/Primalis") as PrimalisController
	_build = _main.get_node("BuildModeController") as BuildModeController
	_den = _main.get_node("TestWorld/Anchors/DenSite") as ConstructionProject
	_resources = _main.get_node("SettlementResources") as SettlementResources
	for node_name in ["Villager", "Villager2", "Villager3", "Villager4"]:
		_villagers.append(_main.get_node("TestWorld/" + node_name) as Villager)
	_villagers.sort_custom(func(a: Villager, b: Villager) -> bool:
		return a.villager_id < b.villager_id)

func _by_id(villager_id: String) -> Villager:
	for villager in _villagers:
		if villager.villager_id == villager_id:
			return villager
	return null

func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS  ", label)
	else:
		print("FAIL  ", label)
		_failures.append(label)

func _finish() -> void:
	if _failures.is_empty():
		print("STEP9A HEADLESS: ALL PASS")
		quit(0)
	else:
		print("STEP9A HEADLESS: %d FAILURE(S)" % _failures.size())
		quit(1)
