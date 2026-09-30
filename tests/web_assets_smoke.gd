extends SceneTree

# Use explicit failures: assert() is disabled in release exports.
const TEXTURES: Array[String] = [
	"res://assets/ui/title/title_background.png",
	"res://assets/ui/kitchen/kitchen_background.png",
	"res://assets/sprites/ingredients/corn.png",
	"res://assets/sprites/utensils/mixer_before.png",
	"res://assets/sprites/customers/boy_before.png",
]
const JAPANESE_TEXT: String = "日本語開始終了時間満足度コンポタ師"


func _init() -> void:
	call_deferred("_run_smoke_test")


func _run_smoke_test() -> void:
	var failed: bool = false
	for path: String in TEXTURES:
		var texture: Texture2D = load(path) as Texture2D
		if texture == null or texture is PlaceholderTexture2D:
			push_error("Web asset missing: " + path)
			failed = true
			continue
		var image: Image = texture.get_image()
		if image == null or image.is_empty():
			push_error("Web asset has no image data: " + path)
			failed = true

	var title_scene: PackedScene = load("res://scenes/game/title.tscn") as PackedScene
	if title_scene == null:
		push_error("Title scene could not be loaded")
		quit(1)
		return
	var title: Control = title_scene.instantiate() as Control
	root.add_child(title)
	var label: Label = title.get_node("StatusLabel") as Label
	var font: Font = label.get_theme_font("font")
	for character: String in JAPANESE_TEXT:
		if not font.has_char(character.unicode_at(0)):
			push_error("UI font missing Japanese glyph: " + character)
			failed = true
	title.free()
	if failed:
		quit(1)
		return
	print("Web assets smoke test passed (Title, sprites, Japanese font)")
	quit(0)
