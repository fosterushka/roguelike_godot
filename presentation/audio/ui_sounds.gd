extends Node

# Bind semantic UI actions once, including controls created when panels refresh.
var _root: Node
var _play: Callable

func setup(ui_root: Node, play_click: Callable) -> void:
	_root = ui_root
	_play = play_click
	if not get_tree().node_added.is_connected(_watch):
		get_tree().node_added.connect(_watch)
	_watch_branch(ui_root)

func _watch_branch(node: Node) -> void:
	_watch(node)
	for child in node.get_children():
		_watch_branch(child)

func _watch(node: Node) -> void:
	if not is_instance_valid(_root) or (node != _root and not _root.is_ancestor_of(node)):
		return
	if node is BaseButton:
		if not node.pressed.is_connected(_request_click):
			node.pressed.connect(_request_click)
	elif node is PopupMenu:
		if not node.id_pressed.is_connected(_item_pressed):
			node.id_pressed.connect(_item_pressed)
	elif node is Slider:
		if not node.drag_started.is_connected(_request_click):
			node.drag_started.connect(_request_click)

func _item_pressed(_id: int) -> void:
	_request_click()

func _request_click() -> void:
	# Actions may pause/reset the run or replace the clicked control immediately.
	# Play after those actions so the click is not stopped by a screen transition.
	_play.call_deferred()
