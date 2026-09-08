extends SceneTree

const Loot = preload("res://presentation/world/raid_loot.gd")
const Catalog = preload("res://modules/meta/expedition_catalog.gd")
const Motion = preload("res://presentation/world/pickup_motion.gd")
const CombatView = preload("res://presentation/combat/combat_view.gd")
const Models = preload("res://presentation/ui/item_loot_models.gd")
const Locale = preload("res://presentation/ui/ui_locale.gd")
const Cargo = preload("res://modules/crew/crew_cargo.gd")

class Receiver extends RefCounted:
	var accepted := true
	var items: Dictionary = {}
	func collect_loot(item: String, count: int = 1) -> bool:
		if not accepted:
			return false
		items[item] = int(items.get(item, 0)) + count
		return true

var checks := 0
var failures := 0
func _init() -> void:
	_run.call_deferred()
func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: ", message)
func _run() -> void:
	Locale.initialize()
	Locale.language = "en"
	var loot := Loot.new()
	root.add_child(loot)
	loot.set_process(false)
	var receiver := Receiver.new()
	var point := Vector3(30, 0, 20)
	for id: String in Catalog.ITEMS:
		loot.spawn_items(id, point, {id: 2})
		var crate: Dictionary = loot.crates.back()
		check(crate.item == id and crate.label.text == Catalog.item_name(id) + " ×2", "World label identifies " + id + " before collection")
		var inventory_model := Models.build(id)
		check(crate.model.get_child(0).mesh == inventory_model.get_child(0).mesh, "World and inventory share cached " + id + " mesh")
		inventory_model.free()
	var basis: Basis = loot.crates[0].model.basis
	loot.advance(0.25)
	check(not loot.crates[0].model.basis.is_equal_approx(basis), "Pickable models rotate")
	check(loot.crates[0].view.basis.is_equal_approx(Basis.IDENTITY), "Names remain upright while models rotate")
	var pickup := {"position": point, "phase": 0.7}
	check(CombatView.pickup_transform(pickup, 1.3).is_equal_approx(Motion.pose(point, 1.3, 0.7)), "Scrap and item drops reuse the same pickup motion")
	Locale.language = "ru"
	loot.advance(0)
	check(loot.crates[1].label.text == "Электроника ×2", "Existing drop labels follow language changes")
	receiver.accepted = false
	var crate: Dictionary = loot.crates[1]
	check(not loot.claim(crate.id, receiver) and crate.count == 2, "Full inventory preserves the visible item and quantity")
	receiver.accepted = true
	check(loot.claim(crate.id, receiver) and receiver.items.get("circuit", 0) == 1 and crate.label.text == "Электроника", "Partial collection transfers the shown electronics and updates quantity")
	var cargo := Cargo.new()
	check(loot.claim(crate.id, cargo) and cargo.parcel.source == "circuit", "Crew parcel preserves the displayed item identity")
	loot.reset()
	for index in 5:
		loot.on_event({"kind": "activity_completed", "id": str(index), "loot_source": "unknown_base", "position": point})
	check(loot.crates[4].item == "circuit", "Fallback electronics roll is resolved at spawn")
	check(loot.claim(loot.crates[4].id, receiver) and receiver.items.circuit == 2, "Collecting drops out of order still gives the displayed item")
	loot.on_event({"kind": "activity_completed", "id": "convoy", "loot_source": "convoy", "loot_count": 2, "position": point})
	check(loot.crates.back().item == "weapon_parts" and loot.crates.back().source == "convoy", "Activity source retained alongside resolved weapon kit")
	var count := loot.crates.size()
	loot.on_event({"kind": "activity_completed", "id": "convoy", "loot_source": "convoy", "position": point})
	check(loot.crates.size() == count, "Repeated activity events do not duplicate loot")
	loot.reset()
	loot.spawn_items("wagon", point, {"scrap": 1, "circuit": 1, "relic": 1})
	check(loot.crates[0].position.distance_to(loot.crates[1].position) > 1, "Different wagon cargo models do not overlap")
	check(not loot.collect_near(point + Vector3(20, 0, 0), receiver), "Remote player cannot collect")
	check(loot.collect_near(point, receiver) and loot.crates.is_empty(), "Nearby player collects all separated wagon cargo")
	loot.free()
	await process_frame
	print("Raid loot: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
