class_name EventManager
extends RefCounted

signal event_started(definition: EventDefinition)
signal event_resolved(event_id: StringName, choice_id: StringName)
signal effects_emitted(effects: Array[EventEffect])
signal event_scheduled(event_id: StringName, trigger_time: float)

const SNAPSHOT_VERSION := 1

var simulation_time := 0.0

var _registry: EventRegistry
var _active_event_id: StringName
var _queued_event_ids: Array[StringName] = []
var _scheduled_events: Array[Dictionary] = []
var _scheduled_effects: Array[Dictionary] = []
var _seen_event_ids: Array[StringName] = []
var _resolved_event_ids: Array[StringName] = []
var _selected_choice_ids: Array[StringName] = []
var _resolution_history: Array[Dictionary] = []
var _last_context: Dictionary = {}
var _sequence := 0


func _init(registry: EventRegistry = null) -> void:
	_registry = registry


func set_registry(registry: EventRegistry) -> void:
	_registry = registry


func get_active_event() -> EventDefinition:
	if _registry == null or String(_active_event_id).is_empty():
		return null
	return _registry.get_definition(_active_event_id)


func get_eligible_events(context: Dictionary) -> Array[EventDefinition]:
	var eligible: Array[EventDefinition] = []
	if _registry == null:
		return eligible
	var evaluation_context := _context_with_history(context)
	for definition in _registry.get_all_definitions():
		if definition.event_id == _active_event_id or _queued_event_ids.has(definition.event_id):
			continue
		if not definition.repeatable and _resolved_event_ids.has(definition.event_id):
			continue
		if definition.is_context_eligible(evaluation_context):
			eligible.append(definition)
	eligible.sort_custom(_definition_precedes)
	return eligible


func evaluate_and_activate(context: Dictionary) -> bool:
	_last_context = context.duplicate(true)
	for definition in get_eligible_events(context):
		_queue_event(definition)
	if get_active_event() == null:
		_activate_next_queued()
	return get_active_event() != null


func resolve_choice(choice_id: StringName) -> Dictionary:
	var definition := get_active_event()
	if definition == null:
		return _failure("No event is active.")

	var choice := definition.find_choice(choice_id)
	if choice == null:
		return _failure("Choice '%s' does not exist on event '%s'." % [String(choice_id), String(definition.event_id)])
	if not choice.conditions_match(_context_with_history(_last_context)):
		return _failure("Choice '%s' is not currently eligible." % String(choice_id))

	var emitted_effects: Array[EventEffect] = []
	for effect in choice.effects:
		emitted_effects.append(effect)
	if not emitted_effects.is_empty():
		effects_emitted.emit(emitted_effects)

	if not choice.delayed_effects.is_empty():
		_schedule_effects(definition.event_id, choice.choice_id, choice.delayed_effects, choice.delayed_effect_delay)
	if not String(choice.followup_event_id).is_empty():
		_schedule_event(choice.followup_event_id, choice.followup_delay)

	_append_unique(_seen_event_ids, definition.event_id)
	_append_unique(_resolved_event_ids, definition.event_id)
	_selected_choice_ids.append(choice.choice_id)
	_resolution_history.append({
		"order": _resolution_history.size(),
		"event_id": String(definition.event_id),
		"choice_id": String(choice.choice_id),
		"simulation_time": simulation_time,
	})
	_active_event_id = StringName()
	event_resolved.emit(definition.event_id, choice.choice_id)
	_activate_next_queued()
	return {
		"ok": true,
		"error": "",
		"event_id": String(definition.event_id),
		"choice_id": String(choice.choice_id),
		"effects": emitted_effects,
	}


func advance_time(delta: float) -> Dictionary:
	if delta < 0.0:
		return _failure("Simulation delta cannot be negative.")
	simulation_time += delta

	var due_items: Array[Dictionary] = []
	var pending_events: Array[Dictionary] = []
	for scheduled_event in _scheduled_events:
		if float(scheduled_event["trigger_time"]) <= simulation_time:
			var due_event := scheduled_event.duplicate(true)
			due_event["kind"] = "event"
			due_items.append(due_event)
		else:
			pending_events.append(scheduled_event)
	_scheduled_events = pending_events

	var pending_effects: Array[Dictionary] = []
	for scheduled_effect in _scheduled_effects:
		if float(scheduled_effect["trigger_time"]) <= simulation_time:
			var due_effect := scheduled_effect.duplicate(true)
			due_effect["kind"] = "effects"
			due_items.append(due_effect)
		else:
			pending_effects.append(scheduled_effect)
	_scheduled_effects = pending_effects

	due_items.sort_custom(_scheduled_item_precedes)
	for due_item in due_items:
		if due_item["kind"] == "event":
			_queue_scheduled_event(StringName(String(due_item["event_id"])))
		else:
			var effects: Array[EventEffect] = []
			for effect_data: Dictionary in due_item["effects"]:
				effects.append(EventEffect.from_data(effect_data))
			if not effects.is_empty():
				effects_emitted.emit(effects)

	if get_active_event() == null:
		_activate_next_queued()
	return {"ok": true, "error": "", "processed": due_items.size()}


func has_seen(event_id_to_find: StringName) -> bool:
	return _seen_event_ids.has(event_id_to_find)


func has_resolved(event_id_to_find: StringName) -> bool:
	return _resolved_event_ids.has(event_id_to_find)


func get_seen_event_ids() -> PackedStringArray:
	return _string_names_to_packed(_seen_event_ids)


func get_resolved_event_ids() -> PackedStringArray:
	return _string_names_to_packed(_resolved_event_ids)


func get_selected_choice_ids() -> PackedStringArray:
	return _string_names_to_packed(_selected_choice_ids)


func get_queued_event_ids() -> PackedStringArray:
	return _string_names_to_packed(_queued_event_ids)


func get_resolution_history() -> Array[Dictionary]:
	return _resolution_history.duplicate(true)


func get_state_snapshot() -> Dictionary:
	return {
		"version": SNAPSHOT_VERSION,
		"simulation_time": simulation_time,
		"active_event_id": String(_active_event_id),
		"queued_event_ids": _string_names_to_strings(_queued_event_ids),
		"scheduled_events": _scheduled_events.duplicate(true),
		"scheduled_effects": _scheduled_effects.duplicate(true),
		"seen_event_ids": _string_names_to_strings(_seen_event_ids),
		"resolved_event_ids": _string_names_to_strings(_resolved_event_ids),
		"selected_choice_ids": _string_names_to_strings(_selected_choice_ids),
		"resolution_history": _resolution_history.duplicate(true),
		"last_context": _last_context.duplicate(true),
		"sequence": _sequence,
	}


func restore_state(snapshot: Dictionary) -> Dictionary:
	var validation_error := _validate_snapshot(snapshot)
	if not validation_error.is_empty():
		return _failure(validation_error)

	simulation_time = float(snapshot["simulation_time"])
	_active_event_id = StringName(String(snapshot["active_event_id"]))
	_queued_event_ids = _strings_to_string_names(snapshot["queued_event_ids"])
	_scheduled_events = _dictionaries_from_array(snapshot["scheduled_events"])
	_scheduled_effects = _dictionaries_from_array(snapshot["scheduled_effects"])
	_seen_event_ids = _strings_to_string_names(snapshot["seen_event_ids"])
	_resolved_event_ids = _strings_to_string_names(snapshot["resolved_event_ids"])
	_selected_choice_ids = _strings_to_string_names(snapshot["selected_choice_ids"])
	_resolution_history = _dictionaries_from_array(snapshot["resolution_history"])
	_last_context = snapshot["last_context"].duplicate(true)
	_sequence = int(snapshot["sequence"])
	return {"ok": true, "error": ""}


func _queue_event(definition: EventDefinition) -> void:
	if definition == null or definition.event_id == _active_event_id or _queued_event_ids.has(definition.event_id):
		return
	_queued_event_ids.append(definition.event_id)
	_queued_event_ids.sort_custom(_event_id_precedes)


func _queue_scheduled_event(event_id_to_queue: StringName) -> void:
	if _registry == null:
		return
	var definition := _registry.get_definition(event_id_to_queue)
	if definition == null:
		return
	if not definition.repeatable and _resolved_event_ids.has(event_id_to_queue):
		return
	_queue_event(definition)


func _activate_next_queued() -> void:
	if not String(_active_event_id).is_empty() or _registry == null:
		return
	while not _queued_event_ids.is_empty():
		var next_event_id: StringName = _queued_event_ids.pop_front()
		var definition: EventDefinition = _registry.get_definition(next_event_id)
		if definition == null:
			continue
		if not definition.repeatable and _resolved_event_ids.has(next_event_id):
			continue
		_active_event_id = next_event_id
		_append_unique(_seen_event_ids, next_event_id)
		event_started.emit(definition)
		return


func _schedule_event(event_id_to_schedule: StringName, delay: float) -> void:
	_sequence += 1
	var trigger_time := simulation_time + delay
	_scheduled_events.append({
		"event_id": String(event_id_to_schedule),
		"trigger_time": trigger_time,
		"sequence": _sequence,
	})
	event_scheduled.emit(event_id_to_schedule, trigger_time)


func _schedule_effects(source_event_id: StringName, choice_id: StringName, effects: Array[EventEffect], delay: float) -> void:
	var effect_data: Array[Dictionary] = []
	for effect in effects:
		effect_data.append(effect.to_data())
	_sequence += 1
	_scheduled_effects.append({
		"source_event_id": String(source_event_id),
		"choice_id": String(choice_id),
		"effects": effect_data,
		"trigger_time": simulation_time + delay,
		"sequence": _sequence,
	})


func _context_with_history(context: Dictionary) -> Dictionary:
	var result := context.duplicate(true)
	for event_id_seen in _seen_event_ids:
		result["event_seen.%s" % String(event_id_seen)] = true
	for event_id_resolved in _resolved_event_ids:
		result["event_resolved.%s" % String(event_id_resolved)] = true
	return result


func _validate_snapshot(snapshot: Dictionary) -> String:
	var required_keys := [
		"version", "simulation_time", "active_event_id", "queued_event_ids",
		"scheduled_events", "scheduled_effects", "seen_event_ids",
		"resolved_event_ids", "selected_choice_ids", "resolution_history",
		"last_context", "sequence",
	]
	for required_key: String in required_keys:
		if not snapshot.has(required_key):
			return "Snapshot is missing '%s'." % required_key
	if int(snapshot["version"]) != SNAPSHOT_VERSION:
		return "Unsupported snapshot version %s." % str(snapshot["version"])
	if typeof(snapshot["simulation_time"]) not in [TYPE_INT, TYPE_FLOAT] or float(snapshot["simulation_time"]) < 0.0:
		return "Snapshot has invalid simulation_time."
	if typeof(snapshot["active_event_id"]) != TYPE_STRING:
		return "Snapshot has invalid active_event_id."
	for array_key: String in ["queued_event_ids", "scheduled_events", "scheduled_effects", "seen_event_ids", "resolved_event_ids", "selected_choice_ids", "resolution_history"]:
		if typeof(snapshot[array_key]) != TYPE_ARRAY:
			return "Snapshot '%s' must be an Array." % array_key
	if typeof(snapshot["last_context"]) != TYPE_DICTIONARY or not EventCondition.is_serialization_safe(snapshot["last_context"]):
		return "Snapshot last_context is not serialization-safe."
	if typeof(snapshot["sequence"]) != TYPE_INT or int(snapshot["sequence"]) < 0:
		return "Snapshot has invalid sequence."
	if not EventCondition.is_serialization_safe(snapshot):
		return "Snapshot contains unsupported live or complex values."
	if _registry == null:
		return "Cannot restore state without an EventRegistry."

	var referenced_ids: Array = snapshot["queued_event_ids"].duplicate()
	if not String(snapshot["active_event_id"]).is_empty():
		referenced_ids.append(snapshot["active_event_id"])
	for scheduled_event: Variant in snapshot["scheduled_events"]:
		if not scheduled_event is Dictionary or not scheduled_event.has("event_id"):
			return "Snapshot contains a malformed scheduled event."
		referenced_ids.append(scheduled_event["event_id"])
	for referenced_id: Variant in referenced_ids:
		if typeof(referenced_id) != TYPE_STRING or _registry.get_definition(StringName(String(referenced_id))) == null:
			return "Snapshot references unknown event_id '%s'." % str(referenced_id)
	return ""


func _definition_precedes(left: EventDefinition, right: EventDefinition) -> bool:
	if left.priority != right.priority:
		return left.priority > right.priority
	return String(left.event_id) < String(right.event_id)


func _event_id_precedes(left: StringName, right: StringName) -> bool:
	var left_definition := _registry.get_definition(left)
	var right_definition := _registry.get_definition(right)
	if left_definition == null:
		return false
	if right_definition == null:
		return true
	return _definition_precedes(left_definition, right_definition)


static func _scheduled_item_precedes(left: Dictionary, right: Dictionary) -> bool:
	if float(left["trigger_time"]) != float(right["trigger_time"]):
		return float(left["trigger_time"]) < float(right["trigger_time"])
	return int(left["sequence"]) < int(right["sequence"])


static func _append_unique(destination: Array[StringName], value: StringName) -> void:
	if not destination.has(value):
		destination.append(value)


static func _string_names_to_packed(source: Array[StringName]) -> PackedStringArray:
	return PackedStringArray(_string_names_to_strings(source))


static func _string_names_to_strings(source: Array[StringName]) -> Array[String]:
	var result: Array[String] = []
	for value in source:
		result.append(String(value))
	return result


static func _strings_to_string_names(source: Array) -> Array[StringName]:
	var result: Array[StringName] = []
	for value: Variant in source:
		result.append(StringName(String(value)))
	return result


static func _dictionaries_from_array(source: Array) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for value: Variant in source:
		result.append((value as Dictionary).duplicate(true))
	return result


static func _failure(message: String) -> Dictionary:
	return {"ok": false, "error": message, "effects": []}
