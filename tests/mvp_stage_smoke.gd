extends SceneTree

const SESSION_SCENE: PackedScene = preload("res://scenes/game/stage_session.tscn")
const ORDER_EVALUATOR: Script = preload("res://scripts/customers/customer_order_evaluator.gd")
const MATERIALS: Dictionary = {
	&"konpota_normal": [&"corn", &"butter"],
	&"konpota_creamy": [&"corn", &"milk"],
	&"konpota_sweet": [&"corn", &"milk", &"sugar"],
	&"konpota_fresh": [&"corn", &"parsley"],
}
var completion_count: int = 0
var request_count: int = 0
var served_count: int = 0


func _init() -> void:
	call_deferred("_run_smoke_test")


func _run_smoke_test() -> void:
	await _run_session([4, 4, 4], 12, true)
	await _run_session([4, 2, 4], 10, false)
	await _run_session([0, 0, 0], 0, false)
	await create_timer(0.5).timeout
	print("MVP stage smoke test passed (real cooking, orders, evaluation, audio, HUD, Result)")
	quit(0)


func _run_session(outcomes: Array[int], expected_total: int, cleared: bool) -> void:
	var session: Node = SESSION_SCENE.instantiate()
	root.add_child(session)
	session.evaluation_requested.connect(_on_request)
	session.kitchen.soup_served.connect(func(_soup: Variant) -> void: served_count += 1)
	var manager: StageManager = session.stage_manager
	var bowl: ServingBowl = session.kitchen.serving_counter.serving_bowl
	var start_requests: int = request_count
	var start_served: int = served_count
	var start_completed: int = completion_count
	manager.evaluation_received.connect(func(_result: EvaluationResult) -> void:
		completion_count += 1)
	assert(session.get_node_or_null("Evaluator") == null)
	assert(session.evaluation_requested.get_connections().size() == 1)
	assert(manager.customer_limit == 3 and manager.get_total_satisfaction() == 0)
	assert(not session.result_view.visible)
	assert(session.hud.satisfaction_label.text == "満足度 0 / 12")
	for customer: MVPCustomer in session.customers:
		assert(customer.order_id in ORDER_EVALUATOR.get_order_ids())
		assert(customer.order_label.text == ORDER_EVALUATOR.get_order_text(customer.order_id))
	var total: int = 0
	for index: int in 3:
		var customer: MVPCustomer = session.get_current_customer() as MVPCustomer
		assert(customer == session.customers[index])
		var who: String = ["boy", "girl", "elder"][index]
		assert((customer.normal_texture as AtlasTexture).atlas.resource_path.ends_with(
			who + "_normal.png"))
		assert(customer.portrait.texture == customer.normal_texture)
		for other: int in 3:
			assert(session.customers[other].visible == (other == index))
			assert(session.customers[other].drop_target.enabled == (other == index))
		var points: int = outcomes[index]
		if points < 4:
			customer.set_order(&"konpota_sweet")
		var cooked_order: StringName = customer.order_id if points == 4 else (
			&"konpota_creamy" if points == 2 else &"")
		await _cook_for_order(session, cooked_order)
		assert(bowl.has_soup())
		assert(session.hud.ingredient_label.text == "鍋の食材数 0")
		for other: int in 3:
			if other != index:
				assert(not session.customers[other].drop_target.try_receive(bowl))
		assert(customer.drop_target.try_receive(bowl))
		assert(session.hud.customer_label.text.contains("評価待ち"))
		assert(not customer.drop_target.try_receive(bowl))
		bowl.drag_finished.emit(bowl, true, customer.drop_target)
		assert(not bowl.has_soup())
		await process_frame
		total += points
		assert(manager.get_total_satisfaction() == total)
		assert(manager.get_completed_customers() == index + 1)
		assert(request_count == start_requests + index + 1)
		assert(served_count == start_served + index + 1)
		assert(completion_count == start_completed + index + 1)
		var result: EvaluationResult = manager.get_result().get_evaluations()[index] if (
			index == 2) else EvaluationResult.new(EvaluationResult.Verdict.SUCCESS)
		assert(not session.submit_evaluation(customer, 1, result))
		assert(not customer.complete_evaluation(1, result))
		assert(manager.get_total_satisfaction() == total)
		assert(customer.visible and session.get_current_customer() == null)
		assert(not session.result_view.visible)
		assert(customer.portrait.texture == (
			customer.smile_texture if points == 4 else customer.normal_texture))
		assert(customer.order_label.text == ("おいしかった！" if points == 4 else "ありがとう"))
		assert(customer.success_sound.playing == (points == 4))
		assert(customer.failure_sound.playing == (points < 4))
		assert(session.hud.satisfaction_label.text == "満足度 %d / 12" % total)
		var started: int = Time.get_ticks_msec()
		await customer.presentation_finished
		assert(Time.get_ticks_msec() - started >= 1400)
		assert(not customer.visible and not customer.drop_target.enabled)
		if index < 2:
			assert(session.get_current_customer() == session.customers[index + 1])
			assert(session.hud.customer_label.text.contains("%d/3" % (index + 2)))
	assert(manager.get_state() == StageManager.State.FINISHED)
	var final_result: StageResult = session.result_receiver.get_result()
	assert(final_result.get_total_satisfaction() == expected_total)
	assert(final_result.is_cleared() == cleared)
	assert(final_result.get_evaluations().size() == 3)
	assert(final_result.get_target_satisfaction() == 12)
	assert(StageResult.new().get_target_satisfaction() == 12)
	for index: int in 3:
		assert(final_result.get_evaluations()[index].satisfaction == outcomes[index])
		assert((final_result.get_evaluations()[index].verdict == (
			EvaluationResult.Verdict.SUCCESS)) == (outcomes[index] == 4))
	assert(session.result_view.visible)
	assert(session.result_view.verdict_label.text == (
		"ステージクリア" if cleared else "ステージ終了：未クリア"))
	assert(session.result_view.satisfaction_label.text == "最終満足度 %d / 12" % expected_total)
	assert(session.hud.customer_label.text == "Customer 3/3 完了")
	assert(not manager.finish_stage())
	assert(session.kitchen.process_mode == Node.PROCESS_MODE_DISABLED)
	session.queue_free()
	await process_frame


func _cook_for_order(session: Node, order: StringName) -> void:
	var ids: Array = MATERIALS.get(order, [&"corn"])
	for id: StringName in ids:
		session.kitchen.pot.add_ingredient(load("res://resources/ingredients/%s.tres" % id))
	assert(session.hud.ingredient_label.text == "鍋の食材数 %d" % ids.size())
	session.kitchen.pot.cook_duration = 0.01
	session.kitchen.stove.call("_begin_drag", 0.0, -1)
	session.kitchen.stove.call("_end_drag")
	await session.kitchen.pot.cooking_completed


func _on_request(_customer: Customer, _id: int, _payload: Variant) -> void:
	request_count += 1
