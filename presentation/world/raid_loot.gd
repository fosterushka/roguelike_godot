extends Node3D

const Catalog = preload("res://modules/meta/expedition_catalog.gd")
const Models = preload("res://presentation/ui/item_loot_models.gd")
const Motion = preload("res://presentation/world/pickup_motion.gd")
const Locale = preload("res://presentation/ui/ui_locale.gd")
const CAPACITY := 64
const COLLECT_RADIUS := 4.5
const LABEL_HEIGHT := 2.6
const LABEL_FONT_SIZE := 48
const LABEL_PIXEL_SIZE := 0.016
const ITEM_SPACING := 2.4
const PHASE_SPACING := 0.7
var crates: Array[Dictionary] = []
var _seen: Dictionary = {}
var _elapsed := 0.0
var _spawn_index := 0

func _process(delta: float) -> void:
	advance(delta)

func advance(delta: float) -> void:
	_elapsed += maxf(0.0, delta)
	for crate: Dictionary in crates:
		_update_view(crate)

func _update_view(crate: Dictionary) -> void:
	var pose := Motion.pose(crate.position, _elapsed, float(crate.phase))
	crate.view.position = pose.origin
	crate.model.basis = pose.basis
	var text := Catalog.item_name(str(crate.item), Locale.language)
	if int(crate.count) > 1:
		text += " ×%d" % int(crate.count)
	if crate.label.text != text:
		crate.label.text = text

func reset() -> void:
	for crate: Dictionary in crates:
		crate.view.queue_free()
	crates.clear()
	_seen.clear()
	_elapsed = 0.0
	_spawn_index = 0

func on_event(event: Dictionary) -> void:
	if event.get("kind", "") != "activity_completed" or not event.has("loot_source"):
		return
	var id := "activity:" + str(event.get("id", ""))
	if _seen.has(id) or crates.size() >= CAPACITY or int(event.get("loot_count", 1)) <= 0:
		return
	_seen[id] = true
	var point: Vector3 = event.get("position", Vector3.ZERO)
	var source := str(event.loot_source)
	# Resolve once, before displaying or handing the item to a crew collector.
	var item := Catalog.loot_item(source, _spawn_index)
	_spawn_index += 1
	var view := Node3D.new()
	view.name = "Pickup_" + item
	var model := Models.build(item)
	view.add_child(model)
	add_child(view)
	var label := Label3D.new()
	label.font_size = LABEL_FONT_SIZE
	label.pixel_size = LABEL_PIXEL_SIZE
	label.position.y = LABEL_HEIGHT
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	view.add_child(label)
	var crate := {"id": id, "view": view, "model": model, "label": label, "position": point, "source": source, "item": item, "count": int(event.get("loot_count", 1)), "phase": float(_spawn_index) * PHASE_SPACING}
	crates.append(crate)
	_update_view(crate)

func spawn_items(id: String, point: Vector3, items: Dictionary) -> void:
	var index := 0
	for item: String in items:
		var count := int(items[item])
		if count > 0:
			var offset := Vector3.ZERO
			if items.size() > 1:
				var angle := TAU * index / items.size()
				offset = Vector3(cos(angle), 0, sin(angle)) * ITEM_SPACING
			on_event({"kind": "activity_completed", "id": "cargo:" + id + ":" + item, "position": point + offset, "loot_source": item, "loot_count": count})
			index += 1

func claim(id: String, expedition: RefCounted) -> bool:
	for index in crates.size():
		var crate: Dictionary = crates[index]
		if str(crate.id) != id or int(crate.count) <= 0:
			continue
		if not expedition.collect_loot(str(crate.item), 1):
			return false
		crate.count -= 1
		_update_view(crate)
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
		if offset.length() > COLLECT_RADIUS:
			continue
		while int(crate.count) > 0 and claim(str(crate.id), expedition):
			collected = true
	return collected
