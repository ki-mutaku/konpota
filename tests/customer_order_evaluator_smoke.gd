extends SceneTree

const EVALUATOR: Script = preload("res://scripts/customers/customer_order_evaluator.gd")
const MATERIALS: Dictionary = {
	&"konpota_normal": [&"corn", &"butter"],
	&"konpota_creamy": [&"corn", &"milk"],
	&"konpota_sweet": [&"corn", &"milk", &"sugar"],
	&"konpota_fresh": [&"corn", &"parsley"],
}


func _init() -> void:
	call_deferred("_run_smoke_test")


func _run_smoke_test() -> void:
	_assert_material_values()
	_assert_pot_amount()
	for order: StringName in MATERIALS:
		var payload: Dictionary = _make_payload(MATERIALS[order])
		payload["recipe_id"] = &"unrelated"
		var result: EvaluationResult = EVALUATOR.evaluate(order, payload)
		assert(result.satisfaction == 4 and result.verdict == EvaluationResult.Verdict.SUCCESS)
		for axis: StringName in EVALUATOR.AXES:
			assert(result.achieved_axes[axis])
	var partial: EvaluationResult = EVALUATOR.evaluate(
		&"konpota_sweet", _make_payload([&"corn", &"milk"]))
	assert(partial.satisfaction == 3 and partial.verdict == EvaluationResult.Verdict.FAILURE)
	assert(not partial.achieved_axes[&"sweetness"])
	var doubled: Dictionary = _make_payload([&"corn"], 2)
	var stats: Dictionary = EVALUATOR.evaluate(&"konpota_normal", doubled).actual_stats
	assert(stats["sweetness"] == 6 and stats["thickness"] == 10)
	assert(stats["richness"] == 4 and stats["flavor"] == 6)
	var salt: Dictionary = EVALUATOR.evaluate(
		&"konpota_normal", _make_payload([&"salt"], 2)).actual_stats
	assert(salt["sweetness"] == -2 and salt["richness"] == 4 and salt["flavor"] == 2)
	# Each threshold is inclusive; missing one or more axes earns partial points.
	for points: int in 5:
		var soup := SoupData.new()
		var target: Dictionary = EVALUATOR.ORDER_TARGETS[&"konpota_creamy"]
		for index: int in 4:
			var axis: StringName = EVALUATOR.AXES[index]
			soup.set(axis, target[axis] if index < points else target[axis] - 1)
		var result: EvaluationResult = EVALUATOR.evaluate(&"konpota_creamy", soup)
		assert(result.satisfaction == points)
		assert((result.verdict == EvaluationResult.Verdict.SUCCESS) == (points == 4))
	# Main's cached Pot snapshot and SoupData routes agree with ingredient summation.
	var creamy: Dictionary = _make_payload([&"corn", &"milk"])
	var result: EvaluationResult = EVALUATOR.evaluate(&"konpota_creamy", creamy)
	var cached: Dictionary = result.actual_stats.duplicate()
	cached["ingredients"] = creamy["ingredients"]
	assert(EVALUATOR.evaluate(&"konpota_creamy", cached).satisfaction == 4)
	var quantity: Dictionary = _make_payload([&"corn", &"milk"], 2)
	assert(EVALUATOR.evaluate(&"konpota_creamy", quantity).satisfaction == 4)
	var matching_recipe_with_stale_stats: Dictionary = {
		"recipe_id": &"konpota_sweet",
		"sweetness": 0.0,
		"thickness": 0.0,
		"richness": 0.0,
		"flavor": 0.0,
	}
	var matching_result: EvaluationResult = EVALUATOR.evaluate(
		&"konpota_sweet", matching_recipe_with_stale_stats)
	assert(matching_result.satisfaction == 4)
	assert(matching_result.verdict == EvaluationResult.Verdict.SUCCESS)
	await create_timer(0.5).timeout
	print("Customer order evaluator smoke test passed (4 axes, 0-4 points, amount, metadata)")
	quit()


func _make_payload(ids: Array, amount: float = 1.0) -> Dictionary:
	var entries: Array[Dictionary] = []
	for id: StringName in ids:
		entries.append({"data": load("res://resources/ingredients/%s.tres" % id), "amount": amount})
	return {"ingredients": entries}


func _assert_material_values() -> void:
	var expected: Dictionary = {
		&"corn": [3, 5, 2, 3], &"milk": [1, 3, 5, 1], &"butter": [0, 2, 8, 2],
		&"parsley": [0, 0, 0, 8], &"sugar": [8, 0, 0, 0], &"salt": [-1, 0, 2, 1],
	}
	for id: StringName in expected:
		var data: IngredientData = load("res://resources/ingredients/%s.tres" % id)
		for index: int in 4:
			assert(data.get(EVALUATOR.AXES[index]) == expected[id][index])


func _assert_pot_amount() -> void:
	var scene: PackedScene = load("res://scenes/cooking/pot.tscn")
	var pot: CookingPot = scene.instantiate() as CookingPot
	root.add_child(pot)
	pot.add_ingredient(load("res://resources/ingredients/corn.tres"), 2)
	var snapshot: Dictionary = pot.get_soup_snapshot()
	var stats: Dictionary = EVALUATOR.evaluate(&"konpota_normal", snapshot).actual_stats
	assert(stats["sweetness"] == 6 and stats["thickness"] == 10)
	assert(stats["richness"] == 4 and stats["flavor"] == 6)
	pot.reset_state()
	pot.free()
