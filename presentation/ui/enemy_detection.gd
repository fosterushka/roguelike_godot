extends RefCounted
const Jammer = preload("res://modules/combat/jammer_rules.gd")
const Weather = preload("res://modules/world/weather_rules.gd")

static func is_jammed(state: Dictionary) -> bool:
	return not Jammer.source(state.get("player", {}), state.get("enemies", [])).is_empty()

static func range_for(state: Dictionary, world: Dictionary) -> float:
	var player: Dictionary = state.get("player", {})
	var radius := float(player.get("radar_range", 0.0))
	if radius <= 0:
		return 0.0
	var weather: Dictionary = world.get("weather", {})
	var fog_strength := float(weather.get("fog_strength", 1.0 if weather.get("type", "") == "foggy" else 0.0))
	radius *= Weather.visibility_multiplier(fog_strength, true)
	return radius * (0.55 if is_jammed(state) else 1.0)
