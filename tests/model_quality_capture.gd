extends SceneTree

const Gallery = preload("res://presentation/debug/model_gallery.tscn")
const Catalog = preload("res://presentation/debug/gallery_catalog.gd")
const OUTPUT := "res://docs/validation/model-quality"
const SKIP := [Catalog.PARTS]

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	root.size = Vector2i(640, 480)
	var gallery := Gallery.instantiate()
	root.add_child(gallery)
	await gallery.gallery_ready
	gallery.panel.hide()
	var inventory := FileAccess.open("res://docs/validation/model-gallery/inventory.json", FileAccess.WRITE)
	inventory.store_string(JSON.stringify(gallery.entries,"\t"))
	inventory.close()
	var directory := ProjectSettings.globalize_path(OUTPUT)
	DirAccess.make_dir_recursive_absolute(directory)
	var manifest: Array = []
	for index in gallery.entries.size():
		var entry: Dictionary = gallery.entries[index]
		if entry.section in SKIP or str(entry.title).begins_with("fx_"):
			continue
		gallery.focus_model(index)
		gallery.camera.yaw = 0.65
		gallery.camera.pitch = 0.45
		gallery.camera.center = gallery.camera.target
		gallery.camera.span = gallery.camera.target_span * 0.75
		gallery.camera.target_span = gallery.camera.span
		for frame in 3:
			await process_frame
		await RenderingServer.frame_post_draw
		var filename := "%03d.png" % index
		root.get_texture().get_image().save_png(directory.path_join(filename))
		manifest.append({"title": entry.title, "section": entry.section, "file": filename})
	var file := FileAccess.open(directory.path_join("captures.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(manifest,"\t"))
	file.close()
	print("QUALITY_CAPTURE_COMPLETE: ", manifest.size())
	gallery.queue_free()
	await process_frame
	quit()
