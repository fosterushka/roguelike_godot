extends Node3D

const Catalog = preload("res://modules/meta/expedition_catalog.gd")
const LootState = preload("res://modules/meta/raid_loot_state.gd")
const Models = preload("res://presentation/ui/item_loot_models.gd")
const Motion = preload("res://presentation/world/pickup_motion.gd")
const Locale = preload("res://presentation/ui/ui_locale.gd")
const LABEL_HEIGHT := 2.6
const LABEL_FONT_SIZE := 48
const LABEL_PIXEL_SIZE := 0.016
var state := LootState.new()
# Compatibility surface for callers that read crate ids and positions. These
# are presentation projections; state is the only owner of live loot values.
var crates: Array[Dictionary] = []
var _views: Dictionary = {}
var _elapsed := 0.0

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
		_free_view(crate)
	crates.clear()
	_views.clear()
	state.reset()
	_elapsed = 0.0

func on_event(event: Dictionary) -> void:
	var crate := state.on_event(event)
	if crate.is_empty():
		return
	_project(crate)

func _project(record: Dictionary) -> void:
	var id := str(record.id)
	if _views.has(id):
		var existing: Dictionary = _views[id]
		existing.merge(record, true)
		_update_view(existing)
		return
	var crate := record.duplicate(true)
	var item := str(crate.item)
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
	crate.view = view
	crate.model = model
	crate.label = label
	_views[id] = crate
	crates.append(crate)
	_update_view(crate)

func spawn_items(id: String, point: Vector3, items: Dictionary) -> void:
	for crate: Dictionary in state.spawn_items(id, point, items):
		_project(crate)

func claim(id: String, expedition: RefCounted) -> bool:
	var result := state.claim(id, expedition)
	if result.is_empty():
		return false
	var crate: Dictionary = result.record
	if result.removed:
		_remove_view(crate)
	else:
		_project(crate)
	return true

func collect_near(point: Vector3, expedition: RefCounted) -> bool:
	var claimed := state.collect_near(point, expedition)
	for result: Dictionary in claimed:
		var crate: Dictionary = result.record
		if result.removed:
			_remove_view(crate)
		else:
			_project(crate)
	return not claimed.is_empty()

func _remove_view(record: Dictionary) -> void:
	var id := str(record.id)
	if not _views.has(id):
		return
	var crate: Dictionary = _views[id]
	crate.merge(record, true)
	_free_view(crate)
	crates.erase(crate)
	_views.erase(id)

func _free_view(crate: Dictionary) -> void:
	if crate.has("view") and is_instance_valid(crate.view):
		crate.view.queue_free()
