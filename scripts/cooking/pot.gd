class_name CookingPot
extends Node2D

signal ingredient_added(ingredient: Variant, amount: float)
signal heat_level_changed(level: float)
signal stirring_updated(total_distance: float)
signal contents_changed(snapshot: Dictionary)

@export_range(24.0, 256.0, 1.0) var interaction_radius: float = 92.0

var heat_level: float = 0.0
var stir_distance: float = 0.0
var ingredients: Array[Dictionary] = []

@onready var soup_surface: Polygon2D = %SoupSurface
@onready var heat_glow: Polygon2D = %HeatGlow
@onready var state_label: Label = %StateLabel
@onready var bowl_drop_area: DirectDropTarget = %BowlDropArea


func _ready() -> void:
	_refresh_visuals()


func add_ingredient(ingredient: Variant, amount: float = 1.0) -> void:
	if ingredient == null or amount <= 0.0:
		return

	ingredients.append({"data": ingredient, "amount": amount})
	ingredient_added.emit(ingredient, amount)
	_refresh_visuals()
	_emit_contents_changed()


func set_heat_level(level: float) -> void:
	var next_level: float = clampf(level, 0.0, 1.0)
	if is_equal_approx(next_level, heat_level):
		return

	heat_level = next_level
	heat_level_changed.emit(heat_level)
	_refresh_visuals()
	_emit_contents_changed()


func register_stir_distance(distance: float) -> void:
	if distance <= 0.0 or ingredients.is_empty():
		return

	stir_distance += distance
	stirring_updated.emit(stir_distance)
	_refresh_visuals()
	_emit_contents_changed()


func contains_global_point(point: Vector2) -> bool:
	return global_position.distance_to(point) <= interaction_radius


func has_contents() -> bool:
	return not ingredients.is_empty()


func get_soup_snapshot() -> Dictionary:
	return {
		"ingredients": ingredients.duplicate(true),
		"heat_level": heat_level,
		"stir_distance": stir_distance,
	}


func take_soup_snapshot() -> Dictionary:
	if ingredients.is_empty():
		return {}

	var snapshot: Dictionary = get_soup_snapshot()
	clear()
	return snapshot


func clear() -> void:
	ingredients.clear()
	stir_distance = 0.0
	_refresh_visuals()
	_emit_contents_changed()


func reset_state() -> void:
	heat_level = 0.0
	clear()


func _on_ingredient_drop_area_item_received(
	payload: Variant,
	source: DirectDraggableItem,
) -> void:
	add_ingredient(payload)
	source.reset_processing_state()


func _on_bowl_drop_area_item_received(
	_payload: Variant,
	source: DirectDraggableItem,
) -> void:
	if not source is ServingBowl or not has_contents():
		return
	var bowl: ServingBowl = source as ServingBowl
	if bowl.has_soup():
		return
	bowl.fill_soup(take_soup_snapshot())


func _emit_contents_changed() -> void:
	contents_changed.emit(get_soup_snapshot())


func _refresh_visuals() -> void:
	soup_surface.visible = not ingredients.is_empty()
	heat_glow.modulate.a = heat_level * 0.8
	bowl_drop_area.enabled = has_contents()
	state_label.text = "材料 %d / 混ぜ %.0f" % [ingredients.size(), stir_distance]
