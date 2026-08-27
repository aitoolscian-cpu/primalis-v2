class_name BuildModeController
extends Node
## Construction direction for the settlement:
##  - knows the ACTIVE construction project (Den first, then the placed
##    Storehouse) that Builders should work on;
##  - owns prototype building-placement mode for the single Storehouse:
##    ghost preview, footprint validation, rotation, cancel, confirm.
## While placing: LMB confirms, RMB/Esc cancels, R rotates. Selection and
## possession input are suspended; the RTS camera stays live. Simulation
## never pauses. Timber (8) is spent only on confirmed valid placement and
## is tracked in total_timber_spent for the conservation invariant.

signal build_mode_changed
signal storehouse_placed

const RAY_LENGTH := 600.0
const FOOTPRINT := Vector3(6.0, 2.0, 5.0)
const BOUNDS_LIMIT := 54.0

@export var storehouse_cost := 8
@export var storehouse_scene: PackedScene
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
var _site: ConstructionProject = null
var _mat_valid: StandardMaterial3D
var _mat_invalid: StandardMaterial3D
var _query_shape: BoxShape3D
var _query_params: PhysicsShapeQueryParameters3D
## Anchor keep-clear list: (node, clearance radius) resolved at ready.
var _clearances: Array = []

func _ready() -> void:
	_den = get_node_or_null(den_path) as ConstructionProject
	_world = get_node_or_null(world_path) as Node3D
	_resources = get_tree().get_first_node_in_group("settlement_resources") as SettlementResources
	_selection = get_tree().get_first_node_in_group("selection_manager") as SelectionManager
	_modes = get_tree().get_first_node_in_group("control_mode_manager") as ControlModeManager
	_build_ghost()
	_resolve_clearances()
	set_process(false)

## The single project Builders should currently work on (null when none).
func get_active_project() -> ConstructionProject:
	if _den != null and not _den.is_complete():
		return _den
	if _site != null and is_instance_valid(_site) and not _site.is_complete():
		return _site
	return null

func has_storehouse_site() -> bool:
	return _site != null and is_instance_valid(_site)

func get_storehouse() -> ConstructionProject:
	return _site

## Why placement cannot begin right now; empty string means available.
func get_unavailable_reason() -> String:
	if placing:
		return "PLACING..."
	if has_storehouse_site():
		return "STOREHOUSE PLACED"
	if _den == null or not _den.is_complete():
		return "COMPLETE PRIMALIS DEN FIRST"
	if _resources == null or not _resources.can_spend_timber(storehouse_cost):
		return "NEED %d TIMBER" % storehouse_cost
	if _modes != null and _modes.is_direct():
		return "UNAVAILABLE"
	return ""

func enter_build_mode() -> bool:
	if get_unavailable_reason() != "":
		return false
	placing = true
	_rotation_index = 0
	_ghost.rotation.y = 0.0
	# Never inherit the previous session's position/validity: an API-driven
	# confirm before the first cursor update must not place at a stale spot.
	_ghost_on_ground = false
	_ghost_valid = false
	_ghost.visible = true
	set_process(true)
	# Suspend selection clicks and possession; RTS camera stays live.
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
	_rotation_index = (_rotation_index + 1) % 4
	_ghost.rotation.y = deg_to_rad(_rotation_index * 90.0)

## Testable placement path: position the ghost explicitly (headless tests).
func set_ghost_position(world_pos: Vector3) -> void:
	_ghost.global_position = Vector3(world_pos.x, 0.0, world_pos.z)
	_ghost_on_ground = true
	_ghost_valid = _validate()
	_apply_ghost_tint()

func try_confirm_placement() -> bool:
	if not placing or not _ghost_on_ground:
		return false
	_ghost_valid = _validate()
	if not _ghost_valid:
		return false
	if _resources == null or not _resources.try_spend_timber(storehouse_cost):
		return false
	total_timber_spent += storehouse_cost
	_spawn_site()
	cancel_build_mode()
	storehouse_placed.emit()
	return true

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
	# Clicks over the HUD are consumed by the panel and can never confirm, so
	# the ghost must not advertise a valid placement underneath it.
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

## Footprint validation: inside bounds, no static-obstacle overlap, and
## clear of every reserved anchor. Moving characters are ignored (their
## bodies are on layer 2, outside the query mask).
func _validate() -> bool:
	var pos := _ghost.global_position
	# Rotated-footprint conservative bounds check.
	var half := FOOTPRINT * 0.5
	var extent := maxf(half.x, half.z)
	if absf(pos.x) > BOUNDS_LIMIT - extent + 3.0 or absf(pos.z) > BOUNDS_LIMIT - extent + 3.0:
		return false
	# Physics overlap against world statics (rocks, trunks, borders...).
	# Box floats above ground so the ground plane itself never hits.
	# Shape and params are cached: _validate runs every frame while placing.
	_query_params.transform = Transform3D(Basis(Vector3.UP, _ghost.rotation.y), pos + Vector3(0, 1.1, 0))
	var space := _ghost.get_world_3d().direct_space_state
	if not space.intersect_shape(_query_params, 1).is_empty():
		return false
	# Reserved-anchor clearances.
	for entry in _clearances:
		var node: Node3D = entry[0]
		var clearance: float = entry[1]
		if node != null and is_instance_valid(node):
			var d := Vector2(pos.x - node.global_position.x, pos.z - node.global_position.z).length()
			if d < clearance:
				return false
	return true

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
	var box := BoxMesh.new()
	box.size = Vector3(FOOTPRINT.x, 3.0, FOOTPRINT.z)
	_ghost_mesh.mesh = box
	_ghost_mesh.position = Vector3(0, 1.5, 0)
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
	_query_shape.size = FOOTPRINT
	_query_params = PhysicsShapeQueryParameters3D.new()
	_query_params.shape = _query_shape
	_query_params.collision_mask = 1

func _cursor_over_hud(mouse: Vector2) -> bool:
	var hud := get_tree().get_first_node_in_group("debug_hud")
	if hud == null:
		return false
	var panel := hud.get_node_or_null("Panel") as Control
	return panel != null and panel.get_global_rect().has_point(mouse)

func _apply_ghost_tint() -> void:
	_ghost_mesh.material_override = _mat_valid if _ghost_valid else _mat_invalid

func _spawn_site() -> void:
	var instance := storehouse_scene.instantiate() as ConstructionProject
	# Under the NavigationRegion so its (completion-enabled) obstacle is
	# parsed when the navmesh rebakes.
	var nav_region := _world.get_node("NavRegion")
	nav_region.add_child(instance)
	instance.global_position = _ghost.global_position
	instance.rotation.y = _ghost.rotation.y
	_site = instance
	_site.completed.connect(_on_storehouse_completed)

func _on_storehouse_completed() -> void:
	# The finished building becomes a physical obstacle; carve the navmesh.
	var shape := _site.get_node("Obstacle/Shape") as CollisionShape3D
	shape.disabled = false
	if _world != null and _world.has_method("rebake_navmesh"):
		_world.rebake_navmesh()
