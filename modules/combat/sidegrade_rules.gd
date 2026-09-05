extends RefCounted

const VARIANTS := {
	"fragmentation-shells": {"bucket": "grenadeLauncher", "range_mult": 0.82, "splash_multiplier": 1.3},
	"penetrator-sabots": {"bucket": "railgun", "damage_mult": 0.8, "pierce": 1},
	"concussion-rounds": {"bucket": "assaultRifle", "damage_mult": 0.82, "slow_multiplier": 0.75, "slow_seconds": 1.5},
	"tracking-rockets": {"bucket": "missileRack", "range_mult": 1.2, "damage_mult": 0.85}}

static func tuning(player: Dictionary, weapon: Dictionary) -> Dictionary:
	var variant_id: String = player.get("selected_sidegrades", {}).get(weapon.type, "")
	var variant: Dictionary = VARIANTS.get(variant_id, {})
	if variant.get("bucket", "") != weapon.type:
		variant = {}
	return {"range": weapon.def.range * variant.get("range_mult", 1.0),
		"damage": weapon.def.damage * variant.get("damage_mult", 1.0), "module_type": weapon.type,
		"variant_id": variant_id if not variant.is_empty() else "",
		"splash_multiplier": variant.get("splash_multiplier", 1.0), "pierce": variant.get("pierce", 0),
		"slow_multiplier": variant.get("slow_multiplier", 1.0), "slow_seconds": variant.get("slow_seconds", 0.0)}

static func apply_control(target: Dictionary, shot: Dictionary) -> void:
	if shot.get("slow_seconds", 0.0) <= 0.0 or target.dead or target.get("boss", false) or target.get("is_component", false) or target.type in ["garrison", "drone"]:
		return
	target.slow_multiplier = minf(target.get("slow_multiplier", 1.0), clampf(shot.slow_multiplier, 0.5, 1.0))
	target.slow_remaining = maxf(target.get("slow_remaining", 0.0), clampf(shot.slow_seconds, 0.0, 2.0))
