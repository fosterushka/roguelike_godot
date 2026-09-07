extends RefCounted

const Source = preload("res://presentation/combat/source_model.gd")
const Enemies = preload("res://modules/combat/enemy_catalog.gd")
const Equipment = preload("res://presentation/vehicles/equipment_model.gd")
const Rig = preload("res://presentation/vehicles/wheeled_rig.gd")
const Wagons = preload("res://modules/caravan/wagon_catalog.gd")
const Crew = preload("res://modules/crew/crew_catalog.gd")
const Appearance = preload("res://presentation/crew/crew_appearance.gd")
const Seats = preload("res://presentation/crew/crew_seats.gd")
const Nature = preload("res://presentation/world/natural_meshes.gd")
const TreeReplacements = preload("res://presentation/world/tree_replacements.gd")
const Context = preload("res://modules/world/generation/generation_context.gd")
const Authored = preload("res://modules/world/generation/authored_props.gd")
const NaturalProps = preload("res://modules/world/generation/natural_props.gd")
const Loot = preload("res://presentation/ui/item_loot_models.gd")
const Items = preload("res://modules/meta/expedition_catalog.gd")

enum Factory { SOURCE, PLAYER, WAGON, EQUIPMENT, CREW_STANDING, CREW_SEATED, NATURE, PROP, LOOT, POOL, PRIMITIVE, COMPONENT, NATURAL_PROP }
const NPC := "NPC / enemies"
const VEHICLES := "Player / wagons"
const GEAR := "Weapons / equipment"
const PEOPLE := "Crew / shared appearances"
const WORLD := "World props / landmarks"
const LANDSCAPE := "Trees / rocks / vegetation"
const ITEMS := "Supplies / loot"
const FX := "Projectiles / wrecks / FX meshes"
const PARTS := "Technical primitives / components"
const PROPS := ["utility_pole", "wreck", "prop_cluster", "well", "market_stall", "windmill", "grazer", "house", "watchtower", "pumpjack", "rock_spire", "dead_grove", "scrap_yard", "water_tower", "recycling_factory", "cargo_crane", "refinery", "satellite_array"]
const SOURCE_SUPPLIES := ["airdrop", "heal_cart", "pickup_fuel", "pickup_salvage"]

const NATURAL_PROPS := ["dead_tree", "boulder", "scrub", "fence"]

static func entries() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var used_source := {}
	for kind: String in Enemies.DEFINITIONS:
		var model: String = Enemies.DEFINITIONS[kind].model
		_add(result, NPC, kind, Factory.SOURCE, model)
		used_source[model] = true
	_add(result, VEHICLES, "player_pickup", Factory.PLAYER)
	for type: String in Wagons.TYPES:
		_add(result, VEHICLES, type, Factory.WAGON, type)
	Equipment.prepare()
	for type: String in Equipment._parts:
		if type in ["ammo_feed", "armor_panels"]:
			continue
		_add(result, GEAR, type, Factory.EQUIPMENT, type)
	for role: String in Crew.ROLES:
		_add(result, PEOPLE, role + " standing", Factory.CREW_STANDING, role, "Authored role equipment / shared body rig")
		_add(result, PEOPLE, role + " seated", Factory.CREW_SEATED, role, "Shared seated body and role kit; bench belongs to the pickup")
	for name: String in SOURCE_SUPPLIES:
		_add(result, ITEMS, name, Factory.SOURCE, name)
		used_source[name] = true
	_add(result, ITEMS, "mine", Factory.SOURCE, "mine_enemy", "One physical mine; enemy, friendly and unarmed are runtime states")
	used_source["mine_enemy"] = true
	for item: String in Items.ITEMS:
		_add(result, ITEMS, item, Factory.LOOT, item, "Canonical mesh: ammo_feed" if item == "weapon_parts" else "")
	for pool: String in Nature.all():
		_add(result, LANDSCAPE, pool, Factory.NATURE, pool)
	for pool: String in Context.POOLS:
		if Nature.mesh_for(pool) == null:
			_add(result, LANDSCAPE, pool, Factory.POOL, pool)
	for method: String in NATURAL_PROPS:
		_add(result, WORLD, method, Factory.NATURAL_PROP, method)
	for method: String in PROPS:
		_add(result, WORLD, method, Factory.PROP, method)
	var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/visual_models/catalog.json"))
	for row: Dictionary in catalog.models:
		var name: String = row.name
		if used_source.has(name) or name.begins_with("world_") or not (name.begins_with("fx_") or name.begins_with("projectile_") or name.begins_with("wreck_")):
			continue
		_add(result, FX, name, Factory.SOURCE, name, "Static mesh preview")
	Source._prepare("world_primitives")
	for part: Dictionary in Source._templates.world_primitives:
		_add(result, PARTS, part.name, Factory.PRIMITIVE, part.name)
	Source._prepare("boss")
	for part: Dictionary in Source._templates.boss:
		if str(part.name).begins_with("Component_"):
			_add(result, PARTS, part.name, Factory.COMPONENT, part.name)
	return result

static func _add(rows: Array[Dictionary], section: String, title: String, factory: Factory, key: String = "", note: String = "") -> void:
	rows.append({"id": section + "/" + title, "section": section, "title": title, "factory": factory, "key": key, "note": note})

static func build(entry: Dictionary) -> Node3D:
	match int(entry.factory):
		Factory.SOURCE: return Source.instantiate(entry.key)
		Factory.PLAYER: return Rig.build_player()
		Factory.WAGON: return Rig.build_trailer(entry.key)
		Factory.EQUIPMENT: return Equipment.build(entry.key)
		Factory.CREW_STANDING:
			var person := Source.instantiate("rifleman")
			for part: Node3D in person.get_children():
				if part.get_meta("source_part").get("rig", {}).get("role", "") == "weapon":
					part.visible = entry.key in ["shooter", "anti_tank", "anti_air"]
			Appearance.apply(person, entry.key)
			return person
		Factory.CREW_SEATED:
			var person := Seats.build()
			Seats.apply_role(person, entry.key, "ally")
			return person
		Factory.NATURE:
			var node := MeshInstance3D.new()
			node.mesh = Nature.mesh_for(entry.key)
			return node
		Factory.PROP: return _prop(entry.key)
		Factory.NATURAL_PROP: return _prop(entry.key, true)
		Factory.POOL:
			var node := MeshInstance3D.new()
			node.mesh = _pool_mesh(entry.key)
			return node
		Factory.PRIMITIVE, Factory.COMPONENT:
			var source_name := "boss" if int(entry.factory) == Factory.COMPONENT else "world_primitives"
			Source._prepare(source_name)
			for part: Dictionary in Source._templates[source_name]:
				if part.name == entry.key:
					var node := MeshInstance3D.new()
					node.mesh = part.mesh
					node.transform = part.transform
					return node
		Factory.LOOT: return Loot.build(entry.key)
	return Node3D.new()

static func _prop(method: String, natural: bool = false) -> Node3D:
	var context := Context.new()
	context.setup(72841)
	var nature := NaturalProps.new()
	nature.setup(context)
	var authored := Authored.new()
	authored.setup(context, nature)
	(nature if natural else authored).call(method, 0.0, 0.0)
	var root := Node3D.new()
	for group: Node3D in context.groups:
		root.add_child(group)
	# Some factories emit shared world instances in addition to authored groups.
	var replacements := TreeReplacements.prepare(context)
	for pool: String in replacements.instances:
		var transforms: Array = replacements.instances[pool].filter(func(pose: Transform3D) -> bool: return not is_zero_approx(pose.basis.determinant()))
		if transforms.is_empty():
			continue
		var mesh: Mesh = Nature.mesh_for(pool)
		if mesh == null:
			mesh = _pool_mesh(pool)
		if mesh == null:
			continue
		var node := MultiMeshInstance3D.new()
		node.multimesh = MultiMesh.new()
		node.multimesh.transform_format = MultiMesh.TRANSFORM_3D
		node.multimesh.mesh = mesh
		node.multimesh.instance_count = transforms.size()
		for index in transforms.size():
			node.multimesh.set_instance_transform(index, transforms[index])
		root.add_child(node)
	return root

static func _pool_mesh(pool: String) -> Mesh:
	Source._prepare("world_72841")
	return Source._templates.world_72841[int(Context.POOLS[pool][0])].mesh

static func bounds(node: Node3D, transform := Transform3D.IDENTITY) -> AABB:
	transform *= node.transform
	var result := AABB()
	if node is MeshInstance3D and node.mesh != null:
		result = transform * node.mesh.get_aabb()
	elif node is MultiMeshInstance3D and node.multimesh != null:
		for index in node.multimesh.instance_count:
			var instance_bounds: AABB = transform * node.multimesh.get_instance_transform(index) * node.multimesh.mesh.get_aabb()
			result = instance_bounds if index == 0 else result.merge(instance_bounds)
	for child: Node in node.get_children():
		if child is Node3D:
			var child_bounds := bounds(child, transform)
			if child_bounds.size.length_squared() > 0.0:
				result = child_bounds if result.size.length_squared() == 0.0 else result.merge(child_bounds)
	return result
