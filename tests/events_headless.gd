extends SceneTree
## Isolated headless coverage for the event/petition data and runtime framework.

const HUNGRY_PATH := "res://data/events/test/evt_test_hungry_primalis.tres"
const OUTSIDERS_PATH := "res://data/events/test/evt_test_outsiders.tres"
const OUTSIDERS_RETURN_PATH := "res://data/events/test/evt_test_outsiders_return.tres"

var _failures := PackedStringArray()
var _checks := 0


func _initialize() -> void:
	_run()


func _run() -> void:
	_test_authored_resources_and_registry()
	_test_conditions()
	_test_eligibility_choice_and_safety()
	_test_priority_and_one_active_policy()
	_test_followup_and_delayed_effects()
	_test_history_and_repeatability()
	_test_event_seen_condition()
	_test_snapshot_restore()
	_test_validation_failures()
	_test_architectural_isolation_and_node_stability()
	_test_performance_sanity()
	_finish()


func _test_authored_resources_and_registry() -> void:
	var hungry := load(HUNGRY_PATH) as EventDefinition
	var outsiders := load(OUTSIDERS_PATH) as EventDefinition
	var outsiders_return := load(OUTSIDERS_RETURN_PATH) as EventDefinition
	_check(hungry != null and outsiders != null and outsiders_return != null, "T1 authored test Resources load")
	if hungry == null or outsiders == null or outsiders_return == null:
		return
	_check(hungry.event_id == &"EVT_TEST_HUNGRY_PRIMALIS", "T1 EventDefinition fields deserialize")
	_check(hungry.choices.size() == 2 and hungry.choices[0].effects.size() == 2, "T1 EventChoice and EventEffect arrays deserialize")
	_check(outsiders_return.trigger_mode == EventDefinition.TriggerMode.SCHEDULED_ONLY, "T1 follow-up is scheduled-only")

	var registry := EventRegistry.new()
	_check(registry.register_definition(hungry), "T1 registry accepts hungry definition")
	_check(registry.register_definition(outsiders), "T1 registry accepts outsiders definition")
	_check(registry.register_definition(outsiders_return), "T1 registry accepts follow-up definition")
	_check(registry.get_definition(&"EVT_TEST_OUTSIDERS") == outsiders, "T1 registry retrieves by event_id")
	_check(registry.get_all_definitions().size() == 3, "T1 registry lists definitions")
	_check(registry.validate_all().is_empty(), "T1 fully loaded sample registry validates")


func _test_conditions() -> void:
	var context := {
		"number": 10,
		"same": "yes",
		"flag": false,
	}
	_check(_condition("same", EventCondition.Comparison.EQUAL, "yes").evaluate(context), "T2 EQUAL comparison")
	_check(_condition("same", EventCondition.Comparison.NOT_EQUAL, "no").evaluate(context), "T2 NOT_EQUAL comparison")
	_check(_condition("number", EventCondition.Comparison.GREATER_THAN, 9).evaluate(context), "T2 GREATER_THAN comparison")
	_check(_condition("number", EventCondition.Comparison.GREATER_OR_EQUAL, 10.0).evaluate(context), "T2 GREATER_OR_EQUAL comparison")
	_check(_condition("number", EventCondition.Comparison.LESS_THAN, 11).evaluate(context), "T2 LESS_THAN comparison")
	_check(_condition("number", EventCondition.Comparison.LESS_OR_EQUAL, 10).evaluate(context), "T2 LESS_OR_EQUAL comparison")
	_check(_condition("flag", EventCondition.Comparison.EQUAL, false).evaluate(context), "T2 boolean equality")
	_check(not _condition("missing", EventCondition.Comparison.EQUAL, true).evaluate(context), "T2 missing context key safely fails")
	_check(not _condition("same", EventCondition.Comparison.GREATER_THAN, "a").evaluate(context), "T2 ordered nonnumeric comparison safely fails")


func _test_eligibility_choice_and_safety() -> void:
	var registry := _sample_registry()
	var manager := EventManager.new(registry)
	var hungry := registry.get_definition(&"EVT_TEST_HUNGRY_PRIMALIS")
	_check(not manager.get_eligible_events({"primalis.hunger": 40}).has(hungry), "T3 hunger 40 is not eligible")
	_check(manager.get_eligible_events({"primalis.hunger": 70}).has(hungry), "T3 hunger 70 is eligible")

	var original_context := {"primalis.hunger": 70, "settlement.food": 10}
	var emitted_batches: Array = []
	manager.effects_emitted.connect(func(effects: Array[EventEffect]) -> void: emitted_batches.append(effects))
	_check(manager.evaluate_and_activate(original_context), "T3 eligible event activates")
	_check(manager.get_active_event() == hungry, "T3 active event is hungry sample")

	var invalid_result := manager.resolve_choice(&"DOES_NOT_EXIST")
	_check(not invalid_result.ok and String(invalid_result.error).contains("does not exist"), "T3 invalid choice returns useful safe failure")
	_check(manager.get_active_event() == hungry and emitted_batches.is_empty(), "T3 invalid choice does not resolve or emit")

	var expected_effects: Array[EventEffect] = hungry.find_choice(&"FEED_HIM").effects
	var result := manager.resolve_choice(&"FEED_HIM")
	_check(result.ok, "T3 valid choice resolves")
	_check(manager.get_active_event() == null, "T3 active event clears after resolution")
	_check(manager.has_seen(hungry.event_id) and manager.has_resolved(hungry.event_id), "T3 seen and resolved history records event")
	_check(manager.get_selected_choice_ids() == PackedStringArray(["FEED_HIM"]), "T3 selected choice history records choice")
	_check(emitted_batches.size() == 1 and _effects_match(emitted_batches[0], expected_effects), "T3 emitted effects exactly match definition")
	_check(original_context == {"primalis.hunger": 70, "settlement.food": 10}, "T3 supplied gameplay context is not mutated")

	var double_result := manager.resolve_choice(&"FEED_HIM")
	_check(not double_result.ok and String(double_result.error).contains("No event"), "T3 double resolution safely fails")
	_check(emitted_batches.size() == 1, "T3 double resolution emits no duplicate effects")


func _test_priority_and_one_active_policy() -> void:
	var registry := EventRegistry.new()
	var low := _definition("EVT_PRIORITY_LOW", 1)
	var high := _definition("EVT_PRIORITY_HIGH", 5)
	var middle := _definition("EVT_PRIORITY_MIDDLE", 3)
	for definition in [low, high, middle]:
		_check(registry.register_definition(definition), "T4 register priority fixture %s" % definition.event_id)
	var manager := EventManager.new(registry)
	manager.evaluate_and_activate({})
	_check(manager.get_active_event() == high, "T4 highest priority eligible event activates")
	_check(manager.get_queued_event_ids() == PackedStringArray(["EVT_PRIORITY_MIDDLE", "EVT_PRIORITY_LOW"]), "T4 remaining events queue by priority")

	manager.evaluate_and_activate({})
	_check(manager.get_active_event() == high, "T4 reevaluation cannot replace active event")
	manager.resolve_choice(&"OK")
	_check(manager.get_active_event() == middle, "T4 next queued event activates after resolution")

	var tie_registry := EventRegistry.new()
	tie_registry.register_definition(_definition("EVT_TIE_B", 7))
	tie_registry.register_definition(_definition("EVT_TIE_A", 7))
	var tie_manager := EventManager.new(tie_registry)
	tie_manager.evaluate_and_activate({})
	_check(tie_manager.get_active_event().event_id == &"EVT_TIE_A", "T4 priority ties use ascending event_id")


func _test_followup_and_delayed_effects() -> void:
	var registry := EventRegistry.new()
	var outsiders := load(OUTSIDERS_PATH) as EventDefinition
	var outsiders_return := load(OUTSIDERS_RETURN_PATH) as EventDefinition
	registry.register_definition(outsiders)
	registry.register_definition(outsiders_return)
	var manager := EventManager.new(registry)
	var scheduled: Array = []
	manager.event_scheduled.connect(func(event_id: StringName, trigger_time: float) -> void: scheduled.append([String(event_id), trigger_time]))
	manager.evaluate_and_activate({"flags.primalis_revealed": false})
	_check(manager.get_active_event() == outsiders, "T5 outsiders context event activates")
	manager.resolve_choice(&"REVEAL_PRIMALIS")
	_check(scheduled == [["EVT_TEST_OUTSIDERS_RETURN", 30.0]], "T5 choice emits deterministic follow-up schedule")
	manager.advance_time(29.9)
	_check(manager.get_active_event() == null, "T5 follow-up is inactive at 29.9 simulation seconds")
	manager.advance_time(0.2)
	_check(manager.get_active_event() == outsiders_return, "T5 scheduled-only follow-up activates after 30 seconds")

	var delayed_registry := EventRegistry.new()
	var delayed_effect := _effect("test.delayed", EventEffect.Operation.SET, true)
	var delayed_choice := _choice("WAIT", [], [delayed_effect], 0.5)
	var delayed_event := _definition("EVT_DELAYED_EFFECT", 1, delayed_choice)
	delayed_registry.register_definition(delayed_event)
	var delayed_manager := EventManager.new(delayed_registry)
	var effect_batches: Array = []
	delayed_manager.effects_emitted.connect(func(effects: Array[EventEffect]) -> void: effect_batches.append(effects))
	delayed_manager.evaluate_and_activate({})
	delayed_manager.resolve_choice(&"WAIT")
	_check(effect_batches.is_empty(), "T5 delayed effect does not emit immediately")
	delayed_manager.advance_time(0.4)
	_check(effect_batches.is_empty(), "T5 delayed effect remains pending before trigger")
	delayed_manager.advance_time(0.2)
	_check(effect_batches.size() == 1 and effect_batches[0][0].to_data() == delayed_effect.to_data(), "T5 delayed effect emits declarative data after simulation delay")


func _test_history_and_repeatability() -> void:
	var registry := EventRegistry.new()
	var first := _definition("EVT_HISTORY_A", 2)
	var second := _definition("EVT_HISTORY_B", 1)
	registry.register_definition(first)
	registry.register_definition(second)
	var manager := EventManager.new(registry)
	manager.evaluate_and_activate({})
	manager.resolve_choice(&"OK")
	manager.resolve_choice(&"OK")
	var history := manager.get_resolution_history()
	_check(manager.get_seen_event_ids() == PackedStringArray(["EVT_HISTORY_A", "EVT_HISTORY_B"]), "T6 seen IDs preserve first-seen order")
	_check(manager.get_resolved_event_ids() == PackedStringArray(["EVT_HISTORY_A", "EVT_HISTORY_B"]), "T6 resolved IDs preserve resolution order")
	_check(manager.get_selected_choice_ids() == PackedStringArray(["OK", "OK"]), "T6 selected choices preserve chronological order")
	_check(history.size() == 2 and history[0].order == 0 and history[1].order == 1, "T6 resolution history is chronological")

	var repeat_registry := EventRegistry.new()
	var repeatable := _definition("EVT_REPEATABLE", 1)
	repeatable.repeatable = true
	repeat_registry.register_definition(repeatable)
	var repeat_manager := EventManager.new(repeat_registry)
	repeat_manager.evaluate_and_activate({})
	repeat_manager.resolve_choice(&"OK")
	repeat_manager.evaluate_and_activate({})
	_check(repeat_manager.get_active_event() == repeatable, "T6 repeatable event may activate again")
	repeat_manager.resolve_choice(&"OK")
	_check(repeat_manager.get_resolution_history().size() == 2, "T6 repeatable event records both resolutions")

	var once_registry := EventRegistry.new()
	var once := _definition("EVT_ONCE", 1)
	once_registry.register_definition(once)
	var once_manager := EventManager.new(once_registry)
	once_manager.evaluate_and_activate({})
	once_manager.resolve_choice(&"OK")
	_check(not once_manager.evaluate_and_activate({}), "T6 non-repeatable event does not fire twice")


func _test_event_seen_condition() -> void:
	var registry := EventRegistry.new()
	var first := _definition("EVT_SEEN_SOURCE", 2)
	var dependent := _definition("EVT_SEEN_DEPENDENT", 1)
	dependent.conditions = [_condition("event_seen.EVT_SEEN_SOURCE", EventCondition.Comparison.EQUAL, true)]
	registry.register_definition(first)
	registry.register_definition(dependent)
	var manager := EventManager.new(registry)
	manager.evaluate_and_activate({})
	manager.resolve_choice(&"OK")
	manager.evaluate_and_activate({})
	_check(manager.get_active_event() == dependent, "T7 event_seen condition is supplied from manager history")


func _test_snapshot_restore() -> void:
	var registry := EventRegistry.new()
	var followup := _definition("EVT_SNAPSHOT_FOLLOWUP", 4)
	followup.trigger_mode = EventDefinition.TriggerMode.SCHEDULED_ONLY
	var schedule_choice := _choice("SCHEDULE")
	schedule_choice.followup_event_id = followup.event_id
	schedule_choice.followup_delay = 30.0
	var first := _definition("EVT_SNAPSHOT_A", 5, schedule_choice)
	var second := _definition("EVT_SNAPSHOT_B", 3)
	var third := _definition("EVT_SNAPSHOT_C", 1, _choice("OK"), [_condition("enable.c", EventCondition.Comparison.EQUAL, true)])
	for definition in [first, second, third, followup]:
		registry.register_definition(definition)
	var manager := EventManager.new(registry)
	manager.evaluate_and_activate({"enable.c": false})
	manager.resolve_choice(&"SCHEDULE")
	manager.evaluate_and_activate({"enable.c": true})
	_check(manager.get_active_event() == second and manager.get_queued_event_ids() == PackedStringArray(["EVT_SNAPSHOT_C"]), "T8 fixture contains active and queued events")

	var snapshot := manager.get_state_snapshot()
	_check(EventCondition.is_serialization_safe(snapshot), "T8 snapshot contains only serialization-safe Variants")
	var restored := EventManager.new(registry)
	var restore_result := restored.restore_state(snapshot)
	_check(restore_result.ok, "T8 valid snapshot restores")
	_check(restored.get_state_snapshot() == snapshot, "T8 restored state is exactly equivalent")
	_check(restored.get_active_event() == second and restored.has_resolved(first.event_id), "T8 active and resolved state restore")
	restored.advance_time(30.0)
	_check(restored.get_queued_event_ids().has("EVT_SNAPSHOT_FOLLOWUP"), "T8 restored schedule continues on simulation time")

	var invalid_snapshot := snapshot.duplicate(true)
	invalid_snapshot.erase("version")
	var invalid_result := restored.restore_state(invalid_snapshot)
	_check(not invalid_result.ok and String(invalid_result.error).contains("version"), "T8 malformed snapshot returns useful failure")


func _test_validation_failures() -> void:
	var registry := EventRegistry.new()
	var blank := EventDefinition.new()
	var blank_errors := registry.validate_definition(blank)
	_check(_contains_error(blank_errors, "blank event_id") and _contains_error(blank_errors, "no choices"), "T9 blank ID and no choices are rejected")

	var valid := _definition("EVT_DUPLICATE", 1)
	_check(registry.register_definition(valid), "T9 valid fixture registers")
	_check(not registry.register_definition(_definition("EVT_DUPLICATE", 2)) and _contains_error(registry.get_last_errors(), "Duplicate event_id"), "T9 duplicate event_id is rejected")

	var duplicate_choices := _definition("EVT_DUPLICATE_CHOICES", 1)
	duplicate_choices.choices.append(_choice("OK"))
	_check(_contains_error(registry.validate_definition(duplicate_choices), "duplicate choice_id"), "T9 duplicate choice IDs are rejected")

	var blank_choice := _definition("EVT_BLANK_CHOICE", 1, _choice(""))
	_check(_contains_error(registry.validate_definition(blank_choice), "blank choice_id"), "T9 blank choice_id is rejected")

	var invalid_condition := _condition("number", EventCondition.Comparison.EQUAL, 1)
	invalid_condition.comparison = 99
	var condition_event := _definition("EVT_BAD_CONDITION", 1, _choice("OK"), [invalid_condition])
	_check(_contains_error(registry.validate_definition(condition_event), "unsupported comparison"), "T9 unsupported condition operator is rejected")

	var malformed_condition := _condition("", EventCondition.Comparison.GREATER_THAN, "not numeric")
	var malformed_event := _definition("EVT_MALFORMED_CONDITION", 1, _choice("OK"), [malformed_condition])
	var malformed_errors := registry.validate_definition(malformed_event)
	_check(_contains_error(malformed_errors, "blank key") and _contains_error(malformed_errors, "numeric value"), "T9 malformed condition reports useful errors")

	var invalid_effect := _effect("target", EventEffect.Operation.ADD, 1)
	invalid_effect.operation = 99
	var effect_event := _definition("EVT_BAD_EFFECT", 1, _choice("OK", [invalid_effect]))
	_check(_contains_error(registry.validate_definition(effect_event), "unsupported operation"), "T9 unsupported effect operation is rejected")

	var malformed_effect := _effect("", EventEffect.Operation.ADD, "not numeric")
	var malformed_effect_event := _definition("EVT_MALFORMED_EFFECT", 1, _choice("OK", [malformed_effect]))
	var effect_errors := registry.validate_definition(malformed_effect_event)
	_check(_contains_error(effect_errors, "blank target") and _contains_error(effect_errors, "numeric value"), "T9 malformed effect reports useful errors")

	var missing_followup_choice := _choice("OK")
	missing_followup_choice.followup_event_id = &"EVT_DOES_NOT_EXIST"
	var missing_followup := _definition("EVT_MISSING_FOLLOWUP", 1, missing_followup_choice)
	_check(registry.register_definition(missing_followup), "T9 unresolved follow-up may register during database loading")
	_check(_contains_error(registry.validate_all(), "nonexistent follow-up"), "T9 fully loaded registry rejects missing follow-up")

	var null_condition_event := _definition("EVT_NULL_CONDITION", 1)
	null_condition_event.conditions.resize(1)
	_check(_contains_error(registry.validate_definition(null_condition_event), "is null"), "T9 null authored data is rejected")


func _test_architectural_isolation_and_node_stability() -> void:
	var nodes_before := get_node_count()
	var registry := EventRegistry.new()
	registry.register_definition(_definition("EVT_NODE_STABILITY", 1))
	var managers: Array[EventManager] = []
	for index in 100:
		var manager := EventManager.new(registry)
		manager.evaluate_and_activate({"iteration": index})
		managers.append(manager)
	var nodes_after := get_node_count()
	_check(nodes_after == nodes_before, "T10 100 managers add no Nodes or Timer nodes")
	_check(not is_instance_of(managers[0], Node), "T10 EventManager is explicitly owned RefCounted state")
	var source := FileAccess.get_file_as_string("res://scripts/events/event_manager.gd")
	var forbidden := ["SelectionManager", "ControlModeManager", "PrimalisController", "RTSCamera", "Engine.time_scale"]
	var isolated := true
	for symbol: String in forbidden:
		if source.contains(symbol):
			isolated = false
	_check(isolated, "T10 manager has no camera, selection, control-mode, Primalis, or pause dependency")
	managers.clear()


func _test_performance_sanity() -> void:
	var registry := EventRegistry.new()
	for index in 100:
		var definition := _definition("EVT_PERF_%03d" % index, index % 5)
		definition.conditions = [_condition("population", EventCondition.Comparison.GREATER_OR_EQUAL, 4)]
		registry.register_definition(definition)
	var definitions := registry.get_all_definitions()
	var started_usec := Time.get_ticks_usec()
	var matches := 0
	for iteration in 10:
		for definition in definitions:
			if definition.is_context_eligible({"population": 4, "iteration": iteration}):
				matches += 1
	var elapsed_usec := Time.get_ticks_usec() - started_usec
	_check(definitions.size() == 100 and matches == 1000, "T11 100 definitions perform 1000 condition evaluations")
	_check(elapsed_usec < 2_000_000, "T11 1000 evaluations complete trivially (%d usec)" % elapsed_usec)


func _sample_registry() -> EventRegistry:
	var registry := EventRegistry.new()
	registry.register_definition(load(HUNGRY_PATH) as EventDefinition)
	registry.register_definition(load(OUTSIDERS_PATH) as EventDefinition)
	registry.register_definition(load(OUTSIDERS_RETURN_PATH) as EventDefinition)
	return registry


func _definition(event_id_value: String, priority_value: int, choice: EventChoice = null, conditions: Array[EventCondition] = []) -> EventDefinition:
	var definition := EventDefinition.new()
	definition.event_id = StringName(event_id_value)
	definition.title = "%s (test)" % event_id_value
	definition.priority = priority_value
	definition.conditions = conditions
	definition.choices = [choice if choice != null else _choice("OK")]
	return definition


func _choice(choice_id_value: String, effects: Array[EventEffect] = [], delayed_effects: Array[EventEffect] = [], delayed_delay := 0.0) -> EventChoice:
	var choice := EventChoice.new()
	choice.choice_id = StringName(choice_id_value)
	choice.label = "%s (test)" % choice_id_value
	choice.effects = effects
	choice.delayed_effects = delayed_effects
	choice.delayed_effect_delay = delayed_delay
	return choice


func _condition(key_value: String, comparison_value: EventCondition.Comparison, expected: Variant) -> EventCondition:
	var condition := EventCondition.new()
	condition.key = StringName(key_value)
	condition.comparison = comparison_value
	condition.value = expected
	return condition


func _effect(target_value: String, operation_value: EventEffect.Operation, effect_value: Variant) -> EventEffect:
	var effect := EventEffect.new()
	effect.target = StringName(target_value)
	effect.operation = operation_value
	effect.value = effect_value
	return effect


func _effects_match(actual: Array, expected: Array[EventEffect]) -> bool:
	if actual.size() != expected.size():
		return false
	for index in expected.size():
		if not actual[index] is EventEffect or actual[index].to_data() != expected[index].to_data():
			return false
	return true


func _contains_error(errors: PackedStringArray, fragment: String) -> bool:
	for error in errors:
		if error.contains(fragment):
			return true
	return false


func _check(condition: bool, label: String) -> void:
	_checks += 1
	if condition:
		print("PASS  ", label)
	else:
		print("FAIL  ", label)
		_failures.append(label)


func _finish() -> void:
	if _failures.is_empty():
		print("EVENTS HEADLESS: ALL PASS (%d checks)" % _checks)
		quit(0)
	else:
		print("EVENTS HEADLESS: %d FAILURE(S) / %d checks" % [_failures.size(), _checks])
		quit(1)
