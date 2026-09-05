extends RefCounted

const KEYS := {
	"drive_forward": [KEY_W],
	"drive_backward": [KEY_S],
	"drive_left": [KEY_A],
	"drive_right": [KEY_D],
	"handbrake": [KEY_SHIFT],
	"focus_target": [KEY_F],
	"interact": [KEY_E],
	"ability_one": [KEY_1],
	"ability_two": [KEY_2],
	"ability_three": [KEY_3],
	"activate_ability": [KEY_SPACE],
	"armory": [KEY_B],
	"inventory": [KEY_I, KEY_TAB],
	"radar_zoom": [KEY_M],
	"pause_game": [KEY_P, KEY_ESCAPE],
	"restart_run": [],
}

static func register() -> void:
	if InputMap.has_action("restart_run"):
		InputMap.action_erase_events("restart_run")
	for action: String in KEYS:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for key: int in KEYS[action]:
			var event := InputEventKey.new()
			event.physical_keycode = key as Key
			if not InputMap.action_has_event(action, event):
				InputMap.action_add_event(action, event)
