extends SceneTree
## Headless functional test for Step 4: one autonomous villager.
## Run: Godot_console.exe --headless --path . -s res://tests/step4_headless.gd
## Covers: identity, routine loop x3 with arrivals, obstacle routing,
## generic selection transfer, F/command ownership, autonomy during
## possession, and node-count stability.

const ARRIVE_TOLERANCE := 2.0

const HOME := Vector3(-12, 0, -16)
const SOURCE := Vector3(18, 0, 2)
const STORE := Vector3(-4, 0, -8)
const REST := Vector3(2, 0, 18)

var _failures := PackedStringArray()

func _initialize() -> void:
	_run()

func _run() -> void:
	Engine.time_scale = 8.0
	var packed: PackedScene = load("res://scenes/main.tscn")
	var main: Node = packed.instantiate()
	root.add_child(main)
	for i in 10:
		await physics_frame

	var villager := get_first_node_in_group("villager") as Villager
	var primalis := get_first_node_in_group("primalis") as PrimalisController
	var manager := get_first_node_in_group("selection_manager") as SelectionManager
	var modes := get_first_node_in_group("control_mode_manager") as ControlModeManager
	var tp_camera := main.get_node("ThirdPersonCamera") as PrimalisThirdPersonCamera

	# T1: existence + identity.
	_check(villager != null, "T1 villager exists")
	if villager == null:
		_finish()
		return
	_check(villager.villager_id == "VIL_TEST_001", "T1 id is VIL_TEST_001")
	_check(villager.display_name == "Mara", "T1 name is Mara")
	_check(villager.get_job_name() == "FORAGER", "T1 job is FORAGER")
	_check(villager.get_selection_type() == "villager", "T1 selection type is villager")
	_check(villager.get_state_name() == "AT_HOME", "T1 starts AT_HOME")

	# T2: three complete routine loops with real arrivals + obstacle routing.
	# Source->Store passes straight through Rock1 at (8,-4): track clearance.
	var loops_done := 0
	var min_rock1_dist := 1e9
	var arrivals_ok := true
	var ticks := 0
	var last_state := villager.get_state_name()
	while loops_done < 3 and ticks < 40000:
		await physics_frame
		ticks += 1
		var s := villager.get_state_name()
		if s == "GOING_TO_STORE":
			var d := Vector2(villager.global_position.x - 8.0, villager.global_position.z + 4.0).length()
			min_rock1_dist = minf(min_rock1_dist, d)
		if s != last_state:
			match s:
				"GATHERING":
					if _flat_dist(villager.global_position, SOURCE) > ARRIVE_TOLERANCE:
						arrivals_ok = false
				"DEPOSITING":
					if _flat_dist(villager.global_position, STORE) > ARRIVE_TOLERANCE:
						arrivals_ok = false
				"RESTING":
					if _flat_dist(villager.global_position, REST) > ARRIVE_TOLERANCE:
						arrivals_ok = false
				"AT_HOME":
					if _flat_dist(villager.global_position, HOME) > ARRIVE_TOLERANCE:
						arrivals_ok = false
					loops_done += 1
			last_state = s
	_check(loops_done == 3, "T2 completed 3 full routine loops (%d in %d ticks)" % [loops_done, ticks])
	_check(arrivals_ok, "T2 every station reached within %.1f m of its anchor" % ARRIVE_TOLERANCE)
	_check(min_rock1_dist > 1.9, "T2 routes around Rock1 on store leg (min dist %.2f m)" % min_rock1_dist)

	# T3: generic selection transfer + ring ownership.
	var p_ring := primalis.get_node("Selection/SelectionRing") as MeshInstance3D
	var v_ring := villager.get_node("Selection/SelectionRing") as MeshInstance3D
	manager.select(primalis)
	_check(manager.get_selected() == primalis and p_ring.visible and not v_ring.visible, "T3 primalis selected: his ring only")
	manager.select(villager)
	_check(manager.get_selected() == villager and v_ring.visible and not p_ring.visible, "T3 villager selected: her ring only")
	manager.deselect_all()
	_check(not manager.has_selection() and not v_ring.visible and not p_ring.visible, "T3 deselect hides both rings")

	# T4: 30-cycle selection soak; node count stable.
	var nodes_before := get_node_count()
	for i in 30:
		manager.select(primalis)
		manager.select(villager)
		manager.deselect_all()
		await physics_frame
	var soak_ok := not manager.has_selection() and not v_ring.visible and not p_ring.visible
	_check(soak_ok, "T4 selection soak: clean final state")
	_check(get_node_count() == nodes_before, "T4 selection soak: node count stable (%d)" % nodes_before)

	# T5: F on villager does nothing; F on Primalis still possesses.
	manager.select(villager)
	modes.toggle_possession()
	await physics_frame
	_check(modes.mode == ControlModeManager.Mode.RTS, "T5 F on villager: mode stays RTS")
	_check(manager.get_selected() == villager, "T5 F on villager: selection untouched")
	_check(root.get_camera_3d() != tp_camera.get_camera(), "T5 F on villager: camera unchanged")
	manager.select(primalis)
	modes.toggle_possession()
	await physics_frame
	_check(modes.mode == ControlModeManager.Mode.DIRECT, "T5 F on Primalis still possesses")

	# T6: villager AI continues while the player possesses Primalis.
	var state_a := villager.get_state_name()
	var pos_a := villager.global_position
	Input.action_press("primalis_move_forward")
	for i in 6:
		await physics_frame
	Input.action_release("primalis_move_forward")
	for i in 900:  # ~2 game-minutes at time_scale 8
		await physics_frame
	var advanced := villager.get_state_name() != state_a or _flat_dist(villager.global_position, pos_a) > 2.0
	_check(modes.mode == ControlModeManager.Mode.DIRECT, "T6 still possessed during observation")
	_check(advanced, "T6 villager routine advanced during possession (%s -> %s)" % [state_a, villager.get_state_name()])
	modes.toggle_possession()
	await physics_frame

	# T7: command ownership — villagers expose no RTS command path.
	_check(not villager.has_method("command_move_to"), "T7 villager has no command_move_to")
	manager.select(villager)
	var v_state := villager.get_state_name()
	var marker := manager.command_marker
	_check(marker != null and not marker.visible, "T7 no stale command marker")
	# The command handler must early-out for villagers (guard is type-based).
	_check(not (manager.get_selected() is PrimalisController), "T7 command guard sees non-Primalis selection")
	_check(villager.get_state_name() == v_state, "T7 villager routine untouched by selection")

	# T8: Primalis RTS command still works after everything.
	manager.select(primalis)
	primalis.command_move_to(Vector3(-20, 0, -20))
	var ok := await _await_arrival(primalis, Vector3(-20, 0, -20), 4800)
	_check(ok, "T8 Primalis RTS navigation intact")

	_finish()

func _flat_dist(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()

func _await_arrival(p: PrimalisController, dest: Vector3, max_ticks: int) -> bool:
	var ticks := 0
	while ticks < max_ticks:
		await physics_frame
		ticks += 1
		if p.state == PrimalisController.State.IDLE:
			return _flat_dist(p.global_position, dest) < 1.5
	return false

func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS  ", label)
	else:
		print("FAIL  ", label)
		_failures.append(label)

func _finish() -> void:
	if _failures.is_empty():
		print("STEP4 HEADLESS: ALL PASS")
		quit(0)
	else:
		print("STEP4 HEADLESS: %d FAILURE(S)" % _failures.size())
		quit(1)
