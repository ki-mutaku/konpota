class_name SoupData
extends Resource

@export var id: StringName
@export var display_name: String

# Completed totals, supplied by the producer; no recipe_id-based scoring.
@export var sweetness: float = 0.0
@export var thickness: float = 0.0
@export var flavor: float = 0.0
@export var richness: float = 0.0
# Legacy resources still serialize this field; it is not an evaluation axis.
@export var texture: float = 0.0
