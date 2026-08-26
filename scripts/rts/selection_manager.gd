class_name SelectionManager
extends Node
## Owns click handling: left-click select/deselect, right-click move commands.
## Layers: 1 = World (ground, rocks, borders, trunks), 2 = Selectable (Primalis).

const RAY_LENGTH := 600.0
const MASK_WORLD := 1
const MASK_CLICKABLE := 3

@export var command_marker_path: NodePath

var command_marker: CommandMarker = null
var _selected: PrimalisController = null

func _ready() -> void:
	if not command_marker_path.is_empty():
		command_marker = get_node_or_null(command_marker_path) as CommandMarker

func has_selection() -> bool:
	return is_instance_valid(_selected)

func select(unit: PrimalisController) -> void:
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
	if collider is PrimalisController:
		_set_selected(collider as PrimalisController)
	else:
		_set_selected(null)

func _handle_command() -> void:
	if not has_selection():
		return
	var hit := _ray_from_cursor(MASK_WORLD)
	if hit.is_empty():
		return
	var map: RID = _selected.get_world_3d().navigation_map
	var target: Vector3 = NavigationServer3D.map_get_closest_point(map, hit.get("position"))
	_selected.command_move_to(target)
	if command_marker != null:
		command_marker.flash_at(target)

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

func _set_selected(next: PrimalisController) -> void:
	if _selected == next:
		return
	if has_selection():
		_selected.set_selected(false)
	_selected = next
	if _selected != null:
		_selected.set_selected(true)
