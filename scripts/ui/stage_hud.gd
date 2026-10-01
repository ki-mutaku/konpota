class_name StageHUD
extends PanelContainer

@onready var satisfaction_label: Label = $Content/Satisfaction
@onready var customer_label: Label = $Content/CustomerProgress
@onready var ingredient_label: Label = $Content/Ingredients


func update_progress(total: int, target: int, completed: int, customer_count: int) -> void:
	satisfaction_label.text = "満足度 %d / %d" % [total, target]
	if completed < customer_count:
		customer_label.text = "Customer %d/%d（完了 %d）" % [completed + 1, customer_count, completed]
	else:
		customer_label.text = "Customer %d/%d 完了" % [completed, customer_count]


func update_pot_contents(snapshot: Dictionary) -> void:
	ingredient_label.text = "鍋の食材数 %d" % snapshot.get("ingredients", []).size()


func show_evaluation_pending() -> void:
	customer_label.text += " 評価待ち"


func show_evaluation_complete(completed: int, customer_count: int) -> void:
	customer_label.text = "Customer %d/%d 評価完了" % [completed, customer_count]
