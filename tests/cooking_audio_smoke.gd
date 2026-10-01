extends SceneTree


func _init() -> void:
	call_deferred("_run_smoke_test")


func _run_smoke_test() -> void:
	_test_ignition()
	await _test_cooking()
	await _test_cooking_results()
	_test_mixer()
	_test_cutting()
	_test_serving()
	# Let the audio server release stopped playbacks before exiting headless tests.
	await create_timer(0.5).timeout
	print("Cooking audio smoke test passed")
	quit(0)


func _test_ignition() -> void:
	var stove: CookingStove = _instantiate("res://scenes/cooking/stove.tscn") as CookingStove
	var sound: AudioStreamPlayer = stove.get_node("IgnitionSound")
	_assert_stream(sound, "res://assets/audio/ignite_gas_stove.mp3")
	assert(not sound.playing, "Stove should be silent on scene load")
	stove._set_heat_level(0.4)
	assert(sound.playing, "Turning on the heat should play ignition")
	sound.stop()
	stove._set_heat_level(0.8)
	assert(not sound.playing, "Adjusting an already lit stove must not replay ignition")
	stove._set_heat_level(0.0)
	assert(not sound.playing, "Turning off the stove must not play ignition")
	stove._set_heat_level(0.2)
	assert(sound.playing, "Relighting the stove should play ignition again")
	stove.reset_state()
	assert(not sound.playing)
	stove.free()


func _test_cooking() -> void:
	var pot: CookingPot = _instantiate("res://scenes/cooking/pot.tscn") as CookingPot
	var sound: AudioStreamPlayer = pot.get_node("CookingSound")
	var success: AudioStreamPlayer = pot.get_node("CookingSuccessSound")
	var failed: AudioStreamPlayer = pot.get_node("CookingFailedSound")
	_assert_stream(sound, "res://assets/audio/cooking_konpota.mp3")
	_assert_stream(success, "res://assets/audio/cooking_success.mp3")
	_assert_stream(failed, "res://assets/audio/cooking_failed.mp3")
	assert(not (success.stream as AudioStreamMP3).loop)
	assert(not (failed.stream as AudioStreamMP3).loop)
	assert(not success.playing and not failed.playing)
	assert((sound.stream as AudioStreamMP3).loop, "Cooking sound must loop")
	assert(not sound.playing)
	assert(not pot.start_cooking(&"konpota_water", "コンポタ"))
	assert(not sound.playing, "Rejected cooking must remain silent")
	assert(not success.playing and not failed.playing)
	pot.cook_duration = 0.01
	pot.add_ingredient(load("res://resources/ingredients/corn.tres"))
	assert(pot.start_cooking(&"konpota_water", "コンポタ"))
	assert(sound.playing, "Cooking should play the cooking loop")
	assert(not success.playing and not failed.playing, "Result SE must wait for completion")
	assert(not pot.start_cooking(&"konpota_water", "コンポタ"))
	await create_timer(0.05).timeout
	assert(not pot.is_cooking and not sound.playing, "Completion should stop cooking audio")
	assert(failed.playing and not success.playing, "Water konpota should play only failure SE")
	pot.reset_state()
	assert(not success.playing and not failed.playing, "Reset should stop result SE")
	pot.cook_duration = 0.01
	pot.add_ingredient(load("res://resources/ingredients/corn.tres"))
	assert(pot.start_cooking(&"konpota_water", "コンポタ"))
	pot.reset_state()
	assert(not sound.playing, "Reset should stop cooking audio immediately")
	await create_timer(0.05).timeout
	assert(not sound.playing, "Cancelled cooking must not restart audio")
	assert(not success.playing and not failed.playing, "Cancelled cooking must not play result SE")
	pot.free()


func _test_cooking_results() -> void:
	var kitchen: Node2D = _instantiate("res://scenes/game/kitchen.tscn") as Node2D
	var pot: CookingPot = kitchen.get_node("KitchenObjects/Pot")
	var stove: CookingStove = kitchen.get_node("KitchenObjects/Stove")
	var counter: ServingCounter = kitchen.get_node("KitchenObjects/ServingCounter")
	var success: AudioStreamPlayer = pot.get_node("CookingSuccessSound")
	var failed: AudioStreamPlayer = pot.get_node("CookingFailedSound")
	pot.cook_duration = 0.01
	var cases: Array[Dictionary] = [
		{"ingredients": [&"corn"], "recipe": &"konpota_water"},
		{"ingredients": [&"corn", &"butter"], "recipe": &"konpota_normal"},
		{"ingredients": [&"corn", &"milk"], "recipe": &"konpota_creamy"},
		{"ingredients": [&"corn", &"milk", &"sugar"], "recipe": &"konpota_sweet"},
		{"ingredients": [&"corn", &"parsley"], "recipe": &"konpota_fresh"},
	]
	for test_case: Dictionary in cases:
		pot.reset_state()
		counter.reset_state()
		for ingredient_id: StringName in test_case["ingredients"]:
			pot.add_ingredient(load("res://resources/ingredients/%s.tres" % ingredient_id))
		stove.cook_requested.emit()
		assert(pot.is_cooking)
		assert(not success.playing and not failed.playing)
		await create_timer(0.05).timeout
		assert(counter.has_soup(), "Result SE must not interfere with filling the bowl")
		assert(counter.serving_bowl.soup["recipe_id"] == test_case["recipe"])
		if test_case["recipe"] == &"konpota_water":
			assert(failed.playing and not success.playing)
		else:
			assert(success.playing and not failed.playing)
	pot.reset_state()
	assert(not success.playing and not failed.playing)
	kitchen.free()


func _test_mixer() -> void:
	var mixer: CookingMixer = _instantiate("res://scenes/cooking/mixer.tscn") as CookingMixer
	var sound: AudioStreamPlayer = mixer.get_node("SpinningSound")
	var button: Button = mixer.get_node("OperationButton")
	_assert_stream(sound, "res://assets/audio/mixer_spinning.mp3")
	assert(not (sound.stream as AudioStreamMP3).loop)
	assert(not sound.playing)
	button.button_down.emit()
	assert(not sound.playing, "Empty mixer must remain silent")
	mixer.add_ingredient(load("res://resources/ingredients/corn.tres"))
	assert(not sound.playing, "Loading corn must not play spinning audio")
	button.button_down.emit()
	assert(sound.playing and mixer.pulse_count == 1, "Stir button should play spinning audio")
	button.button_up.emit()
	assert(sound.playing, "A short tap must not cut off the one-shot SE")
	sound.stop()
	var event: InputEventAction = InputEventAction.new()
	event.action = &"ui_accept"
	event.pressed = true
	mixer._unhandled_input(event)
	assert(sound.playing and mixer.pulse_count == 2, "Keyboard stirring should also play SE")
	sound.stop()
	button.button_down.emit()
	assert(mixer.is_processed and sound.playing, "Final valid pulse should still play SE")
	button.button_up.emit()
	sound.stop()
	button.button_down.emit()
	assert(not sound.playing, "Processed mixer must remain silent")
	mixer.reset_state()
	mixer.add_ingredient(load("res://resources/ingredients/corn.tres"))
	button.button_down.emit()
	assert(sound.playing)
	mixer.reset_state()
	assert(not sound.playing, "Reset should stop spinning audio")
	mixer.free()


func _test_cutting() -> void:
	var board: CookingCuttingBoard = _instantiate(
		"res://scenes/cooking/cutting_board.tscn"
	) as CookingCuttingBoard
	var butter: DirectDraggableItem = _instantiate(
		"res://scenes/ingredients/butter.tscn"
	) as DirectDraggableItem
	var sound: AudioStreamPlayer = board.get_node("CutSound")
	_assert_stream(sound, "res://assets/audio/cut_with_knife.mp3")
	var from: Vector2 = board.global_position + Vector2(0, -80)
	var to: Vector2 = board.global_position + Vector2(0, 80)
	assert(not board.try_slice_segment(from, to))
	assert(not sound.playing, "Empty board must not play a cut sound")
	var target: DirectDropTarget = board.get_node("IngredientDropArea")
	assert(target.try_receive(butter))
	assert(not sound.playing, "Placing an ingredient must remain silent")
	assert(not board.try_slice_segment(to, from))
	assert(not board.try_slice_segment(from, from + Vector2(0, 8)))
	assert(not board.try_slice_segment(from + Vector2(300, 0), to + Vector2(300, 0)))
	assert(not sound.playing, "Rejected swipes must remain silent")
	board.required_swipes = 2
	assert(board.try_slice_segment(from, to))
	assert(sound.playing, "Each valid cut should play audio, even before processing completes")
	sound.stop()
	assert(board.try_slice_segment(from, to))
	assert(sound.playing)
	sound.stop()
	assert(not board.try_slice_segment(from, to))
	assert(not sound.playing, "Already cut ingredients must not play another cut sound")
	board.reset_state()
	board.free()
	butter.free()


func _test_serving() -> void:
	var counter: ServingCounter = _instantiate(
		"res://scenes/cooking/serving_counter.tscn"
	) as ServingCounter
	var customer: Customer = _instantiate("res://scenes/customers/customer.tscn") as Customer
	var bowl: ServingBowl = counter.get_node("ServingBowl")
	var target: DirectDropTarget = customer.get_node("DropTarget")
	var sound: AudioStreamPlayer = counter.get_node("ServeSound")
	_assert_stream(sound, "res://assets/audio/serve_konpota.mp3")
	assert(not target.try_receive(bowl))
	assert(not sound.playing, "Empty bowls must not play serving audio")
	var soup: Dictionary = {
		"ingredients": [{"data": load("res://resources/ingredients/corn.tres"), "amount": 1.0}],
		"heat_level": 0.5,
		"stir_distance": 0.0,
	}
	assert(counter.set_soup(soup))
	assert(not sound.playing, "Filling a bowl must not play serving audio")
	bowl.drag_finished.emit(bowl, false, target)
	assert(not sound.playing, "Rejected delivery must remain silent")
	assert(target.try_receive(bowl))
	bowl.drag_finished.emit(bowl, true, target)
	assert(sound.playing, "Accepted delivery to a customer should play serving audio")
	counter.reset_state()
	assert(not sound.playing)
	counter.free()
	customer.free()


func _assert_stream(player: AudioStreamPlayer, path: String) -> void:
	assert(player.stream is AudioStreamMP3)
	var expected: AudioStreamMP3 = load(path) as AudioStreamMP3
	assert((player.stream as AudioStreamMP3).data == expected.data)
	assert(player.stream.get_length() > 0.0, "Audio must contain playable data")
	assert(not player.autoplay, "SE should only play on its matching action")


func _instantiate(path: String) -> Node:
	var scene: PackedScene = load(path)
	var instance: Node = scene.instantiate()
	root.add_child(instance)
	return instance
