extends Node

@onready var stage_manager: StageManager = $StageManager
@onready var result_receiver: StageResultReceiver = $ResultReceiver


func _ready() -> void:
	stage_manager.stage_finished.connect(result_receiver.receive_result)
	# Starts the lifecycle only. Timer values and customer spawning await agreement.
	stage_manager.start_stage()
