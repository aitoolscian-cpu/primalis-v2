class_name FeedingService
extends Node
## Orchestrates the feed interaction: validates a request, sends Primalis to
## the Feeding Spot, and settles the transaction when eating completes.
## Food is spent at completion (no reservations); one request at a time.

signal feed_state_changed

@export var feed_cost := 3
@export var hunger_reduction := 40.0
@export var fed_threshold := 10.0  # below this, feeding is unnecessary
@export var feeding_spot_path: NodePath

var total_food_consumed := 0

var _resources: SettlementResources
var _primalis: PrimalisController
var _spot: Node3D

func _ready() -> void:
	_resources = get_tree().get_first_node_in_group("settlement_resources") as SettlementResources
	_primalis = get_tree().get_first_node_in_group("primalis") as PrimalisController
	_spot = get_node_or_null(feeding_spot_path) as Node3D
	if _primalis != null:
		_primalis.feeding_completed.connect(_on_feeding_completed)
		_primalis.feeding_cancelled.connect(func() -> void: feed_state_changed.emit())

func is_request_active() -> bool:
	return _primalis != null and (
		_primalis.state == PrimalisController.State.GOING_TO_FEED
		or _primalis.state == PrimalisController.State.FEEDING)

## Why feeding is unavailable right now; empty string means it can start.
func get_unavailable_reason() -> String:
	if _resources == null or _primalis == null or _spot == null:
		return "UNAVAILABLE"
	if is_request_active():
		return "FEEDING..."
	if _primalis.get_hunger() < fed_threshold:
		return "PRIMALIS IS FED"
	if not _resources.can_spend_food(feed_cost):
		return "NOT ENOUGH FOOD"
	if _primalis.control_mode != PrimalisController.ControlMode.RTS_COMMAND:
		return "UNAVAILABLE"
	return ""

func request_feed() -> bool:
	if get_unavailable_reason() != "":
		return false
	_primalis.start_feeding(_spot.global_position)
	feed_state_changed.emit()
	return true

func _on_feeding_completed() -> void:
	# Verify the Food still exists before consuming (spent at completion).
	if _resources.try_spend_food(feed_cost):
		total_food_consumed += feed_cost
		_primalis.get_hunger_node().reduce(hunger_reduction)
	feed_state_changed.emit()
