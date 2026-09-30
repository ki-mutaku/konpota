class_name CookingKnife
extends DirectDraggableItem

signal cut_performed(item: DirectDraggableItem)

var _swipe_start: Vector2 = Vector2.ZERO


func _ready() -> void:
	super._ready()
	drag_started.connect(_on_drag_started)
	drag_moved.connect(_on_drag_moved)
	drag_finished.connect(_on_drag_finished)


func _on_drag_started(_item: DirectDraggableItem) -> void:
	_swipe_start = global_position


func _on_drag_moved(
	_item: DirectDraggableItem,
	global_pointer_position: Vector2,
) -> void:
	for node: Node in get_tree().get_nodes_in_group(&"cooking_cutting_board"):
		if node is not CookingCuttingBoard:
			continue
		var board: CookingCuttingBoard = node as CookingCuttingBoard
		if board.try_slice_segment(_swipe_start, global_pointer_position):
			_swipe_start = global_pointer_position
			cut_performed.emit(board.get_current_ingredient())


func _on_drag_finished(
	_item: DirectDraggableItem,
	_accepted: bool,
	_target: DirectDropTarget,
) -> void:
	_swipe_start = Vector2.ZERO
