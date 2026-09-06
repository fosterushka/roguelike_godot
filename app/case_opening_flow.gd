extends RefCounted

const CasePanel = preload("res://presentation/ui/case_opening_panel.gd")
var game: Node3D
var panel: ColorRect
var pending: Array[Dictionary] = []
var seen := {}

func setup(owner: Node3D) -> void:
	game = owner
	panel = CasePanel.new()
	game.hud.get_node("Screen").add_child(panel)
	panel.closed.connect(_closed)

func enqueue(event: Dictionary) -> void:
	var value: Dictionary = event.get("case", {})
	if value.is_empty() or not value.get("awarded", false) or value.get("pool", []).is_empty() or value.get("selected", {}).is_empty():
		return
	var id := str(value.get("id", ""))
	if id.is_empty() or seen.has(id):
		return
	seen[id] = true
	pending.append(value.duplicate(true))
	try_open.call_deferred()

func try_open() -> void:
	if game.screen_state != "running" or pending.is_empty() or float(game.combat.model.player.hp) <= 0:
		return
	game.hud.hide_menus()
	game._set_screen("case_opening")
	panel.show_case(pending.pop_front())

func _closed() -> void:
	if game.screen_state != "case_opening":
		return
	if not pending.is_empty():
		panel.show_case(pending.pop_front())
	else:
		game._set_screen("running")

func reset() -> void:
	pending.clear()
	seen.clear()
	if is_instance_valid(panel):
		panel.clear()
