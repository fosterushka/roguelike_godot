extends SceneTree
const DIRECTORY := "res://docs/validation/model-quality"
const COLUMNS := 4
const PAGE_SIZE := 20
const WIDTH := 320
const HEIGHT := 240
func _init() -> void:
	var rows: Array = JSON.parse_string(FileAccess.get_file_as_string(DIRECTORY.path_join("captures.json")))
	var sections := {}
	for row: Dictionary in rows:
		if not sections.has(row.section): sections[row.section] = []
		sections[row.section].append(row)
	var section_index := 0
	for section: String in sections:
		var entries: Array = sections[section]
		for page in ceili(entries.size() / float(PAGE_SIZE)):
			var count := mini(PAGE_SIZE, entries.size() - page * PAGE_SIZE)
			var output := Image.create(WIDTH * COLUMNS, HEIGHT * ceili(count / float(COLUMNS)), false, Image.FORMAT_RGB8)
			for index in count:
				var source := Image.load_from_file(ProjectSettings.globalize_path(DIRECTORY.path_join(entries[page * PAGE_SIZE + index].file)))
				source.convert(Image.FORMAT_RGB8)
				source.resize(WIDTH, HEIGHT)
				output.blit_rect(source, Rect2i(0, 0, WIDTH, HEIGHT), Vector2i(index % COLUMNS * WIDTH, index / COLUMNS * HEIGHT))
			output.save_png(DIRECTORY.path_join("sheet-%d-%d.png" % [section_index,page]))
		section_index += 1
	quit()
