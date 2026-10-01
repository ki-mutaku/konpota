class_name CookingCuttingBoard
extends Node2D

signal ingredient_placed(item: DirectDraggableItem)
signal slice_registered(item: DirectDraggableItem, count: int)
signal ingredient_processed(item: DirectDraggableItem)

@export_range(1, 10, 1) var required_swipes: int = 1
@export_range(8.0, 160.0, 1.0) var minimum_downward_distance: float = 48.0
@export_range(16.0, 160.0, 1.0) var cutting_radius: float = 72.0

var _ingredient: DirectDraggableItem
var _swipe_count: int = 0

@onready var ingredient_drop_area: DirectDropTarget = %IngredientDropArea
@onready var state_label: Label = %StateLabel
@onready var cut_sound: AudioStreamPlayer = $CutSound


func _ready() -> void:
	add_to_group(&"cooking_cutting_board")
	_refresh_label()


func try_slice_segment(from: Vector2, to: Vector2) -> bool:
	if _ingredient == null or _ingredient.processing_state == &"cut":
		return false
	if to.y - from.y < minimum_downward_distance:
		return false

	var closest: Vector2 = Geometry2D.get_closest_point_to_segment(
		_ingredient.global_position,
		from,
		to,
	)
	if closest.distance_to(_ingredient.global_position) > cutting_radius:
		return false

	_swipe_count += 1
	cut_sound.play()
	slice_registered.emit(_ingredient, _swipe_count)
	if _swipe_count >= required_swipes:
		_ingredient.mark_processed(&"cut", &"cut")
		ingredient_processed.emit(_ingredient)
	_refresh_label()
	return true


func get_current_ingredient() -> DirectDraggableItem:
	return _ingredient


func reset_state() -> void:
	cut_sound.stop()
	if _ingredient != null:
		_ingredient.reset_to_home()
	_clear_ingredient()


func _on_ingredient_drop_area_item_received(
	_payload: Variant,
	source: DirectDraggableItem,
) -> void:
	_ingredient = source
	_swipe_count = 0
	source.global_position = global_position
	source.accepted_behavior = DirectDraggableItem.AcceptedBehavior.STAY
	source.drag_started.connect(_on_ingredient_drag_started, CONNECT_ONE_SHOT)
	ingredient_drop_area.enabled = false
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
