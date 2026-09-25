extends RefCounted

const BUILD_LIMIT := 3
const BUILD_NAME_LIMIT := 32
const FOG_LAMPS := {"cost": 160, "range": 28.0, "near_radius": 3.0, "half_angle_deg": 38.0, "strength": 0.9, "name": "Противотуманные фары", "name_en": "Fog lamps", "description": "Убирают туман в луче перед машиной", "description_en": "Clear fog in a beam ahead of the pickup"}
const TIRES := {
	"standard": {"cost": 0, "name": "Обычные шины", "name_en": "Standard tires", "description": "Универсальные шины", "description_en": "Balanced tires", "road_speed": 1.0, "road_grip": 1.0, "mud_recovery": 0.0},
	"road_tires": {"cost": 140, "name": "Дорожные шины", "name_en": "Road tires", "description": "+8% скорости и +12% сцепления на дороге", "description_en": "+8% speed and +12% grip on roads", "road_speed": 1.08, "road_grip": 1.12, "mud_recovery": 0.0},
	"mud_tires": {"cost": 140, "name": "Грязевые шины", "name_en": "Mud tires", "description": "Вдвое снижают штраф грязи к скорости и сцеплению", "description_en": "Halve mud penalties to speed and grip", "road_speed": 1.0, "road_grip": 1.0, "mud_recovery": 0.5},
}
const PAINTS := {
	"field": {"cost": 0, "name": "Полевой", "name_en": "Field", "color": Color(0.28, 0.32, 0.23)},
	"sand": {"cost": 0, "name": "Песочный", "name_en": "Sand", "color": Color(0.62, 0.49, 0.29)},
	"oxide": {"cost": 0, "name": "Оксид", "name_en": "Oxide", "color": Color(0.48, 0.17, 0.12)},
}
const EMBLEMS := {
	"none": {"cost": 0, "name": "Без эмблемы", "name_en": "No emblem"},
	"stripe": {"cost": 0, "name": "Полоса", "name_en": "Stripe"},
	"cross": {"cost": 0, "name": "Крест", "name_en": "Cross"},
}

static func defaults() -> Dictionary:
	return {"owned": [], "selected": {"tires": "standard", "paint": "field", "emblem": "none", "fog_lamps": false}}

static func purchasable() -> Dictionary:
	return {"road_tires": TIRES.road_tires, "mud_tires": TIRES.mud_tires, "fog_lamps": FOG_LAMPS}

static func normalize(value: Variant) -> Dictionary:
	var result := defaults()
	if not value is Dictionary:
		return result
	var owned: Variant = value.get("owned", [])
	if owned is Array:
		for id: Variant in owned:
			if id is String and purchasable().has(id) and not result.owned.has(id):
				result.owned.append(id)
	result.selected = normalize_selection(value.get("selected", {}), result.owned)
	return result

static func normalize_selection(value: Variant, owned: Array) -> Dictionary:
	var result: Dictionary = defaults().selected
	if not value is Dictionary:
		return result
	for category: String in ["tires", "paint", "emblem"]:
		var options: Dictionary = TIRES if category == "tires" else PAINTS if category == "paint" else EMBLEMS
		var id: Variant = value.get(category, "")
		if id is String and options.has(id) and (int(options[id].cost) == 0 or owned.has(id)):
			result[category] = id
	result.fog_lamps = value.get("fog_lamps", false) == true and owned.has("fog_lamps")
	return result

static func tire_effects(selected: Dictionary, surface: Dictionary, on_road: bool) -> Dictionary:
	var definition: Dictionary = TIRES.get(selected.get("tires", "standard"), TIRES.standard)
	var result := surface.duplicate()
	# Mud is the surface movement penalty; rain alone still retains its traction penalty.
	if float(surface.get("movement", 1.0)) < 1.0:
		for field: String in ["movement", "traction", "turn"]:
			result[field] = lerpf(float(surface.get(field, 1.0)), 1.0, definition.mud_recovery)
	result.road_speed = definition.road_speed if on_road else 1.0
	if on_road:
		result.traction = float(result.get("traction", 1.0)) * float(definition.road_grip)
	return result

static func rows(value: Dictionary, credits: int, enabled: bool) -> Array:
	var result: Array = []
	for category: String in ["tires", "paint", "emblem", "fog_lamps"]:
		var options: Dictionary = TIRES if category == "tires" else PAINTS if category == "paint" else EMBLEMS if category == "emblem" else {"fog_lamps": FOG_LAMPS}
		for id: String in options:
			var definition: Dictionary = options[id]
			var owned: bool = int(definition.cost) == 0 or value.owned.has(id)
			var selected: bool = bool(value.selected.fog_lamps) if category == "fog_lamps" else str(value.selected[category]) == id
			result.append({"id": id, "category": category, "label": definition.name, "name_en": definition.name_en, "description": definition.get("description", ""), "description_en": definition.get("description_en", ""), "cost": definition.cost, "owned": owned, "selected": selected, "enabled": enabled and (owned or credits >= int(definition.cost))})
	return result
