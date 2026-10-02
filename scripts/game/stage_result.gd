class_name StageResult
extends RefCounted

var _evaluations: Array[EvaluationResult] = []
var _total_satisfaction: int
var _target_satisfaction: int
var _cleared: bool


func _init(
	evaluations: Array[EvaluationResult] = [],
	total_satisfaction: int = 0,
	target_satisfaction: int = 12,
	cleared: bool = false,
) -> void:
	_evaluations.assign(evaluations)
	_total_satisfaction = total_satisfaction
	_target_satisfaction = target_satisfaction
	_cleared = cleared


func get_evaluations() -> Array[EvaluationResult]:
	return _evaluations.duplicate()


func get_total_satisfaction() -> int:
	return _total_satisfaction


func get_target_satisfaction() -> int:
	return _target_satisfaction


func is_cleared() -> bool:
	return _cleared
