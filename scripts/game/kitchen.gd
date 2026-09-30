extends Node2D

signal soup_served(soup: Variant)

@onready var pot: CookingPot = %Pot
@onready var stove: CookingStove = %Stove
@onready var ladle: CookingLadle = %Ladle
@onready var mixer: CookingMixer = %Mixer
@onready var cutting_board: CookingCuttingBoard = %CuttingBoard
@onready var serving_counter: ServingCounter = %ServingCounter
@onready var status_label: Label = %StatusLabel
@onready var pot_drop_highlight: Polygon2D = %PotDropHighlight
@onready var mixer_drop_highlight: Polygon2D = %MixerDropHighlight
@onready var pot_ingredient_drop_area: DirectDropTarget = (
	pot.get_node("IngredientDropArea") as DirectDropTarget
)
@onready var pot_bowl_drop_area: DirectDropTarget = (
	pot.get_node("BowlDropArea") as DirectDropTarget
)
@onready var mixer_ingredient_drop_area: DirectDropTarget = (
	mixer.get_node("IngredientDropArea") as DirectDropTarget
)


func _ready() -> void:
	stove.heat_changed.connect(pot.set_heat_level)
	ladle.dragged.connect(_on_ladle_dragged)
	serving_counter.soup_served.connect(_on_soup_served)
	serving_counter.soup_changed.connect(_on_serving_soup_changed)
	pot.contents_changed.connect(_on_pot_contents_changed)
	pot_ingredient_drop_area.highlight_changed.connect(_on_pot_highlight_changed)
	pot_bowl_drop_area.highlight_changed.connect(_on_pot_highlight_changed)
	mixer_ingredient_drop_area.highlight_changed.connect(_on_mixer_highlight_changed)
	mixer.processing_progress.connect(_on_mixer_processing_progress)
	mixer.processing_completed.connect(_on_mixer_processing_completed)
	cutting_board.ingredient_processed.connect(_on_ingredient_processed)
	status_label.text = "材料を選んで、コンポタを作ろう"


func add_ingredient_to_pot(ingredient: Variant, amount: float = 1.0) -> void:
	pot.add_ingredient(ingredient, amount)


func add_ingredient_to_mixer(ingredient: Variant, amount: float = 1.0) -> void:
	mixer.add_ingredient(ingredient, amount)


func transfer_mixer_contents_to_pot() -> void:
	for entry: Dictionary in mixer.take_contents():
		pot.add_ingredient(entry.get("data"), float(entry.get("amount", 1.0)))
	status_label.text = "ミキサーの中身を鍋へ移しました"


func _on_ladle_dragged(pointer_position: Vector2, distance: float) -> void:
	if pot.contains_global_point(pointer_position):
		pot.register_stir_distance(distance)


func _on_soup_served(soup: Variant) -> void:
	status_label.text = "提供しました（Customer担当へ signal 接続可能）"
	soup_served.emit(soup)


func _on_serving_soup_changed(soup: Variant) -> void:
	if soup != null:
		status_label.text = "盛り付けました。器を客へドラッグしてください"


func _on_pot_highlight_changed(active: bool) -> void:
	pot_drop_highlight.visible = active


func _on_mixer_highlight_changed(active: bool) -> void:
	mixer_drop_highlight.visible = active


func _on_mixer_processing_progress(current: int, required: int) -> void:
	status_label.text = "ミキサー攪拌中：%d / %d" % [current, required]


func _on_mixer_processing_completed(_payload: Resource) -> void:
	status_label.text = "ペースト状コーン完成。右側のコーンを鍋へドラッグ"


func _on_ingredient_processed(item: DirectDraggableItem) -> void:
	status_label.text = "%sをカットしました。鍋へドラッグ" % item.get_payload_id()


func reset_cooking_state() -> void:
	pot.reset_state()
	stove.reset_state()
	mixer.reset_state()
	cutting_board.reset_state()
	ladle.reset_state()
	serving_counter.reset_state()
	pot_drop_highlight.visible = false
	mixer_drop_highlight.visible = false
	for node: Node in get_tree().get_nodes_in_group(&"direct_draggable_item"):
		if node is DirectDraggableItem:
			var item: DirectDraggableItem = node as DirectDraggableItem
			if item == mixer.output_item:
				continue
			item.reset_processing_state()
			item.reset_to_home()
	status_label.text = "材料を選んで、コンポタを作ろう"


func _on_pot_contents_changed(snapshot: Dictionary) -> void:
	var ingredient_count: int = snapshot.get("ingredients", []).size()
	if ingredient_count > 0:
		status_label.text = "調理中：材料 %d / 火力 %d%%" % [
			ingredient_count,
			roundi(float(snapshot.get("heat_level", 0.0)) * 100.0),
		]
