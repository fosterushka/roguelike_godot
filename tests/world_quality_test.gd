extends SceneTree

const Quality = preload("res://presentation/world/world_quality_models.gd")
const NaturalMeshes = preload("res://presentation/world/natural_meshes.gd")
const Context = preload("res://modules/world/generation/generation_context.gd")
const Natural = preload("res://modules/world/generation/natural_props.gd")
const Authored = preload("res://modules/world/generation/authored_props.gd")

var checks := 0
var failures := 0

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	check(ResourceLoader.exists("res://assets/environment/world_quality.glb"), "World quality GLB exists")
	for model: String in Quality.MODELS:
		var mesh := Quality.mesh_for(model)
		check(Quality.has_model(model) and mesh != null and mesh.get_surface_count() == 1, model + " is one cached authored mesh")
		check(mesh == Quality.mesh_for(model), model + " cache is shared")
	for pool: String in ["barrelInstances", "crateInstances", "tankInstances", "rockMass0", "rockMass1", "rockMass2", "rockMass3", "rockMass4", "rockMass5", "rockInstances", "stoneInstances", "fencePosts", "fenceRails", "deadTrees"]:
		check(NaturalMeshes.mesh_for(pool) == Quality.mesh_for(pool), pool + " uses the Blender quality mesh")
	var source = preload("res://presentation/combat/source_model.gd")
	source._prepare("world_72841")
	for pool: String in ["barrelInstances", "crateInstances", "tankInstances", "fencePosts", "fenceRails", "ironStructure", "metalStructure", "woodStructure", "redStructure", "earthStructure", "ruinStructure", "scarStructure", "cliffFaces", "cliffStrata"]:
		var original: AABB = source._templates.world_72841[Context.POOLS[pool][0]].mesh.get_aabb()
		var authored: AABB = Quality.mesh_for(pool).get_aabb()
		check(original.position.distance_to(authored.position) < 0.001 and original.size.distance_to(authored.size) < 0.001, pool + " preserves pooled placement and collision footprint")
	for index in 6:
		var rock := Quality.mesh_for("rockMass%d" % index)
		var inside := true
		for vertex: Vector3 in rock.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
			inside = inside and Vector2(vertex.x, vertex.z).length() <= 1.001 and vertex.y >= -0.001 and vertex.y <= 1.001
		check(inside, "Authored rock fits its circular collision radius and ground height")
	var context := Context.new()
	context.setup(72841)
	var natural := Natural.new()
	natural.setup(context)
	var authored := Authored.new()
	authored.setup(context, natural)
	authored.utility_pole(4, 7, 1, 0.4)
	authored.wreck(8, 7)
	authored.well(12, 7)
	authored.market_stall(16, 7)
	authored.grazer(20, 7)
	var home := authored.house(24, 7)
	for pair: Array in [[context.props[0].groups[0], "utility_pole"], [context.props[1].groups[0], "wreck"], [context.props[2].groups[0], "well"], [context.props[3].groups[0], "market_stall"], [context.ambient_critters[0].group, "grazer"], [home, "house"]]:
		check(_has_mesh(pair[0], pair[1]), pair[1] + " keeps its authored replacement")
	check(context.props.map(func(prop: Dictionary) -> String: return str(prop.kind)) == ["streetlight", "wreck", "well", "stall"], "Replacement props keep registrations")
	authored.satellite_array(0, 24, 0.2)
	var dishes := context.groups.filter(func(group: Node) -> bool: return _has_mesh(group, "satellite_dish"))
	check(dishes.size() == 3, "Satellite array keeps three authored dishes")
	check(context.groups.any(func(group: Node) -> bool: return group.get_meta("military_detail", false) and _has_mesh(group, "detail_satellite")), "Satellite keeps quality detail root")
	authored.windmill(16, 24)
	var windmill: Node3D = context.groups[-1]
	check(_has_mesh(windmill, "windmill"), "Windmill uses authored stationary base")
	var blades := windmill.get_node_or_null("Blades") as Node3D
	check(blades != null and _has_mesh(blades, "windmill_blades") and context.ambient_animators[-1].object == blades, "Windmill keeps animated Blades root")
	for group: Node in context.groups:
		group.free()
	print("World quality: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

func _has_mesh(node: Node, model: String) -> bool:
	if node is MeshInstance3D and (node as MeshInstance3D).mesh == Quality.mesh_for(model):
		return true
	for child: Node in node.get_children():
		if _has_mesh(child, model):
			return true
	return false

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(label)
