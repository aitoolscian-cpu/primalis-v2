class_name EventDefinition
extends Resource

enum TriggerMode {
	CONTEXT,
	SCHEDULED_ONLY,
}

@export var event_id: StringName
@export var title: String
@export_multiline var body_text: String
@export var tags := PackedStringArray()
@export var priority := 0
@export var repeatable := false
@export var trigger_mode: TriggerMode = TriggerMode.CONTEXT
@export var conditions: Array[EventCondition] = []
@export var choices: Array[EventChoice] = []
@export var participants := PackedStringArray()
@export var camera_focus_target_key: StringName
@export var memory_tags := PackedStringArray()


func is_context_eligible(context: Dictionary) -> bool:
	if trigger_mode != TriggerMode.CONTEXT:
		return false
	for condition in conditions:
		if condition == null or not condition.evaluate(context):
			return false
	return true


func find_choice(choice_id_to_find: StringName) -> EventChoice:
	for choice in choices:
		if choice != null and choice.choice_id == choice_id_to_find:
			return choice
	return null
