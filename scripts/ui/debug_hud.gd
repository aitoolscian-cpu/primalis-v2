extends CanvasLayer
## Minimal Step 3 debug readout. Finds its data sources by group.

@onready var _info: Label = $Panel/Margin/InfoLabel

var _selection: SelectionManager
var _primalis: PrimalisController
var _mode_manager: ControlModeManager

func _ready() -> void:
	_selection = get_tree().get_first_node_in_group("selection_manager") as SelectionManager
	_primalis = get_tree().get_first_node_in_group("primalis") as PrimalisController
	_mode_manager = get_tree().get_first_node_in_group("control_mode_manager") as ControlModeManager

func _process(_delta: float) -> void:
	var selected := _selection != null and _selection.has_selection()
	var mode_name := "RTS"
	var control_name := "COMMAND"
	var hint := ""
	if _mode_manager != null:
		mode_name = _mode_manager.get_mode_name()
		control_name = _mode_manager.get_control_name()
		if _mode_manager.is_direct():
			hint = "F - Return to RTS"
		elif selected:
			hint = "F - Possess Primalis"
	var state_name := "?"
	var speed := 0.0
	var dest_line := "-"
	if _primalis != null:
		state_name = _primalis.get_state_name()
		speed = _primalis.get_speed()
		if _primalis.control_mode == PrimalisController.ControlMode.RTS_COMMAND \
				and _primalis.state == PrimalisController.State.MOVING:
			dest_line = "%.1f, %.1f" % [_primalis.destination.x, _primalis.destination.z]
	var text := "PRIMALIS - STEP 3\nMode: %s\nControl: %s\nSelected: %s\nState: %s\nSpeed: %.1f m/s\nDestination: %s\nFPS: %d" % [
		mode_name,
		control_name,
		"YES" if selected else "NO",
		state_name,
		speed,
		dest_line,
		Engine.get_frames_per_second(),
	]
	if hint != "":
		text += "\n" + hint
	_info.text = text
