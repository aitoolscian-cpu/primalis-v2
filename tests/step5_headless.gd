extends SceneTree
## Headless functional test for Step 5: Food -> Hunger -> Feed loop.
## Run: Godot_console.exe --headless --path . -s res://tests/step5_headless.gd
## Includes the resource conservation invariant and a 20-game-minute soak.

const ARRIVE_TOLERANCE := 2.0

var _failures := PackedStringArray()

var _villager: Villager
var _primalis: PrimalisController
var _manager: SelectionManager
var _modes: ControlModeManager
var _resources: SettlementResources
var _feeding: FeedingService
var _source: FoodSource
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

	_villager = get_first_node_in_group("villager") as Villager
	_primalis = get_first_node_in_group("primalis") as PrimalisController
	_manager = get_first_node_in_group("selection_manager") as SelectionManager
	_modes = get_first_node_in_group("control_mode_manager") as ControlModeManager
	_resources = get_first_node_in_group("settlement_resources") as SettlementResources
	_feeding = get_first_node_in_group("feeding_service") as FeedingService
	_source = get_first_node_in_group("food_source") as FoodSource
	# Step 6 evolution: multiple villagers exist. Keep Step 5's economics
	# exact by making Mara the sole Forager for this suite.
	var population := get_first_node_in_group("population_manager") as PopulationManager
	for v in get_nodes_in_group("villager"):
		if v != _villager:
			population.assign_job(v as Villager, Villager.Job.BUILDER)
	_initial_total = _source.get_remaining() + _resources.get_food()

	# T1: resource manager basics.
	_check(_resources.get_food() == 3, "T1 starting food is 3")
	var signal_count := [0]
	_resources.food_changed.connect(func(_a: int) -> void: signal_count[0] += 1)
	_resources.add_food(2)
	_check(_resources.get_food() == 5, "T1 add_food works")
	_check(_resources.try_spend_food(5), "T1 try_spend_food succeeds")
	_check(not _resources.try_spend_food(1), "T1 overspend refused")
	_check(_resources.get_food() == 0, "T1 food never negative")
	_check(signal_count[0] == 2, "T1 food_changed emitted per successful mutation (%d)" % signal_count[0])
	_resources.add_food(3)  # restore baseline for later tests

	# T2: source basics.
	_check(_source.get_remaining() == 20, "T2 source starts at 20")
	_check(_source.try_harvest(), "T2 harvest succeeds")
	_check(_source.get_remaining() == 19, "T2 harvest decrements")
	# Manual harvest leaves the world model: count it as consumed externally.
	_initial_total -= 1
	_conservation("T2")

	# T3: Mara production loop — 3 deposits: food 3 -> 6, source 19 -> 16.
	var food_before := _resources.get_food()
	var source_before := _source.get_remaining()
	var deposits := 0
	var carried_seen := false
	var carried_cleared := true
	var last_state := _villager.get_state_name()
	var ticks := 0
	while deposits < 3 and ticks < 40000:
		await physics_frame
		ticks += 1
		var st := _villager.get_state_name()
		if st != last_state:
			if st == "GOING_TO_STORE":
				carried_seen = carried_seen or _villager.carried_food == 1
			if last_state == "DEPOSITING":
				deposits += 1
				if _villager.carried_food != 0:
					carried_cleared = false
			last_state = st
	_check(deposits == 3, "T3 three deposit cycles completed (%d in %d ticks)" % [deposits, ticks])
	_check(_resources.get_food() == food_before + 3, "T3 stored food +3 (deposit-only)")
	_check(_source.get_remaining() == source_before - 3, "T3 source -3")
	_check(carried_seen, "T3 carrying state observed en route to store")
	_check(carried_cleared, "T3 carrying cleared after deposit")
	_conservation("T3")

	# T4: hunger rate, clamp, mode independence.
	# time_scale multiplies per-step delta, so expected gain is derived from
	# the actual physics steps elapsed: steps * ts / 60 * rate.
	var hunger_node := _primalis.get_hunger_node()
	hunger_node.hunger = 30.0
	var f0 := Engine.get_physics_frames()
	for i in 300:
		await physics_frame
	var game_secs := (Engine.get_physics_frames() - f0) * Engine.time_scale / 60.0
	var expected := game_secs * hunger_node.get_effective_rate()
	var gained := hunger_node.hunger - 30.0
	_check(absf(gained - expected) < 0.5, "T4 hunger rate: %.2f over %.1f game-s (expected %.2f)" % [gained, game_secs, expected])
	_manager.select(_primalis)
	_modes.toggle_possession()
	hunger_node.hunger = 30.0
	for i in 300:
		await physics_frame
	_check(hunger_node.hunger > 30.0 + expected * 0.5, "T4 hunger continues while possessed (+%.2f)" % (hunger_node.hunger - 30.0))
	_modes.toggle_possession()
	await physics_frame
	var saved := hunger_node.hunger
	hunger_node.hunger = 99.5
	for i in 120:
		await physics_frame
	_check(hunger_node.hunger == 100.0, "T4 hunger clamps at 100")
	hunger_node.hunger = saved

	# T5: full feeding transaction.
	while _resources.get_food() < _feeding.feed_cost:
		_resources.add_food(1)
		_initial_total += 1  # external top-up enters the model
	hunger_node.hunger = 60.0
	var food_pre := _resources.get_food()
	var hunger_pre := hunger_node.hunger
	_manager.select(_primalis)
	_check(_feeding.request_feed(), "T5 feed request accepted")
	_check(_primalis.get_state_name() == "GOING_TO_FEED", "T5 state GOING_TO_FEED")
	var saw_feeding := false
	ticks = 0
	while _primalis.state != PrimalisController.State.IDLE and ticks < 4800:
		await physics_frame
		ticks += 1
		if _primalis.state == PrimalisController.State.FEEDING:
			saw_feeding = true
	_check(saw_feeding, "T5 FEEDING state observed")
	_check(_primalis.state == PrimalisController.State.IDLE, "T5 returns to IDLE")
	_check(_resources.get_food() == food_pre - _feeding.feed_cost, "T5 food -%d" % _feeding.feed_cost)
	_check(absf(hunger_node.hunger - (hunger_pre - _feeding.hunger_reduction)) < 2.5,
		"T5 hunger reduced ~%.0f" % _feeding.hunger_reduction)
	var spot := (main.get_node("TestWorld/Anchors/FeedingSpot") as Node3D).global_position
	_check(Vector2(_primalis.global_position.x - spot.x, _primalis.global_position.z - spot.z).length() < 2.5,
		"T5 ate at the feeding spot")
	_conservation("T5")

	# T6: insufficient food refused.
	while _resources.get_food() >= _feeding.feed_cost:
		_check(_resources.try_spend_food(1), "T6 drain")
		_initial_total -= 1
	hunger_node.hunger = 60.0
	_check(not _feeding.request_feed(), "T6 feed refused without food")
	_check(_feeding.get_unavailable_reason() == "NOT ENOUGH FOOD", "T6 reason NOT ENOUGH FOOD")
	_check(_primalis.state == PrimalisController.State.IDLE, "T6 primalis stays put")
	_check(_resources.get_food() >= 0, "T6 food non-negative")

	# T7: command cancellation mid-travel.
	# Park Primalis far from the spot first so the feed request involves
	# genuine travel (T5 finished with him standing at the trough).
	_resources.add_food(3)
	_initial_total += 3
	_primalis.command_move_to(Vector3(14, 0, -10))
	var ok := await _await_idle(_primalis, 3600)
	_check(ok, "T7 pre-park away from spot")
	var consumed_t7 := _feeding.total_food_consumed
	_check(_feeding.request_feed(), "T7 feed request accepted (%s)" % _feeding.get_unavailable_reason())
	for i in 20:
		await physics_frame
	_check(_primalis.get_state_name() == "GOING_TO_FEED", "T7 travelling to feed")
	_primalis.command_move_to(_primalis.global_position + Vector3(-6, 0, -6))
	_check(_primalis.get_state_name() == "MOVING", "T7 move command cancels feed")
	ok = await _await_idle(_primalis, 3600)
	_check(ok, "T7 normal move completes")
	_check(_feeding.total_food_consumed == consumed_t7, "T7 no food consumed on cancel")

	# T8: possession cancellation mid-travel; no resume after release.
	hunger_node.hunger = 60.0
	var consumed_t8 := _feeding.total_food_consumed
	_manager.select(_primalis)
	_check(_feeding.request_feed(), "T8 feed request accepted (%s)" % _feeding.get_unavailable_reason())
	for i in 20:
		await physics_frame
	_check(_primalis.get_state_name() == "GOING_TO_FEED", "T8 travelling to feed")
	_modes.toggle_possession()
	await physics_frame
	_check(_modes.mode == ControlModeManager.Mode.DIRECT, "T8 possession cancels feed travel")
	_check(_feeding.total_food_consumed == consumed_t8, "T8 no food consumed on possession cancel")
	_modes.toggle_possession()
	for i in 150:
		await physics_frame
	_check(_primalis.state == PrimalisController.State.IDLE, "T8 cancelled feed does not resume")
	_conservation("T8")

	# T9: 20-game-minute soak — production + hunger + repeated feedings +
	# natural source exhaustion. Conservation checked continuously.
	Engine.time_scale = 30.0
	var nodes_before := get_node_count()
	var deposits_soak := 0
	last_state = _villager.get_state_name()
	var conservation_ok := true
	var hunger_ok := true
	var soak_feeds := 0
	# Accelerated exhaustion (allowed by spec): pre-drain the source so its
	# depletion falls inside the 20-game-minute window. Externally removed
	# units leave the closed model.
	while _source.get_remaining() > 10:
		if _source.try_harvest():
			_initial_total -= 1
	# 1200 game-seconds: steps * time_scale / 60 game-secs elapse per step,
	# so at ts=30 the soak spans 2,400 physics steps (~40s wall).
	var soak_start := Engine.get_physics_frames()
	var next_audit := 0
	var next_progress := 0
	while (Engine.get_physics_frames() - soak_start) * Engine.time_scale / 60.0 < 1200.0:
		await physics_frame
		var elapsed := int(Engine.get_physics_frames() - soak_start)
		if elapsed >= next_progress:
			print("SOAK step ", elapsed, " game-s ", int(elapsed * Engine.time_scale / 60.0))
			next_progress += 600
		var st := _villager.get_state_name()
		if st != last_state:
			if last_state == "DEPOSITING":
				deposits_soak += 1
			last_state = st
		if elapsed >= next_audit:
			next_audit += 20
			if not _conservation_holds():
				conservation_ok = false
			var h := hunger_node.hunger
			if h < 0.0 or h > 100.0:
				hunger_ok = false
			# Player-like behaviour: feed whenever hungry and affordable.
			if h > 55.0 and _feeding.get_unavailable_reason() == "":
				if _feeding.request_feed():
					soak_feeds += 1
	Engine.time_scale = 8.0
	# Let her finish the in-flight leg and settle into the no-work state.
	var settle := 0
	while _villager.get_state_name() != "IDLE_NO_WORK" and settle < 2400:
		await physics_frame
		settle += 1
	_check(conservation_ok, "T9 conservation held through soak")
	_check(hunger_ok, "T9 hunger stayed in [0,100]")
	_check(deposits_soak > 0, "T9 Mara kept producing (%d deposits)" % deposits_soak)
	_check(soak_feeds > 0, "T9 multiple feedings exercised (%d)" % soak_feeds)
	_check(_source.is_empty(), "T9 source exhausted naturally (remaining %d)" % _source.get_remaining())
	_check(_villager.get_state_name() == "IDLE_NO_WORK" or last_state == "IDLE_NO_WORK",
		"T9 Mara settled in IDLE_NO_WORK (state %s)" % _villager.get_state_name())
	_check(get_node_count() == nodes_before, "T9 node count stable (%d)" % nodes_before)
	_conservation("T9-final")

	_finish()

func _conservation_holds() -> bool:
	var total := _source.get_remaining() + _resources.get_food() \
		+ _feeding.total_food_consumed + _villager.carried_food
	return total == _initial_total

func _conservation(label: String) -> void:
	var total := _source.get_remaining() + _resources.get_food() \
		+ _feeding.total_food_consumed + _villager.carried_food
	_check(total == _initial_total,
		"%s conservation: source+stored+consumed+carried == %d (got %d)" % [label, _initial_total, total])

func _await_idle(p: PrimalisController, max_ticks: int) -> bool:
	var ticks := 0
	while ticks < max_ticks:
		await physics_frame
		ticks += 1
		if p.state == PrimalisController.State.IDLE:
			return true
	return false

func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS  ", label)
	else:
		print("FAIL  ", label)
		_failures.append(label)

func _finish() -> void:
	if _failures.is_empty():
		print("STEP5 HEADLESS: ALL PASS")
		quit(0)
	else:
		print("STEP5 HEADLESS: %d FAILURE(S)" % _failures.size())
		quit(1)
