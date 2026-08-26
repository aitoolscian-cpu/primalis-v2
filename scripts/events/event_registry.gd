class_name EventRegistry
extends RefCounted

var _definitions: Dictionary = {}
var _last_errors := PackedStringArray()


func register_definition(definition: EventDefinition) -> bool:
	_last_errors = PackedStringArray()
	if definition == null:
		_last_errors.append("Cannot register a null event definition.")
		return false

	var event_key := String(definition.event_id).strip_edges()
	if not event_key.is_empty() and _definitions.has(event_key):
		_last_errors.append("Duplicate event_id '%s'." % event_key)
		return false

	_last_errors = validate_definition(definition, false)
	if not _last_errors.is_empty():
		return false

	_definitions[event_key] = definition
	return true


func get_definition(event_id_to_find: StringName) -> EventDefinition:
	return _definitions.get(String(event_id_to_find)) as EventDefinition


func get_all_definitions() -> Array[EventDefinition]:
	var result: Array[EventDefinition] = []
	for definition: EventDefinition in _definitions.values():
		result.append(definition)
	result.sort_custom(_event_id_before)
	return result


func get_last_errors() -> PackedStringArray:
	return _last_errors.duplicate()


func validate_all() -> PackedStringArray:
	var errors := PackedStringArray()
	for definition in get_all_definitions():
		errors.append_array(validate_definition(definition, true))
	return errors


func validate_definition(definition: EventDefinition, check_followups := true) -> PackedStringArray:
	var errors := PackedStringArray()
	if definition == null:
		errors.append("Event definition is null.")
		return errors

	var event_key := String(definition.event_id).strip_edges()
	var event_path := "event '%s'" % (event_key if not event_key.is_empty() else "<blank>")
	if event_key.is_empty():
		errors.append("EventDefinition has a blank event_id.")
	if int(definition.trigger_mode) < EventDefinition.TriggerMode.CONTEXT or int(definition.trigger_mode) > EventDefinition.TriggerMode.SCHEDULED_ONLY:
		errors.append("%s uses unsupported trigger_mode %d." % [event_path, int(definition.trigger_mode)])
	if definition.choices.is_empty():
		errors.append("%s has no choices." % event_path)

	for index in definition.conditions.size():
		var condition := definition.conditions[index]
		if condition == null:
			errors.append("%s condition %d is null." % [event_path, index])
		else:
			errors.append_array(condition.get_validation_errors("%s condition %d" % [event_path, index]))

	var choice_ids: Dictionary = {}
	for index in definition.choices.size():
		var choice := definition.choices[index]
		if choice == null:
			errors.append("%s choice %d is null." % [event_path, index])
			continue
		var choice_path := "%s choice %d" % [event_path, index]
		errors.append_array(choice.get_validation_errors(choice_path))
		var choice_key := String(choice.choice_id).strip_edges()
		if not choice_key.is_empty():
			if choice_ids.has(choice_key):
				errors.append("%s has duplicate choice_id '%s'." % [event_path, choice_key])
			else:
				choice_ids[choice_key] = true
		if check_followups:
			var followup_key := String(choice.followup_event_id).strip_edges()
			if not followup_key.is_empty() and not _definitions.has(followup_key):
				errors.append("%s choice '%s' points to nonexistent follow-up event '%s'." % [event_path, choice_key, followup_key])
	return errors


static func _event_id_before(left: EventDefinition, right: EventDefinition) -> bool:
	return String(left.event_id) < String(right.event_id)
