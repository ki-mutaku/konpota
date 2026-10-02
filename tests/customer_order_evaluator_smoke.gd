extends SceneTree


func _init() -> void:
	call_deferred("_run_smoke_test")


func _run_smoke_test() -> void:
	var cases: Dictionary = {
		&"konpota_normal": [&"corn", &"butter"],
		&"konpota_creamy": [&"corn", &"milk"],
		&"konpota_sweet": [&"corn", &"milk", &"sugar"],
		&"konpota_fresh": [&"corn", &"parsley"],
	}
	for order_id: StringName in cases:
		var payload: Dictionary = _make_payload(cases[order_id] as Array)
		var result: EvaluationResult = CustomerOrderEvaluator.evaluate(order_id, payload)
		assert(result.satisfaction == 4, "Matching recipe should earn four points")
		assert(result.verdict == EvaluationResult.Verdict.SUCCESS)
		for axis: StringName in CustomerOrderEvaluator.AXES:
			assert(result.achieved_axes.get(axis) == true)

	var partial_payload: Dictionary = _make_payload([&"corn", &"milk"])
	var sweet_result: EvaluationResult = CustomerOrderEvaluator.evaluate(
		&"konpota_sweet",
		partial_payload,
	)
	assert(sweet_result.satisfaction == 3)
	assert(sweet_result.achieved_axes[&"sweetness"] == false)
	assert(sweet_result.verdict == EvaluationResult.Verdict.FAILURE)
	print("Customer order evaluator smoke test passed")
	quit(0)


func _make_payload(ingredient_ids: Array) -> Dictionary:
	var pot_scene: PackedScene = load("res://scenes/cooking/pot.tscn")
	var pot: CookingPot = pot_scene.instantiate() as CookingPot
	root.add_child(pot)
	for value: Variant in ingredient_ids:
		var ingredient_id: StringName = StringName(value)
		var ingredient: IngredientData = load(
			"res://resources/ingredients/%s.tres" % ingredient_id
		) as IngredientData
		pot.add_ingredient(ingredient)
	var snapshot: Dictionary = pot.get_soup_snapshot()
	pot.free()
	return snapshot
