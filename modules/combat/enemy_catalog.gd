extends RefCounted

# Values ported from combat/spawning.ts, enemy-system.ts and leviathan.ts.
const DEFINITIONS := {
	"rifleman": {"type": "soldier", "hp": 12.0, "speed": 2.25, "damage": 5.0, "radius": 0.7, "preferred": 18.0, "range": 34.0, "interval": 1.05, "jitter": 0.35},
	"ak": {"type": "soldier", "hp": 16.0, "speed": 2.7, "damage": 6.0, "radius": 0.7, "preferred": 14.0, "range": 28.0, "interval": 0.68, "jitter": 0.22},
	"bazooka": {"type": "soldier", "hp": 24.0, "speed": 1.75, "damage": 24.0, "radius": 0.7, "preferred": 24.0, "range": 46.0, "interval": 3.2, "jitter": 0.7, "projectile": "rocket"},
	"bomber": {"type": "soldier", "hp": 72.0, "speed": 3.85, "damage": 46.0, "radius": 0.7, "preferred": 3.4, "range": 3.4, "interval": 0.0, "incoming": 0.72, "detonate": true},
	"shooter": {"type": "drone", "hp": 48.0, "speed": 4.5, "damage": 7.0, "radius": 0.95, "preferred": 24.0, "range": 46.0, "interval": 0.78, "height": 4.8},
	"kamikaze": {"type": "drone", "hp": 38.0, "speed": 6.4, "damage": 38.0, "radius": 1.05, "preferred": 0.0, "range": 4.2, "interval": 0.0, "height": 3.6, "detonate": true},
	"bike": {"type": "bike", "hp": 34.0, "speed": 8.775, "damage": 9.0, "radius": 1.15, "preferred": 0.0, "range": 0.0, "interval": 0.0},
	"buggy": {"type": "buggy", "hp": 96.0, "speed": 3.8, "damage": 15.0, "radius": 2.05, "preferred": 16.0, "range": 34.0, "interval": 1.25, "jitter": 0.55},
	"keep": {"type": "keep", "hp": 320.0, "speed": 2.0, "damage": 23.0, "radius": 3.8, "preferred": 15.8, "range": 64.0, "interval": 3.1, "projectile": "rocket", "height": 2.5},
	"garrison_1": {"type": "garrison", "tier": 1, "hp": 370.0, "speed": 0.0, "damage": 9.0, "radius": 5.227400, "preferred": 0.0, "range": 48.0, "interval": 2.230000, "jitter": 0.45, "height": 4.071000},
	"garrison_2": {"type": "garrison", "tier": 2, "hp": 480.0, "speed": 0.0, "damage": 11.0, "radius": 5.493200, "preferred": 0.0, "range": 48.0, "interval": 2.010000, "jitter": 0.45, "height": 4.278000},
	"garrison_3": {"type": "garrison", "tier": 3, "hp": 590.0, "speed": 0.0, "damage": 13.0, "radius": 5.759000, "preferred": 0.0, "range": 48.0, "interval": 1.790000, "jitter": 0.45, "height": 4.485000},
	"jammerTruck": {"type": "priorityVehicle", "hp": 150.0, "speed": 3.25, "damage": 10.0, "radius": 2.45, "preferred": 29.0, "range": 43.0, "interval": 1.45, "priority": 2},
	"repairCrawler": {"type": "priorityVehicle", "hp": 185.0, "speed": 2.75, "damage": 0.0, "radius": 2.65, "preferred": 31.0, "range": 0.0, "interval": 0.00, "priority": 2},
	"minelayer": {"type": "priorityVehicle", "hp": 165.0, "speed": 3.45, "damage": 9.0, "radius": 2.50, "preferred": 27.0, "range": 40.0, "interval": 1.70, "priority": 2},
	"leviathan": {"type": "keep", "hp": 1270.0, "speed": 1.55, "damage": 38.0, "radius": 6.0, "preferred": 18.0, "range": 72.0, "interval": 2.75, "projectile": "rocket", "boss": true},
}

static func create(kind: String, id: int, position: Vector3, random: RandomNumberGenerator) -> Dictionary:
	var data: Dictionary = DEFINITIONS[kind].duplicate(true)
	data.merge({"id": id, "kind": kind, "position": position, "x": position.x, "z": position.z,
		"max_hp": data.hp, "yaw": 0.0, "velocity": Vector3.ZERO, "cooldown": random.randf_range(0.3, 1.2),
		"counts_toward_wave": true, "collision_cooldown": 0.0, "dead": false, "hit_time": 0.0})
	if data.type == "drone":
		data.flight_height = data.height
		data.dodge_seed = random.randi()
		data.dodge_sign = -1.0 if random.randf() < 0.5 else 1.0
	if kind == "bike":
		data.speed = random.randf_range(5.2, 6.5) * 1.5
	elif kind == "buggy":
		data.speed = random.randf_range(3.4, 4.2)
	if kind == "leviathan":
		data.phase = 0
		data.components = [
			{"kind": "missilePod", "hp": 220.0, "max_hp": 220.0, "phase": 0},
			{"kind": "gunPod", "hp": 190.0, "max_hp": 190.0, "phase": 0},
			{"kind": "leftDrive", "hp": 250.0, "max_hp": 250.0, "phase": 1},
			{"kind": "rightDrive", "hp": 250.0, "max_hp": 250.0, "phase": 1},
			{"kind": "core", "hp": 360.0, "max_hp": 360.0, "phase": 2}]
	return data
