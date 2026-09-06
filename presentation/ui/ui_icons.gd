extends RefCounted
## Shared GPT Image atlas. Atlas regions preserve the original transparent pixels.
const ATLAS = preload("res://assets/ui/industrial-icons.png")
const KEYS = ["armory", "stash", "vault", "base", "trade", "play", "settings", "close", "health", "fuel", "scrap", "ammo", "repair", "crew", "missions", "extract"]

static func texture(key: String) -> Texture2D:
	var index := KEYS.find(key)
	if index < 0:
		index = KEYS.find("settings")
	var cell := Vector2(ATLAS.get_size()) / 4.0
	var result := AtlasTexture.new()
	result.atlas = ATLAS
	result.region = Rect2(Vector2(index % 4, floori(float(index) / 4.0)) * cell + cell * 0.08, cell * 0.84)
	result.filter_clip = true
	return result

static func apply(button: Button, key: String, icon_size: int = 20) -> void:
	button.icon = texture(key)
	button.expand_icon = true
	button.add_theme_constant_override("icon_max_width", icon_size)
	button.add_theme_constant_override("h_separation", 8)

static func view(key: String, icon_size: int = 22) -> TextureRect:
	var result := TextureRect.new()
	result.texture = texture(key)
	result.custom_minimum_size = Vector2(icon_size, icon_size)
	result.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	result.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return result
