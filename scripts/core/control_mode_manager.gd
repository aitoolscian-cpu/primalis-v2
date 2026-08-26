class_name ControlModeManager
extends Node
## Owns the RTS_COMMAND <-> DIRECT_CONTROL switch (F key):
## input routing, camera ownership, selection suspension, mouse capture.
## There is exactly one Primalis; both modes drive the same body.

enum Mode { RTS, DIRECT }

@export var rts_camera_path: NodePath
@export var selection_manager_path: NodePath
@export var third_person_camera_path: NodePath

var mode: Mode = Mode.RTS

var _rts_camera: RTSCameraController
var _selection: SelectionManager
var _tp_camera: PrimalisThirdPersonCamera
var _possessed: PrimalisController = null

func _ready() -> void:
	_rts_camera = get_node_or_null(rts_camera_path) as RTSCameraController
	_selection = get_node_or_null(selection_manager_path) as SelectionManager
	_tp_camera = get_node_or_null(third_person_camera_path) as PrimalisThirdPersonCamera

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("possess_primalis"):
		toggle_possession()

func is_direct() -> bool:
	return mode == Mode.DIRECT

func get_mode_name() -> String:
	return "PRIMALIS" if mode == Mode.DIRECT else "RTS"

func get_control_name() -> String:
	return "DIRECT" if mode == Mode.DIRECT else "COMMAND"

func toggle_possession() -> void:
	if mode == Mode.RTS:
		if _selection == null:
			return
		var selected := _selection.get_selected()
		if selected is PrimalisController:
			_possess(selected as PrimalisController)
		# F with nothing (or a villager) selected is a safe no-op.
	else:
		_release()

func _possess(primalis: PrimalisController) -> void:
	_possessed = primalis
	_selection.deselect_all()
	_selection.set_active(false)
	_rts_camera.set_active(false)
	primalis.enter_direct_control(_tp_camera)
	_tp_camera.activate(primalis, _rts_camera.rotation.y)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	mode = Mode.DIRECT

func _release() -> void:
	var primalis := _possessed
	_possessed = null
	primalis.exit_direct_control()
	_tp_camera.deactivate()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_rts_camera.recenter_on(primalis.global_position)
	_rts_camera.set_active(true)
	_selection.set_active(true)
	_selection.select(primalis)
	mode = Mode.RTS
