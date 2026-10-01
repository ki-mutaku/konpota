extends SceneTree


func _init() -> void:
	call_deferred("_run_smoke_test")


func _run_smoke_test() -> void:
	var kitchen_scene: PackedScene = load("res://scenes/game/kitchen.tscn")
	var kitchen: Node2D = kitchen_scene.instantiate() as Node2D
	root.add_child(kitchen)

	var pot: CookingPot = kitchen.get_node("KitchenObjects/Pot") as CookingPot
	var stove: CookingStove = kitchen.get_node("KitchenObjects/Stove") as CookingStove
	var counter: ServingCounter = (
		kitchen.get_node("KitchenObjects/ServingCounter") as ServingCounter
	)
	var bowl: ServingBowl = counter.get_node("ServingBowl") as ServingBowl
	var bowl_body: Polygon2D = bowl.get_node("BowlBody") as Polygon2D
	assert(not bowl_body.visible, "Empty bowl should be hidden on the counter")
	_assert_recipe_resolution(kitchen)
	pot.cook_duration = 0.01
	pot.add_ingredient(load("res://resources/ingredients/corn.tres"))
	pot.add_ingredient(load("res://resources/ingredients/milk.tres"))

	stove.call("_begin_drag", 0.0, -1)
	assert(pot.is_cooking, "Knob press should start cooking immediately")
	stove.call("_end_drag")
	await create_timer(0.05).timeout

	assert(not pot.is_cooking, "Cooking should finish after the configured duration")
	assert(counter.has_soup(), "Completed soup should appear on the counter")
	var soup: Dictionary = bowl.soup as Dictionary
	assert(soup.get("recipe_id") == &"konpota_creamy")
	var soup_sprite: Sprite2D = bowl.get_node("SoupSprite") as Sprite2D
	assert(soup_sprite.texture != null, "Completed soup should select its texture")
	assert(soup_sprite.visible, "Completed soup texture should be visible")
	assert(
		not bowl_body.visible,
		"Placeholder bowl should be hidden behind the completed soup image",
	)
	assert(pot.ingredients.is_empty(), "Pot should be ready for the next batch")
	print("Knob cooking smoke test passed")
	quit(0)


func _assert_recipe_resolution(kitchen: Node2D) -> void:
	var cases: Array[Dictionary] = [
		{"ingredients": [&"corn", &"butter"], "expected": &"konpota_normal"},
		{"ingredients": [&"corn", &"milk"], "expected": &"konpota_creamy"},
		{"ingredients": [&"corn", &"milk", &"sugar"], "expected": &"konpota_sweet"},
		{"ingredients": [&"corn", &"parsley"], "expected": &"konpota_fresh"},
		{"ingredients": [&"corn"], "expected": &"konpota_water"},
	]
	for test_case: Dictionary in cases:
		var entries: Array[Dictionary] = []
		for ingredient_id: StringName in test_case["ingredients"]:
			var resource: IngredientData = load(
				"res://resources/ingredients/%s.tres" % ingredient_id
			) as IngredientData
			entries.append({"data": resource, "amount": 1.0})
		var recipe: Dictionary = kitchen.call(
			"_resolve_recipe",
			{"ingredients": entries},
		) as Dictionary
		assert(recipe.get("id") == test_case["expected"])
