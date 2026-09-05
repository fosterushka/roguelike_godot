extends RefCounted

const Locale = preload("res://presentation/ui/ui_locale.gd")
var progression: RefCounted
var hud: CanvasLayer
var sound: Node
var last_progress_at := -1000.0

func setup(run_progression: RefCounted, run_hud: CanvasLayer, run_sound: Node) -> void:
	progression = run_progression
	hud = run_hud
	sound = run_sound

func on_event(event: Dictionary) -> void:
	var completed: Array = progression.profile.completedContractIds.duplicate()
	var previous: Dictionary = progression.profile.contractProgress.duplicate()
	previous.merge(progression.contracts.progress, true)
	if not progression.on_combat_event(event):
		return
	for id: String in progression.profile.completedContractIds:
		if not completed.has(id):
			hud.show_world_banner(Locale.text("КОНТРАКТ ВЫПОЛНЕН"), str(progression.catalog.contracts[id].title))
			sound.play_cue("contractComplete", true)
			return
	var current: Dictionary = progression.profile.contractProgress.duplicate()
	current.merge(progression.contracts.progress, true)
	var now := Time.get_ticks_msec() / 1000.0
	if now - last_progress_at < 0.7:
		return
	for id: String in current:
		if current[id] != previous.get(id, 0):
			last_progress_at = now
			var definition: Dictionary = progression.catalog.contracts[id]
			hud.show_world_banner(str(definition.title), "%d/%d" % [current[id], definition.target])
			sound.play_cue("contractProgress", true)
			return
