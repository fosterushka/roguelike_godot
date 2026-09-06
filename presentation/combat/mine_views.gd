extends Node3D
const Terrain = preload("res://modules/caravan/terrain_surface.gd")
const Source = preload("res://presentation/combat/source_model.gd")
var entries: Array[Dictionary] = []

func _ready() -> void:
	for _index in 36:
		var model := Source.instantiate("mine_enemy")
		add_child(model)
		var signal_visual: MeshInstance3D = model.get_child(1)
		signal_visual.material_override = signal_visual.mesh.surface_get_material(0).duplicate()
		signal_visual.material_override.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		signal_visual.material_override.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		var track := _bar(Vector3(1.18, 0.08, 0.15), Color("241f18"), 0.84)
		track.position = Vector3(0, 0.455, -0.56)
		model.add_child(track)
		var fill := _bar(Vector3(1.08, 0.045, 0.17), Color("ffbf3f"), 1.0)
		fill.position = Vector3(-0.54, 0.46, -0.56)
		model.add_child(fill)
		model.visible = false
		entries.append({"visual": model, "signal": signal_visual, "signal_basis": signal_visual.basis, "track": track, "fill": fill})

func _bar(size_value: Vector3, color: Color, opacity: float) -> MeshInstance3D:
	var result := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size_value
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(color, opacity)
	if opacity < 1.0:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh.material = material
	result.mesh = mesh
	result.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return result

static func appearance(mine: Dictionary) -> Dictionary:
	var friendly: bool = mine.get("allegiance", "enemy") == "friendly"
	var armed := bool(mine.get("armed", false))
	var progress := clampf(float(mine.get("hack_progress", 0.0)) / 3.0, 0, 1)
	var life := clampf(float(mine.get("life", 0.0)) / 25.0, 0, 1)
	var color := Color("36e47a") if friendly else Color("ff382e").srgb_to_linear().lerp(Color("ffbf3f").srgb_to_linear(), progress).linear_to_srgb() if armed else Color("ffa12e")
	var opacity := 0.82 + sin(life * 64) * 0.12 if friendly else 0.72 + sin(life * 90) * 0.18 if armed else 0.34 + sin(life * 38) * 0.14
	return {"color": Color(color, opacity), "scale": 1.16 if friendly else 1.1 if armed else 0.78, "progress": progress, "show_progress": not friendly and progress > 0.0}

func sync_state(mines: Array) -> void:
	var index := 0
	for mine: Dictionary in mines:
		if mine.get("dead", false) or index >= entries.size():
			continue
		var entry := entries[index]
		index += 1
		var state := appearance(mine)
		entry.visual.visible = true
		entry.visual.position = Vector3(mine.position.x, Terrain.height_at(mine.position.x, mine.position.z), mine.position.z)
		entry.signal.material_override.albedo_color = state.color
		entry.signal.basis = entry.signal_basis.scaled(Vector3.ONE * state.scale)
		entry.track.visible = state.show_progress
		entry.fill.visible = state.show_progress
		entry.fill.scale.x = maxf(0.001, state.progress)
		entry.fill.position.x = -0.54 + 0.54 * state.progress
	for hidden in range(index, entries.size()):
		entries[hidden].visual.visible = false

func set_warmup(enabled: bool, point: Vector3) -> void:
	for index in entries.size():
		entries[index].visual.visible = enabled and index == 0
		if enabled and index == 0:
			entries[index].visual.position = point
			entries[index].track.visible = true
			entries[index].fill.visible = true
