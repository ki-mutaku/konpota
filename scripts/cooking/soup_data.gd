class_name SoupData
extends Resource

@export var id: StringName
@export var display_name: String

# SPEC.md で内部値域・レシピごとの値は未確定。
# 0.0 は未調整のプレースホルダーであり、評価やゲームバランスを定義しない。
@export var sweetness: float = 0.0
@export var richness: float = 0.0
@export var texture: float = 0.0
