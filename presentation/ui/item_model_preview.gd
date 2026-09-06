class_name ItemModelPreview
extends SubViewportContainer

## Compact, inert render of a real game model. A thumbnail renders only when its
## content changes; the viewport is disabled afterwards so lists do not animate.
const Equipment = preload("res://presentation/vehicles/equipment_model.gd")
const WheeledRig = preload("res://presentation/vehicles/wheeled_rig.gd")
const LootModels = preload("res://presentation/ui/item_loot_models.gd")

var viewport: SubViewport
var assembly: Node3D
var camera: Camera3D
var _model: Node3D
var _ready_for_preview := false
var preview_kind := ""
var preview_id := ""

func _ready() -> void:
	stretch = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	viewport = SubViewport.new()
	viewport.size = Vector2i(256, 144)
	viewport.transparent_bg = false
	viewport.gui_disable_input = true
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(viewport)
	var scene := Node3D.new()
	viewport.add_child(scene)
	assembly = Node3D.new()
	scene.add_child(assembly)
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.position = Vector3(8, 6.5, 9)
	camera.size = 7.5
	scene.add_child(camera)
	camera.look_at(Vector3(0, 0.8, 0))
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-48, -35, 0)
	key.light_energy = 1.45
	scene.add_child(key)
	var fill := OmniLight3D.new()
	fill.position = Vector3(-3, 3, 2)
	fill.light_color = Color("d7c28a")
	fill.light_energy = 1.1
	scene.add_child(fill)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("1a211e")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color("d4d9c8")
	environment.environment.ambient_light_energy = 0.55
	scene.add_child(environment)
	_ready_for_preview = true
	visibility_changed.connect(_on_visibility_changed)
	resized.connect(_on_resized)
	if not preview_id.is_empty():
		_rebuild()
	else:
		_refit_after_resize.call_deferred()

func set_preview(kind: String, id: String) -> void:
	if preview_kind == kind and preview_id == id and is_instance_valid(_model):
		_request_frame()
		return
	preview_kind = kind
	preview_id = id
	if _ready_for_preview:
		_rebuild()

func set_rendering(value: bool) -> void:
	if not _ready_for_preview:
		return
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE if value else SubViewport.UPDATE_DISABLED

func _rebuild() -> void:
	if is_instance_valid(_model):
		assembly.remove_child(_model)
		_model.queue_free()
	_model = _build_model()
	if _model == null:
		return
	assembly.add_child(_model)
	_model.rotation_degrees = Vector3(-8, 30, 0)
	_fit_camera()
	_request_frame()

func _build_model() -> Node3D:
	match preview_kind:
		"module", "attachment":
			return Equipment.build(preview_id)
		"vehicle":
			return WheeledRig.build_player() if preview_id == "crawler" else WheeledRig.build_trailer(preview_id)
		"loot":
			return LootModels.build(preview_id)
	return null

func _fit_camera() -> void:
	if camera == null or _model == null:
		return
	var bounds := _mesh_bounds()
	if bounds.size.length_squared() <= 0.0001:
		return
	var target := bounds.get_center()
	var orbit := Vector3(8.0, 6.5, 9.0).normalized() * 14.0
	camera.position = target + orbit
	camera.look_at(target)
	var half_width := 0.0
	var half_height := 0.0
	for point: Vector3 in _bounds_corners(bounds):
		var offset := point - target
		half_width = maxf(half_width, absf(offset.dot(camera.global_transform.basis.x)))
		half_height = maxf(half_height, absf(offset.dot(camera.global_transform.basis.y)))
	var aspect := float(viewport.size.x) / maxf(float(viewport.size.y), 1.0)
	camera.size = maxf(half_height * 2.0, half_width * 2.0 / aspect) * 1.16

func _mesh_bounds() -> AABB:
	var has_mesh := false
	var combined := AABB()
	for candidate: Node in _model.find_children("*", "MeshInstance3D", true, false):
		var mesh_node := candidate as MeshInstance3D
		if mesh_node.mesh == null:
			continue
		for point: Vector3 in _bounds_corners(mesh_node.mesh.get_aabb()):
			var local := assembly.to_local(mesh_node.to_global(point))
			if not has_mesh:
				combined = AABB(local, Vector3.ZERO)
				has_mesh = true
			else:
				combined = combined.expand(local)
	return combined

func _bounds_corners(bounds: AABB) -> Array[Vector3]:
	var corners: Array[Vector3] = []
	for x in [bounds.position.x, bounds.end.x]:
		for y in [bounds.position.y, bounds.end.y]:
			for z in [bounds.position.z, bounds.end.z]:
				corners.append(Vector3(x, y, z))
	return corners

func _request_frame() -> void:
	if not _ready_for_preview or not is_visible_in_tree():
		return
	# UPDATE_ONCE lets Godot finish one render pass, then disables the target.
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE

func _on_visibility_changed() -> void:
	if _ready_for_preview and is_visible_in_tree() and not preview_id.is_empty():
		_request_frame()

func _on_resized() -> void:
	if _ready_for_preview:
		_refit_after_resize.call_deferred()

func _refit_after_resize() -> void:
	if not _ready_for_preview or viewport == null:
		return
	var target_size := Vector2i(maxi(1, roundi(size.x)), maxi(1, roundi(size.y)))
	if viewport.size != target_size:
		viewport.size = target_size
	if is_instance_valid(_model):
		_fit_camera()
	_request_frame()
