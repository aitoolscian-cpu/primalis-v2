extends CanvasLayer
## Minimal Step 4 debug readout. Shows the currently selected entity:
## Primalis panel (mode/control/state) or villager inspection panel.

@onready var _info: Label = $Panel/Margin/InfoLabel

var _selection: SelectionManager
var _primalis: PrimalisController
var _mode_manager: ControlModeManager

func _ready() -> void:
	_selection = get_tree().get_first_node_in_group("selection_manager") as SelectionManager
	_primalis = get_tree().get_first_node_in_group("primalis") as PrimalisController
	_mode_manager = get_tree().get_first_node_in_group("control_mode_manager") as ControlModeManager

func _process(_delta: float) -> void:
	var selected_unit: CharacterBody3D = null
	if _selection != null:
		selected_unit = _selection.get_selected()
	if selected_unit is Villager:
		_info.text = _villager_text(selected_unit as Villager)
	else:
		_info.text = _primalis_text(selected_unit != null)

func _villager_text(villager: Villager) -> String:
	return "PRIMALIS - STEP 4\nVILLAGER - TEST\nName: %s\nID: %s\nJob: %s\nState: %s\nDestination: %s\nPosition: %.1f, %.1f\nFPS: %d" % [
		villager.display_name,
		villager.villager_id,
		villager.job,
		villager.get_state_name(),
		villager.get_destination_label(),
		villager.global_position.x,
		villager.global_position.z,
		Engine.get_frames_per_second(),
	]

func _primalis_text(has_selected: bool) -> String:
	var mode_name := "RTS"
	var control_name := "COMMAND"
	var hint := ""
	if _mode_manager != null:
		mode_name = _mode_manager.get_mode_name()
		control_name = _mode_manager.get_control_name()
		if _mode_manager.is_direct():
			hint = "F - Return to RTS"
		elif has_selected:
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
	var text := "PRIMALIS - STEP 4\nMode: %s\nControl: %s\nSelected: %s\nState: %s\nSpeed: %.1f m/s\nDestination: %s\nFPS: %d" % [
		mode_name,
		control_name,
		"YES" if has_selected else "NO",
		state_name,
		speed,
		dest_line,
		Engine.get_frames_per_second(),
	]
	if hint != "":
		text += "\n" + hint
	return text
