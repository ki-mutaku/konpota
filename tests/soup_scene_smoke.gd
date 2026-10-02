extends SceneTree

var received_payload: Variant = null


func _init() -> void:
	call_deferred("_run_smoke_test")


func _run_smoke_test() -> void:
	var customer_target := DirectDropTarget.new()
	customer_target.accepted_tag = &"soup"
	customer_target.item_received.connect(_on_item_received)
	root.add_child(customer_target)

	for variant: String in ["normal", "creamy", "fresh", "sweet"]:
		var id: String = "konpota_" + variant
		var scene: PackedScene = load("res://scenes/cooking/%s.tscn" % id)
		var template: SoupData = load("res://resources/recipes/%s.tres" % id)
		assert(scene != null and template != null, "Soup assets should load")
		var soup: DirectDraggableItem = scene.instantiate() as DirectDraggableItem
		var other: DirectDraggableItem = scene.instantiate() as DirectDraggableItem
		root.add_child(soup)
		root.add_child(other)

		var data: SoupData = soup.payload as SoupData
		assert(data != null and data.id == StringName(id), "Soup should have matching data")
		assert(not data.display_name.is_empty(), "Soup should have a display name")
		assert(data != other.payload and data != template, "Each soup needs independent stats")
		assert(data.sweetness == template.sweetness, "Scene should use configured sweetness")
		assert(data.thickness == template.thickness, "Scene should use configured thickness")
		assert(data.richness == template.richness, "Scene should use configured richness")
		assert(data.flavor == template.flavor, "Scene should use configured flavor")
		data.sweetness += 1.0
		data.thickness += 2.0
		data.richness += 2.0
		data.flavor += 3.0
		var other_data: SoupData = other.payload as SoupData
		assert(other_data.sweetness == template.sweetness, "Sweetness must not leak")
		assert(other_data.thickness == template.thickness, "Thickness must not leak")
		assert(other_data.richness == template.richness, "Richness must not leak")
		assert(other_data.flavor == template.flavor, "Flavor must not leak")

		var sprite: Sprite2D = soup.get_node("Sprite2D") as Sprite2D
		assert(sprite.texture != null, "Soup should display its illustration")
		assert(sprite.texture.resource_path == "res://assets/sprites/recipes/%s.png" % id)
		var collision: CollisionShape2D = soup.get_node("CollisionShape2D") as CollisionShape2D
		assert(collision.shape != null and not collision.disabled, "Soup should be pickable")
		assert(soup.input_pickable and soup.drag_tag == &"soup")
		assert(soup.accepted_behavior == DirectDraggableItem.AcceptedBehavior.HIDE)
		assert(customer_target.try_receive(soup), "Customer should accept soup")
		assert(received_payload == data, "Customer should receive soup stats")
		soup.free()
		other.free()

	customer_target.free()
	print("Soup scene smoke test passed (4 variants)")
	quit(0)


func _on_item_received(payload: Variant, _source: DirectDraggableItem) -> void:
	received_payload = payload
