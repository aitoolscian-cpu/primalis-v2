class_name SelectionManager
extends Node
## Owns click handling: left-click select/deselect, right-click move commands.
## Layers: 1 = World (ground, rocks, borders, trunks), 2 = Selectable bodies.
## Anything in the "selectable" group with the small selection contract
## (set_selected / get_selection_name / get_selection_type) can be selected.
## Only Primalis accepts move commands; villagers stay autonomous.

const RAY_LENGTH := 600.0
const MASK_WORLD := 1
const MASK_CLICKABLE := 3
const CLICK_FORGIVENESS_RADIUS := 1.3  # RTS click tolerance around small units

@export var command_marker_path: NodePath

var command_marker: CommandMarker = null
var _selected: CharacterBody3D = null

func _ready() -> void:
	if not command_marker_path.is_empty():
		command_marker = get_node_or_null(command_marker_path) as CommandMarker

func has_selection() -> bool:
	return is_instance_valid(_selected)

func get_selected() -> CharacterBody3D:
	return _selected

## Suspend/resume RTS mouse gameplay (used while Primalis is possessed).
func set_active(active: bool) -> void:
	set_process_unhandled_input(active)

func select(unit: CharacterBody3D) -> void:
	_set_selected(unit)

func deselect_all() -> void:
	_set_selected(null)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("select_primary"):
		_handle_select()
	elif event.is_action_pressed("command_secondary"):
		_handle_command()

func _handle_select() -> void:
	var hit := _ray_from_cursor(MASK_CLICKABLE)
	if hit.is_empty():
		return  # Clicked the sky: keep current selection.
	var collider: Object = hit.get("collider")
	if collider is CharacterBody3D and (collider as Node).is_in_group("selectable"):
		_set_selected(collider as CharacterBody3D)
	else:
		# Click forgiveness: a near-miss on a small unit still selects it;
		# genuinely empty ground (nothing within the radius) deselects.
		_set_selected(_nearest_selectable_around(hit.get("position")))

func _handle_command() -> void:
	# Villagers are autonomous: commands (and command feedback) apply only to Primalis.
	if not (_selected is PrimalisController):
		return
	var hit := _ray_from_cursor(MASK_WORLD)
	if hit.is_empty():
		return
	var map: RID = _selected.get_world_3d().navigation_map
	var target: Vector3 = NavigationServer3D.map_get_closest_point(map, hit.get("position"))
	(_selected as PrimalisController).command_move_to(target)
	if command_marker != null:
		command_marker.flash_at(target)

func _nearest_selectable_around(world_pos: Vector3) -> CharacterBody3D:
	var best: CharacterBody3D = null
	var best_dist := CLICK_FORGIVENESS_RADIUS
	for node in get_tree().get_nodes_in_group("selectable"):
		var body := node as CharacterBody3D
		if body == null:
			continue
		var d := Vector2(body.global_position.x - world_pos.x, body.global_position.z - world_pos.z).length()
		if d < best_dist:
			best_dist = d
			best = body
	return best

func _ray_from_cursor(mask: int) -> Dictionary:
	var viewport := get_viewport()
	var camera := viewport.get_camera_3d()
	if camera == null:
		return {}
	var mouse := viewport.get_mouse_position()
	var from := camera.project_ray_origin(mouse)
	var to := from + camera.project_ray_normal(mouse) * RAY_LENGTH
	var query := PhysicsRayQueryParameters3D.create(from, to, mask)
	return camera.get_world_3d().direct_space_state.intersect_ray(query)

func _set_selected(next: CharacterBody3D) -> void:
	if _selected == next:
		return
	if has_selection():
		_selected.set_selected(false)
	_selected = next
	if _selected != null:
		_selected.set_selected(true)
