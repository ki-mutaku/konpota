class_name MVPCustomer
extends Customer

signal presentation_finished

# SPEC: show the evaluation expression for 1.5 seconds before departure.
const ORDER_EVALUATOR: Script = preload("res://scripts/customers/customer_order_evaluator.gd")

const FEEDBACK_SECONDS: float = 1.5

@export var order_id: StringName = &"konpota_normal"
@export var normal_texture: Texture2D
@export var smile_texture: Texture2D

@onready var portrait: TextureRect = $Portrait
@onready var order_label: Label = $OrderBubble/Order
@onready var success_sound: AudioStreamPlayer = $SuccessSound
@onready var failure_sound: AudioStreamPlayer = $FailureSound
@onready var caption: Label = $Caption


func _ready() -> void:
	portrait.texture = normal_texture
	set_order(order_id)
	evaluation_completed.connect(_on_evaluation_completed)


func set_order(menu: StringName) -> void:
	order_id = menu
	if is_node_ready():
		order_label.text = ORDER_EVALUATOR.get_order_text(menu)


func _on_evaluation_completed(result: EvaluationResult) -> void:
	var success: bool = result.verdict == EvaluationResult.Verdict.SUCCESS
	portrait.texture = smile_texture if success else normal_texture
	order_label.text = "おいしかった！" if success else "ありがとう"
	if success:
		success_sound.play()
	else:
		failure_sound.play()
	await get_tree().create_timer(FEEDBACK_SECONDS).timeout
	presentation_finished.emit()
