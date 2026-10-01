class_name MVPCustomer
extends Customer

signal presentation_finished

# SPEC: show the evaluation expression for 1.5 seconds before departure.
const FEEDBACK_SECONDS: float = 1.5

@export var normal_texture: Texture2D
@export var smile_texture: Texture2D

@onready var portrait: TextureRect = $Portrait
@onready var caption: Label = $Caption


func _ready() -> void:
	portrait.texture = normal_texture
	evaluation_completed.connect(_on_evaluation_completed)


func _on_evaluation_completed(result: EvaluationResult) -> void:
	var success: bool = result.verdict == EvaluationResult.Verdict.SUCCESS
	portrait.texture = smile_texture if success else normal_texture
	caption.text = "おいしかった！" if success else "ありがとう"
	await get_tree().create_timer(FEEDBACK_SECONDS).timeout
	presentation_finished.emit()
