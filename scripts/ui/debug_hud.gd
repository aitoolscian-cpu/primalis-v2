extends CanvasLayer
## Step 6 debug readout: settlement summary (food, worker split, den),
## selected-entity panels, feed button, and villager job assignment buttons.

@onready var _info: Label = $Panel/Margin/VBox/InfoLabel
@onready var _feed_button: Button = $Panel/Margin/VBox/FeedButton
@onready var _forager_button: Button = $Panel/Margin/VBox/AssignForagerButton
@onready var _builder_button: Button = $Panel/Margin/VBox/AssignBuilderButton

var _selection: SelectionManager
var _primalis: PrimalisController
var _mode_manager: ControlModeManager
var _resources: SettlementResources
var _feeding: FeedingService
var _food_source: FoodSource
var _population: PopulationManager
var _den: ConstructionProject
var _food := 0

func _ready() -> void:
	_selection = get_tree().get_first_node_in_group("selection_manager") as SelectionManager
	_primalis = get_tree().get_first_node_in_group("primalis") as PrimalisController
	_mode_manager = get_tree().get_first_node_in_group("control_mode_manager") as ControlModeManager
	_resources = get_tree().get_first_node_in_group("settlement_resources") as SettlementResources
	_feeding = get_tree().get_first_node_in_group("feeding_service") as FeedingService
	_food_source = get_tree().get_first_node_in_group("food_source") as FoodSource
	_population = get_tree().get_first_node_in_group("population_manager") as PopulationManager
	_den = get_tree().get_first_node_in_group("construction_project") as ConstructionProject
	if _resources != null:
		_food = _resources.get_food()
		_resources.food_changed.connect(func(amount: int) -> void: _food = amount)
	_feed_button.pressed.connect(_on_feed_pressed)
	_forager_button.pressed.connect(func() -> void: _assign(Villager.Job.FORAGER))
	_builder_button.pressed.connect(func() -> void: _assign(Villager.Job.BUILDER))

func _on_feed_pressed() -> void:
	if _feeding != null:
		_feeding.request_feed()

func _assign(job: Villager.Job) -> void:
	var selected := _selection.get_selected() if _selection != null else null
	if selected is Villager and _population != null:
		_population.assign_job(selected as Villager, job)

func _process(_delta: float) -> void:
	var selected_unit: CharacterBody3D = null
	if _selection != null:
		selected_unit = _selection.get_selected()
	if selected_unit is Villager:
		_info.text = _villager_text(selected_unit as Villager)
	else:
		_info.text = _primalis_text(selected_unit != null)
	_update_feed_button(selected_unit)
	_update_assign_buttons(selected_unit)

func _settlement_text() -> String:
	var foragers := 0
	var builders := 0
	var pop := 0
	if _population != null:
		pop = _population.get_population()
		foragers = _population.get_job_count(Villager.Job.FORAGER)
		builders = _population.get_job_count(Villager.Job.BUILDER)
	var den_line := "-"
	if _den != null:
		den_line = "COMPLETE" if _den.is_complete() else "%d%%" % _den.get_percent()
	return "PRIMALIS - STEP 6\nFOOD: %d\nPOP: %d  FORAGERS: %d  BUILDERS: %d\nDEN: %s" % [
		_food, pop, foragers, builders, den_line]

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

func _update_assign_buttons(selected_unit: CharacterBody3D) -> void:
	var show := selected_unit is Villager and _population != null \
		and (_mode_manager == null or not _mode_manager.is_direct())
	_forager_button.visible = show
	_builder_button.visible = show
	if not show:
		return
	var villager := selected_unit as Villager
	_forager_button.disabled = villager.job == Villager.Job.FORAGER
	_builder_button.disabled = villager.job == Villager.Job.BUILDER

func _villager_text(villager: Villager) -> String:
	var lines := _settlement_text()
	lines += "\nVILLAGER - TEST\nName: %s\nID: %s\nJob: %s\nState: %s\nDestination: %s\nCarrying Food: %s\nPosition: %.1f, %.1f" % [
		villager.display_name,
		villager.villager_id,
		villager.get_job_name(),
		villager.get_state_name(),
		villager.get_destination_label(),
		"YES" if villager.carried_food > 0 else "NO",
		villager.global_position.x,
		villager.global_position.z,
	]
	if villager.job == Villager.Job.FORAGER and _food_source != null:
		lines += "\nSource Remaining: %d" % _food_source.get_remaining()
	elif villager.job == Villager.Job.BUILDER and _den != null:
		lines += "\nConstruction: %s" % ("COMPLETE" if _den.is_complete() else "%d%%" % _den.get_percent())
	lines += "\nFPS: %d" % Engine.get_frames_per_second()
	return lines

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
			var hunger_node := _primalis.get_hunger_node()
			hunger_lines = "\nHunger: %d\nStatus: %s" % [
				roundi(_primalis.get_hunger()),
				hunger_node.get_label(),
			]
			if hunger_node.has_shelter_bonus():
				hunger_lines += "\nShelter Bonus: hunger growth -10%"
	var text := _settlement_text()
	text += "\nMode: %s\nControl: %s\nSelected: %s\nState: %s\nSpeed: %.1f m/s\nDestination: %s%s\nFPS: %d" % [
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
