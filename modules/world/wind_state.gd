extends RefCounted
var remaining := 0.0
var duration := 0.0
var spawn_remaining := 0.0
var strength := 0.0
var direction := Vector3.RIGHT

func reset(random: RefCounted) -> void:
	remaining = random.between(5, 10)
	duration = 0.0
	spawn_remaining = 0.0
	strength = 0.0
	direction = Vector3.RIGHT

func step(delta: float, storm: bool, random: RefCounted) -> int:
	var spawned := 0
	if duration > 0:
		duration -= delta
		spawn_remaining -= delta
		while spawn_remaining <= 0:
			spawned += 1
			spawn_remaining += random.between(0.09, 0.16)
		if duration <= 0:
			remaining = random.between(3, 7) if storm else random.between(8, 17)
			strength = 0.0
	else:
		remaining -= delta
		if remaining <= 0:
			var angle: float = random.between(0, TAU)
			direction = Vector3(cos(angle), 0, sin(angle))
			strength = random.between(28, 42) if storm else random.between(18, 32)
			duration = random.between(10, 18) if storm else random.between(6.5, 12.5)
			spawn_remaining = 0
	return spawned

func get_state() -> Dictionary:
	return {"remaining": remaining, "duration": duration, "strength": strength, "direction": direction}
