class_name EventEffect
extends Resource

enum Operation {
	ADD,
	SET,
	MULTIPLY,
}

@export var target: StringName
@export var operation: Operation = Operation.ADD
@export var value: Variant


func get_validation_errors(path: String = "effect") -> PackedStringArray:
	var errors := PackedStringArray()
	if String(target).strip_edges().is_empty():
		errors.append("%s has a blank target." % path)
	if int(operation) < Operation.ADD or int(operation) > Operation.MULTIPLY:
		errors.append("%s uses unsupported operation %d." % [path, int(operation)])
	if not EventCondition.is_serialization_safe(value):
		errors.append("%s contains a value that is not serialization-safe." % path)
	if operation in [Operation.ADD, Operation.MULTIPLY] and typeof(value) not in [TYPE_INT, TYPE_FLOAT]:
		errors.append("%s requires a numeric value for ADD or MULTIPLY." % path)
	return errors


func to_data() -> Dictionary:
	return {
		"target": String(target),
		"operation": int(operation),
		"value": _duplicate_if_container(value),
	}


static func from_data(data: Dictionary) -> EventEffect:
	var effect := EventEffect.new()
	effect.target = StringName(String(data.get("target", "")))
	effect.operation = int(data.get("operation", -1)) as Operation
	effect.value = _duplicate_if_container(data.get("value"))
	return effect


static func _duplicate_if_container(candidate: Variant) -> Variant:
	if candidate is Array or candidate is Dictionary:
		return candidate.duplicate(true)
	return candidate
