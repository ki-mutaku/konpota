class_name CookingCuttingBoard
extends Node2D

signal ingredient_placed(item: DirectDraggableItem)
signal slice_registered(item: DirectDraggableItem, count: int)
signal ingredient_processed(item: DirectDraggableItem)

@export_range(1, 10, 1) var required_swipes: int = 1
@export_range(8.0, 160.0, 1.0) var minimum_downward_distance: float = 48.0

var _ingredient: DirectDraggableItem
var _swipe_count: int = 0
var _slice_segment: SegmentShape2D = SegmentShape2D.new()

@onready var ingredient_drop_area: DirectDropTarget = %IngredientDropArea
@onready var state_label: Label = %StateLabel
@onready var cut_sound: AudioStreamPlayer = $CutSound
@onready var placement_sound: AudioStreamPlayer = $PlacementSound


func _ready() -> void:
	add_to_group(&"cooking_cutting_board")
	_refresh_label()


func try_slice_segment(
	from: Vector2,
	to: Vector2,
	downward_distance: float = -1.0,
) -> bool:
	if _ingredient == null or _ingredient.processing_state == &"cut":
		return false
	var segment_distance: float = to.y - from.y
	if segment_distance <= 0.0:
		return false
	# Accumulate small drag steps without replacing the real path with a start-to-end chord.
	var swipe_distance: float = segment_distance if downward_distance < 0.0 else downward_distance
	if swipe_distance < minimum_downward_distance or not _crosses_ingredient(from, to):
		return false

	_swipe_count += 1
	cut_sound.play()
	slice_registered.emit(_ingredient, _swipe_count)
	if _swipe_count >= required_swipes:
		_ingredient.mark_processed(&"cut", &"cut")
		ingredient_processed.emit(_ingredient)
	_refresh_label()
	return true


func _crosses_ingredient(from: Vector2, to: Vector2) -> bool:
	_slice_segment.a = from
	_slice_segment.b = to
	# Use the ingredient's actual shapes, including their offsets, rotations and scale.
	for owner_id: int in _ingredient.get_shape_owners():
		if _ingredient.is_shape_owner_disabled(owner_id):
			continue
		var shape_transform: Transform2D = (
			_ingredient.global_transform * _ingredient.shape_owner_get_transform(owner_id)
		)
		for shape_index: int in _ingredient.shape_owner_get_shape_count(owner_id):
			var shape: Shape2D = _ingredient.shape_owner_get_shape(owner_id, shape_index)
			if shape.collide(shape_transform, _slice_segment, Transform2D.IDENTITY):
				return true
	return false


func get_current_ingredient() -> DirectDraggableItem:
	return _ingredient


func reset_state() -> void:
	cut_sound.stop()
	placement_sound.stop()
	if _ingredient != null:
		_ingredient.reset_to_home()
	_clear_ingredient()


func _on_ingredient_drop_area_item_received(
	payload: Variant,
	source: DirectDraggableItem,
) -> void:
	_ingredient = source
	_swipe_count = 0
	source.global_position = global_position
	source.accepted_behavior = DirectDraggableItem.AcceptedBehavior.STAY
	source.drag_started.connect(_on_ingredient_drag_started, CONNECT_ONE_SHOT)
	ingredient_drop_area.enabled = false
	if payload is IngredientData and payload.id == &"parsley":
		placement_sound.play()
	ingredient_placed.emit(source)
	_refresh_label()


func _on_ingredient_drag_started(item: DirectDraggableItem) -> void:
	if item != _ingredient:
		return
	item.accepted_behavior = DirectDraggableItem.AcceptedBehavior.RETURN_HOME
	_clear_ingredient()


func _clear_ingredient() -> void:
	var previous: DirectDraggableItem = _ingredient
	_ingredient = null
	_swipe_count = 0
	if previous != null and previous.drag_started.is_connected(_on_ingredient_drag_started):
		previous.drag_started.disconnect(_on_ingredient_drag_started)
	ingredient_drop_area.enabled = true
	_refresh_label()


func _refresh_label() -> void:
	if _ingredient == null:
		state_label.text = "バター / パセリを置く"
	elif _ingredient.processing_state == &"cut":
		state_label.text = "カット済み"
	else:
		state_label.text = "上から下へスワイプ %d/%d" % [
			_swipe_count,
			required_swipes,
		]
