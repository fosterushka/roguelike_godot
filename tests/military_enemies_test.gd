extends SceneTree

const Enemies = preload("res://presentation/combat/military_enemies.gd")
const SourceAnimation = preload("res://presentation/combat/source_animation.gd")
const SourceModel = preload("res://presentation/combat/source_model.gd")
const REVISED_TRIANGLE_BUDGET := 2400
const PATH := "res://assets/actors/military_enemies.glb"
const MODELS := ["bike", "buggy", "drone", "kamikaze", "raider", "jammerTruck", "repairCrawler", "minelayer", "boss", "wreck_bike", "wreck_buggy", "wreck_jammerTruck", "wreck_repairCrawler", "wreck_minelayer"]
const MIN_WIDTH := {"bike": 0.8, "buggy": 2.2, "drone": 2.2, "kamikaze": 2.2, "raider": 5.0, "jammerTruck": 2.5, "repairCrawler": 6.0, "minelayer": 2.5, "boss": 10.0}
const BossGeometry = preload("res://modules/combat/leviathan_geometry.gd")
const Combat = preload("res://modules/combat/combat_model.gd")
const EnemyVisualAnimation = preload("res://presentation/combat/enemy_animation.gd")
var checks := 0
var failures := 0

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	check(FileAccess.file_exists(PATH), "Military enemy GLB is shipped")
	var scene := load(PATH)
	check(scene is PackedScene, "Military enemy GLB imports as a scene")
	for model_name in MODELS:
		check(Enemies.has_model(model_name), model_name + " is owned by the military provider")
		var parts := Enemies.templates(model_name)
		check(not parts.is_empty(), model_name + " contains authored mesh parts")
		var triangles := 0
		var bounds := AABB()
		var roles: Array[String] = []
		var body_material_ok := false
		var body_normals_ok := false
		for part: Dictionary in parts:
			for surface in part.mesh.get_surface_count():
				var arrays: Array = part.mesh.surface_get_arrays(surface)
				var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
				var palette_cells_valid: bool = uvs.size() == arrays[Mesh.ARRAY_VERTEX].size()
				for uv: Vector2 in uvs:
					palette_cells_valid = palette_cells_valid and uv.x > 0.0 and uv.x < 1.0 and uv.y > 0.0 and uv.y < 1.0
				check(palette_cells_valid, model_name + " retains palette UVs when primitive meshes are merged")
			triangles += part.mesh.get_faces().size() / 3
			bounds = bounds.merge(_transformed_bounds(part.mesh.get_aabb(), part.transform))
			for binding: Dictionary in part.bindings:
				roles.append(binding.role)
				if binding.role == "wheel" or binding.role == "rotor":
					var moved := SourceAnimation.transform_for(part, {"wheel_angle": 1.0, "rotor_angle": 1.0})
					check(not moved.is_equal_approx(part.transform) and moved.origin.distance_to(part.transform.origin) < 0.001, model_name + " animated " + binding.role + " spins around its authored pivot")
			if str(part.name).begins_with("Body"):
				var material := part.mesh.surface_get_material(0) as StandardMaterial3D
				body_material_ok = material != null and material.albedo_texture != null
				body_normals_ok = _outward_winding(part.mesh)
		print("ACTOR_BUDGET ", model_name, " triangles=", triangles, " parts=", parts.size())
		check(triangles > (15 if model_name.begins_with("wreck_") else 40) and triangles < (Enemies.BOSS_TRIANGLE_BUDGET if model_name == "boss" else Enemies.TRIANGLE_BUDGET), model_name + " uses real optimized geometry")
		check(bounds.size.length() > 0.45 and (model_name in ["drone", "kamikaze"] or absf(bounds.position.y) < 0.15), model_name + " has grounded mesh contacts")
		if MIN_WIDTH.has(model_name):
			check(bounds.size.x >= float(MIN_WIDTH[model_name]), model_name + " silhouette matches combat scale")
		check(parts.size() <= (6 if model_name == "boss" else 7 if not model_name.begins_with("wreck_") else 2), model_name + " batches static palette geometry into one body mesh")
		check(body_material_ok, model_name + " body uses the shared palette texture")
		check(body_normals_ok, model_name + " body has consistent authored face normals")
		if model_name in ["bike", "buggy", "jammerTruck", "minelayer", "raider"]:
			check(roles.count("wheel") >= 2, model_name + " retains wheel animation bindings")
		if model_name in ["drone", "kamikaze"]:
			check(roles.count("rotor") == 4, model_name + " keeps four animated rotors")
		var runtime := SourceModel.instantiate(model_name)
		check(runtime.get_child_count() == parts.size(), model_name + " is served through SourceModel without legacy JSON")
		runtime.free()
	# Both selectable variants must preserve their animation contracts and budgets.
	var styles: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/enemy_vehicle_styles.json"))
	for model_name: String in styles.models:
		for variant: String in styles.variants:
			var parts := Enemies.templates(model_name, variant, "olive")
			var triangles := 0
			var roles := []
			for part: Dictionary in parts:
				triangles += part.mesh.get_faces().size() / 3
				for binding: Dictionary in part.bindings:
					roles.append(binding.role)
					if binding.role == "wheel":
						check(_wheel_caps_outward(part.mesh), model_name + variant + " flat wheel caps face outside")
			check(not parts.is_empty() and triangles < (Enemies.BOSS_TRIANGLE_BUDGET if model_name == "boss" else REVISED_TRIANGLE_BUDGET), model_name + variant + " imports inside triangle budget")
			check(parts.size() <= (6 if model_name == "boss" else 7), model_name + variant + " keeps batched static geometry")
			if model_name in ["buggy", "raider", "jammerTruck", "minelayer"]:
				check(roles.count("wheel") == 4, model_name + variant + " retains four wheel pivots")
			if model_name == "boss":
				check(roles.count("boss_component") == 5, variant + " retains all five boss components")
	var olive := Enemies.material_for_preset("olive")
	var before := olive.albedo_texture.get_image().get_data()
	var red := Enemies.material_for_preset("oxide")
	check(olive != red and olive == Enemies.material_for_preset("olive"), "Presets cache separate immutable materials")
	var a := olive.albedo_texture.get_image()
	var b := red.albedo_texture.get_image()
	check(a.get_data() == before, "Selecting another preset never mutates the first palette")
	for y in a.get_height():
		for x in a.get_width():
			check((a.get_pixel(x,y) != b.get_pixel(x,y)) == (y == 3 and x < 3), "Only paint, light and shadow atlas cells change")
	var first := SourceModel.instantiate("buggy")
	var second := SourceModel.instantiate("buggy")
	Enemies.apply_preset(first, "slate")
	check(first.get_child(0).material_override == Enemies.material_for_preset("slate") and second.get_child(0).material_override == null, "Instance recoloring leaves other vehicles unchanged")
	first.free()
	second.free()
	var boss_components := {}
	for part: Dictionary in Enemies.templates("boss"):
		if part.bindings.size() > 0 and part.bindings[0].role == "boss_component":
			boss_components[part.bindings[0].kind] = part.transform.origin
	check(boss_components.size() == BossGeometry.DEFINITION.components.size(), "Boss has removable component bindings")
	for kind: String in BossGeometry.DEFINITION.components:
		check(boss_components.get(kind, Vector3.INF).distance_to(BossGeometry.anchor(kind)) < 0.01, "Boss " + kind + " mesh aligns with combat component anchor")
	var combat := Combat.new()
	var boss: Dictionary = combat.spawn_enemy("leviathan", Vector3.ZERO)
	for phase in 3:
		boss.phase = phase
		combat.Leviathan.sync(boss)
		var presentation: Dictionary = EnemyVisualAnimation.advance(boss, {}, 0.0, 0.0)
		check(presentation.pose.components.values().all(func(visible): return visible), "Intact components remain visible in phase " + str(phase))
		for component: Dictionary in boss.components:
			check(component.targetable == (component.phase == phase), "Visibility does not unlock protected boss components")
	for variant: String in styles.variants:
		var bounds := AABB()
		for part: Dictionary in Enemies.templates("boss", variant):
			bounds = bounds.merge(part.transform * part.mesh.get_aabb())
			if part.bindings.is_empty(): continue
			var kind: String = part.bindings[0].kind
			var local_anchor: Vector3 = part.transform.affine_inverse() * BossGeometry.anchor(kind)
			check(part.mesh.get_aabb().grow(0.1).has_point(local_anchor), variant + " target anchor sits inside its visible component bounds: " + kind)
		check(bounds.size.y < bounds.size.x * 0.55, variant + " keeps the new broad, low siege silhouette")
	boss.components[0].dead = true
	var damaged: Dictionary = EnemyVisualAnimation.advance(boss, {}, 0.0, 0.0)
	check(not damaged.pose.components.missilePod and damaged.pose.components.leftDrive, "Only destroyed components disappear")
	print("Military enemies: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)

func _transformed_bounds(local_bounds: AABB, transform: Transform3D) -> AABB:
	var result := AABB(transform * local_bounds.position, Vector3.ZERO)
	for x in [0.0, local_bounds.size.x]:
		for y in [0.0, local_bounds.size.y]:
			for z in [0.0, local_bounds.size.z]:
				result = result.expand(transform * (local_bounds.position + Vector3(x, y, z)))
	return result

func _outward_winding(mesh: Mesh) -> bool:
	for surface in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(surface)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		for index in range(0, indices.size(), 3):
			var a := vertices[indices[index]]
			var b := vertices[indices[index + 1]]
			var c := vertices[indices[index + 2]]
			var geometric := (b - a).cross(c - a)
			var authored := normals[indices[index]] + normals[indices[index + 1]] + normals[indices[index + 2]]
			# glTF's handedness conversion may reverse winding in Godot, but not the
			# authored normal direction. Reject missing, zero, or unrelated normals.
			if absf(geometric.dot(authored)) <= 0.00001:
				return false
	return true

func _wheel_caps_outward(mesh: Mesh) -> bool:
	var cap_vertices := 0
	for surface in mesh.get_surface_count():
		var arrays: Array = mesh.surface_get_arrays(surface)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		for index in vertices.size():
			if absf(normals[index].x) > 0.99:
				cap_vertices += 1
				if normals[index].x * vertices[index].x <= 0.0:
					return false
	return cap_vertices > 0
