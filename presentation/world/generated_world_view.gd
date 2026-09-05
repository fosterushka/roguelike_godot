extends Node3D
const SourceModel = preload("res://presentation/combat/source_model.gd")
var context: RefCounted
var pool_indices: Dictionary = {}

func build(generated: RefCounted) -> Dictionary:
	context = generated
	SourceModel._prepare("world_72841")
	for pool: String in context.POOLS:
		var template: Dictionary = SourceModel._templates.world_72841[context.POOLS[pool][0]]
		var values: Array = context.instances[pool]
		var batch := MultiMeshInstance3D.new()
		batch.name = pool
		batch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var instances := MultiMesh.new()
		instances.transform_format = MultiMesh.TRANSFORM_3D
		instances.mesh = template.mesh
		instances.instance_count = values.size()
		for index in values.size():
			instances.set_instance_transform(index, values[index])
		batch.multimesh = instances
		pool_indices[pool] = get_child_count()
		add_child(batch)
	for group: Node3D in context.groups:
		add_child(group)
	var props: Array = []
	for source: Dictionary in context.props:
		var prop := source.duplicate()
		prop.parts = []
		prop.meshes = []
		prop.visual_nodes = source.get("groups", [])
		for part: Dictionary in source.parts:
			if part.instance < 0:
				continue
			prop.parts.append({"mesh": pool_indices[part.pool], "instance": part.instance, "matrix": matrix(part.transform)})
		props.append(prop)
	var roads: Array = []
	var routes: Array = []
	var anchors: Array = []
	for road: Dictionary in context.layout.roads:
		roads.append(road.points)
		var route_id := "route-" + str(road.id)
		routes.append({"id": route_id, "roadId": road.id, "sourceAnchorId": road.id + "-anchor-00", "destinationAnchorId": "%s-anchor-%02d" % [road.id, road.points.size() - 1], "points": road.points})
		for index in road.points.size():
			anchors.append({"id": "%s-anchor-%02d" % [road.id, index], "roadId": road.id, "routeId": route_id, "order": index, "x": road.points[index].x, "z": road.points[index].z})
	return {"seed": context.layout.seed, "name": context.layout.name, "roads": roads, "villages": context.villages, "landmarks": context.landmarks, "activityRoutes": routes, "activityAnchors": anchors, "activityBlockers": context.activity_blockers, "rockObstacles": context.rock_obstacles, "props": props, "terrainDetails": context.terrain_details, "battlefieldFeatures": context.rendered_features}

static func matrix(transform: Transform3D) -> Array:
	return [transform.basis.x.x, transform.basis.x.y, transform.basis.x.z, 0, transform.basis.y.x, transform.basis.y.y, transform.basis.y.z, 0, transform.basis.z.x, transform.basis.z.y, transform.basis.z.z, 0, transform.origin.x, transform.origin.y, transform.origin.z, 1]
