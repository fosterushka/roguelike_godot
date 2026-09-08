extends RefCounted

const WorldScale = preload("res://modules/world/world_scale.gd")
const GARRISON_AIM_HEIGHT_RATIO := 0.6
const SOLDIER_RADIUS := 0.7 * WorldScale.SOLDIER_SCALE
const SOLDIER_AIM_HEIGHT := 1.05 * WorldScale.SOLDIER_SCALE
const SOLDIER_FIRE_ORIGIN_HEIGHT := 1.3 * WorldScale.SOLDIER_SCALE
const DRONE_FIRE_ORIGIN_OFFSET := 0.2 * WorldScale.DRONE_SCALE

# Values ported from combat/spawning.ts, enemy-system.ts and leviathan.ts.
const DEFINITIONS := {
	"rifleman": {"model": "rifleman","type": "soldier", "hp": 12.0, "speed": 2.25, "damage": 5.0, "radius": SOLDIER_RADIUS, "preferred": 18.0, "range": 34.0, "interval": 1.05, "jitter": 0.35},
	"ak": {"model": "ak","type": "soldier", "hp": 16.0, "speed": 2.7, "damage": 6.0, "radius": SOLDIER_RADIUS, "preferred": 14.0, "range": 28.0, "interval": 0.68, "jitter": 0.22},
	"bazooka": {"model": "bazooka","type": "soldier", "hp": 24.0, "speed": 1.75, "damage": 24.0, "radius": SOLDIER_RADIUS, "preferred": 24.0, "range": 46.0, "interval": 3.2, "jitter": 0.7, "projectile": "rocket"},
	"bomber": {"model": "bomber","type": "soldier", "hp": 72.0, "speed": 3.85, "damage": 46.0, "radius": SOLDIER_RADIUS, "preferred": 3.4, "range": 3.4, "interval": 0.0, "incoming": 0.72, "detonate": true},
	"shooter": {"model": "drone","type": "drone", "hp": 48.0, "speed": 4.5, "damage": 7.0, "radius": 0.95 * WorldScale.DRONE_SCALE, "preferred": 24.0, "range": 46.0, "interval": 0.78, "height": 4.8},
	"kamikaze": {"model": "kamikaze","type": "drone", "hp": 38.0, "speed": 6.4, "damage": 38.0, "radius": 1.05 * WorldScale.DRONE_SCALE, "preferred": 0.0, "range": 4.2, "interval": 0.0, "height": 3.6, "detonate": true},
	"bike": {"model": "bike","spawn": {"speed_range": [5.2, 6.5], "speed_multiplier": 1.5}, "type": "bike", "hp": 34.0, "speed": 8.775, "damage": 9.0, "radius": 1.15, "preferred": 0.0, "range": 0.0, "interval": 0.0},
	"buggy": {"model": "buggy","spawn": {"speed_range": [3.4, 4.2]}, "type": "buggy", "hp": 96.0, "speed": 3.8, "damage": 15.0, "radius": 2.05, "preferred": 16.0, "range": 34.0, "interval": 1.25, "jitter": 0.55},
	"keep": {"model": "raider","type": "keep", "hp": 320.0, "speed": 2.0, "damage": 23.0, "radius": 3.8, "preferred": 15.8, "range": 64.0, "interval": 3.1, "projectile": "rocket", "height": 2.5},
	"garrison_1": {"model": "garrison_1","type": "garrison", "tier": 1, "hp": 370.0, "speed": 0.0, "damage": 9.0, "radius": 5.227400, "preferred": 0.0, "range": 48.0, "interval": 2.230000, "jitter": 0.45, "height": 3.27},
	"garrison_2": {"model": "garrison_2","type": "garrison", "tier": 2, "hp": 480.0, "speed": 0.0, "damage": 11.0, "radius": 5.493200, "preferred": 0.0, "range": 48.0, "interval": 2.010000, "jitter": 0.45, "height": 3.6},
	"garrison_3": {"model": "garrison_3","type": "garrison", "tier": 3, "hp": 590.0, "speed": 0.0, "damage": 13.0, "radius": 5.759000, "preferred": 0.0, "range": 48.0, "interval": 1.790000, "jitter": 0.45, "height": 4.485000},
	"jammerTruck": {"model": "jammerTruck","type": "priorityVehicle", "hp": 150.0, "speed": 3.25, "damage": 10.0, "radius": 2.45, "preferred": 29.0, "range": 43.0, "interval": 1.45, "priority": 2},
	"repairCrawler": {"model": "repairCrawler","type": "priorityVehicle", "hp": 185.0, "speed": 2.75, "damage": 0.0, "radius": 2.65, "preferred": 31.0, "range": 0.0, "interval": 0.00, "priority": 2},
	"minelayer": {"model": "minelayer","type": "priorityVehicle", "hp": 165.0, "speed": 3.45, "damage": 9.0, "radius": 2.50, "preferred": 27.0, "range": 40.0, "interval": 1.70, "priority": 2},
	"leviathan": {"model": "boss","spawn": {"phase": 0, "components": [
		{"kind": "missilePod", "hp": 220.0, "max_hp": 220.0, "phase": 0},
		{"kind": "gunPod", "hp": 190.0, "max_hp": 190.0, "phase": 0},
		{"kind": "leftDrive", "hp": 250.0, "max_hp": 250.0, "phase": 1},
		{"kind": "rightDrive", "hp": 250.0, "max_hp": 250.0, "phase": 1},
		{"kind": "core", "hp": 360.0, "max_hp": 360.0, "phase": 2}]}, "type": "keep", "hp": 1270.0, "speed": 1.55, "damage": 38.0, "radius": 6.0, "preferred": 18.0, "range": 72.0, "interval": 2.75, "projectile": "rocket", "boss": true},
}

static func model_ids(type_filter: String = "") -> Array[String]:
	var result: Array[String] = []
	for definition: Dictionary in DEFINITIONS.values():
		if not type_filter.is_empty() and definition.type != type_filter:
			continue
		var model := str(definition.model)
		if model not in result:
			result.append(model)
	return result
