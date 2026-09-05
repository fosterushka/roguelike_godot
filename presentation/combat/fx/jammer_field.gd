extends Node3D
const Terrain = preload("res://modules/caravan/terrain_surface.gd")
const RING_COUNT := 3
const SPARK_COUNT := 6
const SIGNAL := Color("bd84f5")
const REVERSED := Color("ff9cbc")
var rings: Array[MeshInstance3D] = []
var sparks: Array[MeshInstance3D] = []
var _visuals: Array[MeshInstance3D] = []
var elapsed := 0.0
var strength := 0.0
var _player: Dictionary = {}
var _warmup := false
var _preview: Node3D
var player_view: Node3D

func _ready() -> void:
	var ring_mesh := TorusMesh.new()
	ring_mesh.inner_radius = 0.986
	ring_mesh.outer_radius = 1.014
	ring_mesh.rings = 64
	ring_mesh.ring_segments = 4
	var spark_mesh := BoxMesh.new()
	spark_mesh.size = Vector3(0.045, 0.16, 0.5)
	for index in RING_COUNT:
		rings.append(_mesh(ring_mesh, self))
	for index in SPARK_COUNT:
		sparks.append(_mesh(spark_mesh, self))
	_visuals.assign(rings + sparks)
	_preview = Node3D.new()
	add_child(_preview)
	var ring := _mesh(ring_mesh, _preview)
	ring.visible = true
	ring.scale = Vector3(2, 0.35, 2)
	var spark := _mesh(spark_mesh, _preview)
	spark.visible = true
	spark.position = Vector3(0, 0.5, 0)
	_preview.visible = false

func _mesh(mesh: Mesh, parent: Node3D) -> MeshInstance3D:
	var visual := MeshInstance3D.new()
	visual.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(SIGNAL, 0.48)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	material.no_depth_test = false
	material.render_priority = 0
	visual.material_override = material
	visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	visual.visible = false
	parent.add_child(visual)
	return visual

func sync_state(state: Dictionary) -> void:
	if _warmup:
		return
	_player = state.get("player", {}).duplicate()
	strength = clampf(float(_player.get("jammer_strength", 0)), 0, 1)
	_apply()

func advance(delta: float) -> void:
	if _warmup or delta <= 0 or strength <= 0.001:
		return
	elapsed += delta
	_apply()

func _apply() -> void:
	var active := strength > 0.001 and float(_player.get("hp", 100)) > 0 and int(_player.get("jammer_source_id", -1)) >= 0
	for visual: MeshInstance3D in _visuals:
		visual.visible = active
	if not active:
		return
	var source: Vector3 = _player.get("jammer_source_position", Vector3.ZERO)
	source.y = Terrain.height_at(source.x, source.z) + 3.6
	var player_point: Vector3 = _player.get("position", Vector3.ZERO)
	if is_instance_valid(player_view):
		player_point = player_view.global_position
	var pulse := clampf(float(_player.get("jammer_pulse", 0)), 0, 1)
	var color := REVERSED if _player.get("jammer_reversed", false) else SIGNAL
	var wave_range := clampf(float(_player.get("jammer_radius", 48)) * 0.18, 2.0, 9.0)
	for index in RING_COUNT:
		var phase := fposmod(elapsed * 0.7 + index / float(RING_COUNT), 1)
		var radius := lerpf(1.0, wave_range, phase)
		var ring := rings[index]
		ring.position = source + Vector3.UP * phase * 1.1
		ring.scale = Vector3(radius, 0.4, radius)
		ring.material_override.albedo_color = Color(color, sin(phase * PI) * strength * (0.33 + pulse * 0.15))
	for index in SPARK_COUNT:
		var angle := index * TAU / float(SPARK_COUNT) + elapsed * 0.42
		var flicker := 0.5 + sin(elapsed * 8 + index * 2.7) * 0.5
		var spark := sparks[index]
		spark.position = player_point + Vector3(sin(angle) * 2.0, 1.5 + flicker * 0.8, cos(angle) * 2.0)
		spark.rotation = Vector3(0.25, -angle, sin(elapsed * 2 + index) * 0.45)
		spark.scale = Vector3(1, 1, 0.5 + pulse + flicker)
		spark.material_override.albedo_color = Color(color, strength * flicker * (0.28 + pulse * 0.16))

func reset() -> void:
	_player.clear()
	strength = 0
	elapsed = 0
	_apply()

func set_warmup(enabled: bool, point: Vector3) -> void:
	_warmup = enabled
	_preview.position = point
	_preview.visible = enabled
