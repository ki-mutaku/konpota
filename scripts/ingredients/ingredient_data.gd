class_name IngredientData
extends Resource

@export var id: StringName
@export var display_name: String

# Latest requirements: prepared corn/butter/parsley use these four axes.
@export var sweetness: float = 0.0
@export var thickness: float = 0.0
@export var richness: float = 0.0
@export var flavor: float = 0.0
