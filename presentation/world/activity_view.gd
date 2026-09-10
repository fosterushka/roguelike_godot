extends Node3D
const Terrain = preload("res://modules/caravan/terrain_surface.gd")
const SourceModel = preload("res://presentation/combat/source_model.gd")
const ActivityRules = preload("res://modules/world/activities/activity_rules.gd")
const COLORS := {"raiderSupplyConvoy": Color("e64f3d"), "settlementDistress": Color("ff7552"), "foundryDispatch": Color("f2a13f"), "scavengerRoute": Color("74ddb2")}
var _healers: Dictionary
var _airdrop: Dictionary
var _markers: Array[MeshInstance3D] = []
var _routes: Array[MultiMeshInstance3D] = []
var _extraction_zones: Node3D
var _state: Dictionary = {}
var _warmup := false
var _visual_elapsed := 0.0
var _since_state := 0.0
var _route_seed := -1
var _flare_light: OmniLight3D
var _flare_smoke: Node3D

func _ready() -> void:
	_healers = SourceModel.create_pool("heal_cart", 3)
	_airdrop = SourceModel.create_pool("airdrop", 1)
	add_child(_healers.root)
	add_child(_airdrop.root)
	_prepare_opacity(_healers)
	_prepare_opacity(_airdrop)
	_prepare_flare_colors()
	_flare_smoke = preload("res://presentation/world/airdrop_flare_smoke.gd").new()
	add_child(_flare_smoke)
	_flare_light = OmniLight3D.new()
	_flare_light.light_color = Color("ff4a24")
	_flare_light.omni_range = 24
	_flare_light.omni_attenuation = 2
	_flare_light.visible = false
	add_child(_flare_light)
	for index in 3:
		var marker := _ring(2.2, 2.65, Color("e64f3d"))
		marker.visible = false
		_markers.append(marker)
		var dash := BoxMesh.new()
		dash.size = Vector3(0.10, 0.025, 5)
		dash.material = _material(Color("e64f3d"))
		var multimesh := MultiMesh.new()
		multimesh.transform_format = MultiMesh.TRANSFORM_3D
		multimesh.mesh = dash
		multimesh.instance_count = 256
		multimesh.visible_instance_count = 0
		var route := MultiMeshInstance3D.new()
		route.multimesh = multimesh
		add_child(route)
		_routes.append(route)
	_extraction_zones = preload("res://presentation/world/extraction_zone_view.gd").new()
	add_child(_extraction_zones)

func apply_state(state: Dictionary) -> void:
	_state = state
	_visual_elapsed = float(state.get("game_time", state.get("elapsed", 0)))
	_since_state = 0.0
	if _warmup:
		return
	if int(state.get("seed", 0)) != _route_seed:
		_route_seed = int(state.get("seed", 0))
		for route in _routes:
			if route.has_meta("route_cache"):
				route.remove_meta("route_cache")
	var healer_index := 0
	var records: Array = state.get("activity", {}).get("records", [])
	for index in 3:
		_markers[index].visible = index < records.size()
		if index >= records.size():
			_routes[index].multimesh.visible_instance_count = 0
			continue
		var record: Dictionary = records[index]
		_markers[index].position = _grounded(record.position) + Vector3.UP * 0.08
		_markers[index].material_override.albedo_color = COLORS.get(str(record.type), Color.WHITE)
		_markers[index].transparency = 0.52 if record.state == "announced" else 0.28
		_update_route(_routes[index], record.get("route", []), COLORS.get(str(record.type), Color.WHITE))
		if record.type == "scavengerRoute" and record.state == "active":
			_place_healer(healer_index, record, _visual_elapsed - float(record.get("starts_at", _visual_elapsed)))
			healer_index += 1
	for cart: Dictionary in state.get("support", {}).get("heal_carts", []):
		if healer_index < 3:
			_place_healer(healer_index, cart, float(cart.get("age", 0)))
			healer_index += 1
	for index in range(healer_index, 3):
		SourceModel.hide_pool_instance(_healers, index)
	var drops: Array = state.get("support", {}).get("airdrops", [])
	if drops.is_empty():
		SourceModel.hide_pool_instance(_airdrop, 0)
		_flare_light.visible = false
		_flare_smoke.apply_drop({}, _visual_elapsed)
	else:
		_place_airdrop(drops[0])
	_extraction_zones.apply_state(state.get("extraction", {}))

func _update_route(view: MultiMeshInstance3D, points: Array, color: Color) -> void:
	view.multimesh.mesh.material.albedo_color = color
	var cached: Dictionary = view.get_meta("route_cache", {})
	if cached.get("points") == points:
		if view.multimesh.visible_instance_count != cached.count:
			view.multimesh.visible_instance_count = cached.count
		return
	var distance := 0.0
	var total := ActivityRules.route_length(points)
	var count := 0
	while distance < total and count < 256:
		var start: Vector3 = ActivityRules.sample_route(points, distance).position
		var end: Vector3 = ActivityRules.sample_route(points, minf(total, distance + 5.0)).position
		var direction := end - start
		var basis := Basis(Vector3.UP, atan2(direction.x, direction.z)).scaled(Vector3(1, 1, direction.length() / 5.0))
		view.multimesh.set_instance_transform(count, Transform3D(basis, _grounded((start + end) * 0.5) + Vector3.UP * 0.1))
		count += 1
		distance += 8.0
	view.multimesh.visible_instance_count = count
	view.set_meta("route_cache", {"points": points.duplicate(true), "count": count})

func _ring(inner: float, outer: float, color: Color) -> MeshInstance3D:
	var mesh := TorusMesh.new()
	mesh.inner_radius = inner
	mesh.outer_radius = outer
	mesh.rings = 32
	mesh.ring_segments = 6
	var visual := MeshInstance3D.new()
	visual.mesh = mesh
	visual.scale.y = 0.04
	visual.material_override = _material(color)
	add_child(visual)
	return visual

func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.albedo_color.a = 0.68
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	material.render_priority = -64
	return material

func set_warmup_visible(enabled: bool) -> void:
	_warmup = enabled
	_flare_smoke.set_warmup(enabled)
	if enabled:
		SourceModel.set_pool_instance(_healers, 0, Transform3D.IDENTITY)
		SourceModel.set_pool_instance(_airdrop, 0, Transform3D(Basis.IDENTITY, Vector3(0, -10, 0)))
		_markers[0].visible = true
		_markers[0].position = Vector3(0, 0.2, 0)
		_routes[0].multimesh.visible_instance_count = 1
	else:
		apply_state(_state)

func _prepare_opacity(pool: Dictionary) -> void:
	for index in pool.batches.size():
		var batch: Dictionary = pool.batches[index]
		for binding: Dictionary in batch.bindings:
			if binding.role not in ["airdrop_aura", "airdrop_flareGlow", "airdrop_signalBeam", "heal_cart_aura"]:
				continue
			batch.opacity_role = binding.role
			var material: StandardMaterial3D = batch.mesh.mesh.surface_get_material(0).duplicate()
			if binding.role in ["airdrop_aura", "heal_cart_aura"]:
				material.render_priority = -64
			material.albedo_color.a = 1.0
			material.vertex_color_use_as_albedo = true
			pool.root.get_child(index).material_override = material
			batch.mesh.instance_count = 0
			batch.mesh.use_colors = true
			batch.mesh.instance_count = pool.capacity
			for slot in pool.capacity:
				batch.mesh.set_instance_transform(slot, Transform3D(Basis.from_scale(Vector3.ZERO), Vector3.ZERO))

func _opacity(pool: Dictionary, index: int, values: Dictionary) -> void:
	for batch: Dictionary in pool.batches:
		if batch.has("opacity_role"):
			batch.mesh.set_instance_color(index, Color(1, 1, 1, values.get(batch.opacity_role, 1.0)))

func _place_healer(index: int, cart: Dictionary, age: float) -> void:
	var phase := float(cart.get("phase", age * 3.0)) + _since_state * 3.0
	var pose := {"wheel_angle": (age + _since_state) * float(cart.get("speed", 2.8)) * 1.5, "binding_overrides": {"heal_cart_aura": {"rotation": Vector3(-PI / 2, 0, (age + _since_state) * 0.45)}}}
	SourceModel.set_pool_instance(_healers, index, healer_transform(cart, age, _since_state), pose)
	_opacity(_healers, index, {"heal_cart_aura": 0.25 + sin(phase * 1.7) * 0.12})

func _place_airdrop(drop: Dictionary) -> void:
	var time := _visual_elapsed + _since_state
	var pulse := 0.5 + sin(time * 7.5) * 0.5
	var landed: bool = drop.landed
	var overrides := airdrop_overrides(drop, time, _since_state)
	var transform := Transform3D(Basis(Vector3.UP, float(drop.get("yaw", 0))), _grounded(drop.position) + Vector3.UP * (float(drop.height) - 12.0))
	SourceModel.set_pool_instance(_airdrop, 0, transform, {"binding_overrides": overrides})
	_opacity(_airdrop, 0, {"airdrop_aura": 0.2 + sin(time * 3.4) * 0.08, "airdrop_flareGlow": 0.24 + pulse * 0.22, "airdrop_signalBeam": 0.08 + pulse * 0.09})
	_flare_smoke.apply_drop(drop, time)
	_tint_flare(Color("df291d"))
	_flare_light.visible = landed
	_flare_light.position = _grounded(drop.position) + Basis(Vector3.UP, float(drop.get("yaw", 0))) * Vector3(0.62, 2.9, 0.58)
	_flare_light.light_energy = 3.6 + pulse * 2.8

static func airdrop_overrides(drop: Dictionary, time: float, since_state: float = 0.0) -> Dictionary:
	var pulse := 0.5 + sin(time * 7.5) * 0.5
	var landed: bool = drop.landed
	var overrides := {"airdrop_aura": {"rotation": Vector3(-PI / 2, 0, (float(drop.get("age", 0)) + since_state) * 0.65)}, "airdrop_flareRoot": {"visible": landed}, "airdrop_flareCore": {"scale": Vector3.ONE * (0.92 + pulse * 0.18)}, "airdrop_flareGlow": {"scale": Vector3.ONE * (0.9 + pulse * 0.38)}}
	if landed:
		overrides.airdrop_canopyRig = {"position": Vector3(-2.6, 0.35, -1.5), "rotation": Vector3(0, 0, 1.08), "scale": Vector3(0.68, 0.16, 0.68)}
	return overrides

func _process(delta: float) -> void:
	advance_visual(delta)

func advance_visual(delta: float) -> void:
	if _warmup or _state.is_empty():
		return
	_since_state += delta
	var index := 0
	for record: Dictionary in _state.get("activity", {}).get("records", []):
		if record.type == "scavengerRoute" and record.state == "active" and index < 3:
			_place_healer(index, record, _visual_elapsed - float(record.get("starts_at", _visual_elapsed)))
			index += 1
	for cart: Dictionary in _state.get("support", {}).get("heal_carts", []):
		if index < 3:
			_place_healer(index, cart, float(cart.get("age", 0)))
			index += 1
	var drops: Array = _state.get("support", {}).get("airdrops", [])
	if not drops.is_empty():
		_place_airdrop(drops[0])

static func _grounded(point: Vector3) -> Vector3:
	return Vector3(point.x, Terrain.height_at(point.x, point.z), point.z)

static func healer_transform(cart: Dictionary, age: float, since_state: float = 0.0) -> Transform3D:
	var phase := float(cart.get("phase", age * 3.0)) + since_state * 3.0
	return Transform3D(Basis(Vector3.UP, float(cart.get("yaw", 0))), _grounded(cart.position) + Vector3.UP * sin(phase) * 0.045)

func _prepare_flare_colors() -> void:
	for index in _airdrop.batches.size():
		var batch: Dictionary = _airdrop.batches[index]
		for binding: Dictionary in batch.bindings:
			if binding.role not in ["airdrop_flareCore", "airdrop_flareGlow", "airdrop_signalBeam"]:
				continue
			var visual: MultiMeshInstance3D = _airdrop.root.get_child(index)
			if visual.material_override == null:
				visual.material_override = batch.mesh.mesh.surface_get_material(0).duplicate()
			batch.flare_material = visual.material_override

func _tint_flare(color: Color) -> void:
	_flare_light.light_color = color
	for batch: Dictionary in _airdrop.batches:
		if batch.has("flare_material"):
			var material: StandardMaterial3D = batch.flare_material
			material.albedo_color = Color(color, material.albedo_color.a)
			if material.emission_enabled:
				material.emission = color
