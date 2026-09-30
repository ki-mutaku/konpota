class_name StageResultReceiver
extends Node

signal result_received(result: StageResult)

var _result: StageResult


func receive_result(result: StageResult) -> void:
	if result == null:
		return
	_result = result
	result_received.emit(result)


func get_result() -> StageResult:
	return _result
