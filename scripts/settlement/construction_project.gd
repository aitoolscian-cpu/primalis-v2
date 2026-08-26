class_name ConstructionProject
extends Node3D
## One shared construction project (the prototype Primalis Den).
## Progress 0-100, labour only (no material costs in Step 6). Each Builder
## in BUILDING state calls contribute(delta) per physics tick, so total
## rate scales linearly with active builders. Visual stages are primitive
## child nodes toggled by progress; once complete, progress is frozen.

signal progress_changed(percent: int)
signal completed

@export var project_name := "PRIMALIS DEN"
@export var rate_per_builder := 0.35  # progress per second per active builder

var progress := 0.0
var complete := false

var _last_percent := -1

@onready var _frame: Node3D = $Frame
@onready var _walls: Node3D = $Walls
@onready var _roof: Node3D = $Roof
@onready var _piles: Node3D = $Piles
@onready var _label: Label3D = $Label
## Optional finished-asset visual (the Creative Director's real Den model);
## shown only at 100%, replacing the primitive construction stages.
@onready var _complete_den: Node3D = get_node_or_null("CompleteDen")

func _ready() -> void:
	_refresh()

func get_percent() -> int:
	return clampi(int(floorf(progress)), 0, 100)

func is_complete() -> bool:
	return complete

## Called by each actively BUILDING villager every physics tick.
func contribute(delta: float) -> void:
	if complete:
		return
	progress = clampf(progress + rate_per_builder * delta, 0.0, 100.0)
	if progress >= 100.0:
		complete = true
		completed.emit()
	_refresh()

## Test/debug helper: jump to a progress value (respects completion rules).
func debug_set_progress(value: float) -> void:
	if complete:
		return
	progress = clampf(value, 0.0, 100.0)
	if progress >= 100.0:
		complete = true
		completed.emit()
	_refresh()

func _refresh() -> void:
	var percent := get_percent()
	if percent == _last_percent:
		return
	_last_percent = percent
	var show_primitives := not (complete and _complete_den != null)
	_frame.visible = percent >= 25 and show_primitives
	_walls.visible = percent >= 50 and show_primitives
	_roof.visible = percent >= 75 and show_primitives
	_piles.visible = percent < 100
	if _complete_den != null:
		_complete_den.visible = complete
	($Foundation as Node3D).visible = show_primitives
	if complete:
		_label.text = "%s\nCOMPLETE" % project_name
	else:
		_label.text = "%s %d%%" % [project_name, percent]
	progress_changed.emit(percent)
