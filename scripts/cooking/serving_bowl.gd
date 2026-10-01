class_name ServingBowl
extends DirectDraggableItem

signal soup_delivered(soup: Variant)
signal soup_changed(soup: Variant)

const RECIPE_TEXTURES: Dictionary = {
	&"konpota_normal": preload("res://assets/sprites/recipes/konpota_normal.png"),
	&"konpota_creamy": preload("res://assets/sprites/recipes/konpota_creamy.png"),
	&"konpota_sweet": preload("res://assets/sprites/recipes/konpota_sweet.png"),
	&"konpota_fresh": preload("res://assets/sprites/recipes/konpota_fresh.png"),
	&"konpota_water": preload("res://assets/sprites/recipes/konpota_water.png"),
}

var soup: Variant = null

@onready var soup_fill: Polygon2D = %SoupFill
@onready var bowl_label: Label = %BowlLabel
@onready var shadow: Polygon2D = %Shadow
@onready var bowl_body: Polygon2D = %BowlBody
@onready var soup_sprite: Sprite2D = %SoupSprite


func _ready() -> void:
	super._ready()
	drag_finished.connect(_on_drag_finished)
	clear_soup()


func fill_soup(value: Variant) -> bool:
	if value == null or has_soup():
		return false
	soup = value
	drag_tag = &"soup"
	var recipe_id: StringName = _get_recipe_id(value)
	var fallback_texture: Texture2D = RECIPE_TEXTURES[&"konpota_water"] as Texture2D
	var recipe_texture: Texture2D = RECIPE_TEXTURES.get(
		recipe_id,
		fallback_texture,
	) as Texture2D
	soup_sprite.texture = recipe_texture
	bowl_label.text = _get_display_name(value)
	_refresh_visuals()
	soup_changed.emit(soup)
	return true


func clear_soup() -> void:
	soup = null
	drag_tag = &"bowl"
	if is_node_ready():
		soup_sprite.texture = null
		bowl_label.text = "器"
		_refresh_visuals()
	soup_changed.emit(soup)


func has_soup() -> bool:
	return soup != null


func get_interaction_payload() -> Variant:
	return soup if has_soup() else self


func _get_recipe_id(value: Variant) -> StringName:
	if value is SoupData:
		return value.id if value.id != &"" else &"konpota_water"
	if value is Dictionary:
		var recipe_id: StringName = StringName(value.get("recipe_id", ""))
		if recipe_id != &"":
			return recipe_id
		return _infer_recipe_id(value)
	return &"konpota_water"


func _infer_recipe_id(snapshot: Dictionary) -> StringName:
	var ingredient_ids: Dictionary = {}
	for entry: Dictionary in snapshot.get("ingredients", []):
		var data: Variant = entry.get("data")
		if data != null:
			ingredient_ids[StringName(str(data.get("id")))] = true

	if ingredient_ids.has(&"sugar") and ingredient_ids.has(&"milk"):
		return &"konpota_sweet"
	if ingredient_ids.has(&"parsley"):
		return &"konpota_fresh"
	if ingredient_ids.has(&"milk"):
		return &"konpota_creamy"
	if ingredient_ids.has(&"butter"):
		return &"konpota_normal"
	return &"konpota_water"


func _get_display_name(value: Variant) -> String:
	if value is SoupData:
		return value.display_name
	if value is Dictionary:
		return str(value.get("display_name", "コンポタ"))
	return "コンポタ"


func _refresh_visuals() -> void:
	var has_recipe_texture: bool = has_soup() and soup_sprite.texture != null
	soup_sprite.visible = has_recipe_texture
	shadow.visible = not has_recipe_texture
	bowl_body.visible = not has_recipe_texture
	soup_fill.visible = has_soup() and not has_recipe_texture
	bowl_label.visible = not has_recipe_texture


func reset_bowl() -> void:
	clear_soup()
	reset_to_home()


func _on_drag_finished(
	_item: DirectDraggableItem,
	accepted: bool,
	target: DirectDropTarget,
) -> void:
	if not accepted or target == null or not has_soup():
		return
	if target.accepted_tag != &"soup":
		return

	var delivered_soup: Variant = soup
	clear_soup()
	soup_delivered.emit(delivered_soup)
