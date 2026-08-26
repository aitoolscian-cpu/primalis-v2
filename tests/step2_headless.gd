extends SceneTree
## Headless functional test for the Step 2 sandbox.
## Run: Godot_console.exe --headless --path . -s res://tests/step2_headless.gd
## Covers: navigation arrival, mid-move retarget, obstacle avoidance,
## selection API, and a 30-command soak with node-leak detection.

const ARRIVE_TOLERANCE := 1.5

var _failures := PackedStringArray()

func _initialize() -> void:
	_run()

func _run() -> void:
	Engine.time_scale = 8.0
	var packed: PackedScene = load("res://scenes/main.tscn")
	var main: Node = packed.instantiate()
	root.add_child(main)
	for i in 10:
		await physics_frame  # navmesh bake + map sync

	var primalis := get_first_node_in_group("primalis") as PrimalisController
	var manager := get_first_node_in_group("selection_manager") as SelectionManager
	_check(primalis != null, "T1 primalis exists")
	_check(manager != null, "T1 selection manager exists")
	if primalis == null or manager == null:
		_finish()
		return
	_check(primalis.state == PrimalisController.State.IDLE, "T1 starts IDLE")

	# T2: basic move command arrives.
	primalis.command_move_to(Vector3(20, 0, 20))
	_check(primalis.state == PrimalisController.State.MOVING, "T2 enters MOVING on command")
	var ok := await _await_arrival(primalis, Vector3(20, 0, 20), 3600)
	_check(ok, "T2 arrives at basic destination")

	# T3: retarget mid-move.
	primalis.command_move_to(Vector3(-24, 0, -18))
	for i in 40:
		await physics_frame
	_check(primalis.state == PrimalisController.State.MOVING, "T3 still moving before retarget")
	primalis.command_move_to(Vector3(24, 0, -20))
	ok = await _await_arrival(primalis, Vector3(24, 0, -20), 4200)
	_check(ok, "T3 arrives at retargeted destination")

	# T4: obstacle avoidance. Route crosses Rock1 at (8, _, -4).
	primalis.command_move_to(Vector3(0, 0, 4))
	await _await_arrival(primalis, Vector3(0, 0, 4), 4200)
	var min_rock_dist := 1e9
	primalis.command_move_to(Vector3(16, 0, -12))
	var ticks := 0
	while primalis.state == PrimalisController.State.MOVING and ticks < 4200:
		await physics_frame
		ticks += 1
		var d := Vector2(primalis.global_position.x - 8.0, primalis.global_position.z + 4.0).length()
		min_rock_dist = minf(min_rock_dist, d)
	var arrived := Vector2(primalis.global_position.x - 16.0, primalis.global_position.z + 12.0).length() < ARRIVE_TOLERANCE
	_check(arrived, "T4 arrives across the obstacle")
	_check(min_rock_dist > 1.9, "T4 routes around Rock1 (min dist %.2f m)" % min_rock_dist)

	# T5: selection API + ring visibility.
	var ring := primalis.get_node("Selection/SelectionRing") as MeshInstance3D
	manager.select(primalis)
	_check(manager.has_selection(), "T5 select() registers selection")
	_check(ring.visible, "T5 selection ring becomes visible")
	manager.deselect_all()
	_check(not manager.has_selection(), "T5 deselect_all() clears selection")
	_check(not ring.visible, "T5 selection ring hides")

	# T6: 30-command soak; node count must not grow.
	var nodes_before := get_node_count()
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260826
	var soak_failures := 0
	for i in 30:
		var target := Vector3(rng.randf_range(-40, 40), 0, rng.randf_range(-40, 40))
		manager.select(primalis)
		primalis.command_move_to(target)
		if not await _await_arrival(primalis, target, 4800):
			soak_failures += 1
		manager.deselect_all()
	var nodes_after := get_node_count()
	_check(soak_failures == 0, "T6 soak: all 30 commands arrived (%d failed)" % soak_failures)
	_check(nodes_after == nodes_before, "T6 soak: node count stable (%d -> %d)" % [nodes_before, nodes_after])

	# T7: command marker resolves, flashes, and auto-hides.
	var marker := manager.command_marker
	_check(marker != null, "T7 command marker path resolves")
	if marker != null:
		marker.flash_at(Vector3(5, 0, 5))
		await physics_frame
		_check(marker.visible, "T7 marker visible after flash")
		for i in 90:
			await physics_frame
		_check(not marker.visible, "T7 marker auto-hides after lifetime")

	_finish()

func _await_arrival(p: PrimalisController, dest: Vector3, max_ticks: int) -> bool:
	var ticks := 0
	while ticks < max_ticks:
		await physics_frame
		ticks += 1
		if p.state == PrimalisController.State.IDLE:
			return Vector2(p.global_position.x - dest.x, p.global_position.z - dest.z).length() < ARRIVE_TOLERANCE
	return false

func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS  ", label)
	else:
		print("FAIL  ", label)
		_failures.append(label)

func _finish() -> void:
	if _failures.is_empty():
		print("STEP2 HEADLESS: ALL PASS")
		quit(0)
	else:
		print("STEP2 HEADLESS: %d FAILURE(S)" % _failures.size())
		quit(1)
