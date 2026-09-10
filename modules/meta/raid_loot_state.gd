extends RefCounted

# The raid loot owner has no scene dependency and keeps only gameplay fields.
const Catalog = preload("res://modules/meta/expedition_catalog.gd")

const CAPACITY := 64
const COLLECT_RADIUS := 4.5
const ITEM_SPACING := 2.4
const PHASE_SPACING := 0.7

var _records: Array[Dictionary] = []
var _seen: Dictionary = {}
var _spawn_index := 0

func records() -> Array[Dictionary]:
	return _records.duplicate(true)

func reset() -> void:
	_records.clear()
	_seen.clear()
	_spawn_index = 0

func on_event(event: Dictionary) -> Dictionary:
	if event.get("kind", "") != "activity_completed" or not event.has("loot_source"):
		return {}
	var id := "activity:" + str(event.get("id", ""))
	var count := int(event.get("loot_count", 1))
	if _seen.has(id) or _records.size() >= CAPACITY or count <= 0:
		return {}
	_seen[id] = true
	var source := str(event.loot_source)
	var item := Catalog.loot_item(source, _spawn_index)
	_spawn_index += 1
	var record := {"id": id, "position": event.get("position", Vector3.ZERO), "source": source, "item": item, "count": count, "phase": float(_spawn_index) * PHASE_SPACING}
	_records.append(record)
	return record.duplicate(true)

func spawn_items(id: String, point: Vector3, items: Dictionary) -> Array[Dictionary]:
	var created: Array[Dictionary] = []
	var index := 0
	for item: String in items:
		var count := int(items[item])
		if count <= 0:
			continue
		var offset := Vector3.ZERO
		if items.size() > 1:
			var angle := TAU * index / items.size()
			offset = Vector3(cos(angle), 0, sin(angle)) * ITEM_SPACING
		var record := on_event({"kind": "activity_completed", "id": "cargo:" + id + ":" + item, "position": point + offset, "loot_source": item, "loot_count": count})
		if not record.is_empty():
			created.append(record)
		index += 1
	return created

func claim(id: String, receiver: RefCounted) -> Dictionary:
	for index in _records.size():
		var record: Dictionary = _records[index]
		if str(record.id) != id or int(record.count) <= 0:
			continue
		if not receiver.collect_loot(str(record.item), 1):
			return {}
		record.count -= 1
		var removed := int(record.count) == 0
		if removed:
			_records.remove_at(index)
		return {"record": record.duplicate(true), "removed": removed}
	return {}

func collect_near(point: Vector3, receiver: RefCounted) -> Array[Dictionary]:
	var claimed: Array[Dictionary] = []
	for record: Dictionary in _records.duplicate():
		var offset: Vector3 = point - record.position
		offset.y = 0
		if offset.length() > COLLECT_RADIUS:
			continue
		while int(record.count) > 0:
			var result := claim(str(record.id), receiver)
			if result.is_empty():
				break
			claimed.append(result)
	return claimed
