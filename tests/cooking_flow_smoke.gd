extends SceneTree

var received_payload: Variant = null
var served_payload: Variant = null


func _init() -> void:
	call_deferred("_run_smoke_test")


func _run_smoke_test() -> void:
	var pot_scene: PackedScene = load("res://scenes/cooking/pot.tscn")
	var counter_scene: PackedScene = load("res://scenes/cooking/serving_counter.tscn")
	var target_scene: PackedScene = load("res://scenes/cooking/direct_drop_target.tscn")

	var pot: CookingPot = pot_scene.instantiate() as CookingPot
	var counter: ServingCounter = counter_scene.instantiate() as ServingCounter
	var customer_target: DirectDropTarget = target_scene.instantiate() as DirectDropTarget
	root.add_child(pot)
	root.add_child(counter)
	root.add_child(customer_target)

	customer_target.accepted_tag = &"soup"
	customer_target.item_received.connect(_on_customer_received)
	counter.soup_served.connect(_on_soup_served)

	pot.add_ingredient(load("res://resources/ingredients/corn.tres"))
	pot.add_ingredient(load("res://resources/ingredients/milk.tres"))
	var bowl: ServingBowl = counter.get_node("ServingBowl") as ServingBowl
	var bowl_target: DirectDropTarget = pot.get_node("BowlDropArea") as DirectDropTarget
	assert(bowl_target.try_receive(bowl), "Filled pot should accept an empty bowl")
	assert(bowl.has_soup(), "Bowl should contain soup after dropping onto the pot")
	var soup_sprite: Sprite2D = bowl.get_node("SoupSprite") as Sprite2D
	assert(soup_sprite.texture != null, "Recipe-less soup should infer its image")
	assert(soup_sprite.visible, "Inferred completed soup image should be visible")

	var expected_payload: Variant = bowl.get_interaction_payload()
	assert(customer_target.try_receive(bowl), "Customer target should accept a soup bowl")
	bowl.drag_finished.emit(bowl, true, customer_target)
	assert(received_payload == expected_payload, "Customer should receive the soup payload")
	assert(served_payload == expected_payload, "Kitchen-facing served signal should be emitted")
	assert(not bowl.has_soup(), "Bowl should be empty after serving")

	counter.reset_state()
	pot.reset_state()
	assert(not pot.has_contents(), "Pot should be empty after reset")
	quit(0)


func _on_customer_received(payload: Variant, _source: DirectDraggableItem) -> void:
	received_payload = payload


func _on_soup_served(soup: Variant) -> void:
	served_payload = soup
