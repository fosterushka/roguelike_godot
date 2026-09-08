extends Node3D

const Biomes = preload("res://modules/world/biome_rules.gd")
const TerrainSurface = preload("res://modules/caravan/terrain_surface.gd")
const SourceModel = preload("res://presentation/combat/source_model.gd")
const GeneratedView = preload("res://presentation/world/generated_world_view.gd")
const RoadView = preload("res://presentation/world/road_view.gd")
const LayoutGenerator = preload("res://modules/world/generation/layout_generator.gd")
const TERRAIN_SHADER = preload("res://presentation/world/terrain.gdshader")
const ARENA_HALF_SIZE := 1248.0
const OUTER_WORLD_RADIUS := 1648.0
var world_layout: Dictionary = {}
var source_world: Node3D
var _prop_records: Dictionary = {}
var _prop_colliders: Dictionary = {}
var _collision_nodes: Array[StaticBody3D] = []
var _roads: Node3D
var _prop_offsets: Dictionary = {}


func _ready() -> void:
	_create_lighting()
	source_world = SourceModel.instantiate("world_72841")
	_replace_reference_meshes()
	add_child(source_world)
	preload("res://presentation/world/world_decor_filter.gd").hide_reference_figures(source_world)
	world_layout = JSON.parse_string(FileAccess.get_file_as_string("res://data/visual_models/world_layout.json"))
	preload("res://presentation/world/tree_replacements.gd").replace_reference(source_world, world_layout)
	_split_reference_batches()
	_roads = RoadView.new()
	_roads.name = "OriginalSoftEdgeRoads"
	add_child(_roads)
	var roads: Array = LayoutGenerator.generate(int(world_layout.seed)).roads
	TerrainSurface.configure(world_layout, roads)
	_create_ground()
	_roads.setup(roads)
	for index in world_layout.roads.size() + 1:
		source_world.get_child(index).visible = false
	_bind_layout_collisions()

func _split_reference_batches() -> void:
	var spatial = preload("res://presentation/world/spatial_batches.gd")
	var mapping := {}
	var pools: Dictionary = preload("res://modules/world/generation/generation_context.gd").POOLS
	var replaced_components := [pools.treeTrunks[0], pools.treeCrowns[0], pools.treeCrownsAlt[0], pools.treeBranches[0]]
	var tree_poses := {}
	for prop: Dictionary in world_layout.props:
		if prop.kind in ["tree", "deadTree"]:
			for part: Dictionary in prop.parts:
				if not tree_poses.has(int(part.mesh)):
					tree_poses[int(part.mesh)] = []
				var poses: Array = tree_poses[int(part.mesh)]
				poses.resize(maxi(poses.size(), int(part.instance) + 1))
				poses[int(part.instance)] = SourceModel._transform(part.matrix)
	var original_count := source_world.get_child_count()
	for index in original_count:
		var batch := source_world.get_child(index) as MultiMeshInstance3D
		# The replaced legacy tree components are already hidden.
		if batch == null or index <= world_layout.roads.size() or index in replaced_components:
			continue
		var poses: Array = tree_poses.get(index, [])
		if not tree_poses.has(index):
			for matrix: Array in batch.get_meta("source_part", {}).get("instances", []):
				poses.append(SourceModel._transform(matrix))
		if not poses.is_empty():
			mapping[index] = spatial.split(source_world, batch, poses)
	spatial.remap_props(world_layout.props, mapping)


func _replace_reference_meshes() -> void:
	# Keep indices/transforms: destruction records refer to these source batches.
	var context = preload("res://modules/world/generation/generation_context.gd")
	var meshes = preload("res://presentation/world/natural_meshes.gd")
	var replaced := {}
	for pool: String in context.POOLS:
		if pool in ["spruceTrees", "birchTrees", "deadTrees"] or pool.begins_with("rockMass"):
			continue
		var mesh: Mesh = meshes.mesh_for(pool)
		var index: int = context.POOLS[pool][0]
		if mesh != null and not replaced.has(index):
			var visual := source_world.get_child(index) as MultiMeshInstance3D
			if visual != null:
				visual.multimesh.mesh = mesh
				visual.material_override = null
				replaced[index] = true

func _bind_layout_collisions() -> void:
	for prop: Dictionary in world_layout.props:
		_prop_records[str(prop.id)] = prop
	for obstacle in world_layout.rockObstacles:
		if not _prop_records.has(str(obstacle.id)):
			_add_collision(Vector3(obstacle.x, 0, obstacle.z), float(obstacle.radius), 5.0)
	for prop: Dictionary in world_layout.props:
		if bool(prop.get("solid", str(prop.kind) in ["building", "monument", "well", "windmill", "ruin", "wreck"])):
			var collider := _add_collision(Vector3(prop.position.x, 0, prop.position.z), float(prop.radius), float(prop.get("height", 3.0)))
			collider.set_meta("destructible_prop_id", str(prop.id))
			_prop_colliders[str(prop.id)] = collider


func _create_ground() -> void:
	var ground := get_node_or_null("OriginalTerrainSurface") as MeshInstance3D
	if ground == null:
		ground = MeshInstance3D.new()
		ground.name = "OriginalTerrainSurface"
		var material := ShaderMaterial.new()
		material.shader = TERRAIN_SHADER
		material.set_shader_parameter("biome_border", Biomes.BORDER)
		material.set_shader_parameter("biome_blend", Biomes.BLEND_WIDTH)
		material.set_shader_parameter("biome_wave", Biomes.BORDER_WAVE)
		material.set_shader_parameter("biome_frequency", Biomes.BORDER_FREQUENCY)
		ground.material_override = material
		add_child(ground)
	var chunk_index := 0
	for row in range(0, TerrainSurface.CELLS, TerrainSurface.RENDER_CHUNK_CELLS):
		for column in range(0, TerrainSurface.CELLS, TerrainSurface.RENDER_CHUNK_CELLS):
			var chunk: MeshInstance3D
			if chunk_index < ground.get_child_count():
				chunk = ground.get_child(chunk_index)
			else:
				chunk = MeshInstance3D.new()
				chunk.name = "Terrain_%d_%d" % [column, row]
				chunk.material_override = ground.material_override
				ground.add_child(chunk)
			chunk.mesh = TerrainSurface.create_mesh(Rect2i(column, row, TerrainSurface.RENDER_CHUNK_CELLS, TerrainSurface.RENDER_CHUNK_CELLS))
			chunk_index += 1
	var body := get_node_or_null("TerrainCollision") as StaticBody3D
	if body == null:
		body = StaticBody3D.new()
		body.name = "TerrainCollision"
		body.collision_layer = 16
		var collision := CollisionShape3D.new()
		collision.name = "Heightfield"
		body.add_child(collision)
		add_child(body)
	var shape := HeightMapShape3D.new()
	shape.map_width = TerrainSurface.CELLS + 1
	shape.map_depth = TerrainSurface.CELLS + 1
	shape.map_data = TerrainSurface.heights
	body.get_node("Heightfield").shape = shape
	body.scale = Vector3(TerrainSurface.STEP, 1.0, TerrainSurface.STEP)


func _create_lighting() -> void:
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("b4c5b5")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.ambient_light_energy = 2.0 / PI
	var sky_material := ShaderMaterial.new()
	sky_material.shader = preload("res://presentation/world/hemisphere_sky.gdshader")
	var sky := Sky.new()
	sky.sky_material = sky_material
	sky.process_mode = Sky.PROCESS_MODE_QUALITY
	environment.sky = sky
	environment.tonemap_mode = Environment.TONE_MAPPER_ACES
	environment.fog_enabled = true
	environment.fog_light_color = Color("b4c5b5")
	environment.fog_density = 0.0052 * 0.0052 * 65.0
	var world_environment := WorldEnvironment.new()
	world_environment.environment = environment
	add_child(world_environment)
	var sun := DirectionalLight3D.new()
	sun.name = "WastelandSun"
	sun.rotation = Basis.looking_at(Vector3(45, -70, -25), Vector3.UP).get_euler()
	sun.light_color = Color("ffe2ab")
	sun.light_energy = 3.0 / PI
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 160
	add_child(sun)
	var rim := DirectionalLight3D.new()
	rim.name = "WastelandRim"
	rim.rotation = Basis.looking_at(Vector3(-38, -24, 50), Vector3.UP).get_euler()
	rim.light_color = Color("8eb6df")
	rim.light_energy = 0.52 / PI
	add_child(rim)


func _add_collision(point: Vector3, radius: float, height: float) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.position = point + Vector3(0, height * 0.5, 0)
	var collision := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = radius
	shape.height = height
	collision.shape = shape
	body.add_child(collision)
	add_child(body)
	_collision_nodes.append(body)
	return body


func set_prop_destroyed(id: String, destroyed: bool) -> bool:
	if not _prop_records.has(id):
		return false
	var prop: Dictionary = _prop_records[id]
	for node: Node3D in prop.get("visual_nodes", []):
		if is_instance_valid(node):
			node.visible = not destroyed
	for part in prop.get("parts", []):
		var visual := source_world.get_child(int(part.mesh)) as MultiMeshInstance3D
		if visual == null:
			continue
		var transform := SourceModel._transform(part.matrix)
		if destroyed:
			# Keep hidden instances inside their spatial batch instead of expanding to world zero.
			transform.basis = Basis.from_scale(Vector3.ZERO)
		if not destroyed:
			transform.origin += Vector3(_prop_offsets.get(id, Vector3.ZERO))
		visual.multimesh.set_instance_transform(int(part.instance), transform)
	for index in prop.get("meshes", []):
		source_world.get_child(int(index)).visible = not destroyed
	if _prop_colliders.has(id):
		var collider: StaticBody3D = _prop_colliders[id]
		collider.collision_layer = 0 if destroyed else 1
	return true

func set_prop_position(id: String, point: Vector3) -> void:
	if not _prop_records.has(id):
		return
	var prop: Dictionary = _prop_records[id]
	var origin := Vector3(prop.position.x, 0, prop.position.z)
	var offset := Vector3(point.x, 0, point.z) - origin
	offset.y = TerrainSurface.height_at(point.x, point.z) - TerrainSurface.height_at(origin.x, origin.z)
	var previous: Vector3 = _prop_offsets.get(id, Vector3.ZERO)
	_prop_offsets[id] = offset
	for node: Node3D in prop.get("visual_nodes", []):
		node.position += offset - previous
	for index in prop.get("meshes", []):
		source_world.get_child(int(index)).position += offset - previous
	if _prop_colliders.has(id):
		_prop_colliders[id].position += offset - previous
	set_prop_destroyed(id, false)

func clone_prop(id: String, reusable: Node3D = null) -> Node3D:
	if not _prop_records.has(id):
		return null
	var prop: Dictionary = _prop_records[id]
	var pivot := reusable if reusable != null else Node3D.new()
	var origin := Vector3(prop.position.x, 0, prop.position.z)
	var base := origin + Vector3(_prop_offsets.get(id, Vector3.ZERO))
	pivot.transform = Transform3D(Basis.IDENTITY, base)
	var pieces: Array[Dictionary] = []
	for part: Dictionary in prop.get("parts", []):
		var source := source_world.get_child(int(part.mesh)) as MultiMeshInstance3D
		if source == null:
			continue
		var pose := SourceModel._transform(part.matrix)
		pose.origin -= origin
		pieces.append({"mesh": source.multimesh.mesh, "transform": pose, "material": source.material_override})
	for source: Node3D in prop.get("visual_nodes", []):
		_clone_pieces(source, base, pieces)
	for index in prop.get("meshes", []):
		_clone_pieces(source_world.get_child(int(index)), base, pieces)
	while pivot.get_child_count() < pieces.size():
		pivot.add_child(MeshInstance3D.new())
	for index in pivot.get_child_count():
		var mesh: MeshInstance3D = pivot.get_child(index)
		mesh.visible = index < pieces.size()
		if mesh.visible:
			mesh.mesh = pieces[index].mesh
			mesh.material_override = pieces[index].material
			mesh.transform = pieces[index].transform
	pivot.visible = true
	return pivot

func _clone_pieces(node: Node3D, base: Vector3, pieces: Array[Dictionary]) -> void:
	if node is MeshInstance3D and node.mesh != null:
		var pose := node.global_transform
		pose.origin -= base
		pieces.append({"mesh": node.mesh, "transform": pose, "material": node.material_override})
	for child: Node in node.get_children():
		if child is Node3D:
			_clone_pieces(child, base, pieces)


func rebuild_from_context(context: RefCounted) -> bool:
	if not get_tree().paused:
		return false
	var next_world := GeneratedView.new()
	next_world.name = "GeneratedSourceWorld_%d" % context.layout.seed
	var next_layout := next_world.build(context)
	for body: StaticBody3D in _collision_nodes:
		body.free()
	_collision_nodes.clear()
	_prop_records.clear()
	_prop_colliders.clear()
	_prop_offsets.clear()
	source_world.free()
	source_world = next_world
	add_child(source_world)
	world_layout = next_layout
	TerrainSurface.configure(world_layout, context.layout.roads)
	_create_ground()
	_roads.setup(context.layout.roads)
	_bind_layout_collisions()
	return true

func set_game_time(elapsed: float) -> void:
	get_node("OriginalTerrainSurface").material_override.set_shader_parameter("uTime", elapsed)
