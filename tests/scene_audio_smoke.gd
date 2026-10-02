extends SceneTree


func _init() -> void:
	call_deferred("_run_smoke_test")


func _run_smoke_test() -> void:
	await _test_music_transition()
	_test_stage_clear()
	_test_placement()
	_test_pot_ingredients()
	await create_timer(0.5).timeout
	print("Scene audio smoke test passed (BGM, clear, placement, pot ingredients)")
	quit(0)


func _test_music_transition() -> void:
	var title: Control = _instantiate("res://scenes/game/title.tscn") as Control
	current_scene = title
	var title_music: AudioStreamPlayer = title.get_node("BackgroundMusic")
	_assert_stream(title_music, "res://assets/audio/title_menu.mp3", true)
	assert(title_music.autoplay and title_music.playing)
	(title.get_node("GameStartButton") as Button).pressed.emit()
	await process_frame
	await process_frame
	assert(not is_instance_valid(title_music), "Title BGM must be removed on scene transition")
	var session: Node = current_scene
	assert(session.name == "StageSession")
	var cooking_music: AudioStreamPlayer = session.kitchen.get_node("BackgroundMusic")
	_assert_stream(cooking_music, "res://assets/audio/cooking_scene.mp3", true)
	assert(cooking_music.autoplay and cooking_music.playing)
	assert(session.stage_manager.finish_stage())
	assert(not cooking_music.playing, "Stage completion must stop cooking BGM")
	assert(session.result_view.visible)
	assert(not session.result_view.stage_clear_sound.playing, "Uncleared result must remain silent")
	assert(change_scene_to_file("res://scenes/game/title.tscn") == OK)
	await process_frame
	await process_frame
	assert(not is_instance_valid(cooking_music))
	title_music = current_scene.get_node("BackgroundMusic")
	assert(title_music.playing, "Returning to Title should restart title BGM")
	title_music.stop()
	current_scene.free()


func _test_stage_clear() -> void:
	var view: StageResultView = _instantiate(
		"res://scenes/ui/stage_result_view.tscn"
	) as StageResultView
	_assert_stream(view.stage_clear_sound, "res://assets/audio/stage_clear.mp3")
	assert(not view.visible and not view.stage_clear_sound.playing)
	view.show_result(StageResult.new([], 6, 9, false))
	assert(view.visible and not view.stage_clear_sound.playing)
	view.show_result(StageResult.new([], 9, 9, true))
	assert(view.satisfaction_label.text == "最終満足度 9 / 9")
	assert(view.stage_clear_sound.playing, "Clear audio should start with final satisfaction display")
	view.show_result(StageResult.new([], 0, 9, false))
	assert(not view.stage_clear_sound.playing)
	view.free()


func _test_placement() -> void:
	var mixer: CookingMixer = _instantiate("res://scenes/cooking/mixer.tscn") as CookingMixer
	var board: CookingCuttingBoard = _instantiate(
		"res://scenes/cooking/cutting_board.tscn"
	) as CookingCuttingBoard
	var corn: DirectDraggableItem = _instantiate(
		"res://scenes/ingredients/corn.tscn"
	) as DirectDraggableItem
	var parsley: DirectDraggableItem = _instantiate(
		"res://scenes/ingredients/parsley.tscn"
	) as DirectDraggableItem
	var butter: DirectDraggableItem = _instantiate(
		"res://scenes/ingredients/butter.tscn"
	) as DirectDraggableItem
	_assert_stream(mixer.placement_sound, "res://assets/audio/place_ingredients.mp3")
	_assert_stream(board.placement_sound, "res://assets/audio/place_ingredients.mp3")
	var mixer_target: DirectDropTarget = mixer.get_node("IngredientDropArea")
	assert(not mixer_target.try_receive(butter))
	assert(not mixer.placement_sound.playing, "Rejected mixer ingredient must remain silent")
	assert(mixer_target.try_receive(corn))
	assert(mixer.placement_sound.playing, "Placing corn in mixer should play placement SE")
	mixer.placement_sound.stop()
	mixer.add_ingredient(corn.payload)
	assert(not mixer.placement_sound.playing, "Duplicate ingredient must not replay placement SE")
	mixer.reset_state()
	var board_target: DirectDropTarget = board.ingredient_drop_area
	assert(not board_target.try_receive(corn))
	assert(not board.placement_sound.playing)
	assert(board_target.try_receive(butter))
	assert(not board.placement_sound.playing, "Butter placement is not assigned this SE")
	board.reset_state()
	assert(board_target.try_receive(parsley))
	assert(board.placement_sound.playing, "Placing parsley on board should play placement SE")
	board.placement_sound.stop()
	assert(not board_target.try_receive(parsley))
	assert(not board.placement_sound.playing, "Rejected duplicate placement must remain silent")
	board.reset_state()
	assert(board_target.try_receive(parsley))
	assert(board.placement_sound.playing)
	board.reset_state()
	assert(not board.placement_sound.playing, "Reset must stop placement SE")
	mixer.free()
	board.free()
	corn.free()
	parsley.free()
	butter.free()


func _test_pot_ingredients() -> void:
	var pot: CookingPot = _instantiate("res://scenes/cooking/pot.tscn") as CookingPot
	var milk: DirectDraggableItem = _instantiate(
		"res://scenes/ingredients/milk.tscn"
	) as DirectDraggableItem
	var corn: DirectDraggableItem = _instantiate(
		"res://scenes/ingredients/corn.tscn"
	) as DirectDraggableItem
	var sound: AudioStreamPlayer = pot.ingredient_sound
	_assert_stream(sound, "res://assets/audio/put_in_ingredients.mp3")
	var target: DirectDropTarget = pot.ingredient_drop_area
	assert(not target.try_receive(corn))
	assert(not sound.playing, "Unprocessed corn must not play insertion SE")
	assert(target.try_receive(milk))
	assert(sound.playing, "Accepted ingredient should play insertion SE")
	sound.stop()
	pot.add_ingredient(null)
	pot.add_ingredient(milk.payload, 0.0)
	assert(not sound.playing, "Invalid ingredient additions must remain silent")
	corn.mark_processed(&"paste", &"paste")
	assert(target.try_receive(corn))
	assert(sound.playing)
	sound.stop()
	assert(pot.start_cooking(&"konpota_creamy", "コンポタ"))
	assert(not target.try_receive(milk))
	pot.add_ingredient(milk.payload)
	assert(not sound.playing, "Cooking pot must reject additions without playing SE")
	pot.reset_state()
	assert(target.try_receive(milk))
	assert(sound.playing)
	pot.reset_state()
	assert(not sound.playing, "Reset must stop insertion SE")
	pot.free()
	milk.free()
	corn.free()


func _assert_stream(player: AudioStreamPlayer, path: String, loop: bool = false) -> void:
	assert(player.stream is AudioStreamMP3)
	assert(player.stream.resource_path == path)
	assert(player.stream.get_length() > 0.0)
	assert((player.stream as AudioStreamMP3).loop == loop)


func _instantiate(path: String) -> Node:
	var scene: PackedScene = load(path)
	var instance: Node = scene.instantiate()
	root.add_child(instance)
	return instance
