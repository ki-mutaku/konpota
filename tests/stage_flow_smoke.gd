extends SceneTree

var started_count: int = 0
var finished_count: int = 0
var evaluation_count: int = 0
var received_result: StageResult
var request_id: int = 0


func _init() -> void:
	call_deferred("_run_smoke_test")


func _run_smoke_test() -> void:
	var manager_scene: PackedScene = load("res://scenes/game/stage_manager.tscn")
	assert(manager_scene != null)
	var manager: StageManager = manager_scene.instantiate() as StageManager
	root.add_child(manager)
	var receiver := StageResultReceiver.new()
	root.add_child(receiver)
	manager.stage_started.connect(func() -> void: started_count += 1)
	manager.stage_finished.connect(_on_finished)
	manager.stage_finished.connect(receiver.receive_result)
	manager.evaluation_received.connect(func(_result: EvaluationResult) -> void:
		evaluation_count += 1)
	var fixture := EvaluationResult.new()
	assert(manager.get_state() == StageManager.State.READY)
	assert(manager.get_result() == null)
	assert(not manager.finish_stage())
	assert(not manager.receive_evaluation(fixture))
	assert(manager.start_stage())
	assert(manager.get_state() == StageManager.State.PLAYING and started_count == 1)
	assert(not manager.start_stage())
	assert(not manager.receive_evaluation(null))

	var customer_scene: PackedScene = load("res://scenes/customers/customer.tscn")
	var customer: Customer = customer_scene.instantiate() as Customer
	root.add_child(customer)
	assert(manager.connect_customer(customer))
	assert(manager.connect_customer(customer), "Duplicate connection must be harmless")
	customer.evaluation_requested.connect(func(id: int, _payload: Variant) -> void:
		request_id = id)
	var bowl_scene: PackedScene = load("res://scenes/cooking/serving_bowl.tscn")
	var bowl: ServingBowl = bowl_scene.instantiate() as ServingBowl
	root.add_child(bowl)
	var target: DirectDropTarget = customer.get_node("DropTarget") as DirectDropTarget
	assert(bowl.fill_soup(SoupData.new()))
	assert(target.try_receive(bowl))
	bowl.drag_finished.emit(bowl, true, target)
	assert(customer.complete_evaluation(request_id, fixture))
	assert(evaluation_count == 1)
	assert(manager.finish_stage())
	assert(manager.get_state() == StageManager.State.FINISHED and finished_count == 1)
	assert(received_result == manager.get_result())
	assert(receiver.get_result() == received_result)
	assert(received_result.get_evaluations() == [fixture])
	var copy: Array[EvaluationResult] = received_result.get_evaluations()
	copy.clear()
	assert(received_result.get_evaluations().size() == 1, "Collection must be independent")
	assert(not manager.finish_stage())
	assert(not manager.start_stage())
	customer.evaluation_completed.emit(EvaluationResult.new())
	assert(evaluation_count == 1 and finished_count == 1)
	assert(received_result.get_evaluations().size() == 1)

	var timed: StageManager = manager_scene.instantiate() as StageManager
	root.add_child(timed)
	var timer := Timer.new()
	timer.one_shot = true
	root.add_child(timer)
	assert(timed.connect_timer(timer))
	assert(timed.connect_timer(timer))
	assert(timed.start_stage())
	timer.start(0.01) # Test-only duration; no production stage time configured.
	await timer.timeout
	assert(timed.get_state() == StageManager.State.FINISHED)
	assert(timed.get_result().get_evaluations().is_empty())
	assert(not timed.finish_stage())

	var title_scene: PackedScene = load("res://scenes/game/title.tscn")
	var title: Control = title_scene.instantiate() as Control
	root.add_child(title)
	current_scene = title
	var start_button: Button = title.get_node("GameStartButton") as Button
	start_button.pressed.emit()
	await process_frame
	await process_frame
	assert(current_scene != null and current_scene.name == "StageSession")
	var session_manager: StageManager = current_scene.get_node("StageManager") as StageManager
	var session_receiver: StageResultReceiver = (
		current_scene.get_node("ResultReceiver") as StageResultReceiver
	)
	assert(session_manager.get_state() == StageManager.State.PLAYING)
	assert(session_manager.finish_stage())
	assert(session_receiver.get_result() == session_manager.get_result())
	assert(not session_manager.finish_stage())

	manager.free()
	receiver.free()
	customer.free()
	bowl.free()
	timed.free()
	timer.free()
	await create_timer(0.5).timeout
	print("Stage flow smoke test passed (Title, Customer, Timer, Result handoff)")
	quit(0)


func _on_finished(result: StageResult) -> void:
	finished_count += 1
	received_result = result
