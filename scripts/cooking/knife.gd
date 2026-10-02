class_name CookingKnife
extends DirectDraggableItem

signal cut_performed(item: DirectDraggableItem)

var _previous_position: Vector2 = Vector2.ZERO
var _downward_distance: float = 0.0
var _cut_in_stroke: bool = false


func _ready() -> void:
	super._ready()
	drag_started.connect(_on_drag_started)
	drag_moved.connect(_on_drag_moved)
	drag_finished.connect(_on_drag_finished)


func _on_drag_started(_item: DirectDraggableItem) -> void:
	_previous_position = global_position
	_downward_distance = 0.0
	_cut_in_stroke = false


func _on_drag_moved(
	_item: DirectDraggableItem,
	_global_pointer_position: Vector2,
) -> void:
	var current_position: Vector2 = global_position
	var distance: float = current_position.y - _previous_position.y
	if distance < 0.0:
		_downward_distance = 0.0
		_cut_in_stroke = false
	else:
		_downward_distance += distance
	if _cut_in_stroke:
		_previous_position = current_position
		return
	for node: Node in get_tree().get_nodes_in_group(&"cooking_cutting_board"):
		if node is not CookingCuttingBoard:
			continue
		var board: CookingCuttingBoard = node as CookingCuttingBoard
		if board.try_slice_segment(_previous_position, current_position, _downward_distance):
			_cut_in_stroke = true
			cut_performed.emit(board.get_current_ingredient())
			break
	_previous_position = current_position


func _on_drag_finished(
	_item: DirectDraggableItem,
	_accepted: bool,
	_target: DirectDropTarget,
) -> void:
	_previous_position = Vector2.ZERO
	_downward_distance = 0.0
	_cut_in_stroke = false
