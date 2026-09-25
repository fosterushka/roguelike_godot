extends SceneTree

const Visibility = preload("res://modules/combat/visibility_rules.gd")
const Combat = preload("res://modules/combat/combat_model.gd")
const Arena = preload("res://presentation/world/arena.gd")
const Source = preload("res://presentation/combat/source_model.gd")
const Fog = preload("res://presentation/world/local_fog_view.gd")
var checks := 0
var failures := 0

func _init() -> void:
	_run.call_deferred()

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(label)

func _run() -> void:
	var player := {"position": Vector3.ZERO, "heading": 0.0, "customization": {"fog_lamps": false}}
	check(Visibility.lamp_coverage(player, Vector3(0, 0, 20)) == 0.0, "Unowned lamps do not clear fog")
	player.customization.fog_lamps = true
	check(Visibility.lamp_coverage(player, Vector3(0, 0, 20)) > 0.85, "Equipped lamps clear forward sector")
	check(Visibility.lamp_coverage(player, Vector3(20, 0, 0)) == 0.0, "Lamps do not clear sideways")
	check(Visibility.lamp_coverage(player, Vector3(0, 0, -20)) == 0.0, "Lamps do not clear behind the vehicle")
	check(Visibility.lamp_coverage(player, Vector3(0, 0, 29)) == 0.0, "Beam has finite range")
	player.heading = PI * 0.5
	check(Visibility.lamp_coverage(player, Vector3(20, 0, 0)) > 0.85, "Beam follows heading")
	check(Visibility.range_multiplier(player, Vector3(20, 0, 0), 0.0) == 1.0, "Lamps never increase clear-weather weapon range")
	var model := Combat.new()
	model.reset_run(73)
	model.player.customization = {"fog_lamps": true}
	model.player.position = Vector3.ZERO
	model.player.heading = 0.0
	model.weather_fog_strength = 1.0
	var target := model.spawn_enemy("bike", Vector3(0, 0, 20))
	check(model.resolve_target(25.0, Vector3.ZERO, true).get("id") == target.id, "Weapon acquires enemy revealed by equipped lamps")
	model.player.heading = PI
	check(model.resolve_target(25.0, Vector3.ZERO, true).is_empty(), "Enemy outside beam retains fog range restriction")
	model.player.customization.fog_lamps = false
	model.player.heading = 0.0
	check(model.resolve_target(25.0, Vector3.ZERO, true).is_empty(), "Unequipping lamps removes acquisition benefit")
	var environment := Environment.new()
	environment.fog_enabled = true
	var fog := Fog.new()
	fog.setup(environment)
	fog.apply_state(player)
	check(not environment.fog_enabled and fog.visible, "Equipped lamps own local fog pass without double fog")
	player.customization.fog_lamps = false
	fog.apply_state(player)
	check(environment.fog_enabled and not fog.visible, "Unequipping restores native weather rendering")
	fog.free()
	_test_prop_lifecycle()
	var fade := preload("res://presentation/camera/occlusion_fade.gd").new()
	var record := {"id": "moving-tree", "position": Vector3.ZERO, "radius": 2.0, "bounds": AABB(Vector3.ZERO, Vector3.ONE * 4.0)}
	fade._records[record.id] = record
	fade._grid.insert(record)
	fade._move_prop(record.id, Vector3(200, 0, 0))
	check(fade._grid.nearby(Vector3.ZERO, 1.0).is_empty(), "Tornado-moved prop leaves old occlusion cell")
	check(fade._grid.nearby(Vector3(200, 0, 0), 1.0).size() == 1 and record.bounds.position.x == 200.0, "Moved prop bounds follow its current visual position")
	fade.free()
	print("Visibility QOL: %d/%d tests passed; %d failures" % [checks - failures, checks, failures])
	quit(1 if failures else 0)

func _test_prop_lifecycle() -> void:
	# Minimal arena fixture exercises the production owner, without loading the world.
	var arena := Arena.new()
	var source := Node3D.new()
	arena.source_world = source
	arena.add_child(source)
	var batch := MultiMeshInstance3D.new()
	batch.multimesh = MultiMesh.new()
	batch.multimesh.transform_format = MultiMesh.TRANSFORM_3D
	batch.multimesh.mesh = BoxMesh.new()
	batch.multimesh.instance_count = 2
	var material := StandardMaterial3D.new()
	batch.material_override = material
	source.add_child(batch)
	var identity := [1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1]
	arena._prop_records.test = {"kind": "building", "position": {"x": 0, "z": 0}, "parts": [{"mesh": 0, "instance": 0, "matrix": identity}]}
	var collider := StaticBody3D.new()
	arena.add_child(collider)
	arena._prop_colliders.test = collider
	arena.fade_prop("test", 0.8)
	check(arena._prop_fades.size() == 1 and collider.collision_layer == 1, "Fading never removes collision")
	check(material.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED, "Fading leaves shared source material unchanged")
	var proxy: Node3D = arena._prop_fades.test
	check(proxy.get_child(0).mesh == batch.multimesh.mesh, "Fade proxy reuses the original mesh")
	arena.set_prop_destroyed("test", true)
	check(not proxy.visible and collider.collision_layer == 0, "Destruction hides faded proxy and clears collider")
	arena.fade_prop("test", 0.0)
	check(arena._prop_fades.is_empty() and arena.is_prop_destroyed("test"), "Fade cleanup cannot resurrect destroyed prop")
	arena.set_prop_destroyed("test", false)
	check(collider.collision_layer == 1 and not arena.is_prop_destroyed("test"), "New run can restore prop normally")
	arena.free()
