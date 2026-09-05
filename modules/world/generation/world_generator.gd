extends RefCounted
const Context = preload("res://modules/world/generation/generation_context.gd")
const Natural = preload("res://modules/world/generation/natural_props.gd")
const Rocks = preload("res://modules/world/generation/rock_formations.gd")
const Features = preload("res://modules/world/generation/battlefield_features.gd")
const Scatter = preload("res://modules/world/generation/scatter_generator.gd")

static func generate(seed_value: int, authored: RefCounted) -> RefCounted:
	var context := Context.new()
	context.setup(seed_value)
	var natural := Natural.new()
	natural.setup(context)
	authored.setup(context, natural)
	var features := Features.new()
	features.setup(context, natural, authored)
	var rocks := Rocks.new()
	rocks.setup(context)
	for village: Dictionary in context.layout.villages:
		authored.village(village.id, village.x, village.z, village.count)
	context.rendered_features = {"forests": 0, "ruinedVillages": 0, "trenches": 0, "rockFormations": 0, "craters": 0}
	for forest: Dictionary in context.layout.forests:
		context.rendered_features.forests += int(features.forest(forest) > 0)
	for ruins: Dictionary in context.layout.ruinedVillages:
		context.rendered_features.ruinedVillages += int(features.ruined_village(ruins) > 0)
	for trench: Dictionary in context.layout.trenches:
		context.rendered_features.trenches += int(features.trench(trench) > 0)
	for formation: Dictionary in context.layout.rockFormations:
		context.rendered_features.rockFormations += int(rocks.create(formation) > 0)
	for crater: Dictionary in context.layout.craters:
		context.rendered_features.craters += int(features.crater(crater))
	var scatter := Scatter.new()
	scatter.setup(context, natural, authored)
	scatter.biomes()
	scatter.roadsides()
	scatter.start_area()
	scatter.ambient_tufts()
	scatter.village_details()
	scatter.monuments()
	scatter.outer_dressing()
	scatter.pebbles()
	context.terrain_details.groundCoverInstances = context.instances.grassTufts.size()
	context.terrain_details.extraDrawCalls = 0
	return context
