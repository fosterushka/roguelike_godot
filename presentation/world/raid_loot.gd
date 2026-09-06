extends Node3D

const Ground = preload("res://modules/caravan/terrain_surface.gd")
var crates: Array[Dictionary] = []
var _mesh := BoxMesh.new()
var _material := StandardMaterial3D.new()
var _seen: Dictionary = {}

func _init() -> void:
	_mesh.size = Vector3(1.6, 1.2, 1.2)
	_material.albedo_color = Color("e8be65")
	_material.emission_enabled = true
	_material.emission = Color("9b742f")
	_material.emission_energy_multiplier = 0.3
	_mesh.material = _material

func reset() -> void:
	for crate: Dictionary in crates:
		crate.view.queue_free()
	crates.clear()
	_seen.clear()

func on_event(event: Dictionary) -> void:
	if event.get("kind", "") != "activity_completed" or not event.has("loot_source"):
		return
	var id := "activity:" + str(event.get("id", ""))
	if _seen.has(id) or crates.size() >= 64:
		return
	_seen[id] = true
	var point: Vector3 = event.get("position", Vector3.ZERO)
	point.y = Ground.height_at(point.x, point.z) + 0.8
	var mesh := MeshInstance3D.new()
	mesh.mesh = _mesh
	mesh.position = point
	add_child(mesh)
	var label := Label3D.new()
	label.text = "ДОБЫЧА" if preload("res://presentation/ui/ui_locale.gd").language == "ru" else "LOOT"
	label.font_size = 48
	label.pixel_size = 0.025
	label.position.y = 2.6
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	mesh.add_child(label)
	crates.append({"id": id, "view": mesh, "position": point, "source": str(event.loot_source), "count": int(event.get("loot_count", 1))})

func spawn_items(id: String, point: Vector3, items: Dictionary) -> void:
	for item: String in items:
		var count := int(items[item])
		if count > 0:
			on_event({"kind": "activity_completed", "id": "cargo:" + id + ":" + item, "position": point, "loot_source": item, "loot_count": count})

func claim(id: String, expedition: RefCounted) -> bool:
	for index in crates.size():
		var crate: Dictionary = crates[index]
		if str(crate.id) != id or int(crate.count) <= 0:
			continue
		if not expedition.collect_loot(str(crate.source), 1):
			return false
		crate.count -= 1
		if crate.count == 0:
			crate.view.queue_free()
			crates.remove_at(index)
		return true
	return false

func collect_near(point: Vector3, expedition: RefCounted) -> bool:
	var collected := false
	for crate: Dictionary in crates.duplicate():
		var offset: Vector3 = point - crate.position
		offset.y = 0
		if offset.length() > 4.5:
			continue
		while int(crate.count) > 0 and claim(str(crate.id), expedition):
			collected = true
	return collected
