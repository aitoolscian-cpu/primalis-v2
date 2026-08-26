class_name EventCondition
extends Resource

enum Comparison {
	EQUAL,
	NOT_EQUAL,
	GREATER_THAN,
	GREATER_OR_EQUAL,
	LESS_THAN,
	LESS_OR_EQUAL,
}

@export var key: StringName
@export var comparison: Comparison = Comparison.EQUAL
@export var value: Variant


func evaluate(context: Dictionary) -> bool:
	var context_key := String(key)
	if context_key.is_empty() or not context.has(context_key):
		return false

	var actual: Variant = context[context_key]
	match comparison:
		Comparison.EQUAL:
			return actual == value
		Comparison.NOT_EQUAL:
			return actual != value
		Comparison.GREATER_THAN:
			return _numbers_are_comparable(actual, value) and actual > value
		Comparison.GREATER_OR_EQUAL:
			return _numbers_are_comparable(actual, value) and actual >= value
		Comparison.LESS_THAN:
			return _numbers_are_comparable(actual, value) and actual < value
		Comparison.LESS_OR_EQUAL:
			return _numbers_are_comparable(actual, value) and actual <= value
		_:
			return false


func get_validation_errors(path: String = "condition") -> PackedStringArray:
	var errors := PackedStringArray()
	if String(key).strip_edges().is_empty():
		errors.append("%s has a blank key." % path)
	if int(comparison) < Comparison.EQUAL or int(comparison) > Comparison.LESS_OR_EQUAL:
		errors.append("%s uses unsupported comparison operator %d." % [path, int(comparison)])
	if not is_serialization_safe(value):
		errors.append("%s contains a value that is not serialization-safe." % path)
	if comparison in [Comparison.GREATER_THAN, Comparison.GREATER_OR_EQUAL, Comparison.LESS_THAN, Comparison.LESS_OR_EQUAL] and not _is_number(value):
		errors.append("%s requires a numeric value for an ordered comparison." % path)
	return errors


static func is_serialization_safe(candidate: Variant) -> bool:
	match typeof(candidate):
		TYPE_NIL, TYPE_BOOL, TYPE_INT, TYPE_FLOAT, TYPE_STRING, TYPE_STRING_NAME:
			return true
		TYPE_ARRAY:
			for item: Variant in candidate:
				if not is_serialization_safe(item):
					return false
			return true
		TYPE_DICTIONARY:
			for dictionary_key: Variant in candidate:
				if typeof(dictionary_key) not in [TYPE_STRING, TYPE_STRING_NAME]:
					return false
				if not is_serialization_safe(candidate[dictionary_key]):
					return false
			return true
		_:
			return false


static func _numbers_are_comparable(left: Variant, right: Variant) -> bool:
	return _is_number(left) and _is_number(right)


static func _is_number(candidate: Variant) -> bool:
	return typeof(candidate) in [TYPE_INT, TYPE_FLOAT]
