extends RefCounted

const MODEL_IDS := ["projectile_bullet", "projectile_sabot", "projectile_rocket", "projectile_grenade", "projectile_enemy_sabot", "projectile_enemy_rocket", "projectile_enemy_grenade"]

static func tracer_only(projectile: Dictionary) -> bool:
	return projectile.get("team", "") == "enemy" and projectile.get("kind", "bullet") == "bullet"

static func model_id(projectile: Dictionary) -> String:
	if tracer_only(projectile):
		return ""
	var kind := str(projectile.get("kind", "bullet"))
	return "projectile_" + ("enemy_" if projectile.get("team") == "enemy" else "") + (kind if kind in ["rocket", "grenade", "sabot"] else "bullet")
