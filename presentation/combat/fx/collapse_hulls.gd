extends Node3D
const Pool = preload("res://presentation/combat/fx/effect_pool.gd")
const Source = preload("res://presentation/combat/source_model.gd")
const KINDS := ["raider", "boss", "garrison_1", "garrison_2", "garrison_3"]
var pool: Node3D
func _ready() -> void:
	pool = Pool.new()
	pool.configure(8, 0)
	add_child(pool)
	for entry: Dictionary in pool.entries:
		var models := {}
		for kind in KINDS:
			var model := Source.instantiate(kind)
			model.visible = false
			entry.visual.add_child(model)
			models[kind] = model
		entry.visual.set_meta("models", models)
func spawn(event: Dictionary, random) -> void:
	var velocity := Vector3(random.between(-1.2, 1.2), random.between(2.2, 4.2), random.between(-1.2, 1.2))
	var spin := Vector3(random.between(0.55, 1.15), random.between(-0.35, 0.35), random.between(-0.85, 0.85))
	var entry: Dictionary = pool.acquire({"position": event.get("position", Vector3.ZERO), "rotation": Vector3(0, event.get("heading", 0.0), 0), "velocity": velocity, "spin": spin, "life": 1.55, "max_life": 1.55, "gravity": 7.8, "drag": 0.08, "bounces": 1, "floor_y": 0.04, "fade": false, "shrink": 1.7})
	var kind := "boss" if event.get("boss", false) else "garrison_%d" % clampi(int(event.get("tier", 1)), 1, 3) if event.get("type") == "garrison" else "raider"
	var models: Dictionary = entry.visual.get_meta("models")
	for key in KINDS:
		models[key].visible = key == kind
	if kind == "boss":
		Source.animate_instance(models[kind], {"components": {"missilePod": false, "gunPod": false, "leftDrive": false, "rightDrive": false, "core": false}})
func advance(delta: float) -> void:
	pool.advance(delta)
func reset() -> void:
	pool.reset_pool()
func set_warmup(enabled: bool) -> void:
	for index in KINDS.size():
		var entry: Dictionary = pool.entries[index]
		entry.visual.visible = enabled
		var models: Dictionary = entry.visual.get_meta("models")
		models[KINDS[index]].visible = enabled
