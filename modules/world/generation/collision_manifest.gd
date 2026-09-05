extends RefCounted
const Random = preload("res://modules/world/activities/source_random.gd")
const Layout = preload("res://modules/world/generation/layout_generator.gd")

static func rounded(value: float) -> float:
	return floor(value * 1000 + 0.5) / 1000

static func rock_segments(seed_value: int, formation: Dictionary) -> Array:
	var index := int(str(formation.id).right(2))
	var random := Random.new()
	random.state = ((seed_value & 0xffffffff) ^ (((index + 1) * 0x45d9f3b) & 0xffffffff)) & 0xffffffff
	random.next()
	random.next()
	var count := maxi(3, floori(float(formation.radius) / 2.8 + 0.5))
	var tx := cos(float(formation.rotation))
	var tz := sin(float(formation.rotation))
	var result: Array = []
	for part in count:
		var progress := float(part) / (count - 1) - 0.5
		var bend: float = sin((progress + 0.5) * PI) * formation.radius * 0.24
		var jitter := random.between(-0.5, 0.5)
		result.append({"id": "rock:%s-%d" % [formation.id, part], "kind": "rock", "x": rounded(formation.x + tx * progress * formation.radius * 1.65 - tz * (bend + jitter)), "z": rounded(formation.z + tz * progress * formation.radius * 1.65 + tx * (bend + jitter)), "radius": rounded(random.between(3.1, 4.3))})
	return result

static func generate(seed_value: int) -> Dictionary:
	var layout: Dictionary = Layout.generate(seed_value)
	var rocks: Array = []
	for formation: Dictionary in layout.rockFormations:
		rocks.append_array(rock_segments(layout.seed, formation))
	var props: Array = []
	for site: Dictionary in layout.monuments:
		var factory: bool = site.type == "recycling-factory"
		props.append({"id": "prop:" + site.id, "kind": "monument", "visualType": site.type, "x": rounded(site.x), "z": rounded(site.z), "radius": 10 if factory else 7, "hp": 260 if factory else 150, "salvage": 18 if factory else 10})
	return {"seed": layout.seed, "staticColliders": rocks, "destructibleProps": props}
