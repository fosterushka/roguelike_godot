extends Node3D
signal screen_impact(power: float)
signal body_impact(pitch: float, roll: float)
const BodySplash = preload("res://presentation/combat/fx/body_splash.gd")
const SPARK_COUNT := 6
const SPARK_LIFE := 0.22
const Ground = preload("res://presentation/world/ground_surface_view.gd")
const Pool = preload("res://presentation/combat/fx/effect_pool.gd")
const MathRules = preload("res://presentation/combat/fx/effect_math.gd")
const VisualRandom = preload("res://presentation/combat/fx/visual_random.gd")
const Collapse = preload("res://presentation/combat/fx/fort_collapse.gd")
const Debris = preload("res://presentation/combat/fx/crash_debris.gd")
const RocketTrail = preload("res://presentation/combat/fx/rocket_trail.gd")
const CollapseHulls = preload("res://presentation/combat/fx/collapse_hulls.gd")
const Tracks = preload("res://presentation/combat/fx/wheel_tracks.gd")
const Wrecks = preload("res://presentation/combat/fx/vehicle_wrecks.gd")
const PlayerDestruction = preload("res://presentation/combat/fx/player_destruction.gd")
const Dust = preload("res://presentation/combat/fx/dust_field.gd")
const SmokeShader = preload("res://presentation/combat/fx/smoke.gdshader")
const FIREBALL = preload("res://assets/textures/fx/explosion-fireball.png")
const BLOOD = preload("res://assets/textures/fx/blood-splash.png")
const SCORCHES = [preload("res://assets/textures/fx/rocket-scorch-crater-a.png"), preload("res://assets/textures/fx/rocket-scorch-skid-b.png")]
var time_delta: Callable
var listener_position := Vector3.ZERO
var transient: Node3D
var fireballs: Node3D
var traces: Node3D
var smoke: Node3D
var rockets: Node3D
var dust: Node3D
var hulls: Node3D
var tracks: Node3D
var player_view: Node3D
var wrecks: Node3D
var player_destruction: Node3D
var support_pickup: Node3D
var jammer_field: Node3D
var random = VisualRandom.new()
var _warmup := false
var _scorch_bag: Array = []
var _last_scorch := -1
var _trail_timers: Dictionary = {}
var _smoke_timers: Dictionary = {}
var _warmup_nodes: Array[Node3D] = []

func _ready() -> void:
	transient = _pool(185, 4)
	fireballs = _pool(6, 2, null, true)
	traces = _pool(24, 1)
	smoke = _pool(185, 1, SmokeShader)
	rockets = RocketTrail.new()
	add_child(rockets)
	dust = Dust.new()
	add_child(dust)
	hulls = CollapseHulls.new()
	add_child(hulls)
	tracks = Tracks.new()
	add_child(tracks)
	wrecks = Wrecks.new()
	add_child(wrecks)
	player_destruction = PlayerDestruction.new()
	add_child(player_destruction)
	support_pickup = preload("res://presentation/combat/fx/support_pickup.gd").new()
	add_child(support_pickup)
	jammer_field = preload("res://presentation/combat/fx/jammer_field.gd").new()
	add_child(jammer_field)
	_prepare_warmup()

func _pool(count: int, parts: int, shader: Shader = null, fire: bool = false) -> Node3D:
	var pool := Pool.new()
	pool.configure(count, parts, shader, fire)
	add_child(pool)
	return pool

func on_event(event: Dictionary) -> void:
	if _warmup:
		return
	var point: Vector3 = event.get("position", Vector3.ZERO)
	match str(event.get("kind", "")):
		"explosion":
			var projectile_kind := str(event.get("projectile_kind", "rocket"))
			var size := float(event.get("visual_scale", 1.1 if projectile_kind == "grenade" else 0.9))
			explosion(point, size)
		"shot": spawn_muzzle_flash(point, str(event.get("projectile_kind", "bullet")))
		"hit":
			if event.get("type", "") != "soldier":
				impact_burst(point)
		"projectile_ground":
			var sabot: bool = event.get("projectile_kind") == "sabot"
			spawn_dust(Vector3(point.x, 0.04, point.z), 2 if sabot else 1, 0.34 if sabot else 0.2, Color("9d7653"))
			if sabot and random.next_float() < 0.75:
				spawn_embedded_projectile(event)
		"death":
			var type := str(event.get("type", ""))
			if type in ["bike", "buggy", "priorityVehicle"]:
				wrecks.spawn(event)
			if type == "soldier":
				spawn_blood_mark(point, 0.72)
				BodySplash.spawn(transient, random, point)
			elif type == "drone":
				explosion(point, 1.15 if event.get("enemy_kind") == "kamikaze" else 0.72, true, maxf(0.7, float(event.get("radius", 1.0)) * 2.0))
			elif type == "bike":
				spawn_blood_mark(point, 0.9)
				BodySplash.spawn(transient, random, point, 1.15)
				point.y = 0.65
				explosion(point, 0.8, true, maxf(0.7, float(event.get("radius", 1.0)) * 2.0))
			else:
				Collapse.spawn(self, event)
		"telegraph": spawn_shockwave(point, 3.8, Color("ff381f"))
		"boss_component_destroyed":
			var core: bool = event.get("component_kind") == "core"
			explosion(point, 1.3 if core else 0.72)
			spawn_crash_debris(point, 1.8 if core else 0.85, "metal")
		"death_started":
			point.y = 1.15
			explosion(point, 1.85)
			player_destruction.spawn(player_view, event.get("position", Vector3.ZERO), float(event.get("heading", 0.0)), random)
		"healing_burst": spawn_healing_burst(point)
		"boss_phase": spawn_shockwave(point, 2.3 if event.get("phase") == 2 else 1.5, Color("ff5a2d"))
		"mine_explosion":
			point.y = 0.12
			explosion(point, 0.72, true, maxf(0.7, float(event.get("radius", 2.35)) * 2.0))
		"roadkill_impact":
			if event.get("enemy_type") == "buggy":
				spawn_blood_mark(point, 1.25)
			point.y = 0.04
			spawn_dust(point, 5 if event.get("enemy_type") == "buggy" else 3, 0.9 if event.get("enemy_type") == "buggy" else 0.55, Color("7c4b3d"))
		"ram_impact":
			var speed := float(event.get("speed", 0.0))
			var bumper: bool = event.get("bumper", false)
			spawn_crash_debris(point, minf(3.0, 0.9 + speed * 0.22) if bumper else minf(2.5, 0.7 + speed * 0.18), "stone" if event.get("boss", false) else "mixed")
			if bumper:
				spawn_shockwave(point, 1.15, Color("ffa642"))
			screen_impact.emit(minf(0.82, 0.28 + speed * 0.055) if bumper else minf(0.72, 0.2 + speed * 0.05))
			body_impact.emit(-0.14 if bumper else -minf(0.18, speed * 0.018), random.between(-0.1, 0.1) if bumper else random.between(-0.12, 0.12))
		"conductor_arc":
			var target: Vector3 = event.get("target_position", point)
			point.y = 1.1
			target.y = 1.1
			var delta := target - point
			var effect: Dictionary = transient.acquire({"life": 0.18, "max_life": 0.18})
			transient.set_part(effect, 0, "cylinder5", Vector3(0.045, delta.length(), 0.045), Color(0.6235, 0.9176, 1.0, 0.9), (point + target) * 0.5)
			effect.parts[0].quaternion = Quaternion(Vector3.UP, delta.normalized()) if delta.length_squared() > 0.00001 else Quaternion.IDENTITY
	_limit()

func on_world_event(event: Dictionary) -> void:
	if _warmup:
		return
	if event.get("kind") == "village_consumed":
		for point: Vector3 in event.get("house_positions", []):
			point.y = 0.7
			spawn_crash_debris(point, 0.75, "mixed")
			point.y = 0.04
			spawn_dust(point, 4, 0.9, Color("b58a62"))
		spawn_shockwave(event.get("position", Vector3.ZERO), 1.15, Color("f7c96a"))
		screen_impact.emit(0.24)
	elif event.get("kind") == "airdrop_landed":
		var point: Vector3 = event.get("position", Vector3.ZERO)
		spawn_dust(point, 8, 1.2, Color("b89a73"))
		spawn_shockwave(point, 0.72, Color("ffd15f"))
	elif event.get("kind") == "airdrop_claimed":
		support_pickup.spawn(event, player_view)
	elif event.get("kind") in ["healing_burst", "healer_claimed"]:
		var point: Vector3 = event.get("position", Vector3.ZERO)
		point.y = 0.6
		spawn_healing_burst(point)
		if event.get("kind") == "healer_claimed":
			support_pickup.spawn(event, player_view)
	elif event.get("kind") == "tornado_debris":
		spawn_crash_debris(event.get("position", Vector3.ZERO) + Vector3.UP * 1.5, 0.32, str(event.get("debris_kind", "stone")))
	elif event.get("kind") == "prop_destroyed":
		var kind := str(event.get("prop_kind", "wood"))
		var large: bool = event.get("large", kind in ["building", "monument"])
		var force := float(event.get("force", 1.0))
		var point: Vector3 = event.get("position", Vector3.ZERO)
		point.y = 0.7 if large else 0.6
		if not event.get("tree_fall", false):
			spawn_crash_debris(point, 0.9 + force * 0.2 if large else 0.45 + force * 0.15, str(event.get("debris_kind", "mixed" if kind in ["monument", "streetlight"] else "wood")))
		if kind == "tree":
			spawn_leaf_burst(point, 5 + floori(force * 2.0))
		point.y = 0.04
		spawn_dust(point, 5 if large else 3, 0.65 + force * 0.2, Color("9b7653"))
		if large:
			spawn_shockwave(point, 0.65, Color("d8a45b"))
	_limit()

func spawn_muzzle_flash(point: Vector3, kind: String) -> void:
	var size := 0.5 if kind == "grenade" else 0.42 if kind == "rocket" else 0.3 if kind == "sabot" else 0.16
	var effect: Dictionary = transient.acquire({"position": point, "life": 0.11, "max_life": 0.11, "grow": size * 2.6, "scale": Vector3.ONE * size})
	transient.set_part(effect, 0, "sphere", Vector3.ONE, Color("ff7a21") if kind in ["rocket", "grenade"] else Color("ffe09a"), Vector3.ZERO, Vector3.ZERO, false, true)

func spawn_shockwave(point: Vector3, size: float = 1.0, color: Color = Color("ffc45e")) -> void:
	point.y = 0.09
	var effect: Dictionary = transient.acquire({"position": point, "life": 0.42, "max_life": 0.42, "grow": size * 7.5, "scale": Vector3.ONE * 0.2})
	color.a = 0.7
	transient.set_part(effect, 0, "shockwave", Vector3.ONE, color, Vector3.ZERO, Vector3(-PI / 2, 0, 0), false, true)

func spawn_dust(point: Vector3, count: int = 5, force: float = 1.0, color: Color = Color("b98d61")) -> void:
	dust.spawn(random, point, count, force, color)

func spawn_crash_debris(point: Vector3, intensity: float = 1.0, kind: String = "mixed") -> void:
	spawn_dust(point, mini(12, 3 + floori(intensity * 2.0)), minf(2.2, 0.7 + intensity * 0.22))
	Debris.spawn(transient, random, point, intensity, kind)

func spawn_blood_mark(point: Vector3, size: float = 1.0) -> void:
	point = Ground.point_at(point, Ground.BLOOD_OFFSET)
	var effect: Dictionary = transient.acquire({"position": point, "life": 24.0, "max_life": 24.0})
	transient.set_part(effect, 0, "quad", Vector3(size * random.between(0.82, 1.25) * 2.0, size * random.between(0.82, 1.25) * 2.0, 1.0), Color(1, 1, 1, 0.84), Vector3.ZERO, Vector3(-PI / 2.0, 0, random.between(0, TAU)))
	effect.parts[0].material_override.albedo_texture = BLOOD
	Ground.prepare_material(effect.parts[0].material_override, -110)
	Ground.conform_quad(effect.parts[0], Ground.BLOOD_OFFSET)

func spawn_scorch(point: Vector3, size: float = 1.0, randomized: bool = true) -> void:
	if _scorch_bag.is_empty():
		_scorch_bag = [0, 1]
		if random.next_float() < 0.5:
			_scorch_bag.reverse()
		if _scorch_bag.back() == _last_scorch:
			_scorch_bag.reverse()
	_last_scorch = _scorch_bag.pop_back()
	point = Ground.point_at(point, Ground.SCORCH_OFFSET)
	var effect: Dictionary = traces.acquire({"position": point, "life": 120.0, "max_life": 120.0, "fade_tail": 8.0 / 120.0})
	var scale_x: float = size * random.between(0.92, 1.12) if randomized else size
	var scale_y: float = size * random.between(0.86, 1.08) if randomized else size
	traces.set_part(effect, 0, "quad", Vector3(scale_x * 2, scale_y * 2, 1), Color(1, 1, 1, 0.82), Vector3.ZERO, Vector3(-PI / 2, 0, random.between(0, TAU)))
	effect.parts[0].material_override.albedo_texture = SCORCHES[_last_scorch]
	Ground.prepare_material(effect.parts[0].material_override, -96)
	Ground.conform_quad(effect.parts[0], Ground.SCORCH_OFFSET)
	_sort_scorches()

func explosion(point: Vector3, size: float = 1.0, fiery: bool = true, ground_size: float = -1.0) -> void:
	var angle: float = random.between(-PI, PI)
	var effect: Dictionary = fireballs.acquire({"position": point + Vector3.UP * size * 0.38, "life": 0.52, "max_life": 0.52, "size": size, "angle": angle, "fade": false})
	for index in 2:
		fireballs.set_part(effect, index, "quad", Vector3.ONE, Color.WHITE if index == 0 else Color("ffd18a"), Vector3.ZERO if index == 0 else Vector3(-0.12, -0.02, 0.05) * size, Vector3.ZERO, false, index == 1)
	effect.parts[1].sorting_offset = size * 0.16
	effect.light.position.y = size * 0.28
	effect.light.omni_range = 22.0 + size * 8.0
	_apply_fireball(effect)
	for index in 4:
		var particle_size: float = random.between(0.16, 0.34) * size
		var smoke_seed: float = random.next_float()
		var smoke_point := point + Vector3(random.between(-0.6, 0.6) * size, random.between(0.15, 1.0) * size, random.between(-0.6, 0.6) * size)
		var velocity := Vector3(random.between(-1.7, 1.7), random.between(1.5, 3.4), random.between(-1.7, 1.7)) * size
		_spawn_smoke(smoke_point, particle_size * 4.3, Color("6b5142") if fiery and index == 0 else Color("77736d"), 0.72 if fiery and index == 0 else 0.62, 1.04, smoke_seed, velocity, random.between(0.62, 1.16), 1.16, 0.08, 1.3, 0.3)
	spawn_crash_debris(point, minf(2.5, size), "mixed" if fiery else "stone")
	spawn_scorch(point, 0.75 * size if ground_size < 0.0 else ground_size, ground_size < 0.0)
	var impact := MathRules.impact(listener_position.distance_to(point), 34.0 + size * 18.0, minf(0.78, 0.2 + size * 0.22))
	if impact > 0.0:
		screen_impact.emit(impact)

func _spawn_smoke(point: Vector3, size: float, color: Color, opacity: float, density: float, seed_value: float, velocity: Vector3, life: float, max_life: float, gravity: float, drag: float, shrink: float, grow: float = 0.0) -> void:
	var entry: Dictionary = smoke.acquire({"position": point, "scale": Vector3.ONE * size, "velocity": velocity, "life": life, "max_life": max_life, "gravity": gravity, "drag": drag, "shrink": shrink, "grow": grow, "opacity": opacity, "seed": seed_value, "fade": false})
	smoke.set_part(entry, 0, "quad", Vector3.ONE, Color.WHITE)
	var material: ShaderMaterial = entry.parts[0].material_override
	material.set_shader_parameter("uColor", Vector3(color.r, color.g, color.b))
	material.set_shader_parameter("uDensity", density)
	_apply_smoke(entry)

func impact_burst(point: Vector3) -> void:
	for index in SPARK_COUNT:
		var velocity := Vector3(random.between(-4.0, 4.0), random.between(1.5, 4.0), random.between(-4.0, 4.0))
		var effect: Dictionary = transient.acquire({"position": point, "velocity": velocity, "life": SPARK_LIFE, "max_life": SPARK_LIFE, "shrink": 2.0, "gravity": 7.0, "drag": 0.35})
		var color := Color("ffd17a") if index % 2 == 0 else Color("fff1ca")
		transient.set_part(effect, 0, "box", Vector3(0.022, random.between(0.16, 0.32), 0.022), color, Vector3.ZERO, Vector3.ZERO, false, true)
		effect.parts[0].quaternion = Quaternion(Vector3.UP, velocity.normalized())

func spawn_healing_burst(point: Vector3) -> void:
	spawn_shockwave(point, 1.2, Color("6eff9a"))
	for index in 9:
		var size: float = random.between(0.09, 0.2)
		var origin := point + Vector3(random.between(-1, 1), random.between(0.4, 2.1), random.between(-1, 1))
		var velocity := Vector3(random.between(-2, 2), random.between(1.5, 4.2), random.between(-2, 2))
		var effect: Dictionary = transient.acquire({"position": origin, "velocity": velocity, "life": random.between(0.6, 1.15), "max_life": 1.15, "gravity": 1.4, "drag": 0.6, "shrink": 0.7})
		var color := Color.WHITE if index % 3 == 0 else Color("67e98a")
		color.a = 0.85
		transient.set_part(effect, 0, "sphere", Vector3.ONE * size, color)

func sync_state(state: Dictionary, delta: float) -> void:
	jammer_field.player_view = player_view
	jammer_field.sync_state(state)
	listener_position = state.get("player", {}).get("position", listener_position)
	var shots: Array = state.get("projectiles", [])
	rockets.sync_projectiles(shots, delta)
	var alive := {}
	for shot: Dictionary in shots:
		if shot.kind == "rocket":
			continue
		alive[shot.id] = true
		var timer: float = _trail_timers.get(shot.id, 0.0) - delta
		if timer <= 0.0 and delta > 0.0:
			_projectile_trail(shot)
			var enemy: bool = shot.team == "enemy"
			timer = (0.11 if enemy else 0.09) if shot.kind == "grenade" else (0.14 if enemy else 0.085) if shot.kind == "sabot" else (0.16 if enemy else 0.095)
		_trail_timers[shot.id] = timer
	for id in _trail_timers.keys():
		if not alive.has(id):
			_trail_timers.erase(id)
	_update_damage_smoke(state, delta)
	tracks.sync_state(state, delta, self)
	_limit()

func _projectile_trail(shot: Dictionary) -> void:
	var enemy: bool = shot.team == "enemy"
	var size := (0.075 if enemy else 0.065) if shot.kind == "sabot" else 0.045 if enemy else 0.038
	var color := Color("89d8ff") if shot.kind == "sabot" else Color("ffc96b")
	var life := 0.12 if shot.kind == "sabot" else 0.08
	var explosive: bool = shot.kind == "grenade"
	if explosive:
		color = Color("2c2421") if random.next_float() < 0.55 else Color("9f392c")
		size = random.between(0.11 if enemy else 0.09, 0.19 if enemy else 0.16)
		life = 0.42
	color.a = 0.55 if explosive else 0.82
	var point: Vector3 = shot.position + Vector3(random.between(-0.08, 0.08), random.between(-0.08, 0.08), random.between(-0.08, 0.08))
	var velocity: Vector3 = shot.velocity * -0.035 + Vector3(random.between(-0.25, 0.25), random.between(0.04, 0.38), random.between(-0.25, 0.25))
	var effect: Dictionary = transient.acquire({"position": point, "velocity": velocity, "life": life, "max_life": life, "gravity": 0.2 if explosive else 0.0, "drag": 2.4, "shrink": 1.5})
	transient.set_part(effect, 0, "sphere", Vector3.ONE * size, color, Vector3.ZERO, Vector3.ZERO, false, true)

func _process(delta: float) -> void:
	advance_cinematic(float(time_delta.call(delta)) if time_delta.is_valid() else delta)

func advance_cinematic(delta: float) -> void:
	if _warmup or delta <= 0.0:
		return
	for pool in [transient, fireballs, traces, smoke]:
		pool.advance(delta)
	for entry: Dictionary in fireballs.entries:
		if entry.life > 0.0:
			_apply_fireball(entry)
	for entry: Dictionary in smoke.entries:
		if entry.life > 0.0:
			_apply_smoke(entry)
	rockets.advance(delta)
	dust.advance(delta)
	wrecks.advance(delta)
	player_destruction.advance(delta)
	hulls.advance(delta)
	support_pickup.advance(delta)
	jammer_field.advance(delta)

func _apply_fireball(entry: Dictionary) -> void:
	var state := MathRules.fireball(entry.life)
	var size: float = entry.size
	entry.parts[0].scale = Vector3(size * 4.9 * state.width, size * 4.15 * state.height, 1)
	var core: float = 0.39 + state.progress * 0.38
	entry.parts[1].scale = Vector3(size * 4.9 * core, size * 4.15 * core * 0.88, 1)
	entry.parts[0].material_override.set_shader_parameter("opacity", state.opacity)
	entry.parts[1].material_override.set_shader_parameter("opacity", state.opacity * state.light * 0.92)
	entry.parts[0].material_override.set_shader_parameter("angle", entry.angle + state.progress * 0.08)
	entry.parts[1].material_override.set_shader_parameter("angle", entry.angle + PI * 0.37 - state.progress * 0.12)
	entry.light.light_energy = 54.0 * maxf(0.65, size) * state.light

func _apply_smoke(entry: Dictionary) -> void:
	var remaining := clampf(entry.life / entry.max_life, 0, 1)
	var opacity: float = entry.opacity * minf(1.0, entry.age / 0.18) * remaining * remaining * (3.0 - 2.0 * remaining)
	var material: ShaderMaterial = entry.parts[0].material_override
	material.set_shader_parameter("uOpacity", opacity)
	material.set_shader_parameter("uSeed", entry.seed)
	material.set_shader_parameter("uTime", entry.seed * 2.7 + entry.age)

func _limit() -> void:
	var active: Array[Dictionary] = []
	for pool in [transient, fireballs, traces, smoke, hulls.pool]:
		for entry: Dictionary in pool.entries:
			if entry.life > 0.0:
				active.append(entry)
	while active.size() > 185:
		var oldest := -1
		for index in active.size():
			if active[index].max_life < 120.0 and (oldest < 0 or active[index].sequence < active[oldest].sequence):
				oldest = index
		if oldest < 0:
			oldest = 0
		var entry: Dictionary = active.pop_at(oldest)
		entry.life = 0.0
		entry.visual.visible = false

func reset_effects() -> void:
	for pool in [transient, fireballs, traces, smoke, dust.pool]:
		pool.reset_pool()
	rockets.reset()
	wrecks.reset()
	tracks.reset()
	player_destruction.reset()
	support_pickup.reset()
	jammer_field.reset()
	hulls.reset()
	random = VisualRandom.new()
	_scorch_bag.clear()
	_last_scorch = -1
	_trail_timers.clear()
	_smoke_timers.clear()

func _prepare_warmup() -> void:
	# Dedicated previews never acquire a gameplay slot or consume visual/gameplay RNG.
	for pool in [transient, fireballs, traces, smoke, rockets.pool, dust.pool]:
		for key in pool.meshes:
			if pool != transient and key != "quad":
				continue
			for part_index in (2 if pool == fireballs else 1):
				var preview := MeshInstance3D.new()
				preview.mesh = pool.meshes[key]
				preview.material_override = pool.entries[0].parts[part_index].material_override
				preview.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				preview.position = Vector3(0, 3, 0)
				preview.visible = false
				add_child(preview)
				_warmup_nodes.append(preview)
	for texture in [FIREBALL, BLOOD] + SCORCHES:
		var preview := MeshInstance3D.new()
		preview.mesh = transient.meshes.quad
		var material := StandardMaterial3D.new()
		material.albedo_texture = texture
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		preview.material_override = material
		preview.position = Vector3(0, 3, 0)
		preview.visible = false
		add_child(preview)
		_warmup_nodes.append(preview)

func set_warmup_visible(enabled: bool) -> void:
	_warmup = enabled
	support_pickup.set_warmup(enabled, listener_position + Vector3.UP)
	jammer_field.set_warmup(enabled, listener_position + Vector3.UP * 2)
	tracks.set_warmup(enabled, listener_position + Vector3.UP)
	wrecks.set_warmup(enabled)
	player_destruction.set_warmup(enabled)
	hulls.set_warmup(enabled)
	for preview: Node3D in _warmup_nodes:
		preview.visible = enabled

func spawn_leaf_burst(point: Vector3, count: int = 7) -> void:
	for _index in maxi(3, floori(count * 0.82)):
		var size := Vector3(random.between(0.08, 0.18), 0.025, random.between(0.16, 0.32))
		var origin := point + Vector3(random.between(-0.8, 0.8), random.between(0.2, 1.4), random.between(-0.8, 0.8))
		var velocity := Vector3(random.between(-2.4, 2.4), random.between(1.8, 4.8), random.between(-2.4, 2.4))
		var spin := Vector3(random.between(-7, 7), random.between(-9, 9), random.between(-7, 7))
		var effect: Dictionary = transient.acquire({"position": origin, "velocity": velocity, "spin": spin, "life": random.between(0.8, 1.55), "max_life": 1.55, "gravity": 2.8, "drag": 0.45, "shrink": 0.22})
		transient.set_part(effect, 0, "box", size, Color("5f7d42"))

func _update_damage_smoke(state: Dictionary, delta: float) -> void:
	if delta <= 0.0:
		return
	var targets: Array = state.get("enemies", []).duplicate()
	var player: Dictionary = state.get("player", {})
	if not player.is_empty():
		var vehicle := player.duplicate()
		vehicle.id = "player"
		vehicle.type = "player"
		targets.append(vehicle)
	var alive := {}
	for target: Dictionary in targets:
		if target.get("dead", false) or target.get("max_hp", 0.0) <= 0.0 or target.get("type") == "soldier":
			continue
		alive[target.id] = true
		var ratio: float = target.hp / target.max_hp
		var player_target: bool = target.get("type") == "player"
		var timer: float = _smoke_timers.get(target.id, 0.0)
		if player_target or ratio <= 0.42:
			timer -= delta
		if ratio < (0.4 if player_target else 0.42000001) and timer <= 0.0:
			var point: Vector3 = target.position
			point.y = 4.7 if player_target else (5.25 * [1.18, 1.24, 1.3][clampi(int(target.get("tier", 1)), 1, 3) - 1]) if target.get("type") == "garrison" else 6.0 if target.get("boss", false) else 2.0
			spawn_damage_smoke(point, ratio < 0.2)
			timer = (0.1 if ratio < 0.2 else 0.23) if player_target else (0.12 if ratio < 0.2 else 0.25)
		_smoke_timers[target.id] = timer
	for id in _smoke_timers.keys():
		if not alive.has(id):
			_smoke_timers.erase(id)

func spawn_damage_smoke(point: Vector3, severe: bool = false) -> void:
	var size: float = random.between(0.22, 0.48)
	var seed_value: float = random.next_float()
	var origin := point + Vector3(random.between(-0.6, 0.6), random.between(0.2, 0.9), random.between(-0.6, 0.6))
	var velocity := Vector3(random.between(-0.35, 0.35), random.between(1.1, 2.2), random.between(-0.35, 0.35))
	_spawn_smoke(origin, size * 4.1, Color("20201f") if severe else Color("4b4d49"), 0.78 if severe else 0.64, 1.08 if severe else 0.92, seed_value, velocity, random.between(1.4, 2.5), 2.5, -0.08, 0.35, 0.0, size * 0.14)
	if severe and random.next_float() < 0.25:
		origin = point + Vector3(random.between(-0.4, 0.4), 0.7, random.between(-0.4, 0.4))
		velocity = Vector3(random.between(-1, 1), random.between(1, 3), random.between(-1, 1))
		var effect: Dictionary = transient.acquire({"position": origin, "velocity": velocity, "life": 0.35, "max_life": 0.35, "gravity": 5.0, "drag": 0.1, "shrink": 1.5})
		transient.set_part(effect, 0, "sphere", Vector3.ONE * 0.06, Color(1.0, 0.4784, 0.1843, 0.95))

func spawn_embedded_projectile(event: Dictionary) -> void:
	var kind := str(event.get("projectile_kind", "bullet"))
	if kind in ["rocket", "grenade"]:
		return
	var sabot := kind == "sabot"
	var point: Vector3 = event.get("position", Vector3.ZERO)
	point.y = 0.16
	var entry: Dictionary = transient.acquire({"position": point, "life": random.between(1.8, 3.3), "max_life": 3.3, "fade": false, "shrink": 0.08})
	var velocity: Vector3 = event.get("velocity", Vector3.ZERO) * Vector3(1, 0, 1)
	if velocity.length_squared() > 0.001:
		entry.visual.basis = Basis(Quaternion(Vector3.UP, velocity.normalized())) * Basis(Vector3.RIGHT, 0.28)
	transient.set_part(entry, 0, "cylinder6", Vector3(0.055 if sabot else 0.032, 1.05 if sabot else 0.32, 0.055 if sabot else 0.032), Color("34383a"), Vector3.ZERO, Vector3.ZERO, true)

func _sort_scorches() -> void:
	var active: Array = traces.entries.filter(func(entry: Dictionary) -> bool: return entry.life > 0.0)
	active.sort_custom(func(first: Dictionary, second: Dictionary) -> bool: return first.sequence < second.sequence)
	for index in active.size():
		active[index].parts[0].material_override.render_priority = -96 + index
