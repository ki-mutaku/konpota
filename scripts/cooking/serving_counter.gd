class_name ServingCounter
extends Node2D

signal soup_served(soup: Variant)
signal soup_changed(soup: Variant)

@export var show_counter_visuals: bool = true

@onready var counter: Polygon2D = %Counter
@onready var counter_top: Polygon2D = %CounterTop
@onready var serving_bowl: ServingBowl = %ServingBowl
@onready var serve_sound: AudioStreamPlayer = $ServeSound


func _ready() -> void:
	counter.visible = show_counter_visuals
	counter_top.visible = show_counter_visuals
	serving_bowl.soup_delivered.connect(_on_soup_delivered)
	serving_bowl.soup_changed.connect(_on_soup_changed)


func set_soup(soup: Variant) -> bool:
	return serving_bowl.fill_soup(soup)


func has_soup() -> bool:
	return serving_bowl.has_soup()


func reset_state() -> void:
	serve_sound.stop()
	serving_bowl.reset_bowl()


func _on_soup_delivered(soup: Variant) -> void:
	serve_sound.play()
	soup_served.emit(soup)


func _on_soup_changed(soup: Variant) -> void:
	soup_changed.emit(soup)
