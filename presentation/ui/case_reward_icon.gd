extends Control

var kind := "salvage"
var tint := Color("e8bf76")

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)

func _draw() -> void:
	var center := size * 0.5
	var scale_value := minf(size.x, size.y) / 64.0
	draw_set_transform(center, 0, Vector2.ONE * scale_value)
	match kind:
		"blueprint":
			draw_rect(Rect2(-20, -24, 40, 48), tint, false, 2)
			for y in [-12, 0, 12]:
				draw_line(Vector2(-12, y), Vector2(12, y), tint, 1)
			for x in [-10, 0, 10]:
				draw_line(Vector2(x, -17), Vector2(x, 17), Color(tint, 0.4), 1)
		"fuel":
			draw_rect(Rect2(-17, -16, 34, 39), tint, false, 3)
			draw_rect(Rect2(-10, -25, 20, 9), tint, false, 3)
			draw_line(Vector2(-10, -7), Vector2(10, 14), tint, 2)
			draw_line(Vector2(10, -7), Vector2(-10, 14), tint, 2)
		"repair":
			draw_rect(Rect2(-7, -23, 14, 46), tint)
			draw_rect(Rect2(-23, -7, 46, 14), tint)
		_:
			for i in 3:
				var y := float(i * 13 - 20)
				draw_polygon(PackedVector2Array([Vector2(-22, y + 6), Vector2(-13, y), Vector2(22, y), Vector2(13, y + 6)]), PackedColorArray([tint]))
				draw_line(Vector2(-22, y + 8), Vector2(13, y + 8), tint, 2)
