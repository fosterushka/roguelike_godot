extends RefCounted
## Exact vector paths from the supplied FIELDWORK SVG symbols.
const Tokens = preload("res://presentation/ui/fieldwork_tokens.gd")
const ATLAS = preload("res://assets/ui/fieldwork/icons.svg")
const KEYS = ["armory", "stash", "vault", "base", "trade", "play", "settings", "close", "health", "fuel", "scrap", "ammo", "repair", "crew", "missions", "extract"]

const EXTRA = {
	"car": preload("res://assets/ui/fieldwork/car.svg"),
	"coin": preload("res://assets/ui/fieldwork/coin.svg"),
	"shield": preload("res://assets/ui/fieldwork/shield.svg"),
	"bolt": preload("res://assets/ui/fieldwork/bolt.svg"),
	"ram": preload("res://assets/ui/fieldwork/ram.svg"),
	"monitor": preload("res://assets/ui/fieldwork/monitor.svg"),
	"keyboard": preload("res://assets/ui/fieldwork/keyboard.svg"),
	"sound": preload("res://assets/ui/fieldwork/sound.svg"),
	"arrow": preload("res://assets/ui/fieldwork/arrow.svg"),
	"plus": preload("res://assets/ui/fieldwork/plus.svg"),
	"search": preload("res://assets/ui/fieldwork/search.svg"),
	"exit": preload("res://assets/ui/fieldwork/exit.svg"),
	"back": preload("res://assets/ui/fieldwork/back.svg"),
	"check": preload("res://assets/ui/fieldwork/check.svg"),
	"box": preload("res://assets/ui/fieldwork/box.svg"),
	"gun": preload("res://assets/ui/fieldwork/gun.svg"),
}

static func texture(key: String) -> Texture2D:
	if EXTRA.has(key):
		return EXTRA[key]
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
	for state: String in ["icon_normal_color", "icon_hover_color", "icon_pressed_color", "icon_disabled_color", "icon_focus_color"]:
		button.add_theme_color_override(state, Tokens.QUIET if state == "icon_disabled_color" else Tokens.MUTED)
	button.expand_icon = true
	button.add_theme_constant_override("icon_max_width", icon_size)
	button.add_theme_constant_override("h_separation", 8)

static func view(key: String, icon_size: int = 22) -> TextureRect:
	var result := TextureRect.new()
	result.texture = texture(key)
	result.modulate = Tokens.MUTED
	result.custom_minimum_size = Vector2(icon_size, icon_size)
	result.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	result.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return result
