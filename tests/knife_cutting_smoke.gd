extends SceneTree

var _failed: bool = false
var _board: CookingCuttingBoard
var _ingredient: DirectDraggableItem
var _knife: CookingKnife


func _init() -> void:
	call_deferred("_run_smoke_test")


func _run_smoke_test() -> void:
	_set_up("parsley")
	# The ingredient collider reaches only +/-32.8px horizontally; the board reaches +/-75px.
	_swipe(Vector2(55, -80), Vector2(55, 80))
	_check(_ingredient.processing_state == &"raw", "Board-only crossing must not cut")
	_check(not _board.cut_sound.playing, "Missed ingredient must not play cut SE")
	_swipe(Vector2(0, -80), Vector2(0, 80))
	_check(_ingredient.processing_state == &"cut", "Crossing ingredient collider must cut")
	_check(_board.cut_sound.playing, "Valid cut must play cut SE")
	_tear_down()
	_test_grab_offset()
	_test_bent_path()
	_test_small_steps()
	_test_shape_transforms()
	_test_disabled_shape()
	await create_timer(0.5).timeout
	if _failed:
		quit(1)
		return
	print("Knife cutting smoke test passed (ingredient shapes, grab offset, actual path, small steps)")
	quit(0)


func _test_grab_offset() -> void:
	_set_up("parsley")
	# The pointer passes over the food but the grabbed knife remains 55px to its right.
	_knife.position = _board.position + Vector2(55, -80)
	_knife._begin_drag(_board.position + Vector2(0, -80), -1)
	_knife._move_to(_board.position + Vector2(0, 80))
	_check(_ingredient.processing_state == &"raw", "Pointer alone crossing food must not cut")
	# Conversely, the knife crosses the food even though the pointer stays far to its right.
	_knife.position = _board.position + Vector2(0, -80)
	_knife._begin_drag(_board.position + Vector2(220, -80), -1)
	_knife._move_to(_board.position + Vector2(220, 80))
	_check(_ingredient.processing_state == &"cut", "Knife crossing food must cut despite grab offset")
	_tear_down()


func _test_bent_path() -> void:
	_set_up("parsley")
	_knife.position = _board.position + Vector2(-100, -80)
	_knife.drag_started.emit(_knife)
	_move(Vector2(-100, 80))
	_move(Vector2(100, 80))
	_check(_ingredient.processing_state == &"raw", "An imaginary chord across food must not cut")
	_move(Vector2(0, -80))
	_check(_ingredient.processing_state == &"raw", "Upward movement must not cut")
	_move(Vector2(0, 80))
	_check(_ingredient.processing_state == &"cut", "Subsequent real downward crossing must cut")
	_tear_down()


func _test_small_steps() -> void:
	_set_up("parsley")
	_board.required_swipes = 2
	_knife.position = _board.position + Vector2(0, -80)
	_knife.drag_started.emit(_knife)
	for y: int in [-70, -60, -50, -40]:
		_move(Vector2(0, y))
	_check(_board.get("_swipe_count") == 0, "Short movement above the collider must not count")
	for y: int in [-30, -20, -10, 0, 10, 20, 30]:
		_move(Vector2(0, y))
	_check(_board.get("_swipe_count") == 1, "Small per-frame steps should count one swipe")
	_check(_ingredient.processing_state == &"raw", "Required swipe count must be preserved")
	_move(Vector2(0, -80))
	for y: int in [-70, -60, -50, -40, -30, -20]:
		_move(Vector2(0, y))
	_check(_ingredient.processing_state == &"cut", "Second real swipe should finish processing")
	_tear_down()


func _test_shape_transforms() -> void:
	_set_up("butter")
	var collision: CollisionShape2D = _ingredient.get_node("CollisionShape2D")
	# Exercise the actual rotated capsule and a non-uniformly scaled, rotated ingredient.
	_ingredient.scale = Vector2(0.4, 0.7)
	_ingredient.rotation = 0.35
	collision.position = Vector2(200, -25)
	var center: Vector2 = collision.global_position
	_check(
		_board.try_slice_segment(center - Vector2(0, 80), center + Vector2(0, 80)),
		"Offset, rotated capsule collider must be cut at its real position",
	)
	_tear_down()
	_set_up("parsley")
	collision = _ingredient.get_node("CollisionShape2D")
	var circle: CircleShape2D = CircleShape2D.new()
	circle.radius = 20.0
	collision.shape = circle
	collision.position = Vector2(40, 0)
	var miss: Vector2 = collision.global_position + Vector2(11, 0)
	_check(
		not _board.try_slice_segment(miss - Vector2(0, 80), miss + Vector2(0, 80)),
		"Circular collider must use its scaled radius rather than a fixed cutting radius",
	)
	center = collision.global_position
	_check(
		_board.try_slice_segment(center - Vector2(0, 80), center + Vector2(0, 80)),
		"Crossing a circular ingredient collider should cut",
	)
	_tear_down()


func _test_disabled_shape() -> void:
	_set_up("parsley")
	var collision: CollisionShape2D = _ingredient.get_node("CollisionShape2D")
	collision.disabled = true
	_swipe(Vector2(0, -80), Vector2(0, 80))
	_check(_ingredient.processing_state == &"raw", "Disabled ingredient collider must not cut")
	collision.disabled = false
	var short_from: Vector2 = _board.position + Vector2(0, -10)
	_check(
		not _board.try_slice_segment(short_from, short_from + Vector2(0, 20)),
		"Intersecting the food without enough downward movement must not cut",
	)
	_swipe(Vector2(0, -80), Vector2(0, 80))
	_check(_ingredient.processing_state == &"cut", "Re-enabled collider should allow cutting")
	_tear_down()


func _set_up(ingredient_name: String) -> void:
	_board = _instantiate("res://scenes/cooking/cutting_board.tscn") as CookingCuttingBoard
	_board.position = Vector2(400, 300)
	_ingredient = _instantiate(
		"res://scenes/ingredients/%s.tscn" % ingredient_name
	) as DirectDraggableItem
	_ingredient.scale = Vector2(0.5, 0.5)
	_knife = _instantiate("res://scenes/cooking/knife.tscn") as CookingKnife
	_check(_board.ingredient_drop_area.try_receive(_ingredient), "Board must accept the fixture")


func _swipe(from: Vector2, to: Vector2) -> void:
	_knife.position = _board.position + from
	_knife.drag_started.emit(_knife)
	_move(to)


func _move(to: Vector2) -> void:
	_knife.position = _board.position + to
	_knife.drag_moved.emit(_knife, _knife.global_position)


func _tear_down() -> void:
	_board.reset_state()
	_board.free()
	_ingredient.free()
	_knife.free()


func _check(condition: bool, message: String) -> void:
	if not condition:
		push_error(message)
		_failed = true


func _instantiate(path: String) -> Node:
	var scene: PackedScene = load(path)
	var instance: Node = scene.instantiate()
	root.add_child(instance)
	return instance
