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
	var count := maxi(3, floori(float(site.radius) / 2.8 + 0.5))
	var tx := cos(float(site.rotation))
	var tz := sin(float(site.rotation))
	var nx := -tz
	var nz := tx
	var face_sign := -1.0 if random.next() < 0.5 else 1.0
	var silhouette_phase := random.between(0, TAU)
	var yaw: float = -site.rotation
	var collisions := Collision.rock_segments(context.layout.seed, site)
	for index in count:
		var progress := float(index) / (count - 1) - 0.5
		var collision: Dictionary = collisions[index]
		var x: float = collision.x
		var z: float = collision.z
		var radius: float = collision.radius
		context.rock_obstacles.append(collision)
		var silhouette := 0.9 + sin(progress * PI * 1.7 + silhouette_phase) * 0.16
		var height := radius * random.between(2.05, 2.85) * silhouette
		var face_offset := radius * random.between(0.02, 0.12) * face_sign
		context.append("cliffFaces", Vector3(x + nx * face_offset, height * 0.5, z + nz * face_offset), Vector3(random.between(-0.035, 0.035), yaw + random.between(-0.16, 0.16), random.between(-0.055, 0.055)), Vector3(radius * random.between(0.84, 1.02), height, radius * random.between(0.72, 0.92)))
		var buttress_height := height * random.between(0.42, 0.7)
		var buttress_offset := radius * random.between(0.24, 0.38) * face_sign
		context.append("cliffFaces", Vector3(x + nx * buttress_offset, buttress_height * 0.5, z + nz * buttress_offset), Vector3(0, yaw + random.between(-0.3, 0.3), random.between(-0.08, 0.08)), Vector3(radius * 0.68, buttress_height, radius * 0.58))
		var strata_count := 3 if index % 2 == 0 else 2
		for layer in strata_count:
			var level := float(layer + 1) / (strata_count + 1)
			var shelf_offset := face_offset + face_sign * radius * random.between(0.03, 0.12)
			context.append("cliffStrata", Vector3(x + nx * shelf_offset, height * level, z + nz * shelf_offset), Vector3(random.between(-0.03, 0.03), yaw + random.between(-0.1, 0.1), 0), Vector3(radius * random.between(0.86, 1.08), random.between(0.16, 0.28), radius * random.between(0.76, 0.96)))
		var cap_scale := radius / 0.68
		context.append("stoneInstances" if index % 3 == 0 else "rockInstances", Vector3(x + tx * random.between(-0.35, 0.35), height * random.between(0.86, 0.96), z + tz * random.between(-0.35, 0.35)), Vector3(random.between(-0.2, 0.2), random.between(0, TAU), random.between(-0.18, 0.18)), Vector3(cap_scale * 0.54, cap_scale * random.between(0.35, 0.62), cap_scale * 0.58))
		for shard in 4:
			var angle := random.between(0, TAU)
			var offset := radius * random.between(0.5, 0.82)
			var shard_scale := cap_scale * random.between(0.16, 0.32)
			context.append("rockInstances" if shard % 2 == 0 else "stoneInstances", Vector3(x + cos(angle) * offset, shard_scale * 0.34, z + sin(angle) * offset), Vector3(random.between(-0.35, 0.35), random.between(0, TAU), random.between(-0.35, 0.35)), Vector3(shard_scale * 1.3, shard_scale * random.between(0.62, 1.15), shard_scale))
	return count
