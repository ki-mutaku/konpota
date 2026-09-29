class_name IngredientData
extends Resource

@export var id: StringName
@export var display_name: String

# SPEC.md で影響値は未確定。既定値は未調整のプレースホルダーであり、
# 材料ごとのゲームバランスを定義するものではない。
@export var sweetness: float = 0.0
@export var richness: float = 0.0
@export var texture: float = 0.0
