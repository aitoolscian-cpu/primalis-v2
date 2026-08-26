extends CanvasLayer
## Minimal Step 2 debug readout. Finds its data sources by group.

@onready var _info: Label = $Panel/Margin/InfoLabel

var _selection: SelectionManager
var _primalis: PrimalisController

func _ready() -> void:
	_selection = get_tree().get_first_node_in_group("selection_manager") as SelectionManager
	_primalis = get_tree().get_first_node_in_group("primalis") as PrimalisController

func _process(_delta: float) -> void:
	var selected := _selection != null and _selection.has_selection()
	var state_name := "?"
	var dest_line := "-"
	if _primalis != null:
		state_name = _primalis.get_state_name()
		if _primalis.state == PrimalisController.State.MOVING:
			dest_line = "%.1f, %.1f" % [_primalis.destination.x, _primalis.destination.z]
	_info.text = "PRIMALIS - STEP 2\nSelected: %s\nState: %s\nDestination: %s\nCamera: RTS\nFPS: %d" % [
		"YES" if selected else "NO",
		state_name,
		dest_line,
		Engine.get_frames_per_second(),
	]
