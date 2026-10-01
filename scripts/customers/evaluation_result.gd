class_name EvaluationResult
extends RefCounted

# B supplies the recipe verdict. C only maps SUCCESS to MVP satisfaction.
enum Verdict { UNSET, SUCCESS, FAILURE }

var verdict: Verdict = Verdict.UNSET


func _init(value: Verdict = Verdict.UNSET) -> void:
	verdict = value
