extends SceneTree

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	root.add_child(preload("res://tests/tornado_capture_scene.gd").new())
