class_name MVPCustomer
extends Customer

signal presentation_finished

# SPEC: show the evaluation expression for 1.5 seconds before departure.
const FEEDBACK_SECONDS: float = 1.5

@export var normal_texture: Texture2D
@export var smile_texture: Texture2D
@export var order_id: StringName = &"konpota_normal"

@onready var portrait: TextureRect = $Portrait
@onready var order_label: Label = $OrderBubble/OrderLabel


func _ready() -> void:
	portrait.texture = normal_texture
	order_label.text = CustomerOrderEvaluator.get_order_text(order_id)
	evaluation_completed.connect(_on_evaluation_completed)


func set_order(value: StringName) -> void:
	order_id = value
	if is_node_ready():
		order_label.text = CustomerOrderEvaluator.get_order_text(order_id)


func _on_evaluation_completed(result: EvaluationResult) -> void:
	var success: bool = result.verdict == EvaluationResult.Verdict.SUCCESS
	portrait.texture = smile_texture if success else normal_texture
	order_label.text = "おいしかった！" if success else "ありがとう"
	await get_tree().create_timer(FEEDBACK_SECONDS).timeout
	presentation_finished.emit()
