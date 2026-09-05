extends Node3D

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


func _ready() -> void:
	_create_lighting()
	source_world = SourceModel.instantiate("world_72841")
	add_child(source_world)
	world_layout = JSON.parse_string(FileAccess.get_file_as_string("res://data/visual_models/world_layout.json"))
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

func _bind_layout_collisions() -> void:
	for obstacle in world_layout.rockObstacles:
		_add_collision(Vector3(obstacle.x, 0, obstacle.z), float(obstacle.radius), 5.0)
	for prop in world_layout.props:
		_prop_records[str(prop.id)] = prop
		if str(prop.kind) in ["building", "monument", "well", "windmill", "ruin", "wreck"]:
			_prop_colliders[str(prop.id)] = _add_collision(Vector3(prop.position.x, 0, prop.position.z), float(prop.radius), 3.0)


func _create_ground() -> void:
	var ground := get_node_or_null("OriginalTerrainSurface") as MeshInstance3D
	if ground == null:
		ground = MeshInstance3D.new()
		ground.name = "OriginalTerrainSurface"
		var material := ShaderMaterial.new()
		material.shader = TERRAIN_SHADER
		ground.material_override = material
		add_child(ground)
	ground.mesh = TerrainSurface.create_mesh()
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
	environment.background_color = Color("8fa08f")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.ambient_light_energy = 2.25 / PI
	var sky_material := ShaderMaterial.new()
	sky_material.shader = preload("res://presentation/world/hemisphere_sky.gdshader")
	var sky := Sky.new()
	sky.sky_material = sky_material
	sky.process_mode = Sky.PROCESS_MODE_QUALITY
	environment.sky = sky
	environment.tonemap_mode = Environment.TONE_MAPPER_ACES
	environment.fog_enabled = true
	environment.fog_light_color = Color("8f9a97")
	environment.fog_density = 0.0052 * 0.0052 * 65.0
	var world_environment := WorldEnvironment.new()
	world_environment.environment = environment
	add_child(world_environment)
	var sun := DirectionalLight3D.new()
	sun.name = "WastelandSun"
	sun.rotation = Basis.looking_at(Vector3(45, -70, -25), Vector3.UP).get_euler()
	sun.light_color = Color("f2dfbe")
	sun.light_energy = 3.0 / PI
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 160
	add_child(sun)
	var rim := DirectionalLight3D.new()
	rim.name = "WastelandRim"
	rim.rotation = Basis.looking_at(Vector3(-38, -24, 50), Vector3.UP).get_euler()
	rim.light_color = Color("86b9d8")
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
		var transform := Transform3D(Basis.from_scale(Vector3.ZERO), Vector3.ZERO) if destroyed else SourceModel._transform(part.matrix)
		visual.multimesh.set_instance_transform(int(part.instance), transform)
	for index in prop.get("meshes", []):
		source_world.get_child(int(index)).visible = not destroyed
	if _prop_colliders.has(id):
		var collider: StaticBody3D = _prop_colliders[id]
		collider.collision_layer = 0 if destroyed else 1
	return true


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
