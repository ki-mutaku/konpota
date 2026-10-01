class_name CookingStove
extends Node2D

signal heat_changed(level: float)
signal cook_requested

@export_range(40.0, 400.0, 1.0) var drag_pixels_for_full_power: float = 180.0
@export_range(0.0, 1.0, 0.01) var heat_level: float = 0.0
var _dragging: bool = false
var _touch_index: int = -1
var _drag_start_y: float = 0.0
var _drag_start_level: float = 0.0

@onready var knob: Polygon2D = %Knob
@onready var flame: Polygon2D = %Flame
@onready var power_label: Label = %PowerLabel


func _ready() -> void:
	_set_heat_level(heat_level, false)


func _input(event: InputEvent) -> void:
	if not _dragging:
		return

	if event is InputEventScreenDrag and event.index == _touch_index:
		_update_drag(event.position.y)
	elif event is InputEventScreenTouch and event.index == _touch_index and not event.pressed:
		_update_drag(event.position.y)
		_end_drag()
	elif event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_update_drag(event.position.y)
	elif (
		event is InputEventMouseButton
		and event.button_index == MOUSE_BUTTON_LEFT
		and not event.pressed
	):
		_update_drag(event.position.y)
		_end_drag()


func _on_knob_input_event(viewport: Viewport, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventScreenTouch and event.pressed:
		_begin_drag(event.position.y, event.index)
		viewport.set_input_as_handled()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_begin_drag(event.position.y, -1)
		viewport.set_input_as_handled()


func _begin_drag(pointer_y: float, touch_index: int) -> void:
	_dragging = true
	_touch_index = touch_index
	_drag_start_y = pointer_y
	_drag_start_level = heat_level
	cook_requested.emit()


func _update_drag(pointer_y: float) -> void:
	var delta: float = (_drag_start_y - pointer_y) / drag_pixels_for_full_power
	_set_heat_level(_drag_start_level + delta)


func _end_drag() -> void:
	_dragging = false
	_touch_index = -1


func reset_state() -> void:
	_end_drag()
	_set_heat_level(0.0)


func _set_heat_level(value: float, emit_change: bool = true) -> void:
	heat_level = clampf(value, 0.0, 1.0)
	knob.rotation = lerpf(-2.3, 2.3, heat_level)
	flame.scale.y = lerpf(0.15, 1.0, heat_level)
	flame.modulate.a = lerpf(0.15, 1.0, heat_level)
	power_label.text = "火力 %d%%" % roundi(heat_level * 100.0)
	if emit_change:
		heat_changed.emit(heat_level)
