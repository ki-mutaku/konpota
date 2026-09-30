class_name DirectDraggableItem
extends Area2D

signal drag_started(item: DirectDraggableItem)
signal drag_moved(item: DirectDraggableItem, global_pointer_position: Vector2)
signal drag_finished(
	item: DirectDraggableItem,
	accepted: bool,
	target: DirectDropTarget,
)

enum AcceptedBehavior {
	STAY,
	RETURN_HOME,
	HIDE,
}

@export var drag_tag: StringName = &"ingredient"
@export var payload: Resource
@export var processing_state: StringName = &"raw"
@export var movement_bounds: Rect2 = Rect2(0.0, 0.0, 1280.0, 720.0)
@export var use_viewport_bounds: bool = true
@export var return_on_rejected: bool = true
@export var accepted_behavior: AcceptedBehavior = AcceptedBehavior.RETURN_HOME
@export_flags_2d_physics var drop_target_collision_mask: int = 2

var _dragging: bool = false
var _touch_index: int = -1
var _grab_offset: Vector2 = Vector2.ZERO
var _home_global_position: Vector2 = Vector2.ZERO
var _hovered_target: DirectDropTarget


func _ready() -> void:
	_home_global_position = global_position
	add_to_group(&"direct_draggable_item")
	input_event.connect(_on_input_event)


func _input(event: InputEvent) -> void:
	if not _dragging:
		return

	if event is InputEventScreenDrag and event.index == _touch_index:
		_move_to(event.position)
	elif event is InputEventScreenTouch and event.index == _touch_index and not event.pressed:
		_finish_drag(event.position)
	elif event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_move_to(event.position)
	elif (
		event is InputEventMouseButton
		and event.button_index == MOUSE_BUTTON_LEFT
		and not event.pressed
	):
		_finish_drag(event.position)


func get_interaction_payload() -> Variant:
	return payload if payload != null else self


func get_payload_id() -> StringName:
	if payload == null:
		return &""
	return StringName(str(payload.get("id")))


func mark_processed(state: StringName, animation_name: StringName = &"") -> void:
	processing_state = state
	if animation_name == &"":
		return
	var sprite: AnimatedSprite2D = get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if sprite != null and sprite.sprite_frames.has_animation(animation_name):
		sprite.play(animation_name)


func reset_processing_state() -> void:
	processing_state = &"raw"
	var sprite: AnimatedSprite2D = get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if sprite != null and sprite.sprite_frames.has_animation(&"default"):
		sprite.play(&"default")


func reset_to_home() -> void:
	_clear_hover_target()
	_dragging = false
	_touch_index = -1
	global_position = _home_global_position
	z_index = 0
	visible = true


func _on_input_event(viewport: Viewport, event: InputEvent, _shape_index: int) -> void:
	if event is InputEventScreenTouch and event.pressed:
		_begin_drag(event.position, event.index)
		viewport.set_input_as_handled()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_begin_drag(event.position, -1)
		viewport.set_input_as_handled()


func _begin_drag(pointer_position: Vector2, touch_index: int) -> void:
	_dragging = true
	_touch_index = touch_index
	_grab_offset = global_position - pointer_position
	z_index = 100
	drag_started.emit(self)


func _move_to(pointer_position: Vector2) -> void:
	var desired: Vector2 = pointer_position + _grab_offset
	var bounds: Rect2 = movement_bounds
	if use_viewport_bounds:
		bounds = get_viewport_rect()
	desired.x = clampf(desired.x, bounds.position.x, bounds.end.x)
	desired.y = clampf(desired.y, bounds.position.y, bounds.end.y)
	global_position = desired
	_update_hover_target(pointer_position)
	drag_moved.emit(self, pointer_position)


func _finish_drag(pointer_position: Vector2) -> void:
	_dragging = false
	_touch_index = -1
	z_index = 0

	var accepted: bool = false
	var target: DirectDropTarget = _find_drop_target(pointer_position)
	if target != null:
		accepted = target.try_receive(self)
	_clear_hover_target()

	if accepted:
		_apply_accepted_behavior()
	elif return_on_rejected:
		reset_to_home()

	drag_finished.emit(self, accepted, target)


func _find_drop_target(point: Vector2) -> DirectDropTarget:
	var query: PhysicsPointQueryParameters2D = PhysicsPointQueryParameters2D.new()
	query.position = point
	query.collide_with_areas = true
	query.collide_with_bodies = false
	query.collision_mask = drop_target_collision_mask

	var hits: Array[Dictionary] = get_world_2d().direct_space_state.intersect_point(query, 32)
	for hit: Dictionary in hits:
		var collider: Variant = hit.get("collider")
		if collider is DirectDropTarget and collider.accepts(self):
			return collider
	return null


func _update_hover_target(point: Vector2) -> void:
	var next_target: DirectDropTarget = _find_drop_target(point)
	if next_target == _hovered_target:
		return
	_clear_hover_target()
	_hovered_target = next_target
	if _hovered_target != null:
		_hovered_target.set_highlighted(true)


func _clear_hover_target() -> void:
	if _hovered_target != null:
		_hovered_target.set_highlighted(false)
	_hovered_target = null


func _apply_accepted_behavior() -> void:
	match accepted_behavior:
		AcceptedBehavior.STAY:
			pass
		AcceptedBehavior.RETURN_HOME:
			reset_to_home()
		AcceptedBehavior.HIDE:
			visible = false
