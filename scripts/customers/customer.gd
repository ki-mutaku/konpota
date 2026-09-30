class_name Customer
extends Node2D

signal soup_received(payload: Variant)
signal evaluation_requested(request_id: int, payload: Variant)
signal evaluation_completed(result: EvaluationResult)

var _request_sequence: int = 0
var _pending_request_id: int = 0
var _notifying_completion: bool = false

@onready var drop_target: DirectDropTarget = $DropTarget


func can_receive_soup(payload: Variant) -> bool:
	return (
		not _notifying_completion
		and _pending_request_id == 0
		and is_supported_payload(payload)
	)


static func is_supported_payload(payload: Variant) -> bool:
	if payload is SoupData:
		return true
	if not payload is Dictionary:
		return false
	# Validate the existing CookingPot snapshot, without converting or scoring it.
	if not payload.get("ingredients") is Array or payload["ingredients"].is_empty():
		return false
	for entry: Variant in payload["ingredients"]:
		if not entry is Dictionary or not entry.get("data") is Resource:
			return false
		var amount: Variant = entry.get("amount")
		if not _is_finite_number(amount) or amount <= 0.0:
			return false
	return (
		_is_finite_number(payload.get("heat_level"))
		and _is_finite_number(payload.get("stir_distance"))
	)


static func _is_finite_number(value: Variant) -> bool:
	return (value is float or value is int) and is_finite(float(value))


func _on_drop_target_item_received(payload: Variant, _source: DirectDraggableItem) -> void:
	# CustomerDropTarget validates before try_receive reports success to Cooking.
	if not can_receive_soup(payload):
		return
	_request_sequence += 1
	_pending_request_id = _request_sequence
	drop_target.enabled = false
	soup_received.emit(payload)
	# The evaluator subscribes here and later calls complete_evaluation.
	evaluation_requested.emit(_pending_request_id, payload)


func complete_evaluation(request_id: int, result: EvaluationResult) -> bool:
	if result == null or request_id == 0 or request_id != _pending_request_id:
		return false
	_pending_request_id = 0
	_notifying_completion = true
	# Keep receiving disabled during notification to avoid reentrant deliveries.
	evaluation_completed.emit(result)
	_notifying_completion = false
	drop_target.enabled = true
	return true
