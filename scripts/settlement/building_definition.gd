class_name BuildingDefinition
extends Resource
## Small tunable description for the two Step 8 buildable structures.
## Runtime placement/construction behavior remains in BuildModeController.

@export var building_id: StringName
@export var display_name := "BUILDING"
@export var timber_cost := 1
@export var footprint := Vector3(1.0, 2.0, 1.0)
@export var max_instances := 1
@export var housing_capacity := 0
@export var packed_scene: PackedScene

func is_configured() -> bool:
	return not building_id.is_empty() \
		and timber_cost > 0 \
		and footprint.x > 0.0 \
		and footprint.z > 0.0 \
		and max_instances > 0 \
		and packed_scene != null
