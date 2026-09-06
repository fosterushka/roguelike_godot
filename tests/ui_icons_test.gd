extends SceneTree

const Icons = preload("res://presentation/ui/ui_icons.gd")

func _init() -> void:
	var failures := 0
	var cell: Vector2 = Icons.ATLAS.get_size() / 4.0
	for row in 4:
		for column in 4:
			var icon: AtlasTexture = Icons.texture(Icons.KEYS[row * 4 + column])
			var expected := Rect2(Vector2(column, row) * cell + cell * 0.08, cell * 0.84)
			if not icon.region.is_equal_approx(expected):
				failures += 1
				push_error("Icon must stay in its own atlas cell: " + Icons.KEYS[row * 4 + column])
	print("UI icons: 16 checks, %d failures" % failures)
	quit(0 if failures == 0 else 1)
