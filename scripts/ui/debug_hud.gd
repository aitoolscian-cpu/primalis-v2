extends CanvasLayer
## Compact Step 9A settlement/build catalog and entity inspection UI.

@onready var _info: Label = $Panel/Margin/VBox/InfoLabel
@onready var _feed_button: Button = $Panel/Margin/VBox/FeedButton
@onready var _forager_button: Button = $Panel/Margin/VBox/AssignForagerButton
@onready var _woodcutter_button: Button = $Panel/Margin/VBox/AssignWoodcutterButton
@onready var _builder_button: Button = $Panel/Margin/VBox/AssignBuilderButton
@onready var _build_label: Label = $Panel/Margin/VBox/BuildLabel
@onready var _storehouse_button: Button = $Panel/Margin/VBox/PlaceStorehouseButton
@onready var _house_button: Button = $Panel/Margin/VBox/PlaceHouseButton

var _selection: SelectionManager
var _primalis: PrimalisController
var _mode_manager: ControlModeManager
var _resources: SettlementResources
var _feeding: FeedingService
var _food_source: FoodSource
var _timber_source: TimberSource
var _population: PopulationManager
var _housing: HousingManager
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
	_housing = get_tree().get_first_node_in_group("housing_manager") as HousingManager
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
	_storehouse_button.pressed.connect(func() -> void: _enter_build(BuildModeController.STOREHOUSE_ID))
	_house_button.pressed.connect(func() -> void: _enter_build(BuildModeController.HOUSE_ID))

func _on_feed_pressed() -> void:
	if _feeding != null:
		_feeding.request_feed()

func _enter_build(building_id: StringName) -> void:
	if _build != null:
		_build.enter_build_mode(building_id)

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
	_update_build_buttons()

func _settlement_text() -> String:
	var foragers := 0
	var woodcutters := 0
	var builders := 0
	var population := 0
	if _population != null:
		population = _population.get_population()
		foragers = _population.get_job_count(Villager.Job.FORAGER)
		woodcutters = _population.get_job_count(Villager.Job.WOODCUTTER)
		builders = _population.get_job_count(Villager.Job.BUILDER)
	var hungry := _population.get_hungry_count() if _population != null else 0
	var housed := _housing.get_housed_count() if _housing != null else 0
	var den_line := "-"
	if _den != null:
		den_line = "COMPLETE" if _den.is_complete() else "%d%%" % _den.get_percent()
	var storehouse_line := "NOT PLACED"
	var house_count := 0
	if _build != null:
		house_count = _build.get_building_count(BuildModeController.HOUSE_ID)
		if _build.has_storehouse_site():
			var storehouse := _build.get_storehouse()
			storehouse_line = "COMPLETE" if storehouse.is_complete() else "%d%%" % storehouse.get_percent()
	var houses_line := "%d / 2" % house_count
	var active := _build.get_active_project() if _build != null else null
	if active != null and active.building_id == BuildModeController.HOUSE_ID:
		houses_line += " (%d%%)" % active.get_percent()
	return "PRIMALIS - STEP 9A\nFOOD: %d  TIMBER: %d\nPOP: %d  HOUSED: %d / %d  HUNGRY: %d / %d\nWORK: F %d  W %d  B %d\nDEN: %s\nSTOREHOUSE: %s\nHOUSES: %s" % [
		_food, _timber, population, housed, population, hungry, population,
		foragers, woodcutters, builders, den_line, storehouse_line, houses_line]

func _build_mode_text() -> String:
	var definition := _build.get_selected_definition()
	var building_name := definition.display_name if definition != null else "BUILDING"
	var cost := definition.timber_cost if definition != null else 0
	var validity := "VALID" if _build.is_ghost_valid() else "INVALID"
	return _settlement_text() + "\n%s PLACEMENT\nLMB: PLACE\nR: ROTATE (%d deg)\nRMB / ESC: CANCEL\n%s\nCOST: %d TIMBER\nFPS: %d" % [
		building_name, _build.get_ghost_rotation_degrees(), validity, cost,
		Engine.get_frames_per_second()]

func _update_feed_button(selected_unit: CharacterBody3D) -> void:
	var placing := _build != null and _build.placing
	var should_show := _mode_manager != null and not _mode_manager.is_direct() and not placing \
		and selected_unit is PrimalisController and _feeding != null
	_feed_button.visible = should_show
	if not should_show:
		return
	var reason := _feeding.get_unavailable_reason()
	_feed_button.disabled = reason != ""
	_feed_button.text = "FEED PRIMALIS - %d FOOD" % _feeding.feed_cost if reason == "" else reason

func _update_assign_buttons(selected_unit: CharacterBody3D) -> void:
	var placing := _build != null and _build.placing
	var should_show := selected_unit is Villager and _population != null and not placing \
		and (_mode_manager == null or not _mode_manager.is_direct())
	_forager_button.visible = should_show
	_woodcutter_button.visible = should_show
	_builder_button.visible = should_show
	if not should_show:
		return
	var villager := selected_unit as Villager
	_forager_button.disabled = villager.job == Villager.Job.FORAGER
	_woodcutter_button.disabled = villager.job == Villager.Job.WOODCUTTER
	_builder_button.disabled = villager.job == Villager.Job.BUILDER

func _update_build_buttons() -> void:
	if _build == null:
		_build_label.visible = false
		_storehouse_button.visible = false
		_house_button.visible = false
		return
	var should_show := not _build.placing and (_mode_manager == null or not _mode_manager.is_direct())
	_build_label.visible = should_show
	_storehouse_button.visible = should_show
	_house_button.visible = should_show
	if not should_show:
		return
	_update_build_button(_storehouse_button, BuildModeController.STOREHOUSE_ID)
	_update_build_button(_house_button, BuildModeController.HOUSE_ID)

func _update_build_button(button: Button, building_id: StringName) -> void:
	var definition := _build.get_definition(building_id)
	if definition == null:
		button.disabled = true
		button.text = "UNAVAILABLE"
		return
	var reason := _build.get_unavailable_reason(building_id)
	button.disabled = reason != ""
	var display_reason := reason
	if reason == "STOREHOUSE PLACED":
		display_reason = "MAX BUILT"
	elif reason.begins_with("NEED "):
		display_reason = "NOT ENOUGH TIMBER"
	button.text = "%s - %d TIMBER" % [definition.display_name, definition.timber_cost] \
		if reason == "" else "%s - %s" % [definition.display_name, display_reason]

func _villager_text(villager: Villager) -> String:
	var home_position := villager.get_home_position()
	var lines := _settlement_text()
	lines += "\nVILLAGER - TEST\nName: %s\nID: %s\nJob: %s\nState: %s\nDestination: %s\nHOUSING: %s\nHOME: %.1f, %.1f\nPosition: %.1f, %.1f" % [
		villager.display_name, villager.villager_id, villager.get_job_name(),
		villager.get_state_name(), villager.get_destination_label(),
		villager.get_housing_label(), home_position.x, home_position.z,
		villager.global_position.x, villager.global_position.z]
	lines += "\nHUNGER: %d\nSTATUS: %s" % [
		roundi(villager.get_hunger()), villager.get_hunger_status()]
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
			var project := _build.get_active_project() if _build != null else null
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
	var destination_line := "-"
	var hunger_lines := ""
	if _primalis != null:
		state_name = _primalis.get_state_name()
		speed = _primalis.get_speed()
		if _primalis.control_mode == PrimalisController.ControlMode.RTS_COMMAND \
				and _primalis.state == PrimalisController.State.MOVING:
			destination_line = "%.1f, %.1f" % [_primalis.destination.x, _primalis.destination.z]
		if has_selected or (_mode_manager != null and _mode_manager.is_direct()):
			var hunger_node := _primalis.get_hunger_node()
			hunger_lines = "\nHunger: %d\nStatus: %s" % [
				roundi(_primalis.get_hunger()), hunger_node.get_label()]
			if hunger_node.has_shelter_bonus():
				hunger_lines += "\nShelter Bonus: hunger growth -10%"
	var result := _settlement_text()
	result += "\nMode: %s\nControl: %s\nSelected: %s\nState: %s\nSpeed: %.1f m/s\nDestination: %s%s\nFPS: %d" % [
		mode_name, control_name, "YES" if has_selected else "NO", state_name,
		speed, destination_line, hunger_lines, Engine.get_frames_per_second()]
	if hint != "":
		result += "\n" + hint
	return result
