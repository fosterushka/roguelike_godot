extends RefCounted

const FINAL_WAVE := 6
const INTERMISSION_SECONDS := 5.0
const SPAWN_INTERVAL := 0.45
const PLAYABLE_RADIUS := 1248.0

static func radius(wave: int) -> float:
	return PLAYABLE_RADIUS * sqrt(0.4 + clampi(wave, 1, FINAL_WAVE) * 0.1)

static func queue_for(wave: int) -> Array[String]:
	wave = clampi(wave, 1, FINAL_WAVE)
	var result: Array[String] = []
	var counts := {"rifleman": 6 + wave * 2, "ak": 1 + wave if wave >= 2 else 0,
		"bazooka": maxi(1, floori(wave / 2.0)) if wave >= 3 else 0, "bomber": maxi(1, wave - 1) if wave >= 2 else 0,
		"shooter": maxi(1, floori(wave / 2.0)) if wave >= 2 else 0, "kamikaze": maxi(1, floori((wave - 1) / 2.0)) if wave >= 3 else 0}
	for kind: String in counts:
		for _index in int(counts[kind]):
			result.append(kind)
	for index in mini(5, 1 + floori(wave / 2.0)):
		result.append("buggy" if wave >= 2 and index % 2 == 1 else "bike")
	if wave == FINAL_WAVE:
		result.append("leviathan")
	return result
