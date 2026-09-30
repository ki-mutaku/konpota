class_name StageResult
extends RefCounted

# Recorded evaluation events only; no score, satisfaction, or clear verdict yet.
var _evaluations: Array[EvaluationResult] = []


func _init(evaluations: Array[EvaluationResult] = []) -> void:
	_evaluations.assign(evaluations)


func get_evaluations() -> Array[EvaluationResult]:
	return _evaluations.duplicate()
