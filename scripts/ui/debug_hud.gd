extends CanvasLayer
## Step 5 debug readout: settlement Food, selected-entity panel, Primalis
## hunger, and the prototype FEED button. Finds data sources by group.

@onready var _info: Label = $Panel/Margin/VBox/InfoLabel
@onready var _feed_button: Button = $Panel/Margin/VBox/FeedButton

var _selection: SelectionManager
var _primalis: PrimalisController
var _mode_manager: ControlModeManager
var _resources: SettlementResources
var _feeding: FeedingService
var _food_source: FoodSource
var _food := 0

func _ready() -> void:
	_selection = get_tree().get_first_node_in_group("selection_manager") as SelectionManager
	_primalis = get_tree().get_first_node_in_group("primalis") as PrimalisController
	_mode_manager = get_tree().get_first_node_in_group("control_mode_manager") as ControlModeManager
	_resources = get_tree().get_first_node_in_group("settlement_resources") as SettlementResources
	_feeding = get_tree().get_first_node_in_group("feeding_service") as FeedingService
	_food_source = get_tree().get_first_node_in_group("food_source") as FoodSource
	if _resources != null:
		_food = _resources.get_food()
		_resources.food_changed.connect(func(amount: int) -> void: _food = amount)
	_feed_button.pressed.connect(_on_feed_pressed)

func _on_feed_pressed() -> void:
	if _feeding != null:
		_feeding.request_feed()

func _process(_delta: float) -> void:
	var selected_unit: CharacterBody3D = null
	if _selection != null:
		selected_unit = _selection.get_selected()
	if selected_unit is Villager:
		_info.text = _villager_text(selected_unit as Villager)
	else:
		_info.text = _primalis_text(selected_unit != null)
	_update_feed_button(selected_unit)

func _update_feed_button(selected_unit: CharacterBody3D) -> void:
	var show := _mode_manager != null and not _mode_manager.is_direct() \
		and selected_unit is PrimalisController and _feeding != null
	_feed_button.visible = show
	if not show:
		return
	var reason := _feeding.get_unavailable_reason()
	if reason == "":
		_feed_button.disabled = false
		_feed_button.text = "FEED PRIMALIS - %d FOOD" % _feeding.feed_cost
	else:
		_feed_button.disabled = true
		_feed_button.text = reason

func _villager_text(villager: Villager) -> String:
	var source_remaining := 0
	if _food_source != null:
		source_remaining = _food_source.get_remaining()
	return "PRIMALIS - STEP 5\nFOOD: %d\nVILLAGER - TEST\nName: %s\nID: %s\nJob: %s\nState: %s\nDestination: %s\nCarrying Food: %s\nSource Remaining: %d\nPosition: %.1f, %.1f\nFPS: %d" % [
		_food,
		villager.display_name,
		villager.villager_id,
		villager.job,
		villager.get_state_name(),
		villager.get_destination_label(),
		"YES" if villager.carried_food > 0 else "NO",
		source_remaining,
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
	var hunger_lines := ""
	if _primalis != null:
		state_name = _primalis.get_state_name()
		speed = _primalis.get_speed()
		if _primalis.control_mode == PrimalisController.ControlMode.RTS_COMMAND \
				and _primalis.state == PrimalisController.State.MOVING:
			dest_line = "%.1f, %.1f" % [_primalis.destination.x, _primalis.destination.z]
		if has_selected or (_mode_manager != null and _mode_manager.is_direct()):
			hunger_lines = "\nHunger: %d\nStatus: %s" % [
				roundi(_primalis.get_hunger()),
				_primalis.get_hunger_node().get_label(),
			]
	var text := "PRIMALIS - STEP 5\nFOOD: %d\nMode: %s\nControl: %s\nSelected: %s\nState: %s\nSpeed: %.1f m/s\nDestination: %s%s\nFPS: %d" % [
		_food,
		mode_name,
		control_name,
		"YES" if has_selected else "NO",
		state_name,
		speed,
		dest_line,
		hunger_lines,
		Engine.get_frames_per_second(),
	]
	if hint != "":
		text += "\n" + hint
	return text
