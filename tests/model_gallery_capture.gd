extends SceneTree

const Gallery = preload("res://presentation/debug/model_gallery.tscn")
const OUTPUT := "res://docs/validation/model-gallery"
const SUBJECTS := ["bike", "player_pickup", "airdrop", "garrison_3"]

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	root.size = Vector2i(1440, 900)
	var gallery := Gallery.instantiate()
	root.add_child(gallery)
	await gallery.gallery_ready
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	var inventory := FileAccess.open(OUTPUT.path_join("inventory.json"), FileAccess.WRITE)
	inventory.store_string(JSON.stringify(gallery.entries, "\t"))
	inventory.close()
	await _capture("npc-map")
	for subject: String in SUBJECTS:
		for index in gallery.entries.size():
			if gallery.entries[index].title == subject:
				gallery.focus_model(index)
				await _capture(subject)
				break
	gallery.queue_free()
	await process_frame
	quit()

func _capture(name_value: String) -> void:
	for frame in 45:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUTPUT.path_join(name_value + ".png"))
