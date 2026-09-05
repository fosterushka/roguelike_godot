extends Node3D
const Source = preload("res://presentation/combat/source_model.gd")
const Terrain = preload("res://modules/caravan/terrain_surface.gd")
const CAPACITY := 4
const DURATION := 0.95
var entries: Array[Dictionary] = []
var cursor := 0
var _seen: Array[String] = []
var _warmup := false
var _preview: Node3D

func _ready() -> void:
	var mote_mesh := BoxMesh.new()
	mote_mesh.size = Vector3(0.13, 0.13, 0.32)
	for slot in CAPACITY:
		var group := Node3D.new()
		add_child(group)
		var models := {}
		for kind in ["airdrop", "heal_cart"]:
			var model := Source.instantiate(kind)
			for part: MeshInstance3D in model.get_children():
				var omit := false
				for binding: Dictionary in part.get_meta("source_part").bindings:
					if str(binding.role).begins_with("airdrop_") or binding.role == "heal_cart_aura":
						omit = true
				part.visible = not omit
				if kind == "airdrop":
					part.position.y -= 12.0
				var material: StandardMaterial3D = part.mesh.surface_get_material(0).duplicate()
				material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
				material.no_depth_test = false
				part.material_override = material
				part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			group.add_child(model)
			model.visible = false
			models[kind] = model
		var motes: Array[MeshInstance3D] = []
		for index in 6:
			var mote := MeshInstance3D.new()
			mote.mesh = mote_mesh
			var material := StandardMaterial3D.new()
			material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
			material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
			mote.material_override = material
			mote.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			group.add_child(mote)
			motes.append(mote)
		group.visible = false
		entries.append({"visual": group, "models": models, "motes": motes, "age": DURATION, "target_node": null})
	_preview = Node3D.new()
	add_child(_preview)
	for kind in ["airdrop", "heal_cart"]:
		var model: Node3D = entries[0].models[kind].duplicate()
		model.visible = true
		model.position.x = -1.0 if kind == "airdrop" else 1.0
		for part: MeshInstance3D in model.get_children():
			part.transparency = 0.25
		_preview.add_child(model)
	var mote: MeshInstance3D = entries[0].motes[0].duplicate()
	mote.position.y = 2
	mote.transparency = 0.25
	_preview.add_child(mote)
	_preview.visible = false

func spawn(event: Dictionary, target_node: Node3D = null) -> bool:
	if _warmup:
		return false
	var key := "%s:%s" % [event.get("kind", ""), event.get("id", -1)]
	if key in _seen:
		return false
	_seen.append(key)
	if _seen.size() > 16:
		_seen.pop_front()
	var entry := entries[cursor]
	cursor = (cursor + 1) % CAPACITY
	entry.kind = "airdrop" if event.get("kind") == "airdrop_claimed" else "heal_cart"
	var point: Vector3 = event.get("position", Vector3.ZERO)
	entry.origin = Vector3(point.x, Terrain.height_at(point.x, point.z), point.z)
	entry.target = event.get("target_position", entry.origin) + Vector3.UP * 1.5
	entry.target_node = target_node
	entry.heading = float(event.get("yaw", 0.0))
	entry.age = 0.0
	entry.visual.visible = true
	for kind: String in entry.models:
		entry.models[kind].visible = kind == entry.kind
	var color := Color("ffd475") if entry.kind == "airdrop" else Color("67f5a0")
	for mote: MeshInstance3D in entry.motes:
		mote.material_override.albedo_color = color
	_apply(entry)
	return true

func advance(delta: float) -> void:
	if _warmup or delta <= 0.0:
		return
	for entry: Dictionary in entries:
		if entry.age >= DURATION:
			continue
		entry.age = minf(DURATION, entry.age + delta)
		entry.visual.visible = entry.age < DURATION
		_apply(entry)

func _apply(entry: Dictionary) -> void:
	var progress: float = entry.age / DURATION
	var travel := smoothstep(0.16, 1.0, progress)
	var target: Vector3 = entry.target
	if is_instance_valid(entry.target_node):
		target = entry.target_node.global_position + Vector3.UP * 1.5
	var model: Node3D = entry.models[entry.kind]
	model.position = Vector3(entry.origin).lerp(target, travel) + Vector3.UP * sin(progress * PI) * 2.1
	model.rotation.y = entry.heading + progress * 0.9
	model.scale = Vector3.ONE * lerpf(1.0, 0.04, pow(travel, 0.8))
	for part: MeshInstance3D in model.get_children():
		part.transparency = smoothstep(0.68, 1.0, progress)
	for index in entry.motes.size():
		var mote: MeshInstance3D = entry.motes[index]
		var phase := clampf(progress * 1.32 - index * 0.055, 0, 1)
		var angle: float = index * TAU / 6.0 + progress * 3.0
		var radius := sin(phase * PI) * 0.9
		mote.position = Vector3(entry.origin).lerp(target, smoothstep(0, 1, phase)) + Vector3(cos(angle) * radius, 0.5 + sin(phase * PI) * 2.6, sin(angle) * radius) * (1.0 - phase)
		mote.rotation = Vector3(progress * 4, angle, progress * 3)
		mote.transparency = 1.0 - sin(phase * PI)

func active_count() -> int:
	var count := 0
	for entry: Dictionary in entries:
		count += int(entry.age < DURATION)
	return count

func reset() -> void:
	cursor = 0
	_seen.clear()
	for entry: Dictionary in entries:
		entry.age = DURATION
		entry.visual.visible = false
		entry.target_node = null

func set_warmup(enabled: bool, point: Vector3) -> void:
	_warmup = enabled
	_preview.position = point
	_preview.visible = enabled
