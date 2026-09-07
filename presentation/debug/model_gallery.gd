extends Node3D

signal gallery_ready
const Catalog = preload("res://presentation/debug/gallery_catalog.gd")
const Orbit = preload("res://presentation/debug/gallery_camera.gd")
const GalleryPanel = preload("res://presentation/debug/gallery_panel.gd")
const COLUMNS := 8
const CELL := 20.0
const MODEL_SPAN := 13.0
const TILE_SIZE := 16.0
const LABEL_HEIGHT := 0.14
var entries: Array[Dictionary] = []
var displays: Array[Dictionary] = []
var camera: Camera3D
var panel: CanvasLayer
var selection: MeshInstance3D
var map_bounds := AABB()
var selected_index := 0
var built :=  false
var errors: Array[String] = []

func _ready() -> void:
	get_window().title = "Iron Caravan | Blender model gallery"
	_build.call_deferred()

func _build() -> void:
	_environment()
	camera = Orbit.new()
	add_child(camera)
	panel = GalleryPanel.new()
	add_child(panel)
	panel.selected.connect(focus_model)
	panel.overview_requested.connect(overview)
	entries = Catalog.entries()
	var section := ""
	var column := 0
	var z := 0.0
	for index in entries.size():
		var entry: Dictionary = entries[index]
		if entry.section != section:
			if index > 0:
				z += CELL * (2.0 if column != 0 else 1.0)
			section = entry.section
			column = 0
			_label(section, Vector3(0, 1.0, z - CELL * 0.65), 38)
		var point := Vector3(column * CELL, 0, z)
		var holder := Node3D.new()
		holder.name = "Display_%03d" % index
		holder.position = point
		add_child(holder)
		var model := Catalog.build(entry)
		var bounds := Catalog.bounds(model)
		if bounds.size.length_squared() < 0.000001:
			errors.append(entry.id)
		var original_size := bounds.size
		var largest := maxf(bounds.size.x, bounds.size.z)
		var scale_value := minf(1.0, MODEL_SPAN / maxf(0.01, largest))
		model.scale *= scale_value
		model.position -= Vector3(bounds.get_center().x, bounds.position.y, bounds.get_center().z) * scale_value
		holder.add_child(model)
		_tile(point, Color("353f43") if index % 2 == 0 else Color("303a3e"))
		_label(entry.title, point + Vector3(0, LABEL_HEIGHT, TILE_SIZE * 0.5 + 0.6), 24)
		var center := point + Vector3.UP * original_size.y * scale_value * 0.5
		displays.append({"model": model, "point": point, "center": center, "size": original_size, "scale": scale_value})
		var cell_bounds := AABB(point - Vector3(CELL * 0.5, 0, CELL * 0.5), Vector3(CELL, maxf(1, original_size.y * scale_value), CELL))
		map_bounds = cell_bounds if index == 0 else map_bounds.merge(cell_bounds)
		column += 1
		if column == COLUMNS:
			column = 0
			z += CELL
		if index % 12 == 0:
			panel.status.text = "Building %d / %d" % [index + 1, entries.size()]
			await get_tree().process_frame
	selection = _tile(Vector3.ZERO, Color("a8894d"), TILE_SIZE + 0.7)
	selection.position.y = -0.025
	panel.populate(entries)
	camera.center = Vector3(CELL * 3.5, 0, CELL * 0.5)
	camera.target = camera.center
	camera.span = 95.0
	camera.target_span = 95.0
	built = true
	panel.show_entry(0, displays[0].size, displays[0].scale)
	print("MODEL_GALLERY_READY: %d entries, %d empty models" % [entries.size(), errors.size()])
	gallery_ready.emit()

func _environment() -> void:
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color("222b31")
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color("d5e0e3")
	env.environment.ambient_light_energy = 0.68
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, -30, 0)
	sun.light_energy = 1.5
	sun.shadow_enabled = true
	add_child(sun)

func _tile(point: Vector3, color: Color, size_value: float = TILE_SIZE) -> MeshInstance3D:
	var mesh := PlaneMesh.new()
	mesh.size = Vector2.ONE * size_value
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 1.0
	mesh.material = material
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.position = point - Vector3.UP * 0.02
	add_child(node)
	return node

func _label(text: String, point: Vector3, font_size: int) -> void:
	var label := Label3D.new()
	label.text = text
	label.position = point
	label.font_size = font_size
	label.pixel_size = 0.025
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = false
	label.visibility_range_end = 190.0
	add_child(label)

func focus_model(index: int) -> void:
	if not built or index < 0 or index >= displays.size():
		return
	selected_index = index
	var display: Dictionary = displays[index]
	var size_value: Vector3 = display.size * display.scale
	camera.focus(display.center, maxf(3.0, maxf(size_value.x, maxf(size_value.y, size_value.z)) * 2.5))
	selection.position = display.point - Vector3.UP * 0.025
	panel.show_entry(index, display.size, display.scale)

func overview() -> void:
	camera.focus(map_bounds.get_center(), maxf(map_bounds.size.x, map_bounds.size.z) * 1.1)

func _process(_delta: float) -> void:
	if built:
		camera.input_blocked = get_viewport().gui_get_focus_owner() is LineEdit

func _unhandled_input(event: InputEvent) -> void:
	if not built or not event is InputEventKey or not event.pressed or event.echo:
		return
	match event.physical_keycode:
		KEY_HOME: overview()
		KEY_F: focus_model(selected_index)
		KEY_PAGEDOWN: focus_model((selected_index + 1) % entries.size())
		KEY_PAGEUP: focus_model(posmod(selected_index - 1, entries.size()))
