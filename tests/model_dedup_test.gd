extends SceneTree

const Props = preload("res://presentation/combat/military_field_props.gd")
const Seats = preload("res://presentation/crew/crew_seats.gd")
const CrewView = preload("res://presentation/crew/crew_view.gd")
const Crew = preload("res://modules/crew/crew_catalog.gd")
const Gallery = preload("res://presentation/debug/gallery_catalog.gd")
const Trees = preload("res://presentation/world/tree_meshes.gd")
const EnvironmentLibrary = preload("res://presentation/world/environment_library.gd")
const Equipment = preload("res://presentation/vehicles/equipment_model.gd")
const Loot = preload("res://presentation/ui/item_loot_models.gd")

var checks := 0
var failures := 0

func _init() -> void:
	_run.call_deferred()

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(label)

func _run() -> void:
	_test_mines()
	_test_seating()
	_test_gallery()
	_test_tree_alias()
	_test_gear_alias()
	_test_removed_data()
	await process_frame
	print("Model dedup tests: %d/%d" % [checks - failures, checks])
	quit(0 if failures == 0 else 1)

func _test_mines() -> void:
	var library := Props.LIBRARY.instantiate()
	check(library.get_node_or_null("FIELD_mine") != null, "Field-prop GLB contains the canonical mine root")
	for old_root: String in ["FIELD_mine_enemy", "FIELD_mine_friendly", "FIELD_mine_unarmed", "FIELD_airdrop", "FIELD_garrison_1", "FIELD_garrison_2"]:
		check(library.get_node_or_null(old_root) == null, old_root + " obsolete GLB root removed")
	library.free()
	var canonical := Props.templates("mine_enemy")
	for alias: String in ["mine_friendly", "mine_unarmed"]:
		var state := Props.templates(alias)
		check(state.size() == canonical.size(), alias + " keeps the mine part layout")
		for index in canonical.size():
			check(state[index].mesh == canonical[index].mesh, alias + " shares canonical mine mesh " + str(index))

func _test_seating() -> void:
	var pickup := Node3D.new()
	pickup.name = "Pickup"
	root.add_child(pickup)
	var wagon := Node3D.new()
	wagon.name = "Wagon"
	wagon.position = Vector3(8, 0, 0)
	root.add_child(wagon)
	var view := CrewView.new()
	view.set_carrier_visuals({"crawler": pickup, "wagon-1": wagon})
	root.add_child(view)
	var people := [
		{"id": "pickup-crew", "role": "civilian", "position": Vector3.ZERO, "boarded": true, "carrier_id": "crawler", "seat": 0},
		{"id": "wagon-crew", "role": "civilian", "position": Vector3.ZERO, "boarded": true, "carrier_id": "wagon-1", "seat": 1},
	]
	view.update_people(people, 0.0)
	check(view.views[0].root.global_position.is_equal_approx(pickup.to_global(Seats.anchor("crawler", 0))), "Pickup seated crew uses carrier anchor")
	check(view.views[1].root.global_position.is_equal_approx(wagon.to_global(Seats.anchor("wagon-1", 1))), "Wagon seated crew uses carrier anchor")
	var first: Node3D = view.views[0].seated
	var second: Node3D = view.views[1].seated
	check(first.get_node_or_null("PickupBench") == null and second.get_node_or_null("PickupBench") == null, "Crew bodies do not own pickup furniture")
	check((first.get_node("Torso") as MeshInstance3D).mesh == (second.get_node("Torso") as MeshInstance3D).mesh, "Seated crew roles share one imported body mesh")
	check(pickup.get_node_or_null("PickupBench") != null and wagon.get_node_or_null("PickupBench") == null, "Only pickup mounts its bench")
	var bench_count := view._pickup_benches.size()
	view.update_people(people, 0.0)
	check(view._pickup_benches.size() == bench_count and pickup.get_child_count() == 1, "Repeated crew sync does not duplicate carrier benches")
	var replacement := Node3D.new()
	replacement.name = "ReplacementPickup"
	root.add_child(replacement)
	pickup.free()
	view.set_carrier_visuals({"crawler": replacement, "wagon-1": wagon})
	check(view._pickup_benches.is_empty(), "Replacing a carrier clears stale bench cache")
	view.update_people(people, 0.0)
	check(view._pickup_benches.size() == 1 and replacement.get_node_or_null("PickupBench") != null, "Replacement carrier gets one new bench")
	view.free()
	check(replacement.get_node_or_null("PickupBench") == null, "Freeing CrewView removes its carrier bench")
	var next_view := CrewView.new()
	next_view.set_carrier_visuals({"crawler": replacement, "wagon-1": wagon})
	root.add_child(next_view)
	next_view.update_people(people, 0.0)
	check(replacement.get_child_count() == 1, "Replacement CrewView mounts one bench after prior view is freed")
	next_view.free()
	replacement.queue_free()
	wagon.queue_free()

func _test_gallery() -> void:
	var entries := Gallery.entries()
	for role: String in Crew.ROLES:
		var seated := entries.filter(func(entry: Dictionary) -> bool: return entry.title == role + " seated")
		check(seated.size() == 1, role + " has one seated gallery entry")
	check(not entries.any(func(entry: Dictionary) -> bool: return str(entry.section).contains("Archive")), "Gallery has no archive section")
	check(entries.filter(func(entry: Dictionary) -> bool: return entry.title == "mine").size() == 1, "Gallery has one mine preview for all gameplay states")
	check(not entries.any(func(entry: Dictionary) -> bool: return entry.title in ["mine_enemy", "mine_friendly", "mine_unarmed"]), "Gallery does not duplicate mine state previews")
	check(not entries.any(func(entry: Dictionary) -> bool: return entry.title == "ammo_feed"), "Gallery uses weapon_parts as the single ammo-feed preview")
	check(entries.filter(func(entry: Dictionary) -> bool: return entry.title == "weapon_parts").size() == 1, "Gallery has one weapon-parts preview")
	check(not entries.any(func(entry: Dictionary) -> bool: return entry.title == "armor_panels"), "Gallery uses armor as the single plate-set preview")

func _test_tree_alias() -> void:
	check(Trees.mesh_for("spruceTrees") == EnvironmentLibrary.mesh_for("spruceTrees"), "Spruce uses the shared environment mesh")
	var entries := Gallery.entries()
	check(entries.filter(func(entry: Dictionary) -> bool: return entry.title == "spruceTrees").size() == 1, "Gallery has one spruce mesh preview")
	check(not entries.any(func(entry: Dictionary) -> bool: return entry.title == "tree"), "Tree alias does not duplicate spruce preview")

func _test_gear_alias() -> void:
	Equipment.prepare()
	var library := Equipment.Library.instantiate()
	check(library.get_node_or_null("EQUIPMENT_armor") != null and library.get_node_or_null("EQUIPMENT_armor_panels") == null, "Equipment GLB exports one canonical armor root")
	library.free()
	var signatures := {}
	var model_signatures := {}
	for type: String in Equipment._parts:
		var model := Equipment.build(type)
		for mesh: Mesh in _meshes(model):
			var signature := str(mesh.get_faces()).sha256_text()
			if not signatures.has(signature):
				signatures[signature] = []
			if type not in signatures[signature]:
				signatures[signature].append(type)
		var model_signature := _model_signature(model)
		if not model_signatures.has(model_signature):
			model_signatures[model_signature] = []
		model_signatures[model_signature].append(type)
		model.free()
	for types: Array in signatures.values():
		if types.size() > 1:
			var names := PackedStringArray()
			for type: String in types:
				names.append(type)
			print("GEAR_GEOMETRY_ALIAS: ", ",".join(names))
	for types: Array in model_signatures.values():
		if types.size() > 1:
			var names := PackedStringArray()
			for type: String in types:
				names.append(type)
			print("GEAR_MODEL_ALIAS: ", ",".join(names))
	var loot := Loot.build("weapon_parts")
	var equipment := Equipment.build("ammo_feed")
	var loot_mesh := _first_mesh(loot)
	var equipment_mesh := _first_mesh(equipment)
	check(loot_mesh != null and loot_mesh == equipment_mesh, "weapon_parts reuses canonical ammo_feed mesh")
	var armor := Equipment.build("armor")
	var panels := Equipment.build("armor_panels")
	check(_first_mesh(armor) == _first_mesh(panels), "armor_panels reuses canonical armor mesh")
	loot.free()
	equipment.free()
	armor.free()
	panels.free()

func _test_removed_data() -> void:
	var manifest := FileAccess.get_file_as_string("res://data/asset_manifest.json")
	var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/visual_models/catalog.json"))
	for name: String in ["player", "walker_trailer", "evolution_2", "evolution_3", "evolution_4", "mine_enemy", "mine_friendly", "mine_unarmed", "weapon_akTurret", "weapon_armor", "weapon_assaultRifle", "weapon_bazooka", "weapon_bumper", "weapon_counterDroneJammer", "weapon_flamethrower", "weapon_grenadeLauncher", "weapon_mineHacker", "weapon_minigun", "weapon_missileRack", "weapon_radar", "weapon_railgun", "weapon_treasury", "weapon_workshop"]:
		var path := "res://data/visual_models/" + name + ".json"
		check(not FileAccess.file_exists(path), name + " archive JSON removed")
		check(not manifest.contains(path), name + " archive JSON removed from preload manifest")
		check(not catalog.models.any(func(row: Dictionary) -> bool: return str(row.name) == name), name + " archive JSON removed from model catalog")
	for path: String in ["res://assets/models/pickup.zip", "res://assets/models/reference_runtime/preview_source.png", "res://assets/models/reference_runtime/runtime_player.json", "res://assets/models/trees/spruce_tree.obj", "res://assets/models/trees/birch_tree.obj", "res://assets/models/trees/dead_tree.obj", "res://assets/models/equipment/armor_panels.obj", "res://assets/models/monuments/authored_monuments.blend", "res://assets/models/monuments/authored_monuments.glb", "res://assets/models/monuments/prop_house.obj", "res://assets/models/monuments/prop_wreck.obj"]:
		check(not FileAccess.file_exists(path), path + " obsolete archive removed")

func _first_mesh(root_node: Node) -> Mesh:
	if root_node is MeshInstance3D:
		return root_node.mesh
	for child: Node in root_node.get_children():
		var mesh := _first_mesh(child)
		if mesh != null:
			return mesh
	return null

func _meshes(root_node: Node) -> Array[Mesh]:
	var result: Array[Mesh] = []
	if root_node is MeshInstance3D:
		result.append(root_node.mesh)
	for child: Node in root_node.get_children():
		result.append_array(_meshes(child))
	return result

func _model_signature(root_node: Node) -> String:
	var parts := PackedStringArray()
	_collect_model_parts(root_node, Transform3D.IDENTITY, parts)
	parts.sort()
	return "|".join(parts).sha256_text()

func _collect_model_parts(node: Node, parent_transform: Transform3D, parts: PackedStringArray) -> void:
	var transform := parent_transform
	if node is Node3D:
		transform *= node.transform
	if node is MeshInstance3D:
		parts.append(str(node.mesh.get_faces()).sha256_text() + ":" + str(transform))
	for child: Node in node.get_children():
		_collect_model_parts(child, transform, parts)
