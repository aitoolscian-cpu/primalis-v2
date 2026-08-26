extends SceneTree
## Headless functional test for Step 6: population, job assignment, and the
## Primalis Den construction project. Grounded in physics steps (game-seconds
## = steps * time_scale / 60). Conservation sums carried Food over ALL
## villagers; construction integrity asserted throughout.

var _failures := PackedStringArray()

var _primalis: PrimalisController
var _manager: SelectionManager
var _modes: ControlModeManager
var _resources: SettlementResources
var _feeding: FeedingService
var _source: FoodSource
var _population: PopulationManager
var _den: ConstructionProject
var _villagers: Array[Villager] = []
var _initial_total := 0

func _initialize() -> void:
	_run()

func _run() -> void:
	Engine.time_scale = 8.0
	Engine.max_physics_steps_per_frame = 240
	var packed: PackedScene = load("res://scenes/main.tscn")
	var main: Node = packed.instantiate()
	root.add_child(main)
	for i in 10:
		await physics_frame

	_primalis = get_first_node_in_group("primalis") as PrimalisController
	_manager = get_first_node_in_group("selection_manager") as SelectionManager
	_modes = get_first_node_in_group("control_mode_manager") as ControlModeManager
	_resources = get_first_node_in_group("settlement_resources") as SettlementResources
	_feeding = get_first_node_in_group("feeding_service") as FeedingService
	_source = get_first_node_in_group("food_source") as FoodSource
	_population = get_first_node_in_group("population_manager") as PopulationManager
	_den = get_first_node_in_group("construction_project") as ConstructionProject
	for node in get_nodes_in_group("villager"):
		_villagers.append(node as Villager)
	_initial_total = _source.get_remaining() + _resources.get_food()

	# T1: population integrity.
	_check(_population.get_population() == 4, "T1 population is 4")
	_check(_villagers.size() == 4, "T1 four villagers in world")
	var ids := {}
	var names_ok := true
	var positions_distinct := true
	for v in _villagers:
		ids[v.villager_id] = true
		if v.display_name.is_empty():
			names_ok = false
		for other in _villagers:
			if other != v and v.global_position.distance_to(other.global_position) < 0.5:
				positions_distinct = false
	_check(ids.size() == 4, "T1 four unique IDs")
	_check(names_ok, "T1 all names populated")
	_check(positions_distinct, "T1 villagers not stacked at one point")
	_check(_population.get_job_count(Villager.Job.FORAGER) == 2, "T1 initial foragers 2")
	_check(_population.get_job_count(Villager.Job.BUILDER) == 2, "T1 initial builders 2")

	var mara := _by_name("Mara")
	var tomas := _by_name("Tomas")
	var elia := _by_name("Elia")
	var bren := _by_name("Bren")
	_check(mara != null and tomas != null and elia != null and bren != null, "T1 named villagers found")

	# T2: assignment changes counts, signal fires, behavior follows.
	var signal_count := [0]
	_population.jobs_changed.connect(func() -> void: signal_count[0] += 1)
	_population.assign_job(tomas, Villager.Job.BUILDER)
	_check(signal_count[0] == 1, "T2 jobs_changed emitted")
	_check(_population.get_job_count(Villager.Job.FORAGER) == 1, "T2 foragers now 1")
	_check(_population.get_job_count(Villager.Job.BUILDER) == 3, "T2 builders now 3")
	_check(tomas.get_job_name() == "BUILDER", "T2 Tomas job label updated")
	var reached := await _await_state(tomas, "BUILDING", 3600)
	_check(reached, "T2 Tomas physically reaches den and builds")
	_population.assign_job(tomas, Villager.Job.FORAGER)
	_check(_population.get_job_count(Villager.Job.FORAGER) == 2, "T2 reverse: foragers 2")
	reached = await _await_state_any(tomas, ["GOING_TO_SOURCE", "GATHERING"], 2400)
	_check(reached, "T2 reverse: Tomas re-enters food loop")
	_conservation("T2")

	# T3: builder scaling — progress rate scales ~linearly with N builders.
	# Measure with every villager parked in BUILDING except the off-duty ones
	# held as foragers; windows are step-based.
	var rates: Array[float] = []
	for n in [1, 2, 3, 4]:
		_den.debug_set_progress(5.0)
		await _set_builders(n)
		var ok := await _await_builders_building(n, 4800)
		_check(ok, "T3 %d builder(s) reached BUILDING" % n)
		var before := _den.progress
		var f0 := Engine.get_physics_frames()
		for i in 150:
			await physics_frame
		var game_secs := (Engine.get_physics_frames() - f0) * Engine.time_scale / 60.0
		var rate := (_den.progress - before) / game_secs
		rates.append(rate)
	_check(absf(rates[0] - _den.rate_per_builder) < 0.08, "T3 single-builder rate ~%.2f/s (got %.3f)" % [_den.rate_per_builder, rates[0]])
	var linear := true
	for n in [2, 3, 4]:
		var ratio: float = rates[n - 1] / rates[0]
		if absf(ratio - float(n)) > 0.6:
			linear = false
	_check(linear, "T3 scaling ~linear (rates %.2f / %.2f / %.2f / %.2f)" % [rates[0], rates[1], rates[2], rates[3]])

	# T3b: zero builders => zero progress.
	_den.debug_set_progress(10.0)
	await _set_builders(0)
	for i in 60:
		await physics_frame
	var frozen := _den.progress
	for i in 120:
		await physics_frame
	_check(is_equal_approx(_den.progress, frozen), "T3b zero builders: progress frozen at %.1f" % frozen)

	# T4: mid-build reassignment never resets progress.
	_den.debug_set_progress(20.0)
	await _set_builders(1)
	await _await_builders_building(1, 4800)
	var progress_before := _den.progress
	var the_builder := _first_with_job(Villager.Job.BUILDER)
	_population.assign_job(the_builder, Villager.Job.FORAGER)
	for i in 120:
		await physics_frame
	_check(_den.progress >= progress_before and _den.progress < progress_before + 0.5,
		"T4 reassign stops contribution, no reset (%.1f -> %.1f)" % [progress_before, _den.progress])
	_check(not _den.is_complete(), "T4 den still incomplete (test validity)")

	# T5: concurrent foragers — safe finite harvesting (3 foragers).
	_reset_source(15)
	await _set_builders(1)  # 3 foragers, 1 builder
	var source_before := _source.get_remaining()
	var food_before := _resources.get_food()
	var carried_ok := true
	var deposits := [0]
	_resources.food_changed.connect(func(_a: int) -> void: deposits[0] += 1)
	var f0 := Engine.get_physics_frames()
	while (Engine.get_physics_frames() - f0) * Engine.time_scale / 60.0 < 180.0:
		await physics_frame
		for v in _villagers:
			if v.carried_food < 0 or v.carried_food > 1:
				carried_ok = false
	_check(carried_ok, "T5 every carried_food stayed in {0,1}")
	_check(_source.get_remaining() >= 0, "T5 source never negative")
	var harvested := source_before - _source.get_remaining()
	var gained := _resources.get_food() - food_before
	_check(harvested == gained + _carried_total(), "T5 every harvest is deposited or in transit (%d = %d + %d)" % [harvested, gained, _carried_total()])
	_check(harvested >= 3, "T5 multiple foragers actually produced (%d harvests)" % harvested)
	_conservation("T5")

	# T6: mid-carry reassignment finishes the delivery first.
	_reset_source(12)
	var carrier: Villager = null
	f0 = Engine.get_physics_frames()
	while carrier == null and (Engine.get_physics_frames() - f0) * Engine.time_scale / 60.0 < 240.0:
		await physics_frame
		for v in _villagers:
			if v.job == Villager.Job.FORAGER and v.carried_food == 1:
				carrier = v
				break
	_check(carrier != null, "T6 found a carrying forager")
	if carrier != null:
		var food_t6 := _resources.get_food()
		_population.assign_job(carrier, Villager.Job.BUILDER)
		_check(carrier.get_job_name() == "BUILDER", "T6 job label flips immediately")
		_check(carrier.get_state_name() == "FINISHING_DELIVERY", "T6 enters FINISHING_DELIVERY")
		var delivered := false
		f0 = Engine.get_physics_frames()
		while (Engine.get_physics_frames() - f0) * Engine.time_scale / 60.0 < 120.0:
			await physics_frame
			if _resources.get_food() == food_t6 + 1 and carrier.carried_food == 0:
				delivered = true
				break
		_check(delivered, "T6 carried unit deposited before switching")
		reached = await _await_state_any(carrier, ["GOING_TO_BUILD", "BUILDING"], 1200)
		_check(reached, "T6 then heads to the den")
	_conservation("T6")

	# T7: den visual thresholds + completion + integrity.
	await _set_builders(0)
	for i in 30:
		await physics_frame
	var frame_node := _den.get_node("Frame") as Node3D
	var walls_node := _den.get_node("Walls") as Node3D
	var roof_node := _den.get_node("Roof") as Node3D
	_den.debug_set_progress(24.0)
	await physics_frame
	_check(not frame_node.visible, "T7 24%: frame hidden")
	_den.debug_set_progress(25.0)
	await physics_frame
	_check(frame_node.visible and not walls_node.visible, "T7 25%: frame visible")
	_den.debug_set_progress(50.0)
	await physics_frame
	_check(walls_node.visible and not roof_node.visible, "T7 50%: walls visible")
	_den.debug_set_progress(75.0)
	await physics_frame
	_check(roof_node.visible, "T7 75%: roof visible")
	var completed_count := [0]
	_den.completed.connect(func() -> void: completed_count[0] += 1)
	_den.debug_set_progress(99.5)
	await _set_builders(2)
	await _await_builders_building(0, 4800)  # builders flip to IDLE_PROJECT_COMPLETE on completion
	f0 = Engine.get_physics_frames()
	while not _den.is_complete() and (Engine.get_physics_frames() - f0) * Engine.time_scale / 60.0 < 120.0:
		await physics_frame
	_check(_den.is_complete(), "T7 den completes")
	_check(is_equal_approx(_den.progress, 100.0), "T7 progress clamped at 100")
	_check(completed_count[0] == 1, "T7 completed emitted exactly once")
	var locked := _den.progress
	_den.contribute(5.0)
	_den.debug_set_progress(50.0)
	_check(is_equal_approx(_den.progress, locked), "T7 progress frozen after completion")
	var settled := true
	for i in 600:
		await physics_frame
	for v in _villagers:
		if v.job == Villager.Job.BUILDER and v.get_state_name() != "IDLE_PROJECT_COMPLETE":
			settled = false
	_check(settled, "T7 builders settle into IDLE_PROJECT_COMPLETE")

	# T8: den gameplay effect — hunger growth reduced by exactly 10%.
	var hunger_node := _primalis.get_hunger_node()
	_check(hunger_node.has_shelter_bonus(), "T8 shelter bonus active after completion")
	_check(absf(hunger_node.get_effective_rate() - hunger_node.rate_per_second * 0.9) < 0.0001,
		"T8 effective rate is 90%% of base (%.4f)" % hunger_node.get_effective_rate())
	hunger_node.hunger = 30.0
	f0 = Engine.get_physics_frames()
	for i in 300:
		await physics_frame
	var game_secs := (Engine.get_physics_frames() - f0) * Engine.time_scale / 60.0
	var expected := game_secs * hunger_node.get_effective_rate()
	_check(absf((hunger_node.hunger - 30.0) - expected) < 0.5,
		"T8 measured growth matches reduced rate (+%.2f over %.0f game-s)" % [hunger_node.hunger - 30.0, game_secs])

	# T9: possession continuity — all systems advance while possessed.
	await _set_builders(0)  # everyone forages
	var food_p := _resources.get_food()
	hunger_node.hunger = 30.0
	_manager.select(_primalis)
	_modes.toggle_possession()
	f0 = Engine.get_physics_frames()
	while (Engine.get_physics_frames() - f0) * Engine.time_scale / 60.0 < 60.0:
		await physics_frame
	_check(_modes.mode == ControlModeManager.Mode.DIRECT, "T9 still possessed")
	_check(hunger_node.hunger > 30.5, "T9 hunger advanced while possessed")
	_check(_resources.get_food() > food_p or _carried_total() > 0 or _source.is_empty(),
		"T9 food loop advanced while possessed")
	_modes.toggle_possession()
	await physics_frame
	_conservation("T9")

	# T10: the allocation tradeoff, both extremes.
	# All foragers: den frozen (already complete here, so assert food flow).
	await _set_builders(0)
	_check(_population.get_job_count(Villager.Job.FORAGER) == 4, "T10 all-forager split 4/0")
	# All builders: food production stops entirely.
	await _set_builders(4)
	_check(_population.get_job_count(Villager.Job.BUILDER) == 4, "T10 all-builder split 0/4")
	# Wait for any in-flight deliveries (FINISHING_DELIVERY) to settle.
	f0 = Engine.get_physics_frames()
	while _carried_total() > 0 and (Engine.get_physics_frames() - f0) * Engine.time_scale / 60.0 < 120.0:
		await physics_frame
	var food_locked := _resources.get_food()
	var hunger_t10 := hunger_node.hunger
	f0 = Engine.get_physics_frames()
	while (Engine.get_physics_frames() - f0) * Engine.time_scale / 60.0 < 90.0:
		await physics_frame
	_check(_resources.get_food() == food_locked, "T10 all-builders: food production stopped")
	_check(hunger_node.hunger > hunger_t10, "T10 hunger keeps rising (pressure)")
	# Reassign to foragers: production resumes (resource-pressure recovery).
	_reset_source(10)
	await _set_builders(0)
	var food_recover := _resources.get_food()
	f0 = Engine.get_physics_frames()
	while _resources.get_food() == food_recover and (Engine.get_physics_frames() - f0) * Engine.time_scale / 60.0 < 240.0:
		await physics_frame
	_check(_resources.get_food() > food_recover, "T10 reassigned foragers resume production")
	_conservation("T10")

	# T11: 30-game-minute soak with job churn and feeding.
	_reset_source(20)
	Engine.time_scale = 30.0
	var nodes_before := get_node_count()
	var conservation_ok := true
	var integrity_ok := true
	var churn := 0
	var soak_feeds := 0
	var soak_start := Engine.get_physics_frames()
	var next_audit := 0
	while (Engine.get_physics_frames() - soak_start) * Engine.time_scale / 60.0 < 1800.0:
		await physics_frame
		var elapsed := int(Engine.get_physics_frames() - soak_start)
		if elapsed >= next_audit:
			next_audit += 20
			if not _conservation_holds():
				conservation_ok = false
			if _den.progress < 0.0 or _den.progress > 100.0:
				integrity_ok = false
			var h := hunger_node.hunger
			if h < 0.0 or h > 100.0:
				integrity_ok = false
			# Periodic churn: rotate a villager's job; feed when sensible.
			if elapsed % 200 == 0:
				var v := _villagers[churn % 4]
				_population.assign_job(v, Villager.Job.BUILDER if v.job == Villager.Job.FORAGER else Villager.Job.FORAGER)
				churn += 1
			if h > 55.0 and _feeding.get_unavailable_reason() == "":
				if _feeding.request_feed():
					soak_feeds += 1
	Engine.time_scale = 8.0
	_check(conservation_ok, "T11 conservation held through soak (%d churns)" % churn)
	_check(integrity_ok, "T11 den/hunger bounds held")
	_check(soak_feeds > 0, "T11 feedings exercised (%d)" % soak_feeds)
	_check(_population.get_population() == 4, "T11 no duplicate/lost villagers")
	_check(get_node_count() == nodes_before, "T11 node count stable (%d)" % nodes_before)
	_conservation("T11-final")

	_finish()

## Conservation-safe source refill: the delta enters the closed model.
func _reset_source(value: int) -> void:
	_initial_total += value - _source.get_remaining()
	_source.debug_set_stock(value)

func _by_name(name_query: String) -> Villager:
	for v in _villagers:
		if v.display_name == name_query:
			return v
	return null

func _first_with_job(job: Villager.Job) -> Villager:
	for v in _villagers:
		if v.job == job:
			return v
	return null

## Assign exactly n villagers as builders (the first n), rest foragers.
func _set_builders(n: int) -> void:
	for i in _villagers.size():
		var want := Villager.Job.BUILDER if i < n else Villager.Job.FORAGER
		if _villagers[i].job != want:
			_population.assign_job(_villagers[i], want)
	await physics_frame

func _await_builders_building(n: int, max_ticks: int) -> bool:
	var ticks := 0
	while ticks < max_ticks:
		await physics_frame
		ticks += 1
		var building := 0
		for v in _villagers:
			if v.get_state_name() == "BUILDING":
				building += 1
		if building == n and n > 0:
			return true
		if n == 0:
			return true
	return false

func _await_state(v: Villager, state_name: String, max_ticks: int) -> bool:
	var ticks := 0
	while ticks < max_ticks:
		await physics_frame
		ticks += 1
		if v.get_state_name() == state_name:
			return true
	return false

func _await_state_any(v: Villager, names: Array, max_ticks: int) -> bool:
	var ticks := 0
	while ticks < max_ticks:
		await physics_frame
		ticks += 1
		if names.has(v.get_state_name()):
			return true
	return false

func _carried_total() -> int:
	var total := 0
	for v in _villagers:
		total += v.carried_food
	return total

func _conservation_holds() -> bool:
	var total := _source.get_remaining() + _resources.get_food() \
		+ _feeding.total_food_consumed + _carried_total()
	return total == _initial_total

func _conservation(label: String) -> void:
	var total := _source.get_remaining() + _resources.get_food() \
		+ _feeding.total_food_consumed + _carried_total()
	_check(total == _initial_total,
		"%s conservation: source+stored+consumed+carried == %d (got %d)" % [label, _initial_total, total])

func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS  ", label)
	else:
		print("FAIL  ", label)
		_failures.append(label)

func _finish() -> void:
	if _failures.is_empty():
		print("STEP6 HEADLESS: ALL PASS")
		quit(0)
	else:
		print("STEP6 HEADLESS: %d FAILURE(S)" % _failures.size())
		quit(1)
