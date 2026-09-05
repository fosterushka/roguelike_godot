extends RefCounted
const Geometry = preload("res://presentation/ui/map_geometry.gd")

static func range_for(state: Dictionary, world: Dictionary) -> float:
	var player: Dictionary = state.get("player", {})
	var radius := float(player.get("radar_range", 0.0))
	if radius <= 0:
		return 0.0
	if world.get("weather", {}).get("type", "") == "foggy":
		radius *= 0.84
	for enemy: Dictionary in state.get("enemies", []):
		if float(player.get("hp", 0)) > 0 and enemy.get("kind", "") == "jammerTruck" and not enemy.get("dead", false) and enemy.get("allegiance", "enemy") != "friendly" and float(enemy.get("stagger_remaining", 0.0)) <= 0 and Geometry.distance_squared(enemy.position, player.get("position", Vector3.ZERO)) <= 48.0 * 48.0:
			return radius * 0.55
	return radius
