class_name StageManager
extends Node

signal state_changed(state: State)
signal stage_started
signal evaluation_received(result: EvaluationResult)
signal progress_changed(total_satisfaction: int, completed_customers: int)
signal stage_finished(result: StageResult)

enum State { READY, PLAYING, FINISHED }

const MVP_CUSTOMER_COUNT: int = 3
const TARGET_SATISFACTION: int = 12

# Zero preserves the foundation's explicit finish/timer interface.
@export_range(0, 3) var customer_limit: int = 0

var _total_satisfaction: int = 0
var _notifying_evaluation: bool = false
var _state: State = State.READY
var _evaluations: Array[EvaluationResult] = []
var _result: StageResult
var _timer: Timer
var _notifying_transition: bool = false


func get_state() -> State:
	return _state


func get_total_satisfaction() -> int:
	return _total_satisfaction


func get_completed_customers() -> int:
	return _evaluations.size()


func get_result() -> StageResult:
	return _result


func start_stage() -> bool:
	if _state != State.READY or _notifying_transition:
		return false
	_state = State.PLAYING
	_notifying_transition = true
	state_changed.emit(_state)
	stage_started.emit()
	_notifying_transition = false
	return true


func finish_stage() -> bool:
	if _state != State.PLAYING or _notifying_transition or _notifying_evaluation:
		return false
	_state = State.FINISHED
	if is_instance_valid(_timer):
		_timer.stop()
	_result = StageResult.new(
		_evaluations, _total_satisfaction, TARGET_SATISFACTION,
		_evaluations.size() == MVP_CUSTOMER_COUNT and _total_satisfaction >= TARGET_SATISFACTION,
	)
	_notifying_transition = true
	state_changed.emit(_state)
	stage_finished.emit(_result)
	_notifying_transition = false
	return true


func receive_evaluation(result: EvaluationResult) -> bool:
	if (
		_state != State.PLAYING or result == null
		or _notifying_evaluation or _notifying_transition
	):
		return false
	if customer_limit > 0:
		if result.verdict == EvaluationResult.Verdict.UNSET or _evaluations.size() >= customer_limit:
			return false
	_evaluations.append(result)
	_total_satisfaction += result.satisfaction
	_notifying_evaluation = true
	evaluation_received.emit(result)
	progress_changed.emit(_total_satisfaction, _evaluations.size())
	_notifying_evaluation = false
	if customer_limit > 0 and _evaluations.size() == customer_limit:
		finish_stage()
	return true


func connect_customer(customer: Customer) -> bool:
	if not is_instance_valid(customer) or _state == State.FINISHED:
		return false
	if not customer.evaluation_completed.is_connected(_on_customer_evaluation_completed):
		customer.evaluation_completed.connect(_on_customer_evaluation_completed)
	return true


func connect_timer(timer: Timer) -> bool:
	if not is_instance_valid(timer) or _state == State.FINISHED:
		return false
	if is_instance_valid(_timer) and _timer.timeout.is_connected(_on_timer_timeout):
		_timer.timeout.disconnect(_on_timer_timeout)
	_timer = timer
	_timer.timeout.connect(_on_timer_timeout)
	# Duration and timer start belong to the agreed stage configuration.
	return true


func _on_customer_evaluation_completed(result: EvaluationResult) -> void:
	receive_evaluation(result)


func _on_timer_timeout() -> void:
	finish_stage()


func _exit_tree() -> void:
	if is_instance_valid(_timer) and _timer.timeout.is_connected(_on_timer_timeout):
		_timer.timeout.disconnect(_on_timer_timeout)
