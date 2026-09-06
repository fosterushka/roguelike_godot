extends SceneTree

const People = preload("res://presentation/combat/military_people.gd")
const Source = preload("res://presentation/combat/source_model.gd")
const LIBRARY := "res://assets/actors/military_people.glb"
var checks := 0
var failures := 0

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	check(FileAccess.file_exists(LIBRARY), "Military people GLB is shipped")
	for kind in ["rifleman", "ak", "bazooka", "bomber"]:
		check(People.has_model(kind), kind + " is provided")
		var parts := People.templates(kind)
		check(parts.size() == 7, kind + " has seven articulated optimized parts")
		var roles := {}
		for part: Dictionary in parts:
			roles[part.rig.role] = int(roles.get(part.rig.role, 0)) + 1
			check(part.mesh != null and part.mesh.get_surface_count() > 0, kind + " part has authored mesh")
			var arrays: Array = part.mesh.surface_get_arrays(0)
			check(not (arrays[Mesh.ARRAY_NORMAL] as PackedVector3Array).is_empty(), kind + " part exports normals")
			check(part.cast_shadow and part.instances == null and part.bindings.is_empty(), kind + " keeps SourceModel provider contract")
		check(parts[2].mesh == parts[3].mesh and parts[4].mesh == parts[5].mesh, kind + " reuses left and right limb meshes")
		var material: Material = parts[0].mesh.surface_get_material(0)
		check((material as StandardMaterial3D).albedo_texture != null and not (material as StandardMaterial3D).vertex_color_use_as_albedo, kind + " binds the authored palette texture instead of vertex-color white")
		var shared_material := material != null
		for part: Dictionary in parts:
			shared_material = shared_material and part.mesh.surface_get_material(0) == material
		check(shared_material, kind + " uses the shared military palette material")
		check(roles.get("body", 0) == 1 and roles.get("head", 0) == 1 and roles.get("leg", 0) == 2 and roles.get("arm", 0) == 2 and roles.get("weapon", 0) == 1, kind + " keeps soldier animation rig roles")
		var model := Source.instantiate(kind)
		check(model.get_child_count() == 7, kind + " replaces the legacy JSON model through SourceModel")
		var leg := model.get_child(2) as GeometryInstance3D
		var rest := leg.transform
		Source.animate_instance(model, {"move_blend": 1.0, "phase": PI * 0.5, "animation_time": 0.4, "instance_index": 1, "attack_animation": 0.5})
		check(not leg.transform.is_equal_approx(rest), kind + " keeps walking and attack rig animation")
		var pool := Source.create_pool(kind, 2)
		root.add_child(pool.root)
		check(pool.batches.size() == 7 and pool.root.get_child_count() == 7 and int(pool.capacity) == 2, kind + " creates seven-part combat pool")
		Source.set_pool_instance(pool, 0, Transform3D(Basis.IDENTITY, Vector3(4, 0, -3)), {"move_blend": 1.0, "phase": 1.0})
		Source.hide_pool_instance(pool, 0)
		check(pool.batches[0].mesh.instance_count == 2, kind + " accepts animated placement and release in combat pool")
		model.free()
		pool.root.free()
	check(not People.has_model("raider") and People.templates("raider").is_empty(), "Vehicle raider stays outside humanoid provider")
	print("Military people tests: %d/%d" % [checks - failures, checks])
	quit(1 if failures else 0)

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(label)
