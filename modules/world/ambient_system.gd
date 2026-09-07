extends RefCounted
const Wildlife = preload("res://modules/world/wildlife_rules.gd")
const Dimensions = preload("res://modules/caravan/player_dimensions.gd")
const Terrain = preload("res://modules/caravan/terrain_surface.gd")

const Random = preload("res://modules/world/activities/source_random.gd")
var random := Random.new()
var critters: Array = []
var animators: Array = []
var _initial: Array = []
var rewards: Array[Vector3] = []
var _previous_player := Vector3.INF

func bind(generated: RefCounted) -> void:
	critters = generated.ambient_critters if generated != null else []
	animators = generated.ambient_animators if generated != null else []
	_initial.clear()
	for critter: Dictionary in critters:
		var state := critter.duplicate()
		state.transform = critter.group.transform
		_initial.append(state)
	for animator: Dictionary in animators:
		animator.initial_phase = animator.get("phase", 0.0)
		animator.initial_rotation = animator.object.rotation

func reset(seed_value: int) -> void:
	random.state = seed_value & 0xffffffff
	rewards.clear()
	_previous_player = Vector3.INF
	for index in critters.size():
		critters[index].merge(_initial[index], true)
		critters[index].group.transform = _initial[index].transform
	for animator: Dictionary in animators:
		animator.phase = animator.initial_phase
		animator.object.rotation = animator.initial_rotation

func step(delta: float, enemies: Array, severe_weather: bool, wind_strength: float = 0.0, player_position: Vector3 = Vector3.INF, player_speed: float = 0.0, player_scale: float = Dimensions.BASE_SCALE) -> void:
	for animator: Dictionary in animators:
		if animator.type == "windmill":
			animator.object.rotation.z -= delta * animator.speed * (1.0 + wind_strength * 0.035)
		elif animator.type == "pumpjack":
			animator.phase += delta * animator.speed * (1.0 + wind_strength * 0.006)
			animator.object.rotation.z = sin(animator.phase) * animator.amplitude
	var threats := enemies.filter(func(enemy: Dictionary) -> bool: return enemy.get("type", "") != "garrison" and not enemy.get("dead", false) and float(enemy.get("hp", 0)) > 0 and enemy.get("allegiance", "enemy") != "friendly")
	if player_position.is_finite():
		threats.append({"position": player_position})
	var previous := _previous_player if _previous_player.is_finite() else player_position
	for critter: Dictionary in critters:
		if critter.get("dead", false):
			Wildlife.settle(critter, delta)
			continue
		if Wildlife.run_over(critter, previous, player_position, player_speed, Dimensions.radius(player_scale)):
			rewards.append(critter.group.position)
			continue
		critter.phase += delta * 2.0
		critter.turn -= delta
		if critter.turn <= 0.0 and critter.activityState == "roaming":
			critter.heading += random.between(-1.2, 1.2)
			critter.turn = random.between(2, 5)
		update_behavior(critter, delta, threats, severe_weather, random)
		critter.group.position.y = Terrain.height_at(critter.group.position.x, critter.group.position.z) + sin(critter.phase) * 0.018
		critter.group.rotation.y = critter.heading
	_previous_player = player_position

static func update_behavior(critter: Dictionary, delta: float, threats: Array, severe_weather: bool, rng: RefCounted) -> String:
	var point: Vector3 = critter.group.position
	var nearest: Variant = null
	var nearest_distance := 42.0 * 42.0
	for threat: Dictionary in threats:
		var source: Vector3 = threat.get("position", threat.get("pos", Vector3.INF))
		var distance := Vector2(point.x - source.x, point.z - source.z).length_squared()
		if distance < nearest_distance:
			nearest = source
			nearest_distance = distance
	if nearest != null or severe_weather:
		var source: Vector3 = nearest if nearest != null else critter.origin
		var away := Vector2(point.x - source.x, point.z - source.z)
		if absf(away.x) + absf(away.y) < 0.01:
			var angle: float = rng.between(0, TAU)
			away = Vector2(sin(angle), cos(angle))
		critter.heading = atan2(away.x, away.y)
		critter.fleeRemaining = 2.5 if severe_weather else 3.5
		critter.activityState = "fleeing"
	elif float(critter.get("fleeRemaining", 0)) > 0:
		critter.fleeRemaining = maxf(0, critter.fleeRemaining - delta)
		critter.activityState = "fleeing" if critter.fleeRemaining > 0 else "recovering"
	elif critter.get("activityState", "") == "recovering":
		critter.recoveryRemaining = maxf(0, critter.get("recoveryRemaining", 2) - delta)
		if critter.recoveryRemaining <= 0:
			critter.activityState = "roaming"
			critter.recoveryRemaining = 2
	else:
		critter.activityState = "roaming"
	var offset := Vector2(point.x - critter.origin.x, point.z - critter.origin.z)
	var radius := 18.0 if critter.activityState == "fleeing" else 8.0
	if offset.length_squared() > radius * radius:
		critter.heading = atan2(-offset.x, -offset.y)
	var multiplier := 4.5 if critter.activityState == "fleeing" else 1.8 if critter.activityState == "recovering" else 1.0
	point.x += sin(critter.heading) * critter.speed * multiplier * delta
	point.z += cos(critter.heading) * critter.speed * multiplier * delta
	critter.group.position = point
	return critter.activityState
