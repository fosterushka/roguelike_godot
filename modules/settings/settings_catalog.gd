extends RefCounted

const MAX_CAMERA_SHAKE := 1.5
const SLIDER_STEP := 0.01
const LAPTOP_FPS := 60
const RESOLUTIONS := [Vector2i(1280, 800), Vector2i(1280, 720), Vector2i(1600, 900), Vector2i(1920, 1080), Vector2i(2560, 1440), Vector2i(3840, 2160)]
const FPS_LIMITS := [0, 30, 60, 90, 120, 144, 165, 240]
const QUALITY := [
	{"scale": 0.7, "msaa": 0, "shadows": false, "shadow_distance": 60.0},
	{"scale": 0.85, "msaa": 1, "shadows": true, "shadow_distance": 100.0},
	{"scale": 1.0, "msaa": 2, "shadows": true, "shadow_distance": 160.0},
]
const DEFAULTS := {"soundEnabled": true, "cameraShake": 1.0, "masterVolume": 1.0, "effectsVolume": 1.0, "engineVolume": 1.0, "uiVolume": 1.0, "fullscreen": false, "resolution": 0, "vsync": true, "quality": 2, "fpsLimit": 0, "laptop": false, "bindings": {}}

static func normalize(raw: Variant) -> Dictionary:
	var result := DEFAULTS.duplicate(true)
	if not raw is Dictionary:
		return result
	for key: String in DEFAULTS:
		var value: Variant = raw.get(key, DEFAULTS[key])
		if DEFAULTS[key] is bool:
			result[key] = value if value is bool else DEFAULTS[key]
		elif DEFAULTS[key] is float:
			result[key] = clampf(float(value), 0.0, MAX_CAMERA_SHAKE if key == "cameraShake" else 1.0) if (value is float or value is int) and is_finite(float(value)) else DEFAULTS[key]
		elif DEFAULTS[key] is int:
			var maximum: int = {"resolution": RESOLUTIONS.size() - 1, "quality": QUALITY.size() - 1, "fpsLimit": FPS_LIMITS.size() - 1}[key]
			result[key] = clampi(int(value), 0, maximum) if (value is int or value is float) and is_finite(float(value)) else DEFAULTS[key]
	if raw.get("bindings") is Dictionary:
		for action: Variant in raw.bindings:
			var key: Variant = raw.bindings[action]
			if action is String and (key is int or key is float) and is_finite(float(key)) and key > 0 and key <= (KEY_SPECIAL | 0xffff):
				result.bindings[action] = int(key)
	return result

static func effective_quality(values: Dictionary) -> Dictionary:
	return QUALITY[0 if values.laptop else int(values.quality)]

static func effective_fps(values: Dictionary) -> int:
	return LAPTOP_FPS if values.laptop else FPS_LIMITS[int(values.fpsLimit)]
