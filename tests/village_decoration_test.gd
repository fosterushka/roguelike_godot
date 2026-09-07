extends SceneTree

const Context = preload("res://modules/world/generation/generation_context.gd")
const Authored = preload("res://modules/world/generation/authored_props.gd")
const Natural = preload("res://modules/world/generation/natural_props.gd")
const Generator = preload("res://modules/world/generation/world_generator.gd")
const Source = preload("res://presentation/combat/source_model.gd")
const Decor = preload("res://presentation/world/world_decor_filter.gd")
const Model = preload("res://modules/combat/combat_model.gd")
var checks := 0
var failures := 0

func _initialize() -> void:
	var fixtures: Array = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/authored_props.json"))
	for fixture: Dictionary in fixtures:
		if fixture.name != "critter":
			continue
		var context := Context.new()
		context.setup(int(fixture.seed))
		var natural := Natural.new()
		natural.setup(context)
		var authored := Authored.new()
		authored.setup(context, natural)
		authored.callv("critter", fixture.args)
		_check(not context.groups.is_empty() and context.groups.size() == context.ambient_critters.size() and context.ambient_critters.all(func(critter: Dictionary) -> bool: return critter.kind == "grazer"), "Sheep flocks replace retired decorative humans")
		for group: Node3D in context.groups:
			group.free()
		_check(context.random.state == int(fixture.state), "Retired figure consumes exactly the historical RNG draws")
	for seed_value in [72841, 0, 991827]:
		var context := Generator.generate(seed_value, Authored.new())
		_check(not context.ambient_critters.is_empty() and context.ambient_critters.all(func(critter: Dictionary) -> bool: return str(critter.id).begins_with("grazer-")), "Generated seed %d retains animals and contains no village or ruined-village human" % seed_value)
		_check(context.villages.all(func(village: Dictionary) -> bool: return not village.houses.is_empty()), "Village houses remain intact for seed %d" % seed_value)
		for group: Node3D in context.groups:
			group.free()
	var reference := Source.instantiate("world_72841")
	var layout: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/visual_models/world_layout.json"))
	_check(Decor.hide_reference_figures(reference) == 640, "Reference filter removes all eight parts of each of the 80 decorative humans")
	for prop: Dictionary in layout.props:
		for index in prop.get("meshes", []):
			_check(reference.get_child(int(index)).visible, "Reference filter leaves registered prop %s visible" % prop.id)
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/visual_models/world_72841.json"))
	var heads := 0
	var sheep := 0
	for index in data.meshes.size():
		var name_value: String = data.meshes[index].material.name
		if name_value == "skin":
			heads += 1
			_check(not reference.get_child(index).visible, "No reference human head remains visible")
		elif name_value == "sheep":
			sheep += 1
			_check(reference.get_child(index).visible, "Reference animal remains visible")
	_check(heads == 80 and sheep == 14, "Reference check covers all figures and grazing animals")
	reference.free()
	var model := Model.new()
	model.running = true
	for kind in ["rifleman", "ak", "bazooka", "bomber"]:
		var enemy: Dictionary = model.spawn_enemy(kind, Vector3(30, 0, 30))
		_check(not enemy.is_empty() and enemy.model == kind and not enemy.dead, "Actual hostile %s remains spawnable" % kind)
	print("Village decoration: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

func _check(value: bool, description: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(description)
