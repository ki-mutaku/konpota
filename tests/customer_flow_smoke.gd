extends SceneTree

var received_count: int = 0
var requested_count: int = 0
var completed_count: int = 0
var last_payload: Variant
var last_request_id: int = 0
var last_result: EvaluationResult


func _init() -> void:
	call_deferred("_run_smoke_test")


func _run_smoke_test() -> void:
	var scene: PackedScene = load("res://scenes/customers/customer.tscn")
	assert(scene != null, "Customer scene should load")
	var customer: Customer = scene.instantiate() as Customer
	root.add_child(customer)
	var target: DirectDropTarget = customer.get_node("DropTarget") as DirectDropTarget
	assert(target != null and target.accepted_tag == &"soup")
	assert(target.get_node("CollisionShape2D") != null)
	customer.soup_received.connect(_on_received)
	customer.evaluation_requested.connect(_on_requested)
	customer.evaluation_completed.connect(_on_completed)

	var bowl_scene: PackedScene = load("res://scenes/cooking/serving_bowl.tscn")
	var bowl: ServingBowl = bowl_scene.instantiate() as ServingBowl
	root.add_child(bowl)
	var invalid_inputs: Array[Variant] = [42, Resource.new(), {},
		{"ingredients": [], "heat_level": 0.0, "stir_distance": 0.0},
		{"ingredients": [42], "heat_level": 0.0, "stir_distance": 0.0}]
	for payload: Variant in invalid_inputs:
		assert(bowl.fill_soup(payload))
		assert(not target.try_receive(bowl), "Unsupported input must be rejected")
		bowl.drag_finished.emit(bowl, false, target)
		assert(bowl.has_soup(), "Rejected soup must not be consumed")
		bowl.clear_soup()
	assert(not target.try_receive(bowl), "Empty bowl must be rejected")
	assert(not target.try_receive(null))
	assert(received_count == 0 and requested_count == 0)

	var pot_scene: PackedScene = load("res://scenes/cooking/pot.tscn")
	var pot: CookingPot = pot_scene.instantiate() as CookingPot
	root.add_child(pot)
	pot.add_ingredient(IngredientData.new())
	var snapshot: Dictionary = pot.take_soup_snapshot()
	assert(bowl.fill_soup(snapshot))
	assert(target.try_receive(bowl), "Actual Pot snapshot should be accepted")
	assert(last_payload == snapshot, "Payload must pass through without conversion")
	assert(received_count == 1 and requested_count == 1 and completed_count == 0)
	assert(not target.try_receive(bowl), "Pending evaluation must reject duplicates")
	bowl.drag_finished.emit(bowl, true, target)
	assert(not bowl.has_soup(), "Accepted soup should be consumed by existing Cooking")

	# Test result is an opaque fixture, not a production score or evaluator.
	var result := EvaluationResult.new()
	var first_id: int = last_request_id
	assert(not customer.complete_evaluation(first_id + 1, result))
	assert(not customer.complete_evaluation(first_id, null))
	assert(customer.complete_evaluation(first_id, result))
	assert(last_result == result and completed_count == 1)
	assert(not customer.complete_evaluation(first_id, result))
	assert(completed_count == 1, "Completion must notify exactly once")

	var soup_scene: PackedScene = load("res://scenes/cooking/konpota_normal.tscn")
	var soup: DirectDraggableItem = soup_scene.instantiate() as DirectDraggableItem
	root.add_child(soup)
	assert(target.try_receive(soup), "Existing SoupData scene should be accepted")
	assert(last_payload == soup.payload and last_payload is SoupData)
	assert(last_request_id > first_id)
	assert(not customer.complete_evaluation(first_id, result), "Stale results must be rejected")
	assert(customer.complete_evaluation(last_request_id, result))
	assert(received_count == 2 and requested_count == 2 and completed_count == 2)

	customer.evaluation_requested.connect(func(id: int, _payload: Variant) -> void:
		assert(customer.complete_evaluation(id, EvaluationResult.new())))
	assert(target.try_receive(soup), "Synchronous evaluator completion should work")
	assert(received_count == 3 and requested_count == 3 and completed_count == 3)
	assert(target.enabled)
	customer.free()
	bowl.free()
	pot.free()
	soup.free()
	print("Customer flow smoke test passed (no scoring rules)")
	quit(0)


func _on_received(_payload: Variant) -> void:
	received_count += 1


func _on_requested(request_id: int, payload: Variant) -> void:
	requested_count += 1
	last_request_id = request_id
	last_payload = payload


func _on_completed(result: EvaluationResult) -> void:
	completed_count += 1
	last_result = result
