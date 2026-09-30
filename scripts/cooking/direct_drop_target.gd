class_name DirectDropTarget
extends Area2D

signal item_received(payload: Variant, source: DirectDraggableItem)
signal highlight_changed(active: bool)

@export var accepted_tag: StringName = &"ingredient"
@export var accepted_payload_ids: Array[StringName] = []
@export var required_processing_states: Dictionary = {}
@export var enabled: bool = true

var is_highlighted: bool = false


func accepts(item: DirectDraggableItem) -> bool:
	if not enabled:
		return false
	if accepted_tag != &"" and item.drag_tag != accepted_tag:
		return false

	var payload_id: StringName = item.get_payload_id()
	if not accepted_payload_ids.is_empty() and payload_id not in accepted_payload_ids:
		return false

	var required_state: StringName = StringName(
		str(required_processing_states.get(payload_id, &""))
	)
	return required_state == &"" or item.processing_state == required_state


func try_receive(item: DirectDraggableItem) -> bool:
	if not accepts(item):
		return false

	item_received.emit(item.get_interaction_payload(), item)
	return true


func set_highlighted(active: bool) -> void:
	if is_highlighted == active:
		return
	is_highlighted = active
	highlight_changed.emit(is_highlighted)
