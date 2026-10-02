class_name CookingMixer
extends Node2D

signal contents_changed(contents: Array[Dictionary])
signal operation_started
signal operation_stopped
signal processing_progress(current: int, required: int)
signal processing_completed(payload: Resource)

@export_range(1, 20, 1) var required_pulses: int = 3

var contents: Array[Dictionary] = []
var is_operating: bool = false
var pulse_count: int = 0
var is_processed: bool = false

@onready var blade: Polygon2D = %Blade
@onready var state_label: Label = %StateLabel
@onready var vacant_visual: Sprite2D = %VacantVisual
@onready var before_visual: Sprite2D = %BeforeVisual
@onready var after_visual: Sprite2D = %AfterVisual
@onready var output_item: DirectDraggableItem = %OutputItem
@onready var spinning_sound: AudioStreamPlayer = $SpinningSound
@onready var placement_sound: AudioStreamPlayer = $PlacementSound


func _process(delta: float) -> void:
	if is_operating:
		blade.rotation += delta * 12.0


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_accept"):
		register_pulse()


func add_ingredient(ingredient: Variant, amount: float = 1.0) -> void:
	if ingredient == null or amount <= 0.0:
		return
	if not contents.is_empty():
		return
	contents.append({"data": ingredient, "amount": amount})
	pulse_count = 0
	is_processed = false
	if ingredient is IngredientData and ingredient.id == &"corn":
		placement_sound.play()
	contents_changed.emit(contents.duplicate(true))
	_refresh_visuals()


func take_contents() -> Array[Dictionary]:
	if not is_processed:
		return []
	var result: Array[Dictionary] = contents.duplicate(true)
	reset_state()
	return result


func register_pulse() -> void:
	if contents.is_empty() or is_processed:
		return
	spinning_sound.play()
	is_operating = true
	operation_started.emit()
	pulse_count += 1
	processing_progress.emit(pulse_count, required_pulses)
	if pulse_count >= required_pulses:
		_finish_processing()
	else:
		_refresh_visuals()


func reset_state() -> void:
	spinning_sound.stop()
	placement_sound.stop()
	is_operating = false
	contents.clear()
	pulse_count = 0
	is_processed = false
	output_item.payload = null
	output_item.processing_state = &"raw"
	output_item.reset_to_home()
	output_item.visible = false
	contents_changed.emit([])
	_refresh_visuals()


func _on_ingredient_drop_area_item_received(
	payload: Variant,
	_source: DirectDraggableItem,
) -> void:
	add_ingredient(payload)


func _on_operation_button_button_down() -> void:
	register_pulse()


func _on_operation_button_button_up() -> void:
	if not is_operating:
		return
	is_operating = false
	operation_stopped.emit()
	_refresh_visuals()


func _on_output_item_drag_finished(
	_item: DirectDraggableItem,
	accepted: bool,
	_target: DirectDropTarget,
) -> void:
	if accepted:
		reset_state()


func _finish_processing() -> void:
	is_processed = true
	is_operating = false
	var source_payload: Resource = contents[0].get("data") as Resource
	output_item.payload = source_payload.duplicate(true) if source_payload != null else null
	output_item.mark_processed(&"paste")
	output_item.visible = true
	processing_completed.emit(output_item.payload)
	operation_stopped.emit()
	_refresh_visuals()


func _refresh_visuals() -> void:
	vacant_visual.visible = contents.is_empty()
	before_visual.visible = not contents.is_empty() and not is_processed
	after_visual.visible = is_processed
	if is_operating:
		state_label.text = "攪拌中 %d/%d" % [pulse_count, required_pulses]
	elif is_processed:
		state_label.text = "ペースト完成：鍋へドラッグ"
	else:
		state_label.text = (
			"コーンを入れる"
			if contents.is_empty()
			else "タップ / Space %d/%d" % [pulse_count, required_pulses]
		)
