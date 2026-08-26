class_name EventChoice
extends Resource

@export var choice_id: StringName
@export var label: String
@export_multiline var description: String
@export var conditions: Array[EventCondition] = []
@export var effects: Array[EventEffect] = []
@export var delayed_effects: Array[EventEffect] = []
@export_range(0.0, 86400.0, 0.1, "or_greater") var delayed_effect_delay := 0.0
@export var followup_event_id: StringName
@export_range(0.0, 86400.0, 0.1, "or_greater") var followup_delay := 0.0


func conditions_match(context: Dictionary) -> bool:
	for condition in conditions:
		if condition == null or not condition.evaluate(context):
			return false
	return true


func get_validation_errors(path: String = "choice") -> PackedStringArray:
	var errors := PackedStringArray()
	if String(choice_id).strip_edges().is_empty():
		errors.append("%s has a blank choice_id." % path)
	if delayed_effect_delay < 0.0:
		errors.append("%s has a negative delayed_effect_delay." % path)
	if followup_delay < 0.0:
		errors.append("%s has a negative followup_delay." % path)
	for index in conditions.size():
		var condition := conditions[index]
		if condition == null:
			errors.append("%s condition %d is null." % [path, index])
		else:
			errors.append_array(condition.get_validation_errors("%s condition %d" % [path, index]))
	for index in effects.size():
		var effect := effects[index]
		if effect == null:
			errors.append("%s effect %d is null." % [path, index])
		else:
			errors.append_array(effect.get_validation_errors("%s effect %d" % [path, index]))
	for index in delayed_effects.size():
		var effect := delayed_effects[index]
		if effect == null:
			errors.append("%s delayed effect %d is null." % [path, index])
		else:
			errors.append_array(effect.get_validation_errors("%s delayed effect %d" % [path, index]))
	return errors
