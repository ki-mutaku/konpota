extends Control

@onready var game_start_button: Button = %GameStartButton
@onready var exit_button: Button = %ExitButton
@onready var status_label: Label = %StatusLabel


func _ready() -> void:
	game_start_button.pressed.connect(_on_game_start_pressed)
	exit_button.pressed.connect(_on_exit_pressed)


func _on_game_start_pressed() -> void:
	game_start_button.disabled = true
	var error: Error = get_tree().change_scene_to_file("res://scenes/game/stage_session.tscn")
	if error != OK:
		game_start_button.disabled = false
		status_label.text = "Stageを読み込めませんでした"


func _on_exit_pressed() -> void:
	if OS.has_feature("web"):
		status_label.text = "Web版ではブラウザのタブを閉じて終了してください"
		return

	get_tree().quit()
