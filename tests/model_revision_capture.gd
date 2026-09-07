extends SceneTree

const Source = preload("res://presentation/combat/source_model.gd")
const Nature = preload("res://presentation/world/natural_meshes.gd")
const Context = preload("res://modules/world/generation/generation_context.gd")
const NaturalProps = preload("res://modules/world/generation/natural_props.gd")
const Authored = preload("res://modules/world/generation/authored_props.gd")
const Seats = preload("res://presentation/crew/crew_seats.gd")
const Crew = preload("res://modules/crew/crew_catalog.gd")
const WorldModels = preload("res://presentation/world/world_quality_models.gd")
const OUTPUT := "res://docs/validation/model-revision"
enum Factory { ENEMY, TREE, HOUSE, SEAT, WORLD }
const SUBJECTS := {
	"buggy": [Factory.ENEMY, "buggy"], "keep": [Factory.ENEMY, "raider"],
	"repair-crawler": [Factory.ENEMY, "repairCrawler"], "leviathan": [Factory.ENEMY, "boss"],
	"wreck-bike": [Factory.ENEMY, "wreck_bike"], "wreck-buggy": [Factory.ENEMY, "wreck_buggy"],
	"wreck-jammer": [Factory.ENEMY, "wreck_jammerTruck"], "wreck-crawler": [Factory.ENEMY, "wreck_repairCrawler"],
	"wreck-minelayer": [Factory.ENEMY, "wreck_minelayer"], "house": [Factory.HOUSE, "house"],
	"wreck-roadside": [Factory.WORLD, "wreck"],
	"spruce": [Factory.TREE, "spruceTrees"], "birch": [Factory.TREE, "birchTrees"],
	"mine": [Factory.ENEMY, "mine_enemy"], "civilian": [Factory.SEAT, "civilian"],
	"anti-tank": [Factory.SEAT, "anti_tank"], "fuel": [Factory.SEAT, "fuel"], "shooter": [Factory.SEAT, "shooter"],
}
const VIEWPORT := Vector2i(960, 720)
var stage: Node3D
var camera: Camera3D
var content: Node3D
var phase := "after"
var failures := 0

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if not args.is_empty(): phase = args[0]
	root.size = VIEWPORT
	root.content_scale_size = VIEWPORT
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT.path_join(phase)))
	stage = Node3D.new()
	root.add_child(stage)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("2f383e")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color("d5dde2")
	environment.environment.ambient_light_energy = 0.62
	stage.add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-42, -35, 0)
	sun.light_energy = 1.25
	sun.shadow_enabled = true
	stage.add_child(sun)
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2.ONE * 250
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("465052")
	material.roughness = 1
	plane.material = material
	ground.mesh = plane
	ground.position.y = -0.02
	stage.add_child(ground)
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	stage.add_child(camera)
	camera.current = true
	content = Node3D.new()
	stage.add_child(content)
	var metrics := {}
	var captured := 0
	var metrics_path := OUTPUT.path_join(phase).path_join("metrics.json")
	if args.size() > 1 and FileAccess.file_exists(metrics_path):
		metrics = JSON.parse_string(FileAccess.get_file_as_string(metrics_path))
	for title: String in SUBJECTS:
		if args.size() > 1 and title not in args.slice(1): continue
		var spec: Array = SUBJECTS[title]
		var model: Node3D
		match int(spec[0]):
			Factory.ENEMY: model = Source.instantiate(spec[1])
			Factory.WORLD: model = WorldModels.create(spec[1])
			Factory.TREE:
				model = MeshInstance3D.new()
				model.mesh = Nature.mesh_for(spec[1])
			Factory.HOUSE:
				var context := Context.new()
				context.setup(72841)
				var nature := NaturalProps.new()
				nature.setup(context)
				var authored := Authored.new()
				authored.setup(context, nature)
				model = authored.house(0, 0)
			Factory.SEAT:
				model = Seats.build()
				Seats.apply_role(model, spec[1], "ally")
		content.add_child(model)
		var bounds := _bounds(model)
		if bounds.size.length_squared() <= 0.00001 or _triangles(model) == 0:
			failures += 1
			push_error("Empty revision capture model: " + title)
		model.position -= Vector3(bounds.get_center().x, bounds.position.y, bounds.get_center().z)
		var center := Vector3.UP * bounds.size.y * 0.5
		var span := maxf(2.5, maxf(bounds.size.x, maxf(bounds.size.y, bounds.size.z)) * 1.45)
		camera.size = span
		for side in ["front", "rear"]:
			camera.position = center + Vector3(0.7 if side == "front" else -0.7, 0.48, 1 if side == "front" else -1) * span
			camera.look_at(center)
			for frame in 5: await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(OUTPUT.path_join(phase).path_join(title + "-" + side + ".png"))
		metrics[title] = {"size": [bounds.size.x,bounds.size.y,bounds.size.z], "triangles": _triangles(model)}
		captured += 1
		content.remove_child(model)
		model.queue_free()
	var file := FileAccess.open(OUTPUT.path_join(phase).path_join("metrics.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(metrics,"\t"));file.close()
	stage.queue_free()
	await process_frame
	await process_frame
	print("MODEL_REVISION_CAPTURE: ", phase, " ", captured, " models, ", failures, " failures")
	quit(0 if failures == 0 else 1)

func _bounds(node: Node3D, pose := Transform3D.IDENTITY) -> AABB:
	pose *= node.transform
	var result := AABB()
	if node is MeshInstance3D and node.mesh != null and node.visible:
		result = pose * node.mesh.get_aabb()
	for child: Node in node.get_children():
		if child is Node3D:
			var next := _bounds(child, pose)
			if next.size.length_squared() > 0:
				result = next if result.size.length_squared() == 0 else result.merge(next)
	return result

func _triangles(node: Node) -> int:
	var count := 0
	if node is MeshInstance3D and node.mesh != null:
		count += node.mesh.get_faces().size() / 3
	for child: Node in node.get_children(): count += _triangles(child)
	return count
