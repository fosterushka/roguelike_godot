extends RefCounted

const PROFILES := [
	{"hitbox_size": Vector3(8.0, 3.27, 6.0), "height": 3.27, "door_distance": 2.82},
	{"hitbox_size": Vector3(9.2, 3.6, 5.7), "height": 3.6, "door_distance": 2.5},
	{"hitbox_size": Vector3(10.8, 4.485, 9.8), "height": 4.485, "door_distance": 3.3},
]

static func profile(tier: int) -> Dictionary:
	return PROFILES[clampi(tier, 1, PROFILES.size()) - 1]
