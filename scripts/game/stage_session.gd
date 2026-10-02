extends Node

# Requests carry the exact Customer/request pair to the production evaluator.
signal evaluation_requested(customer: Customer, request_id: int, payload: Variant)

const ORDER_EVALUATOR: Script = preload("res://scripts/customers/customer_order_evaluator.gd")

var _feedback_customer: Customer
var _pending_result: StageResult

@onready var stage_manager: StageManager = $StageManager
@onready var result_receiver: StageResultReceiver = $ResultReceiver
@onready var hud: StageHUD = $UI/HUD
@onready var result_view: StageResultView = $UI/ResultView
@onready var kitchen: Node2D = $Kitchen
@onready var customers: Array[Customer] = [
	$CustomerRoster/Customer1, $CustomerRoster/Customer2, $CustomerRoster/Customer3,
]


func _ready() -> void:
	stage_manager.stage_finished.connect(result_receiver.receive_result)
	result_receiver.result_received.connect(_on_result_received)
	$CustomerRoster.reparent(kitchen.get_node("Customers"), true)
	stage_manager.evaluation_received.connect(_on_evaluation_received)
	stage_manager.progress_changed.connect(_on_progress_changed)
	kitchen.pot.contents_changed.connect(hud.update_pot_contents)
	# Replace only the static HUD; A's status panel and cooking remain intact.
	kitchen.get_node("UI/HUDMount").hide()
	var order_ids: Array[StringName] = ORDER_EVALUATOR.get_order_ids()
	order_ids.shuffle()
	for customer: Customer in customers:
		customer.set_receiving_enabled(false)
		var presentation: MVPCustomer = customer as MVPCustomer
		presentation.set_order(order_ids[customers.find(customer)])
		presentation.presentation_finished.connect(_on_presentation_finished.bind(customer))
		stage_manager.connect_customer(customer)
		customer.evaluation_requested.connect(_on_evaluation_requested.bind(customer))
	stage_manager.start_stage()
	hud.update_pot_contents(kitchen.pot.get_soup_snapshot())
	_on_progress_changed(0, 0)


func get_current_customer() -> Customer:
	if stage_manager.get_state() != StageManager.State.PLAYING or _feedback_customer != null:
		return null
	var completed: int = stage_manager.get_completed_customers()
	return customers[completed] if completed < customers.size() else null


func submit_evaluation(customer: Customer, request_id: int, result: EvaluationResult) -> bool:
	if customer == null or customer != get_current_customer() or result == null:
		return false
	if result.verdict == EvaluationResult.Verdict.UNSET:
		return false
	return customer.complete_evaluation(request_id, result)


func _on_evaluation_requested(request_id: int, payload: Variant, customer: Customer) -> void:
	hud.show_evaluation_pending()
	evaluation_requested.emit(customer, request_id, payload)
	_evaluate_order(customer, request_id, payload)


func _evaluate_order(customer: Customer, request_id: int, payload: Variant) -> void:
	var result: EvaluationResult = ORDER_EVALUATOR.evaluate(
		(customer as MVPCustomer).order_id, payload,
	)
	submit_evaluation.call_deferred(customer, request_id, result)


func _on_progress_changed(total: int, completed: int) -> void:
	hud.update_progress(total, StageManager.TARGET_SATISFACTION, completed, customers.size())
	if _feedback_customer != null:
		hud.show_evaluation_complete(completed, customers.size())
		return
	_activate_customer(completed)


func _activate_customer(completed: int) -> void:
	for index: int in customers.size():
		var active: bool = index == completed
		customers[index].visible = active
		customers[index].set_receiving_enabled(active)


func _on_evaluation_received(_result: EvaluationResult) -> void:
	_feedback_customer = customers[stage_manager.get_completed_customers() - 1]


func _on_presentation_finished(customer: Customer) -> void:
	if customer != _feedback_customer:
		return
	_feedback_customer = null
	if _pending_result != null:
		_show_result(_pending_result)
	else:
		_on_progress_changed(
			stage_manager.get_total_satisfaction(), stage_manager.get_completed_customers(),
		)


func _on_result_received(result: StageResult) -> void:
	_pending_result = result
	if kitchen.has_method("stop_background_music"):
		kitchen.stop_background_music()
	kitchen.process_mode = Node.PROCESS_MODE_DISABLED
	if _feedback_customer == null:
		_show_result(result)


func _show_result(result: StageResult) -> void:
	hud.update_progress(
		result.get_total_satisfaction(), result.get_target_satisfaction(),
		stage_manager.get_completed_customers(), customers.size(),
	)
	for customer: Customer in customers:
		customer.set_receiving_enabled(false)
		customer.hide()
	result_view.show_result(result)
