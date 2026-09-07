extends SceneTree

const Models = preload("res://presentation/combat/military_field_props.gd")
const BaseVariants = preload("res://presentation/combat/base_variants.gd")
const Catalog = preload("res://modules/combat/enemy_catalog.gd")
const BaseDefenseRules = preload("res://modules/world/activities/base_defense_rules.gd")
const Source = preload("res://presentation/combat/source_model.gd")
const AnimationRules = preload("res://presentation/combat/source_animation.gd")
const Mines = preload("res://presentation/combat/mine_views.gd")
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
	for name: String in Models.MODELS:
		var parts := Models.templates(name)
		var triangles := 0
		check(not parts.is_empty(), name + " has authored geometry")
		for part: Dictionary in parts:
			triangles += part.mesh.get_faces().size() / 3
			check(AnimationRules.transform_for(part, {}).is_equal_approx(part.transform), name + " retains authored rest placement")
		check(triangles > 30 and triangles < 5000, name + " bounded low-poly geometry")
		var model := Source.instantiate(name)
		check(model.get_child_count() >= parts.size(), name + " routes to authored library")
		for index in parts.size():
			check(model.get_child(index).mesh == parts[index].mesh, name + " uses shared library mesh")
		model.free()
	var canonical_mine := Models.templates("mine_enemy")
	for alias: String in ["mine_friendly", "mine_unarmed"]:
		var state_mine := Models.templates(alias)
		check(state_mine.size() == canonical_mine.size(), alias + " keeps the canonical mine part layout")
		for index in canonical_mine.size():
			check(state_mine[index].mesh == canonical_mine[index].mesh, alias + " reuses the one physical mine mesh")
	for name: String in ["garrison_1", "garrison_2", "garrison_3"]:
		var names: Array[String] = []
		for part: Dictionary in Models.templates(name):
			names.append(str(part.name))
		var prefix: String = "Bunker" if name == "garrison_1" else "Barracks" if name == "garrison_2" else "Factory"
		check(names.any(func(part_name: String) -> bool: return part_name.begins_with(prefix)), name + " has its own readable silhouette module")
		var within_collider := true
		for part: Dictionary in BaseVariants.templates(name):
			for corner in 8:
				var point: Vector3 = part.transform * part.mesh.get_aabb().get_endpoint(corner)
				within_collider = within_collider and Vector2(point.x, point.z).length() <= float(Catalog.DEFINITIONS[name].radius) and point.y >= 0.0 and point.y <= float(Catalog.DEFINITIONS[name].height)
		check(within_collider, name + " silhouette fits its combat collider")
	var cart := Models.templates("heal_cart")
	var wheels := 0
	for part: Dictionary in cart:
		if not part.bindings.is_empty():
			wheels += 1
			var rotated := AnimationRules.transform_for(part, {"wheel_angle": 1.2})
			check(rotated.origin.is_equal_approx(part.transform.origin), "Cart wheels rotate about their own axle")
			check(not rotated.basis.is_equal_approx(part.transform.basis), "Cart wheel rotation is live")
	check(wheels == 4, "Cart has four independently animated wheels")
	for part: Dictionary in Models.templates("airdrop"):
		if part.name == "Canopy":
			var landed := AnimationRules.transform_for(part, {"binding_overrides": {"airdrop_canopyRig": {"position": Vector3(-2.6, 0.35, -1.5), "rotation": Vector3(0, 0, 1.08), "scale": Vector3(0.68, 0.16, 0.68)}}})
			check(landed.origin.is_equal_approx(Vector3(-2.6, 12.35, -1.5)), "Landed canopy preserves model origin above support animation anchor")
			check(landed.basis.y.length() < 0.17, "Landed canopy deflates")
	var mines := Mines.new()
	root.add_child(mines)
	check(mines.entries.size() == 36, "Mine pool is retained")
	var signal_mesh: MeshInstance3D = mines.entries[0].signal
	check(str(signal_mesh.name) == "MineSignal", "Mine pulse targets the indicator, not the body")
	check(signal_mesh.material_override.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA, "Mine indicator supports pulse opacity")
	mines.sync_state([{"position": Vector3.ZERO, "armed": true, "life": 10.0, "hack_progress": 1.5}])
	check(mines.entries[0].fill.visible and is_equal_approx(mines.entries[0].fill.scale.x, 0.5), "Authored mine retains hacking feedback")
	mines.free()
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/asset_manifest.json"))
	for path: String in ["res://assets/actors/military_field_props.glb", "res://assets/environment/military_environment.glb"]:
		check(path in manifest.resources, path + " participates in preloading")
	print("Military field props: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
