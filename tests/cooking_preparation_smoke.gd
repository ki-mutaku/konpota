extends SceneTree


func _init() -> void:
	call_deferred("_run_smoke_test")


func _run_smoke_test() -> void:
	var board: CookingCuttingBoard = _instantiate(
		"res://scenes/cooking/cutting_board.tscn"
	) as CookingCuttingBoard
	var mixer: CookingMixer = _instantiate(
		"res://scenes/cooking/mixer.tscn"
	) as CookingMixer
	var pot: CookingPot = _instantiate("res://scenes/cooking/pot.tscn") as CookingPot
	var butter: DirectDraggableItem = _instantiate(
		"res://scenes/ingredients/butter.tscn"
	) as DirectDraggableItem
	var corn: DirectDraggableItem = _instantiate(
		"res://scenes/ingredients/corn.tscn"
	) as DirectDraggableItem
	var milk: DirectDraggableItem = _instantiate(
		"res://scenes/ingredients/milk.tscn"
	) as DirectDraggableItem

	var pot_target: DirectDropTarget = pot.get_node("IngredientDropArea") as DirectDropTarget
	assert(not pot_target.accepts(butter), "Raw butter must be cut before pot insertion")
	assert(not pot_target.accepts(corn), "Raw corn must be pasted before pot insertion")
	assert(pot_target.accepts(milk), "Milk should be accepted without preprocessing")

	var board_target: DirectDropTarget = (
		board.get_node("IngredientDropArea") as DirectDropTarget
	)
	assert(board_target.try_receive(butter), "Board should accept butter")
	var cut_from: Vector2 = butter.global_position + Vector2(0.0, -80.0)
	var cut_to: Vector2 = butter.global_position + Vector2(0.0, 80.0)
	assert(board.try_slice_segment(cut_from, cut_to), "Downward swipe should cut butter")
	assert(butter.processing_state == &"cut")
	var butter_sprite: AnimatedSprite2D = butter.get_node("AnimatedSprite2D")
	assert(butter_sprite.animation == &"cut", "Cut butter should use butter_cut.png")
	assert(pot_target.accepts(butter), "Cut butter should be accepted by the pot")

	var mixer_target: DirectDropTarget = (
		mixer.get_node("IngredientDropArea") as DirectDropTarget
	)
	var vacant_visual: Sprite2D = mixer.get_node("VacantVisual") as Sprite2D
	var before_visual: Sprite2D = mixer.get_node("BeforeVisual") as Sprite2D
	var after_visual: Sprite2D = mixer.get_node("AfterVisual") as Sprite2D
	assert(vacant_visual.visible, "Empty mixer should display mixer_vacant")
	assert(not before_visual.visible and not after_visual.visible)
	assert(mixer_target.try_receive(corn), "Mixer should accept corn")
	assert(not vacant_visual.visible and before_visual.visible)
	assert(not after_visual.visible, "Loaded mixer should display mixer_before")
	for _pulse: int in mixer.required_pulses:
		mixer.register_pulse()
	assert(mixer.is_processed, "Required pulses should make corn paste")
	assert(not vacant_visual.visible and not before_visual.visible)
	assert(after_visual.visible, "Processed mixer should display mixer_after")
	assert(mixer.output_item.visible, "Processed corn output should become draggable")
	assert(mixer.output_item.processing_state == &"paste")
	assert(pot_target.accepts(mixer.output_item), "Corn paste should be accepted by the pot")

	print("Cooking preparation smoke test passed")
	quit(0)


func _instantiate(path: String) -> Node:
	var scene: PackedScene = load(path)
	var instance: Node = scene.instantiate()
	root.add_child(instance)
	return instance
