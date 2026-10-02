class_name CookingPot
extends Node2D

signal ingredient_added(ingredient: Variant, amount: float)
signal heat_level_changed(level: float)
signal stirring_updated(total_distance: float)
signal contents_changed(snapshot: Dictionary)
signal cooking_started(snapshot: Dictionary)
signal cooking_completed(soup: Dictionary)

const WATER_POT_TEXTURE: Texture2D = preload(
	"res://assets/sprites/utensils/water-pot-transparent.png"
)
const CORN_POT_TEXTURE: Texture2D = preload(
	"res://assets/sprites/utensils/corn-pot-transparent.png"
)

@export_range(24.0, 256.0, 1.0) var interaction_radius: float = 92.0
@export_range(0.1, 30.0, 0.1) var cook_duration: float = 3.0

var heat_level: float = 0.0
var stir_distance: float = 0.0
var ingredients: Array[Dictionary] = []
var is_cooking: bool = false
var _cooking_snapshot: Dictionary = {}
var _cook_generation: int = 0

@onready var soup_surface: Polygon2D = %SoupSurface
@onready var heat_glow: Polygon2D = %HeatGlow
@onready var state_label: Label = %StateLabel
@onready var ingredient_drop_area: DirectDropTarget = $IngredientDropArea
@onready var bowl_drop_area: DirectDropTarget = %BowlDropArea
@onready var pot_state_sprite: Sprite2D = %PotStateSprite
@onready var cooking_sound: AudioStreamPlayer = $CookingSound
@onready var cooking_success_sound: AudioStreamPlayer = $CookingSuccessSound
@onready var cooking_failed_sound: AudioStreamPlayer = $CookingFailedSound
@onready var ingredient_sound: AudioStreamPlayer = $IngredientSound


func _ready() -> void:
	# Keep looping local to this pot instead of changing the shared audio resource.
	var cooking_stream: AudioStreamMP3 = cooking_sound.stream.duplicate() as AudioStreamMP3
	cooking_stream.loop = true
	cooking_sound.stream = cooking_stream
	_refresh_visuals()


func add_ingredient(ingredient: Variant, amount: float = 1.0) -> void:
	if ingredient == null or amount <= 0.0 or is_cooking:
		return

	ingredients.append({"data": ingredient, "amount": amount})
	ingredient_sound.play()
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


func has_ingredient_id(ingredient_id: StringName) -> bool:
	for entry: Dictionary in ingredients:
		var data: Variant = entry.get("data")
		if data != null and data.get("id") == ingredient_id:
			return true
	return false


func get_soup_snapshot() -> Dictionary:
	var snapshot: Dictionary = {
		"ingredients": ingredients.duplicate(true),
		"heat_level": heat_level,
		"stir_distance": stir_distance,
	}
	snapshot.merge(_calculate_ingredient_totals())
	return snapshot


func _calculate_ingredient_totals() -> Dictionary:
	var totals: Dictionary = {
		"sweetness": 0.0,
		"thickness": 0.0,
		"richness": 0.0,
		"flavor": 0.0,
	}
	for entry: Dictionary in ingredients:
		var data: Variant = entry.get("data")
		if not data is IngredientData:
			continue
		var ingredient: IngredientData = data as IngredientData
		var amount: float = float(entry.get("amount", 1.0))
		totals["sweetness"] += ingredient.sweetness * amount
		totals["thickness"] += ingredient.thickness * amount
		totals["richness"] += ingredient.richness * amount
		totals["flavor"] += ingredient.flavor * amount
	return totals


func take_soup_snapshot() -> Dictionary:
	if ingredients.is_empty() or is_cooking:
		return {}

	var snapshot: Dictionary = get_soup_snapshot()
	clear()
	return snapshot


func clear() -> void:
	if is_cooking:
		return
	ingredients.clear()
	stir_distance = 0.0
	_refresh_visuals()
	_emit_contents_changed()


func reset_state() -> void:
	cooking_sound.stop()
	cooking_success_sound.stop()
	cooking_failed_sound.stop()
	ingredient_sound.stop()
	_cook_generation += 1
	is_cooking = false
	_cooking_snapshot.clear()
	heat_level = 0.0
	clear()
	pot_state_sprite.texture = WATER_POT_TEXTURE


func start_cooking(recipe_id: StringName, display_name: String) -> bool:
	if is_cooking or ingredients.is_empty() or not has_ingredient_id(&"corn"):
		return false

	cooking_success_sound.stop()
	cooking_failed_sound.stop()
	is_cooking = true
	_cook_generation += 1
	var generation: int = _cook_generation
	_cooking_snapshot = get_soup_snapshot()
	_cooking_snapshot["recipe_id"] = recipe_id
	_cooking_snapshot["display_name"] = display_name
	pot_state_sprite.texture = CORN_POT_TEXTURE
	cooking_sound.play()
	cooking_started.emit(_cooking_snapshot.duplicate(true))
	_refresh_visuals()
	get_tree().create_timer(cook_duration).timeout.connect(
		_complete_cooking.bind(generation)
	)
	return true


func _complete_cooking(generation: int) -> void:
	if not is_cooking or generation != _cook_generation:
		return

	var completed_soup: Dictionary = _cooking_snapshot.duplicate(true)
	cooking_sound.stop()
	is_cooking = false
	_cooking_snapshot.clear()
	ingredients.clear()
	stir_distance = 0.0
	pot_state_sprite.texture = WATER_POT_TEXTURE
	_refresh_visuals()
	_emit_contents_changed()
	if StringName(completed_soup["recipe_id"]) == &"konpota_water":
		cooking_failed_sound.play()
	else:
		cooking_success_sound.play()
	cooking_completed.emit(completed_soup)


func _on_ingredient_drop_area_item_received(
	payload: Variant,
	source: DirectDraggableItem,
) -> void:
	if is_cooking:
		return
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
	soup_surface.visible = false
	heat_glow.modulate.a = heat_level * 0.8
	ingredient_drop_area.enabled = not is_cooking
	bowl_drop_area.enabled = has_contents() and not is_cooking
	if is_cooking:
		state_label.text = "調理中…"
	else:
		state_label.text = "材料 %d / 混ぜ %.0f" % [ingredients.size(), stir_distance]
