class_name StageResultView
extends Control

@onready var verdict_label: Label = $Panel/Content/Verdict
@onready var satisfaction_label: Label = $Panel/Content/Satisfaction


func show_result(result: StageResult) -> void:
	verdict_label.text = "ステージクリア" if result.is_cleared() else "ステージ終了：未クリア"
	satisfaction_label.text = "最終満足度 %d / %d" % [
		result.get_total_satisfaction(), result.get_target_satisfaction(),
	]
	show()
