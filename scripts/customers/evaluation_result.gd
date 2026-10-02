class_name EvaluationResult
extends RefCounted

enum Verdict { UNSET, SUCCESS, FAILURE }

var verdict: Verdict = Verdict.UNSET
var satisfaction: int = 0
var achieved_axes: Dictionary = {}
var actual_stats: Dictionary = {}
var target_stats: Dictionary = {}


func _init(
	value: Verdict = Verdict.UNSET,
	points: int = -1,
	achieved: Dictionary = {},
	actual: Dictionary = {},
	target: Dictionary = {},
) -> void:
	verdict = value
	var resolved_points: int = points
	if resolved_points < 0:
		resolved_points = 4 if verdict == Verdict.SUCCESS else 0
	satisfaction = clampi(resolved_points, 0, 4)
	achieved_axes = achieved.duplicate(true)
	actual_stats = actual.duplicate(true)
	target_stats = target.duplicate(true)
