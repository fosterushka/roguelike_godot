extends SceneTree
const Gallery = preload("res://presentation/debug/model_gallery.tscn")
var failures := 0
var checks := 0

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var gallery := Gallery.instantiate()
	root.add_child(gallery)
	await gallery.gallery_ready
	check(gallery.errors.is_empty(), "Every named gallery entry has visible model geometry: " + str(gallery.errors))
	var ids := {}
	for entry: Dictionary in gallery.entries:
		check(not ids.has(entry.id), "Unique model identity " + entry.id)
		ids[entry.id] = true
	for enemy: String in gallery.Catalog.Enemies.DEFINITIONS:
		check(ids.has(gallery.Catalog.NPC + "/" + enemy), "All combat NPC catalog entries represented")
	for wagon: String in gallery.Catalog.Wagons.TYPES:
		check(ids.has(gallery.Catalog.VEHICLES + "/" + wagon), "All real wagon models represented")
	gallery.panel.search.text = "airdrop"
	gallery.panel._filter()
	check(gallery.panel.listing.item_count > 0 and gallery.panel.listing.item_count < gallery.entries.size(), "Search filters model inventory")
	gallery.panel.search.text = ""
	gallery.panel._filter()
	gallery.focus_model(gallery.entries.size() - 1)
	check(gallery.camera.target.is_equal_approx(gallery.displays.back().center), "Selecting list entry focuses its actual model")
	gallery.overview()
	check(gallery.camera.target_span >= gallery.map_bounds.size.z, "Overview includes complete single-scene map")
	print("Model gallery: %d checks, %d failures, %d models" % [checks, failures, gallery.entries.size()])
	gallery.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)
