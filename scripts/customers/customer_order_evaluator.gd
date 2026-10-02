class_name CustomerOrderEvaluator
extends RefCounted

const AXES: Array[StringName] = [
	&"sweetness", &"thickness", &"richness", &"flavor",
]

const ORDER_TEXTS: Dictionary = {
	&"konpota_normal": "普通のがほしい",
	&"konpota_creamy": "とろとろしたやつがほしい",
	&"konpota_sweet": "甘いものが欲しい",
	&"konpota_fresh": "さっぱりしたものが欲しい",
}

# Each target is the sum of the requirement document's recommended ingredients.
const ORDER_TARGETS: Dictionary = {
	&"konpota_normal": {
		"sweetness": 3.0, "thickness": 7.0, "richness": 10.0, "flavor": 5.0,
	},
	&"konpota_creamy": {
		"sweetness": 4.0, "thickness": 8.0, "richness": 7.0, "flavor": 4.0,
	},
	&"konpota_sweet": {
		"sweetness": 12.0, "thickness": 8.0, "richness": 7.0, "flavor": 4.0,
	},
	&"konpota_fresh": {
		"sweetness": 3.0, "thickness": 5.0, "richness": 2.0, "flavor": 11.0,
	},
}


static func get_order_ids() -> Array[StringName]:
	return [
		&"konpota_normal", &"konpota_creamy", &"konpota_sweet", &"konpota_fresh",
	]


static func get_order_text(order_id: StringName) -> String:
	return str(ORDER_TEXTS.get(order_id, "普通のがほしい"))


static func evaluate(order_id: StringName, payload: Variant) -> EvaluationResult:
	var target: Dictionary = ORDER_TARGETS.get(order_id, {}) as Dictionary
	var actual: Dictionary = _extract_stats(payload)
	var achieved: Dictionary = {}
	var satisfaction: int = 0
	for axis: StringName in AXES:
		var reached: bool = (
			float(actual.get(axis, 0.0)) >= float(target.get(axis, INF))
		)
		achieved[axis] = reached
		if reached:
			satisfaction += 1
	var verdict: EvaluationResult.Verdict = (
		EvaluationResult.Verdict.SUCCESS
		if satisfaction == AXES.size()
		else EvaluationResult.Verdict.FAILURE
	)
	return EvaluationResult.new(verdict, satisfaction, achieved, actual, target)


static func _extract_stats(payload: Variant) -> Dictionary:
	if payload is SoupData:
		var soup: SoupData = payload as SoupData
		return {
			"sweetness": soup.sweetness,
			"thickness": soup.thickness,
			"richness": soup.richness,
			"flavor": soup.flavor,
		}
	if not payload is Dictionary:
		return {}
	var snapshot: Dictionary = payload as Dictionary
	if snapshot.has("sweetness"):
		return {
			"sweetness": float(snapshot.get("sweetness", 0.0)),
			"thickness": float(snapshot.get("thickness", 0.0)),
			"richness": float(snapshot.get("richness", 0.0)),
			"flavor": float(snapshot.get("flavor", 0.0)),
		}
	var entries: Array = snapshot.get("ingredients", []) as Array
	return _sum_ingredients(entries)


static func _sum_ingredients(entries: Array) -> Dictionary:
	var totals: Dictionary = {
		"sweetness": 0.0,
		"thickness": 0.0,
		"richness": 0.0,
		"flavor": 0.0,
	}
	for value: Variant in entries:
		if not value is Dictionary:
			continue
		var entry: Dictionary = value as Dictionary
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
