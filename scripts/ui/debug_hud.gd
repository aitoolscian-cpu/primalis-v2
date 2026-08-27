extends CanvasLayer
## Step 7 debug readout: settlement summary (food, timber, worker split,
## den, storehouse), selected-entity panels, feed button, three-job
## assignment buttons, storehouse placement button, and build-mode overlay.

@onready var _info: Label = $Panel/Margin/VBox/InfoLabel
@onready var _feed_button: Button = $Panel/Margin/VBox/FeedButton
@onready var _forager_button: Button = $Panel/Margin/VBox/AssignForagerButton
@onready var _woodcutter_button: Button = $Panel/Margin/VBox/AssignWoodcutterButton
@onready var _builder_button: Button = $Panel/Margin/VBox/AssignBuilderButton
@onready var _place_button: Button = $Panel/Margin/VBox/PlaceStorehouseButton

var _selection: SelectionManager
var _primalis: PrimalisController
var _mode_manager: ControlModeManager
var _resources: SettlementResources
var _feeding: FeedingService
var _food_source: FoodSource
var _timber_source: TimberSource
var _population: PopulationManager
var _den: ConstructionProject
var _build: BuildModeController
var _food := 0
var _timber := 0

func _ready() -> void:
	_selection = get_tree().get_first_node_in_group("selection_manager") as SelectionManager
	_primalis = get_tree().get_first_node_in_group("primalis") as PrimalisController
	_mode_manager = get_tree().get_first_node_in_group("control_mode_manager") as ControlModeManager
	_resources = get_tree().get_first_node_in_group("settlement_resources") as SettlementResources
	_feeding = get_tree().get_first_node_in_group("feeding_service") as FeedingService
	_food_source = get_tree().get_first_node_in_group("food_source") as FoodSource
	_timber_source = get_tree().get_first_node_in_group("timber_source") as TimberSource
	_population = get_tree().get_first_node_in_group("population_manager") as PopulationManager
	_den = get_tree().get_first_node_in_group("construction_project") as ConstructionProject
	_build = get_tree().get_first_node_in_group("build_mode") as BuildModeController
	if _resources != null:
		_food = _resources.get_food()
		_timber = _resources.get_timber()
		_resources.food_changed.connect(func(amount: int) -> void: _food = amount)
		_resources.timber_changed.connect(func(amount: int) -> void: _timber = amount)
	_feed_button.pressed.connect(_on_feed_pressed)
	_forager_button.pressed.connect(func() -> void: _assign(Villager.Job.FORAGER))
	_woodcutter_button.pressed.connect(func() -> void: _assign(Villager.Job.WOODCUTTER))
	_builder_button.pressed.connect(func() -> void: _assign(Villager.Job.BUILDER))
	_place_button.pressed.connect(_on_place_pressed)

func _on_feed_pressed() -> void:
	if _feeding != null:
		_feeding.request_feed()

func _on_place_pressed() -> void:
	if _build != null:
		_build.enter_build_mode()

func _assign(job: Villager.Job) -> void:
	var selected := _selection.get_selected() if _selection != null else null
	if selected is Villager and _population != null:
		_population.assign_job(selected as Villager, job)

func _process(_delta: float) -> void:
	var selected_unit: CharacterBody3D = null
	if _selection != null:
		selected_unit = _selection.get_selected()
	if _build != null and _build.placing:
		_info.text = _build_mode_text()
	elif selected_unit is Villager:
		_info.text = _villager_text(selected_unit as Villager)
	else:
		_info.text = _primalis_text(selected_unit != null)
	_update_feed_button(selected_unit)
	_update_assign_buttons(selected_unit)
	_update_place_button()

func _settlement_text() -> String:
	var foragers := 0
	var woodcutters := 0
	var builders := 0
	var pop := 0
	if _population != null:
		pop = _population.get_population()
		foragers = _population.get_job_count(Villager.Job.FORAGER)
		woodcutters = _population.get_job_count(Villager.Job.WOODCUTTER)
		builders = _population.get_job_count(Villager.Job.BUILDER)
	var den_line := "-"
	if _den != null:
		den_line = "COMPLETE" if _den.is_complete() else "%d%%" % _den.get_percent()
	var storehouse_line := "NOT PLACED"
	if _build != null:
		if _build.placing:
			storehouse_line = "PLACING"
		elif _build.has_storehouse_site():
			var site := _build.get_storehouse()
			storehouse_line = "COMPLETE" if site.is_complete() else "%d%%" % site.get_percent()
	return "PRIMALIS - STEP 7\nFOOD: %d  TIMBER: %d\nPOP: %d  F: %d  W: %d  B: %d\nDEN: %s\nSTOREHOUSE: %s" % [
		_food, _timber, pop, foragers, woodcutters, builders, den_line, storehouse_line]

func _build_mode_text() -> String:
	var validity := "VALID" if _build.is_ghost_valid() else "INVALID"
	return _settlement_text() + "\nSTOREHOUSE PLACEMENT\nLMB: PLACE\nR: ROTATE (%d deg)\nRMB / ESC: CANCEL\n%s\nCOST: %d TIMBER\nFPS: %d" % [
		_build.get_ghost_rotation_degrees(), validity, _build.storehouse_cost,
		Engine.get_frames_per_second()]

func _update_feed_button(selected_unit: CharacterBody3D) -> void:
	var placing := _build != null and _build.placing
	var show := _mode_manager != null and not _mode_manager.is_direct() and not placing \
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
	var placing := _build != null and _build.placing
	var show := selected_unit is Villager and _population != null and not placing \
		and (_mode_manager == null or not _mode_manager.is_direct())
	_forager_button.visible = show
	_woodcutter_button.visible = show
	_builder_button.visible = show
	if not show:
		return
	var villager := selected_unit as Villager
	_forager_button.disabled = villager.job == Villager.Job.FORAGER
	_woodcutter_button.disabled = villager.job == Villager.Job.WOODCUTTER
	_builder_button.disabled = villager.job == Villager.Job.BUILDER

func _update_place_button() -> void:
	if _build == null:
		_place_button.visible = false
		return
	var placing := _build.placing
	var in_direct := _mode_manager != null and _mode_manager.is_direct()
	if placing or in_direct or _build.has_storehouse_site():
		_place_button.visible = false
		return
	_place_button.visible = true
	var reason := _build.get_unavailable_reason()
	if reason == "":
		_place_button.disabled = false
		_place_button.text = "PLACE STOREHOUSE - %d TIMBER" % _build.storehouse_cost
	else:
		_place_button.disabled = true
		_place_button.text = reason

func _villager_text(villager: Villager) -> String:
	var lines := _settlement_text()
	lines += "\nVILLAGER - TEST\nName: %s\nID: %s\nJob: %s\nState: %s\nDestination: %s\nPosition: %.1f, %.1f" % [
		villager.display_name,
		villager.villager_id,
		villager.get_job_name(),
		villager.get_state_name(),
		villager.get_destination_label(),
		villager.global_position.x,
		villager.global_position.z,
	]
	match villager.job:
		Villager.Job.FORAGER:
			lines += "\nCarrying Food: %s" % ("YES" if villager.carried_food > 0 else "NO")
			if _food_source != null:
				lines += "\nSource Remaining: %d" % _food_source.get_remaining()
		Villager.Job.WOODCUTTER:
			lines += "\nCarrying Timber: %s" % ("YES" if villager.carried_timber > 0 else "NO")
			if _timber_source != null:
				lines += "\nGrove Remaining: %d" % _timber_source.get_remaining()
		Villager.Job.BUILDER:
			var project: ConstructionProject = null
			if _build != null:
				project = _build.get_active_project()
			if project != null:
				lines += "\nProject: %s\nConstruction: %d%%" % [project.project_name, project.get_percent()]
			else:
				lines += "\nProject: NONE"
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
