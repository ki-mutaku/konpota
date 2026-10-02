extends SceneTree

const SESSION_SCENE: PackedScene = preload("res://scenes/game/stage_session.tscn")

var requested_customer: Customer
var requested_id: int = 0
var requested_payload: Variant
var finish_count: int = 0


func _init() -> void:
	call_deferred("_run_smoke_test")


func _run_smoke_test() -> void:
	await _run_session([true, true, true], 12, true)
	await _run_session([true, false, true], 8, false)
	await _run_session([false, false, false], 0, false)
	await _run_synchronous_session()
	await create_timer(0.5).timeout
	print("MVP stage smoke test passed (3 Customers, satisfaction, HUD, Clear/Uncleared)")
	quit(0)


func _run_session(outcomes: Array[bool], expected_total: int, cleared: bool) -> void:
	var session: Node = SESSION_SCENE.instantiate()
	root.add_child(session)
	session.evaluation_requested.connect(_on_evaluation_requested)
	var manager: StageManager = session.stage_manager
	manager.stage_finished.connect(func(_result: StageResult) -> void: finish_count += 1)
	var original_finish_count: int = finish_count
	var customers: Array[Customer] = session.customers
	var bowl: ServingBowl = session.kitchen.serving_counter.serving_bowl
	assert(manager.customer_limit == 3 and manager.get_total_satisfaction() == 0)
	assert(customers[0].get_parent().get_parent() == session.kitchen.get_node("Customers"))
	assert(not session.result_view.visible)
	assert(session.hud.satisfaction_label.text == "満足度 0 / 12")
	assert(session.hud.customer_label.text.contains("1/3"))
	assert(session.kitchen.get_node("UI/HUDMount").visible == false)
	var total: int = 0
	for index: int in 3:
		var customer: Customer = customers[index]
		assert(session.get_current_customer() == customer)
		var normal: AtlasTexture = (customer as MVPCustomer).normal_texture as AtlasTexture
		var who: String = ["boy", "girl", "elder"][index]
		assert(normal.atlas.resource_path.ends_with(who + "_normal.png"))
		var smile: AtlasTexture = (customer as MVPCustomer).smile_texture as AtlasTexture
		assert(smile.atlas.resource_path.ends_with(who + "_smile.png"))
		var presentation: MVPCustomer = customer as MVPCustomer
		assert(presentation.portrait.texture == normal)
		assert(
			presentation.order_label.text
			== CustomerOrderEvaluator.get_order_text(presentation.order_id)
		)
		for other: int in 3:
			assert(customers[other].visible == (other == index))
			assert(customers[other].drop_target.enabled == (other == index))
		session.kitchen.pot.add_ingredient(IngredientData.new())
		assert(session.hud.ingredient_label.text == "鍋の食材数 1")
		var snapshot: Dictionary = session.kitchen.pot.take_soup_snapshot()
		assert(session.hud.ingredient_label.text == "鍋の食材数 0")
		assert(bowl.fill_soup(snapshot))
		for other: int in 3:
			if other != index:
				assert(not customers[other].drop_target.try_receive(bowl))
		var target: DirectDropTarget = customer.drop_target
		assert(target.try_receive(bowl))
		assert(requested_customer == customer and requested_payload == snapshot)
		assert(session.hud.customer_label.text.contains("評価待ち"))
		assert(not target.try_receive(bowl), "Pending delivery must reject duplicates")
		bowl.drag_finished.emit(bowl, true, target)
		assert(not bowl.has_soup())
		var verdict: EvaluationResult.Verdict = (
			EvaluationResult.Verdict.SUCCESS if outcomes[index] else EvaluationResult.Verdict.FAILURE
		)
		var result := EvaluationResult.new(verdict)
		assert(not session.submit_evaluation(customers[(index + 1) % 3], requested_id, result))
		assert(not session.submit_evaluation(customer, requested_id + 1, result))
		assert(not session.submit_evaluation(customer, requested_id, null))
		assert(not session.submit_evaluation(customer, requested_id, EvaluationResult.new()))
		assert(not customer.complete_evaluation(requested_id, EvaluationResult.new()))
		assert(manager.get_completed_customers() == index)
		assert(session.submit_evaluation(customer, requested_id, result))
		assert(customer.visible, "Keep expression visible before departure")
		assert(presentation.portrait.texture == (
			presentation.smile_texture if outcomes[index] else presentation.normal_texture))
		assert(
			presentation.order_label.text
			== ("おいしかった！" if outcomes[index] else "ありがとう")
		)
		assert(session.get_current_customer() == null, "No delivery during feedback")
		assert(not session.result_view.visible, "Show final feedback before Result")
		assert(not session.result_view.stage_clear_sound.playing, "Clear audio must wait for Result")
		await presentation.presentation_finished
		if outcomes[index]:
			total += 4
		assert(manager.get_total_satisfaction() == total)
		assert(manager.get_completed_customers() == index + 1)
		assert(session.hud.satisfaction_label.text == "満足度 %d / 12" % total)
		assert(not session.submit_evaluation(customer, requested_id, result))
		assert(not customer.complete_evaluation(requested_id, result))
		assert(not customer.can_receive_soup(SoupData.new()))
		assert(not target.enabled, "Completed customer must never receive again")
		if index < 2:
			assert(manager.get_state() == StageManager.State.PLAYING)
			assert(not session.result_view.visible)
			assert(session.hud.customer_label.text.contains("%d/3" % (index + 2)))
	assert(manager.get_state() == StageManager.State.FINISHED)
	assert(session.get_current_customer() == null)
	assert(finish_count == original_finish_count + 1)
	assert(not manager.finish_stage())
	assert(not manager.receive_evaluation(EvaluationResult.new(EvaluationResult.Verdict.SUCCESS)))
	var final_result: StageResult = session.result_receiver.get_result()
	assert(final_result == manager.get_result())
	assert(final_result.get_total_satisfaction() == expected_total)
	assert(final_result.get_target_satisfaction() == 12)
	assert(final_result.is_cleared() == cleared)
	assert(final_result.get_evaluations().size() == 3)
	assert(session.result_view.visible)
	assert(not session.kitchen.background_music.playing)
	assert(session.result_view.stage_clear_sound.playing == cleared)
	var expected_verdict: String = "ステージクリア" if cleared else "ステージ終了：未クリア"
	assert(session.result_view.verdict_label.text == expected_verdict)
	assert(session.result_view.satisfaction_label.text == "最終満足度 %d / 12" % expected_total)
	assert(session.hud.customer_label.text == "Customer 3/3 完了")
	assert(session.kitchen.process_mode == Node.PROCESS_MODE_DISABLED)
	for customer: Customer in customers:
		assert(not customer.visible and not customer.drop_target.enabled)
	session.result_view.stage_clear_sound.stop()
	session.queue_free()
	await process_frame


func _run_synchronous_session() -> void:
	var session: Node = SESSION_SCENE.instantiate()
	root.add_child(session)
	var bowl: ServingBowl = session.kitchen.serving_counter.serving_bowl
	var manager: StageManager = session.stage_manager
	manager.evaluation_received.connect(func(result: EvaluationResult) -> void:
		assert(not manager.receive_evaluation(result), "Reentrant scoring must be rejected")
		assert(not manager.finish_stage(), "Evaluation notification must finish atomically"))
	for index: int in 3:
		var customer: Customer = session.get_current_customer()
		assert(customer == session.customers[index])
		var presentation: MVPCustomer = customer as MVPCustomer
		var soup: SoupData = load(
			"res://resources/recipes/%s.tres" % presentation.order_id
		) as SoupData
		assert(bowl.fill_soup(soup))
		assert(customer.drop_target.try_receive(bowl))
		bowl.drag_finished.emit(bowl, true, customer.drop_target)
		assert(not customer.drop_target.enabled)
		await presentation.presentation_finished
	assert(session.stage_manager.get_result().is_cleared())
	assert(not session.kitchen.background_music.playing)
	assert(session.result_view.stage_clear_sound.playing)
	session.result_view.stage_clear_sound.stop()
	session.queue_free()
	await process_frame


func _on_evaluation_requested(customer: Customer, id: int, payload: Variant) -> void:
	requested_customer = customer
	requested_id = id
	requested_payload = payload
