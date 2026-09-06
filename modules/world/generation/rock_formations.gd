extends RefCounted

const Random = preload("res://modules/world/activities/source_random.gd")
const Collision = preload("res://modules/world/generation/collision_manifest.gd")
var context: RefCounted

func setup(value: RefCounted) -> void:
	context = value

func create(site: Dictionary) -> int:
	var formation_index := int(str(site.id).right(2))
	var random := Random.new()
	random.state = (int(context.layout.seed) ^ (((formation_index + 1) * 0x45d9f3b) & 0xffffffff)) & 0xffffffff
	var collisions := Collision.rock_segments(context.layout.seed, site)
	for index in collisions.size():
		var collision: Dictionary = collisions[index]
		var radius: float = collision.radius
		var height := radius * random.between(1.0, 1.7)
		var pool := "rockMass%d" % ((formation_index + index) % 6)
		var part: Dictionary = context.append(pool, Vector3(collision.x, 0, collision.z), Vector3(0, -float(site.rotation) + random.between(-0.7, 0.7), 0), Vector3(radius, height, radius))
		context.rock_obstacles.append(collision)
		context.register_prop("boulder", collision.x, collision.z, 1.0, {"parts": [part]}, {"id": str(collision.id), "radius": radius, "height": height, "hp": 180.0 + radius * 35.0, "solid": true, "rock_obstacle": true, "salvage": 2, "large": true, "debrisKind": "stone"})
	return collisions.size()
