extends Node3D
const Ground = preload("res://presentation/world/ground_surface_view.gd")
const Source = preload("res://presentation/combat/source_model.gd")
const SmokeShader = preload("res://presentation/combat/fx/smoke.gdshader")
const KINDS := ["bike", "buggy", "jammerTruck", "repairCrawler", "minelayer"]
var entries: Array[Dictionary] = []
var cursor := 0
func _ready() -> void:
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	for index in 8:
		var group := Node3D.new()
		add_child(group)
		var models := {}
		for kind in KINDS:
			var model := Source.instantiate("wreck_" + kind)
			model.visible = false
			group.add_child(model)
			models[kind] = model
		var plumes: Array[MeshInstance3D] = []
		for plume_index in 2:
			var visual := MeshInstance3D.new()
			visual.mesh = quad
			var material := ShaderMaterial.new()
			material.shader = SmokeShader
			visual.material_override = material
			visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			group.add_child(visual)
			plumes.append(visual)
		group.visible = false
		entries.append({"visual": group, "models": models, "plumes": plumes, "life": 0.0, "age": 0.0})
func spawn(event: Dictionary) -> void:
	var kind := str(event.get("enemy_kind", event.get("type", "buggy")))
	if kind not in KINDS:
		return
	var previous_count := active_count()
	var entry := entries[cursor]
	cursor = (cursor + 1) % 8
	entry.life = 120.0
	entry.age = 0.0
	entry.kind = kind
	entry.seed_value = str(event.get("source_id", "")).length() * 0.137 + previous_count * 0.293
	var profile := Vector4(0.72, 2.12, 0.92, 1.45) if kind == "bike" else Vector4(2.12, 2.85, 1.08, 1.9) if kind == "buggy" else Vector4(2.45, 3.8, 1.35, 2.35)
	entry.profile = profile
	entry.visual.position = Ground.point_at(event.get("position", Vector3.ZERO), 0.0)
	entry.visual.rotation.y = float(event.get("heading", 0.0))
	entry.visual.visible = true
	for model_kind: String in KINDS:
		entry.models[model_kind].visible = model_kind == kind
	for index in 2:
		var plume: MeshInstance3D = entry.plumes[index]
		var size := profile.w * (1.0 if index == 0 else 1.24)
		plume.position = Vector3((index - 0.5) * profile.x * 0.2, profile.z + 1.17 + index * 0.62, -profile.y * 0.08)
		plume.scale = Vector3(size * 1.25, size * 2.15, 1)
		var material: ShaderMaterial = plume.material_override
		var color := Color("292827") if index == 0 else Color("46423d")
		material.set_shader_parameter("uColor", Vector3(color.r, color.g, color.b))
		material.set_shader_parameter("uDensity", 1.25 if index == 0 else 0.92)
	_apply(entry)
func advance(delta: float) -> void:
	if delta <= 0.0:
		return
	for entry: Dictionary in entries:
		if entry.life <= 0.0:
			continue
		entry.life = maxf(0.0, entry.life - delta)
		entry.age += delta
		entry.visual.visible = entry.life > 0.0
		_apply(entry)
func _apply(entry: Dictionary) -> void:
	for index in 2:
		var plume: MeshInstance3D = entry.plumes[index]
		var material: ShaderMaterial = plume.material_override
		var seed_value: float = entry.seed_value + index * 0.41
		var remaining: float = entry.life / 120.0
		var opacity := 0.62 if index == 0 else 0.38
		material.set_shader_parameter("uOpacity", opacity * minf(1.0, entry.age / 0.18) * remaining * remaining * (3.0 - 2.0 * remaining))
		material.set_shader_parameter("uSeed", seed_value)
		material.set_shader_parameter("uTime", seed_value * 2.7 + entry.age)
		var size: float = entry.profile.w * (1.0 if index == 0 else 1.24)
		var pulse: float = 1.0 + sin(entry.age * 0.72 + index * 1.9) * 0.045
		plume.scale = Vector3(size * 1.25 * pulse, size * 2.15 * (1.0 + (pulse - 1.0) * 0.55), 1)
func active_count() -> int:
	var count := 0
	for entry: Dictionary in entries:
		count += int(entry.life > 0.0)
	return count
func reset() -> void:
	cursor = 0
	for entry: Dictionary in entries:
		entry.life = 0.0
		entry.visual.visible = false
func set_warmup(enabled: bool) -> void:
	for index in KINDS.size():
		entries[index].visual.visible = enabled
		entries[index].models[KINDS[index]].visible = enabled
