class_name BuildModeController
extends Node
## One reusable placement/construction director for the Step 8 catalog.
## The Den is always first; afterwards Storehouse and House definitions use
## the same ghost, validation, rotation, spend, site, and completion path.

signal build_mode_changed
signal building_placed(definition: BuildingDefinition, site: ConstructionProject)
signal building_completed(definition: BuildingDefinition, site: ConstructionProject)
signal storehouse_placed

const STOREHOUSE_ID := &"BLD_006"
const HOUSE_ID := &"BLD_002"
const RAY_LENGTH := 600.0
const BOUNDS_LIMIT := 54.0

@export var storehouse_cost := 8 # Step 7 API/fixture compatibility.
@export var storehouse_definition: BuildingDefinition
@export var house_definition: BuildingDefinition
@export var den_path: NodePath
@export var world_path: NodePath

var placing := false
var total_timber_spent := 0

var _den: ConstructionProject
var _world: Node3D
var _resources: SettlementResources
var _selection: SelectionManager
var _modes: ControlModeManager
var _ghost: Node3D
var _ghost_mesh: MeshInstance3D
var _ghost_valid := false
var _ghost_on_ground := false
var _rotation_index := 0
var _selected_definition: BuildingDefinition
var _active_site: ConstructionProject = null
var _definitions: Dictionary = {}
var _sites: Dictionary = {}
var _site_definitions: Dictionary = {}
var _mat_valid: StandardMaterial3D
var _mat_invalid: StandardMaterial3D
var _query_shape: BoxShape3D
var _query_params: PhysicsShapeQueryParameters3D
var _clearances: Array = []

func _ready() -> void:
	_den = get_node_or_null(den_path) as ConstructionProject
	_world = get_node_or_null(world_path) as Node3D
	_resources = get_tree().get_first_node_in_group("settlement_resources") as SettlementResources
	_selection = get_tree().get_first_node_in_group("selection_manager") as SelectionManager
	_modes = get_tree().get_first_node_in_group("control_mode_manager") as ControlModeManager
	_register_definition(storehouse_definition)
	_register_definition(house_definition)
	if storehouse_definition != null:
		storehouse_cost = storehouse_definition.timber_cost
	_build_ghost()
	_resolve_clearances()
	set_process(false)

func _register_definition(definition: BuildingDefinition) -> void:
	if definition == null or not definition.is_configured():
		return
	_definitions[definition.building_id] = definition
	_sites[definition.building_id] = []

func get_building_definitions() -> Array[BuildingDefinition]:
	var result: Array[BuildingDefinition] = []
	for building_id in [STOREHOUSE_ID, HOUSE_ID]:
		var definition := get_definition(building_id)
		if definition != null:
			result.append(definition)
	return result

func get_definition(building_id: StringName) -> BuildingDefinition:
	return _definitions.get(building_id) as BuildingDefinition

func get_active_project() -> ConstructionProject:
	if _den != null and not _den.is_complete():
		return _den
	if _active_site != null and is_instance_valid(_active_site) and not _active_site.is_complete():
		return _active_site
	return null

func has_storehouse_site() -> bool:
	return get_building_count(STOREHOUSE_ID) > 0

func get_storehouse() -> ConstructionProject:
	var storehouses := get_buildings(STOREHOUSE_ID)
	return storehouses[0] if not storehouses.is_empty() else null

func get_houses() -> Array[ConstructionProject]:
	return get_buildings(HOUSE_ID)

func get_completed_houses() -> Array[ConstructionProject]:
	var result: Array[ConstructionProject] = []
	for house in get_houses():
		if house.is_complete():
			result.append(house)
	return result

func get_buildings(building_id: StringName) -> Array[ConstructionProject]:
	var result: Array[ConstructionProject] = []
	var registered: Array = _sites.get(building_id, [])
	for site in registered:
		if site != null and is_instance_valid(site):
			result.append(site as ConstructionProject)
	return result

func get_building_count(building_id: StringName) -> int:
	return get_buildings(building_id).size()

func get_completed_building_count(building_id: StringName) -> int:
	var count := 0
	for site in get_buildings(building_id):
		if site.is_complete():
			count += 1
	return count

func get_selected_definition() -> BuildingDefinition:
	return _selected_definition

func get_unavailable_reason(building_id: StringName = STOREHOUSE_ID) -> String:
	var definition := get_definition(building_id)
	if definition == null:
		return "UNAVAILABLE"
	if placing:
		return "PLACING..."
	if _den == null or not _den.is_complete():
		return "COMPLETE PRIMALIS DEN FIRST"
	if get_building_count(building_id) >= definition.max_instances:
		return "%s PLACED" % definition.display_name if building_id == STOREHOUSE_ID else "MAX BUILT"
	if get_active_project() != null:
		return "CONSTRUCTION IN PROGRESS"
	if _resources == null or not _resources.can_spend_timber(definition.timber_cost):
		return "NEED %d TIMBER" % definition.timber_cost \
			if building_id == STOREHOUSE_ID else "NOT ENOUGH TIMBER"
	if _modes != null and _modes.is_direct():
		return "UNAVAILABLE"
	return ""

func enter_build_mode(building_id: StringName = STOREHOUSE_ID) -> bool:
	if get_unavailable_reason(building_id) != "":
		return false
	_selected_definition = get_definition(building_id)
	placing = true
	_rotation_index = 0
	_ghost.rotation.y = 0.0
	_set_ghost_footprint(_selected_definition.footprint)
	_ghost_on_ground = false
	_ghost_valid = false
	_ghost.visible = true
	set_process(true)
	if _selection != null:
		_selection.set_active(false)
	if _modes != null:
		_modes.set_process_unhandled_input(false)
	build_mode_changed.emit()
	return true

func cancel_build_mode() -> void:
	if not placing:
		return
	placing = false
	_ghost.visible = false
	set_process(false)
	if _selection != null:
		_selection.set_active(true)
	if _modes != null:
		_modes.set_process_unhandled_input(true)
	build_mode_changed.emit()

func is_ghost_valid() -> bool:
	return _ghost_valid

func get_ghost_rotation_degrees() -> int:
	return _rotation_index * 90

func rotate_ghost() -> void:
	if not placing:
		return
	_rotation_index = (_rotation_index + 1) % 4
	_ghost.rotation.y = deg_to_rad(_rotation_index * 90.0)
	if _ghost_on_ground:
		_ghost_valid = _validate()
		_apply_ghost_tint()

func set_ghost_position(world_pos: Vector3) -> void:
	if not placing:
		return
	_ghost.global_position = Vector3(world_pos.x, 0.0, world_pos.z)
	_ghost_on_ground = true
	_ghost_valid = _validate()
	_apply_ghost_tint()

func try_confirm_placement() -> bool:
	if not placing or not _ghost_on_ground or _selected_definition == null:
		return false
	if _get_confirmation_blocker() != "":
		return false
	_ghost_valid = _validate()
	if not _ghost_valid:
		return false
	var cost := _selected_definition.timber_cost
	if _resources == null or not _resources.try_spend_timber(cost):
		return false
	total_timber_spent += cost
	var definition := _selected_definition
	var site := _spawn_site(definition)
	cancel_build_mode()
	building_placed.emit(definition, site)
	if definition.building_id == STOREHOUSE_ID:
		storehouse_placed.emit()
	return true

func _get_confirmation_blocker() -> String:
	if _selected_definition == null:
		return "UNAVAILABLE"
	if _den == null or not _den.is_complete():
		return "COMPLETE PRIMALIS DEN FIRST"
	if get_building_count(_selected_definition.building_id) >= _selected_definition.max_instances:
		return "MAX BUILT"
	if get_active_project() != null:
		return "CONSTRUCTION IN PROGRESS"
	if _resources == null or not _resources.can_spend_timber(_selected_definition.timber_cost):
		return "NOT ENOUGH TIMBER"
	return ""

func _unhandled_input(event: InputEvent) -> void:
	if not placing:
		return
	if event.is_action_pressed("select_primary"):
		try_confirm_placement()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("command_secondary") or event.is_action_pressed("build_cancel"):
		cancel_build_mode()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("build_rotate"):
		rotate_ghost()
		get_viewport().set_input_as_handled()

func _process(_delta: float) -> void:
	if not placing:
		return
	var viewport := get_viewport()
	var camera := viewport.get_camera_3d()
	if camera == null:
		return
	var mouse := viewport.get_mouse_position()
	if _cursor_over_hud(mouse):
		_ghost_on_ground = false
		_ghost_valid = false
		_apply_ghost_tint()
		return
	var from := camera.project_ray_origin(mouse)
	var to := from + camera.project_ray_normal(mouse) * RAY_LENGTH
	var query := PhysicsRayQueryParameters3D.create(from, to, 1)
	var hit := camera.get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		_ghost_on_ground = false
		_ghost_valid = false
	else:
		_ghost.global_position = Vector3(hit.position.x, 0.0, hit.position.z)
		_ghost_on_ground = true
		_ghost_valid = _validate()
	_apply_ghost_tint()

func _validate() -> bool:
	if _selected_definition == null:
		return false
	var pos := _ghost.global_position
	var extents := _rotated_half_extents(_selected_definition.footprint, _rotation_index)
	if absf(pos.x) > BOUNDS_LIMIT - extents.x + 3.0 \
			or absf(pos.z) > BOUNDS_LIMIT - extents.y + 3.0:
		return false
	_query_params.transform = Transform3D(Basis(Vector3.UP, _ghost.rotation.y), pos + Vector3(0, 1.1, 0))
	var space := _ghost.get_world_3d().direct_space_state
	if not space.intersect_shape(_query_params, 1).is_empty():
		return false
	for building_id in _sites:
		for site in get_buildings(building_id):
			var existing_definition := _site_definitions.get(site.get_instance_id()) as BuildingDefinition
			if existing_definition != null and _overlaps_site(pos, extents, site, existing_definition):
				return false
	for entry in _clearances:
		var node: Node3D = entry[0]
		var clearance: float = entry[1]
		if node != null and is_instance_valid(node):
			var distance := Vector2(pos.x - node.global_position.x, pos.z - node.global_position.z).length()
			if distance < clearance:
				return false
	return true

func _rotated_half_extents(footprint: Vector3, rotation_index: int) -> Vector2:
	if rotation_index % 2 == 1:
		return Vector2(footprint.z * 0.5, footprint.x * 0.5)
	return Vector2(footprint.x * 0.5, footprint.z * 0.5)

func _overlaps_site(pos: Vector3, extents: Vector2, site: ConstructionProject,
		existing_definition: BuildingDefinition) -> bool:
	var site_rotation := posmod(roundi(rad_to_deg(site.rotation.y) / 90.0), 4)
	var site_extents := _rotated_half_extents(existing_definition.footprint, site_rotation)
	return absf(pos.x - site.global_position.x) < extents.x + site_extents.x \
		and absf(pos.z - site.global_position.z) < extents.y + site_extents.y

func _resolve_clearances() -> void:
	if _world == null:
		return
	var anchors := _world.get_node_or_null("Anchors")
	if anchors == null:
		return
	var spec := [
		["DenSite", 8.0],
		["FeedingSpot", 6.0],
		["FoodSource", 6.0],
		["TimberGrove", 6.0],
		["FoodStore", 5.5],
		["MaterialYard", 5.5],
	]
	for entry in spec:
		var node := anchors.get_node_or_null(entry[0]) as Node3D
		if node != null:
			_clearances.append([node, entry[1]])

func _build_ghost() -> void:
	_ghost = Node3D.new()
	_ghost.name = "PlacementGhost"
	_ghost_mesh = MeshInstance3D.new()
	_ghost_mesh.mesh = BoxMesh.new()
	_mat_valid = StandardMaterial3D.new()
	_mat_valid.albedo_color = Color(0.4, 0.9, 0.5, 0.45)
	_mat_valid.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat_invalid = StandardMaterial3D.new()
	_mat_invalid.albedo_color = Color(0.95, 0.35, 0.3, 0.5)
	_mat_invalid.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_ghost_mesh.material_override = _mat_valid
	_ghost.add_child(_ghost_mesh)
	_ghost.visible = false
	add_child(_ghost)
	_query_shape = BoxShape3D.new()
	_query_params = PhysicsShapeQueryParameters3D.new()
	_query_params.shape = _query_shape
	_query_params.collision_mask = 1

func _set_ghost_footprint(footprint: Vector3) -> void:
	(_ghost_mesh.mesh as BoxMesh).size = Vector3(footprint.x, 3.0, footprint.z)
	_ghost_mesh.position = Vector3(0, 1.5, 0)
	_query_shape.size = footprint

func _cursor_over_hud(mouse: Vector2) -> bool:
	var hud := get_tree().get_first_node_in_group("debug_hud")
	if hud == null:
		return false
	var panel := hud.get_node_or_null("Panel") as Control
	return panel != null and panel.get_global_rect().has_point(mouse)

func _apply_ghost_tint() -> void:
	_ghost_mesh.material_override = _mat_valid if _ghost_valid else _mat_invalid

func _spawn_site(definition: BuildingDefinition) -> ConstructionProject:
	var instance := definition.packed_scene.instantiate() as ConstructionProject
	var nav_region := _world.get_node("NavRegion")
	nav_region.add_child(instance)
	instance.global_position = _ghost.global_position
	instance.rotation.y = _ghost.rotation.y
	var number := get_building_count(definition.building_id) + 1
	instance.configure_building(definition, number)
	(_sites[definition.building_id] as Array).append(instance)
	_site_definitions[instance.get_instance_id()] = definition
	_active_site = instance
	instance.completed.connect(_on_site_completed.bind(definition, instance))
	return instance

func _on_site_completed(definition: BuildingDefinition, site: ConstructionProject) -> void:
	var shape := site.get_node_or_null("Obstacle/Shape") as CollisionShape3D
	if shape != null:
		shape.disabled = false
	if _active_site == site:
		_active_site = null
	if _world != null and _world.has_method("rebake_navmesh"):
		_world.rebake_navmesh()
	building_completed.emit(definition, site)
