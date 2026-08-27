extends SceneTree
## Headless functional test for Step 7: Timber, Woodcutters, and the
## player-placed Storehouse. Grounded in physics steps (game-seconds =
## steps * time_scale / 60). Dual conservation invariants (Food + Timber)
## audited throughout; placement exercised via the testable ghost API.

var _failures := PackedStringArray()

var _primalis: PrimalisController
var _manager: SelectionManager
var _modes: ControlModeManager
var _resources: SettlementResources
var _feeding: FeedingService
var _source: FoodSource
var _grove: TimberSource
var _population: PopulationManager
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
	_grove = get_first_node_in_group("timber_source") as TimberSource
	_population = get_first_node_in_group("population_manager") as PopulationManager
	_den = get_first_node_in_group("construction_project") as ConstructionProject
	_build = get_first_node_in_group("build_mode") as BuildModeController
	for node in get_nodes_in_group("villager"):
		_villagers.append(node as Villager)
	_initial_food = _source.get_remaining() + _resources.get_food()
	_initial_timber = _grove.get_remaining() + _resources.get_timber()

	var mara := _by_name("Mara")
	var tomas := _by_name("Tomas")

	# T0: storehouse placement is den-gated (checked at boot, while the
	# initial builders are still working on the den).
	_check(not _den.is_complete(), "T0 den incomplete at boot")
	_check(_build.get_unavailable_reason() == "COMPLETE PRIMALIS DEN FIRST", "T0 gated on den")
	_check(not _build.enter_build_mode(), "T0 enter refused before den completes")

	# T1: timber initialization + API.
	_check(_resources.get_timber() == 0, "T1 stored timber starts 0")
	_check(_grove.get_remaining() == 30, "T1 grove starts 30")
	_resources.add_timber(2)
	_initial_timber += 2
	_check(_resources.get_timber() == 2, "T1 add_timber works")
	_check(not _resources.try_spend_timber(3), "T1 overspend refused")
	_check(_resources.try_spend_timber(2), "T1 spend works")
	_initial_timber -= 2
	_check(_resources.get_timber() == 0, "T1 timber never negative")

	# T2: woodcutter loop — 3 full cycles (spec section 41).
	_population.assign_job(tomas, Villager.Job.WOODCUTTER)
	_check(_population.get_job_count(Villager.Job.WOODCUTTER) == 1, "T2 woodcutter count 1")
	var reached := await _await_state(tomas, "CHOPPING", 4800)
	_check(reached, "T2 Tomas reaches grove and chops")
	var carried_seen := false
	var deposit_pos := Vector3.ZERO
	var deposits := 0
	var grove_before := _grove.get_remaining()
	var timber_before := _resources.get_timber()
	var last_state := tomas.get_state_name()
	var ticks := 0
	while deposits < 3 and ticks < 40000:
		await physics_frame
		ticks += 1
		var st := tomas.get_state_name()
		if st != last_state:
			if st == "GOING_TO_TIMBER_DROP" and tomas.carried_timber == 1:
				carried_seen = true
			if last_state == "DEPOSITING_TIMBER":
				deposits += 1
				deposit_pos = tomas.global_position
			last_state = st
	_check(deposits == 3, "T2 three timber deposit cycles (%d in %d ticks)" % [deposits, ticks])
	_check(carried_seen, "T2 carried_timber observed en route")
	_check(_grove.get_remaining() == grove_before - 3, "T2 grove -3")
	_check(_resources.get_timber() == timber_before + 3, "T2 stored timber +3")
	var yard := (main.get_node("TestWorld/Anchors/MaterialYard") as Node3D).global_position
	_check(Vector2(deposit_pos.x - yard.x, deposit_pos.z - yard.z).length() < 3.0,
		"T2 deposits at material yard (%.1f m)" % Vector2(deposit_pos.x - yard.x, deposit_pos.z - yard.z).length())
	_conservation("T2")

	# T3: three concurrent woodcutters (spec section 42).
	await _set_jobs([Villager.Job.WOODCUTTER, Villager.Job.WOODCUTTER, Villager.Job.WOODCUTTER, Villager.Job.BUILDER])
	var grove_t3 := _grove.get_remaining()
	var stored_t3 := _resources.get_timber()
	var carried_ok := true
	var f0 := Engine.get_physics_frames()
	while (Engine.get_physics_frames() - f0) * Engine.time_scale / 60.0 < 180.0:
		await physics_frame
		for v in _villagers:
			if v.carried_timber < 0 or v.carried_timber > 1 or (v.carried_timber + v.carried_food) > 1:
				carried_ok = false
	_check(carried_ok, "T3 carry limits held (0/1, never both)")
	_check(_grove.get_remaining() >= 0, "T3 grove never negative")
	var chopped := grove_t3 - _grove.get_remaining()
	var gained := _resources.get_timber() - stored_t3
	_check(chopped == gained + _carried_timber_total(), "T3 chopped == deposited + carried (%d = %d + %d)" % [chopped, gained, _carried_timber_total()])
	_check(chopped >= 3, "T3 concurrent production real (%d chops)" % chopped)
	_conservation("T3")

	# T4: job change while carrying timber finishes the delivery first.
	var carrier: Villager = null
	f0 = Engine.get_physics_frames()
	while carrier == null and (Engine.get_physics_frames() - f0) * Engine.time_scale / 60.0 < 240.0:
		await physics_frame
		for v in _villagers:
			if v.job == Villager.Job.WOODCUTTER and v.carried_timber == 1:
				carrier = v
				break
	_check(carrier != null, "T4 found a timber carrier")
	if carrier != null:
		var timber_t4 := _resources.get_timber()
		_population.assign_job(carrier, Villager.Job.FORAGER)
		_check(carrier.get_state_name() == "FINISHING_TIMBER_DELIVERY", "T4 FINISHING_TIMBER_DELIVERY entered")
		var delivered := false
		f0 = Engine.get_physics_frames()
		while (Engine.get_physics_frames() - f0) * Engine.time_scale / 60.0 < 120.0:
			await physics_frame
			if _resources.get_timber() == timber_t4 + 1 and carrier.carried_timber == 0:
				delivered = true
				break
		_check(delivered, "T4 carried timber delivered before job switch")
	_conservation("T4")

	# T5: storehouse unlock gating on timber (den completes naturally or by
	# debug; either way the timber gate must hold).
	if _build.placing:
		_build.cancel_build_mode()
	_den.debug_set_progress(100.0)
	await physics_frame
	_check(_den.is_complete(), "T5 den complete")
	while _resources.get_timber() >= _build.storehouse_cost:
		_check(_resources.try_spend_timber(1), "T5 drain")
		_initial_timber -= 1
	_check(_build.get_unavailable_reason() == "NEED 8 TIMBER", "T5 gated on timber")
	_resources.add_timber(10)
	_initial_timber += 10
	_check(_build.get_unavailable_reason() == "", "T5 unlocked with den + timber")

	# T6: build mode ownership.
	_check(_build.enter_build_mode(), "T6 build mode entered")
	_check(_build.placing, "T6 placing flag set")
	_check(not _manager.is_processing_unhandled_input(), "T6 selection input suspended")
	_check(not _modes.is_processing_unhandled_input(), "T6 possession input suspended (F dead)")

	# T7: placement validity matrix.
	_build.set_ghost_position(Vector3(0, 0, -3))
	_check(_build.is_ghost_valid(), "T7 open ground valid")
	_build.set_ghost_position(Vector3(8, 0, -4))
	_check(not _build.is_ghost_valid(), "T7 inside Rock1 invalid")
	_build.set_ghost_position(Vector3(-10, 0, 16))
	_check(not _build.is_ghost_valid(), "T7 over Den invalid")
	_build.set_ghost_position(Vector3(18, 0, 2))
	_check(not _build.is_ghost_valid(), "T7 over Food Source invalid")
	_build.set_ghost_position(Vector3(-24, 0, 0))
	_check(not _build.is_ghost_valid(), "T7 over Timber Grove invalid")
	_build.set_ghost_position(Vector3(60, 0, 60))
	_check(not _build.is_ghost_valid(), "T7 out of bounds invalid")
	_build.set_ghost_position(Vector3(-2, 0, 10))
	_check(not _build.is_ghost_valid(), "T7 over Feeding Spot invalid")

	# T8: rotation.
	_check(_build.get_ghost_rotation_degrees() == 0, "T8 rotation starts 0")
	_build.rotate_ghost()
	_check(_build.get_ghost_rotation_degrees() == 90, "T8 rotate -> 90")
	_build.rotate_ghost()
	_build.rotate_ghost()
	_build.rotate_ghost()
	_check(_build.get_ghost_rotation_degrees() == 0, "T8 full cycle -> 0")
	_build.rotate_ghost()  # leave at 90 to verify stored rotation on confirm

	# T9: cancel + 30-cycle enter/cancel soak.
	_build.cancel_build_mode()
	_check(not _build.placing, "T9 cancel exits build mode")
	_check(_manager.is_processing_unhandled_input(), "T9 selection restored")
	_check(_modes.is_processing_unhandled_input(), "T9 possession restored")
	var timber_t9 := _resources.get_timber()
	var nodes_t9 := get_node_count()
	for i in 30:
		_check_quiet(_build.enter_build_mode())
		_build.set_ghost_position(Vector3(0, 0, -3))
		_build.cancel_build_mode()
		await physics_frame
	_check(_resources.get_timber() == timber_t9, "T9 soak: zero timber lost")
	_check(get_node_count() == nodes_t9, "T9 soak: node count stable (%d)" % nodes_t9)
	_check(_manager.is_processing_unhandled_input(), "T9 soak: inputs restored after 30 cycles")

	# T10: confirm refused without timber (no spend on failure).
	var stash := _resources.get_timber()
	while _resources.get_timber() >= _build.storehouse_cost:
		_resources.try_spend_timber(1)
		_initial_timber -= 1
	_check(not _build.enter_build_mode(), "T10 enter refused when poor")
	_resources.add_timber(stash)
	_initial_timber += stash

	# T11: valid confirmed placement.
	_check(_build.enter_build_mode(), "T11 re-enter build mode")
	_build.rotate_ghost()  # 90 degrees
	var place_pos := Vector3(0, 0, -3)
	_build.set_ghost_position(place_pos)
	_check(_build.is_ghost_valid(), "T11 placement position valid")
	var timber_pre := _resources.get_timber()
	_check(_build.try_confirm_placement(), "T11 confirm succeeds")
	_check(_resources.get_timber() == timber_pre - 8, "T11 exactly 8 timber spent")
	_check(_build.total_timber_spent == 8, "T11 spend tracked for conservation")
	_check(not _build.placing, "T11 build mode exited")
	_check(_build.has_storehouse_site(), "T11 site exists")
	var site := _build.get_storehouse()
	_check(Vector2(site.global_position.x - place_pos.x, site.global_position.z - place_pos.z).length() < 0.5,
		"T11 site at chosen position")
	_check(absf(fmod(rad_to_deg(site.rotation.y), 360.0) - 90.0) < 1.0, "T11 rotation stored (90 deg)")
	_check(site.get_percent() == 0, "T11 construction starts at 0")
	_conservation("T11")

	# T12: rapid/duplicate confirm protection + single storehouse.
	_check(not _build.try_confirm_placement(), "T12 stray second confirm refused")
	_check(not _build.enter_build_mode(), "T12 second placement refused")
	_check(_build.get_unavailable_reason() == "STOREHOUSE PLACED", "T12 reason: already placed")
	_check(_resources.get_timber() == timber_pre - 8, "T12 no double spend")

	# T13: storehouse construction (active project switches to it).
	await _set_jobs([Villager.Job.FORAGER, Villager.Job.WOODCUTTER, Villager.Job.BUILDER, Villager.Job.BUILDER])
	_check(_build.get_active_project() == site, "T13 storehouse is the active project")
	reached = false
	f0 = Engine.get_physics_frames()
	while (Engine.get_physics_frames() - f0) * Engine.time_scale / 60.0 < 120.0:
		await physics_frame
		var building := 0
		for v in _villagers:
			if v.job == Villager.Job.BUILDER and v.get_state_name() == "BUILDING":
				building += 1
		if building >= 2:
			reached = true
			break
	_check(reached, "T13 builders reach the site and build")
	var p0 := site.progress
	f0 = Engine.get_physics_frames()
	for i in 150:
		await physics_frame
	var game_secs := (Engine.get_physics_frames() - f0) * Engine.time_scale / 60.0
	var rate := (site.progress - p0) / game_secs
	_check(absf(rate - 0.70) < 0.25, "T13 two-builder rate ~0.70/s (got %.2f)" % rate)
	await _set_jobs([Villager.Job.FORAGER, Villager.Job.WOODCUTTER, Villager.Job.FORAGER, Villager.Job.FORAGER])
	for i in 60:
		await physics_frame
	var frozen := site.progress
	for i in 120:
		await physics_frame
	_check(is_equal_approx(site.progress, frozen), "T13 zero builders: frozen at %.1f" % frozen)

	# T14: completion — obstacle activates, navmesh recarves, once-only.
	var completed_count := [0]
	site.completed.connect(func() -> void: completed_count[0] += 1)
	site.debug_set_progress(99.5)
	await _set_jobs([Villager.Job.FORAGER, Villager.Job.WOODCUTTER, Villager.Job.BUILDER, Villager.Job.BUILDER])
	f0 = Engine.get_physics_frames()
	while not site.is_complete() and (Engine.get_physics_frames() - f0) * Engine.time_scale / 60.0 < 180.0:
		await physics_frame
	_check(site.is_complete(), "T14 storehouse completes")
	_check(completed_count[0] == 1, "T14 completed emitted once")
	var obstacle := site.get_node("Obstacle/Shape") as CollisionShape3D
	_check(not obstacle.disabled, "T14 obstacle collider enabled on completion")
	site.contribute(5.0)
	_check(is_equal_approx(site.progress, 100.0), "T14 progress frozen at 100")
	# Nobody may be sealed in / stuck by the collider that activates exactly
	# where builders were standing: every villager in a travelling state must
	# still be making real progress across the world.
	for i in 300:
		await physics_frame
	var start_pos := {}
	var travelling := {}
	for v in _villagers:
		start_pos[v] = v.global_position
		travelling[v] = v.get_state_name().begins_with("GOING_")
	for i in 240:
		await physics_frame
	var stuck := []
	for v in _villagers:
		if travelling[v] and v.get_state_name().begins_with("GOING_"):
			# Still travelling after 4 game-seconds: must have covered ground.
			if v.global_position.distance_to(start_pos[v]) < 0.5:
				stuck.append(v.display_name)
	_check(stuck.is_empty(), "T14 nobody stuck by the new building collider (%s)" % str(stuck))

	# T15: logistics switch to the storehouse.
	await _set_jobs([Villager.Job.FORAGER, Villager.Job.WOODCUTTER, Villager.Job.FORAGER, Villager.Job.WOODCUTTER])
	_reset_food_source(10)
	_reset_grove(10)
	var food_dep := Vector3.ZERO
	var timber_dep := Vector3.ZERO
	var states := {}
	f0 = Engine.get_physics_frames()
	while (food_dep == Vector3.ZERO or timber_dep == Vector3.ZERO) \
			and (Engine.get_physics_frames() - f0) * Engine.time_scale / 60.0 < 420.0:
		await physics_frame
		for v in _villagers:
			var st := v.get_state_name()
			if states.get(v, "") != st:
				if st == "DEPOSITING" and food_dep == Vector3.ZERO:
					food_dep = v.global_position
				if st == "DEPOSITING_TIMBER" and timber_dep == Vector3.ZERO:
					timber_dep = v.global_position
				states[v] = st
	var site_pos := site.global_position
	_check(food_dep != Vector3.ZERO and Vector2(food_dep.x - site_pos.x, food_dep.z - site_pos.z).length() < 6.5,
		"T15 forager deposits at storehouse (%.1f m)" % Vector2(food_dep.x - site_pos.x, food_dep.z - site_pos.z).length())
	_check(timber_dep != Vector3.ZERO and Vector2(timber_dep.x - site_pos.x, timber_dep.z - site_pos.z).length() < 6.5,
		"T15 woodcutter deposits at storehouse (%.1f m)" % Vector2(timber_dep.x - site_pos.x, timber_dep.z - site_pos.z).length())
	_conservation("T15")

	# T16: location consequence — real navmesh path lengths, no fake bonus.
	var map: RID = _primalis.get_world_3d().navigation_map
	var food_pos := (main.get_node("TestWorld/Anchors/FoodSource") as Node3D).global_position
	var grove_pos := (main.get_node("TestWorld/Anchors/TimberGrove") as Node3D).global_position
	var pos_a := Vector3(12, 0, 0)   # near food side
	var pos_b := Vector3(-18, 0, -4)  # near timber side
	var forager_a := _path_len(map, food_pos, pos_a)
	var forager_b := _path_len(map, food_pos, pos_b)
	var wood_a := _path_len(map, grove_pos, pos_a)
	var wood_b := _path_len(map, grove_pos, pos_b)
	_check(forager_a < forager_b - 5.0,
		"T16 forager haul shorter near food (%.1f vs %.1f)" % [forager_a, forager_b])
	_check(wood_b < wood_a - 5.0,
		"T16 woodcutter haul shorter near timber (%.1f vs %.1f)" % [wood_b, wood_a])

	# T17: possession continuity with storehouse logistics live.
	var hunger_node := _primalis.get_hunger_node()
	hunger_node.hunger = 30.0
	var food_p := _resources.get_food()
	var timber_p := _resources.get_timber()
	_manager.select(_primalis)
	_modes.toggle_possession()
	f0 = Engine.get_physics_frames()
	while (Engine.get_physics_frames() - f0) * Engine.time_scale / 60.0 < 60.0:
		await physics_frame
	_check(_modes.mode == ControlModeManager.Mode.DIRECT, "T17 possessed")
	_check(hunger_node.hunger > 30.5, "T17 hunger advanced")
	var advanced := _resources.get_food() > food_p or _resources.get_timber() > timber_p \
		or _carried_food_total() > 0 or _carried_timber_total() > 0
	_check(advanced, "T17 logistics advanced during possession")
	_modes.toggle_possession()
	await physics_frame
	_conservation("T17")

	# T18: 30-game-minute soak with three-job churn and feeding.
	_reset_food_source(15)
	_reset_grove(15)
	Engine.time_scale = 30.0
	var nodes_before := get_node_count()
	var conservation_ok := true
	var bounds_ok := true
	var churn := 0
	var soak_feeds := 0
	var soak_start := Engine.get_physics_frames()
	var next_audit := 0
	var jobs := [Villager.Job.FORAGER, Villager.Job.WOODCUTTER, Villager.Job.BUILDER]
	while (Engine.get_physics_frames() - soak_start) * Engine.time_scale / 60.0 < 1800.0:
		await physics_frame
		var elapsed := int(Engine.get_physics_frames() - soak_start)
		if elapsed >= next_audit:
			next_audit += 20
			if not _conservation_holds():
				conservation_ok = false
			var h := hunger_node.hunger
			if h < 0.0 or h > 100.0 or site.progress > 100.0 or _den.progress > 100.0:
				bounds_ok = false
			if elapsed % 200 == 0:
				var v := _villagers[churn % 4]
				_population.assign_job(v, jobs[churn % 3])
				churn += 1
			if h > 55.0 and _feeding.get_unavailable_reason() == "":
				if _feeding.request_feed():
					soak_feeds += 1
	Engine.time_scale = 8.0
	_check(conservation_ok, "T18 dual conservation held through soak (%d churns)" % churn)
	_check(bounds_ok, "T18 hunger/progress bounds held")
	_check(soak_feeds > 0, "T18 feedings exercised (%d)" % soak_feeds)
	_check(_population.get_population() == 4, "T18 population stable")
	_check(get_node_count() == nodes_before, "T18 node count stable (%d)" % nodes_before)
	_conservation("T18-final")

	_finish()

## --- helpers ------------------------------------------------------------

func _by_name(name_query: String) -> Villager:
	for v in _villagers:
		if v.display_name == name_query:
			return v
	return null

func _set_jobs(jobs: Array) -> void:
	for i in _villagers.size():
		if _villagers[i].job != jobs[i]:
			_population.assign_job(_villagers[i], jobs[i])
	await physics_frame

func _await_state(v: Villager, state_name: String, max_ticks: int) -> bool:
	var ticks := 0
	while ticks < max_ticks:
		await physics_frame
		ticks += 1
		if v.get_state_name() == state_name:
			return true
	return false

func _path_len(map: RID, from: Vector3, to: Vector3) -> float:
	var path := NavigationServer3D.map_get_path(map, from, to, true)
	var total := 0.0
	for i in range(1, path.size()):
		total += path[i - 1].distance_to(path[i])
	return total

func _reset_food_source(value: int) -> void:
	_initial_food += value - _source.get_remaining()
	_source.debug_set_stock(value)

func _reset_grove(value: int) -> void:
	_initial_timber += value - _grove.get_remaining()
	_grove.debug_set_stock(value)

func _carried_food_total() -> int:
	var total := 0
	for v in _villagers:
		total += v.carried_food
	return total

func _carried_timber_total() -> int:
	var total := 0
	for v in _villagers:
		total += v.carried_timber
	return total

func _conservation_holds() -> bool:
	var food_total := _source.get_remaining() + _resources.get_food() \
		+ _feeding.total_food_consumed + _carried_food_total()
	var timber_total := _grove.get_remaining() + _resources.get_timber() \
		+ _build.total_timber_spent + _carried_timber_total()
	return food_total == _initial_food and timber_total == _initial_timber

func _conservation(label: String) -> void:
	var food_total := _source.get_remaining() + _resources.get_food() \
		+ _feeding.total_food_consumed + _carried_food_total()
	var timber_total := _grove.get_remaining() + _resources.get_timber() \
		+ _build.total_timber_spent + _carried_timber_total()
	_check(food_total == _initial_food,
		"%s food conservation == %d (got %d)" % [label, _initial_food, food_total])
	_check(timber_total == _initial_timber,
		"%s timber conservation == %d (got %d)" % [label, _initial_timber, timber_total])

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
		print("STEP7 HEADLESS: ALL PASS")
		quit(0)
	else:
		print("STEP7 HEADLESS: %d FAILURE(S)" % _failures.size())
		quit(1)
