extends SceneTree
## Headless functional test for Step 3 possession.
## Run: Godot_console.exe --headless --path . -s res://tests/step3_headless.gd
## Covers: mode transitions, navigation cancellation on possession, no old
## destination resumption, camera-relative direct movement, sprint, facing,
## stationary orbit, camera ownership, and a 30-cycle possession soak.

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
		await physics_frame

	var primalis := get_first_node_in_group("primalis") as PrimalisController
	var manager := get_first_node_in_group("selection_manager") as SelectionManager
	var modes := get_first_node_in_group("control_mode_manager") as ControlModeManager
	var rts_camera := main.get_node("RTSCamera") as RTSCameraController
	var tp_camera := main.get_node("ThirdPersonCamera") as PrimalisThirdPersonCamera
	var tp_yaw := tp_camera.get_node("YawPivot") as Node3D

	# T1: initial state; F with nothing selected is a safe no-op.
	_check(modes.mode == ControlModeManager.Mode.RTS, "T1 starts in RTS mode")
	modes.toggle_possession()
	_check(modes.mode == ControlModeManager.Mode.RTS, "T1 possession refused with no selection")

	# T2: possess -> ownership handover.
	manager.select(primalis)
	modes.toggle_possession()
	await physics_frame
	var ring := primalis.get_node("Selection/SelectionRing") as MeshInstance3D
	_check(modes.mode == ControlModeManager.Mode.DIRECT, "T2 enters DIRECT mode")
	_check(primalis.control_mode == PrimalisController.ControlMode.DIRECT_CONTROL, "T2 primalis owns DIRECT_CONTROL")
	_check(not manager.has_selection(), "T2 selection cleared on possession")
	_check(not ring.visible, "T2 selection ring hidden")
	_check(not rts_camera.is_processing(), "T2 RTS camera input disabled")
	_check(root.get_camera_3d() == tp_camera.get_camera(), "T2 third-person camera is current")
	modes.toggle_possession()
	await physics_frame
	_check(modes.mode == ControlModeManager.Mode.RTS, "T2 release returns to RTS")
	_check(manager.has_selection(), "T2 primalis auto-selected on release")
	_check(rts_camera.is_processing(), "T2 RTS camera input restored")
	_check(root.get_camera_3d() != tp_camera.get_camera(), "T2 RTS camera is current again")

	# T3: mid-command possession cancels navigation permanently (spec section 22).
	primalis.command_move_to(Vector3(35, 0, 35))
	for i in 60:
		await physics_frame
	_check(primalis.state == PrimalisController.State.MOVING, "T3 navigating before possession")
	modes.toggle_possession()
	await physics_frame
	_check(primalis.state == PrimalisController.State.IDLE, "T3 navigation cancelled on possession")
	for i in 30:
		await physics_frame
	var held_pos := primalis.global_position
	for i in 150:
		await physics_frame
	_check(_flat_dist(primalis.global_position, held_pos) < 0.1, "T3 no creep while possessed and idle")
	modes.toggle_possession()
	for i in 150:
		await physics_frame
	_check(_flat_dist(primalis.global_position, held_pos) < 0.1, "T3 old command NOT resumed after release")
	primalis.command_move_to(Vector3(held_pos.x + 8, 0, held_pos.z))
	var ok := await _await_arrival(primalis, Vector3(held_pos.x + 8, 0, held_pos.z), 3600)
	_check(ok, "T3 fresh RTS command works after release")

	# T4: direct movement — camera-relative, correct speed, clean stop.
	# Teleport to open ground so obstacles cannot skew speed measurements.
	manager.select(primalis)
	modes.toggle_possession()
	primalis.global_position = Vector3(-30, 0.3, -30)
	primalis.velocity = Vector3.ZERO
	await physics_frame
	tp_yaw.rotation.y = 0.0
	Input.action_press("primalis_move_forward")
	for i in 12:
		await physics_frame
	var speed_walk := primalis.get_speed()
	_check(absf(speed_walk - primalis.direct_speed) < 0.4, "T4 walk speed ~%.1f (got %.2f)" % [primalis.direct_speed, speed_walk])
	var v := Vector2(primalis.velocity.x, primalis.velocity.z).normalized()
	_check(v.dot(Vector2(0, -1)) > 0.95, "T4 forward moves along camera -Z (dot %.2f)" % v.dot(Vector2(0, -1)))
	Input.action_release("primalis_move_forward")
	for i in 20:
		await physics_frame
	_check(primalis.get_speed() < 0.15, "T4 decelerates to stop on key release")

	# T5: sprint is physically faster.
	Input.action_press("primalis_move_forward")
	Input.action_press("primalis_sprint")
	for i in 12:
		await physics_frame
	var speed_sprint := primalis.get_speed()
	_check(absf(speed_sprint - primalis.sprint_speed) < 0.4, "T5 sprint speed ~%.1f (got %.2f)" % [primalis.sprint_speed, speed_sprint])
	_check(speed_sprint - speed_walk > 1.5, "T5 sprint meaningfully faster (+%.2f m/s)" % (speed_sprint - speed_walk))
	_check(primalis.get_state_name() == "SPRINTING", "T5 state reads SPRINTING")
	Input.action_release("primalis_move_forward")
	Input.action_release("primalis_sprint")
	for i in 20:
		await physics_frame

	# T6: camera-relative redirection — rotate camera yaw 90 deg, move forward.
	tp_yaw.rotation.y = PI / 2.0
	Input.action_press("primalis_move_forward")
	for i in 12:
		await physics_frame
	var v2 := Vector2(primalis.velocity.x, primalis.velocity.z).normalized()
	var expected := Vector2(-sin(PI / 2.0), -cos(PI / 2.0))  # -Z of yaw basis
	_check(v2.dot(expected) > 0.95, "T6 movement follows rotated camera (dot %.2f)" % v2.dot(expected))
	Input.action_release("primalis_move_forward")
	for i in 20:
		await physics_frame

	# T7: stationary camera orbit must not rotate Primalis.
	var facing_before := primalis.rotation.y
	for i in 60:
		tp_yaw.rotation.y += TAU / 60.0
		await physics_frame
	_check(absf(angle_difference(primalis.rotation.y, facing_before)) < 0.01, "T7 stationary orbit leaves facing unchanged")
	_check(is_finite(tp_camera.global_position.x), "T7 camera position finite (no NaN)")

	# T-COL: run head-on into the west border ridge — must not pass through.
	primalis.global_position = Vector3(-55, 0.3, -30)
	primalis.velocity = Vector3.ZERO
	await physics_frame
	tp_yaw.rotation.y = PI / 2.0  # forward = -X, straight at the ridge
	Input.action_press("primalis_move_forward")
	for i in 150:
		await physics_frame
	_check(primalis.global_position.x > -58.6, "T-COL body stopped by border (x %.2f, wall face -58.8)" % primalis.global_position.x)
	_check(primalis.get_speed() < 0.5, "T-COL velocity killed against wall (%.2f m/s)" % primalis.get_speed())
	Input.action_release("primalis_move_forward")
	for i in 30:
		await physics_frame

	# T8: 30 possession cycles with movement, sprint, and RTS commands.
	modes.toggle_possession()
	await physics_frame
	var nodes_before := get_node_count()
	var cycle_failures := 0
	for cycle in 30:
		manager.select(primalis)
		modes.toggle_possession()
		Input.action_press("primalis_move_forward")
		if cycle % 2 == 0:
			Input.action_press("primalis_sprint")
		for i in 25:
			await physics_frame
		Input.action_release("primalis_move_forward")
		Input.action_release("primalis_sprint")
		modes.toggle_possession()
		await physics_frame
		if modes.mode != ControlModeManager.Mode.RTS:
			cycle_failures += 1
		if not manager.has_selection():
			cycle_failures += 1
		if root.get_camera_3d() == tp_camera.get_camera():
			cycle_failures += 1
		primalis.command_move_to(primalis.global_position + Vector3(2, 0, 0))
		for i in 20:
			await physics_frame
	var nodes_after := get_node_count()
	_check(cycle_failures == 0, "T8 soak: 30 possession cycles clean (%d faults)" % cycle_failures)
	_check(nodes_after == nodes_before, "T8 soak: node count stable (%d -> %d)" % [nodes_before, nodes_after])

	# T9: Step 2 RTS behaviour intact after all the switching.
	for i in 120:
		await physics_frame
	var target := Vector3(-20, 0, -20)
	primalis.command_move_to(target)
	ok = await _await_arrival(primalis, target, 4800)
	_check(ok, "T9 RTS navigation fully functional after soak")

	_finish()

func _flat_dist(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()

func _await_arrival(p: PrimalisController, dest: Vector3, max_ticks: int) -> bool:
	var ticks := 0
	while ticks < max_ticks:
		await physics_frame
		ticks += 1
		if p.state == PrimalisController.State.IDLE:
			return _flat_dist(p.global_position, dest) < ARRIVE_TOLERANCE
	return false

func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS  ", label)
	else:
		print("FAIL  ", label)
		_failures.append(label)

func _finish() -> void:
	if _failures.is_empty():
		print("STEP3 HEADLESS: ALL PASS")
		quit(0)
	else:
		print("STEP3 HEADLESS: %d FAILURE(S)" % _failures.size())
		quit(1)
