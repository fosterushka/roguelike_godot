extends SceneTree
const Effects = preload("res://presentation/combat/impact_effects.gd")
const Source = preload("res://presentation/combat/source_model.gd")
const Equipment = preload("res://presentation/vehicles/equipment_model.gd")
var failures := 0

func _init() -> void:
	_run.call_deferred()

func check(value: bool, label: String) -> void:
	if not value:
		failures += 1
		push_error(label)

func _run() -> void:
	var fx := Effects.new()
	root.add_child(fx)
	fx.set_process(false)
	var count: int = fx.transient.get_child_count()
	fx.on_event({"kind":"hit","team":"player","position":Vector3.ZERO})
	check(fx.transient.cursor == Effects.SPARK_COUNT, "Player damage emits metal sparks")
	fx.on_event({"kind":"hit","type":"soldier","position":Vector3.ZERO})
	check(fx.transient.cursor == Effects.SPARK_COUNT, "Infantry hit avoids metal sparks")
	fx.on_event({"kind":"death","type":"soldier","position":Vector3.ZERO})
	check(fx.transient.cursor == Effects.SPARK_COUNT + 1 + Effects.BodySplash.DROPLETS, "Infantry death emits ground stain and airborne splash")
	for index in 40:
		fx.on_event({"kind":"hit","type":"bike","position":Vector3.ZERO})
	check(fx.transient.get_child_count() == count, "Sustained impacts reuse fixed effect pool")
	var drop := Source.instantiate("airdrop")
	var body := drop.get_node("Body") as MeshInstance3D
	check(body.position.y + body.get_aabb().position.y >= 11.99, "Drop origin matches activity and pickup offset")
	drop.free()
	var bike := Source.instantiate("bike")
	var rider_body := bike.get_node("Body") as MeshInstance3D
	check((rider_body.transform * rider_body.get_aabb()).end.y > 2.0, "Seated rider raises motorcycle silhouette")
	bike.free()
	var bazooka := Equipment.build("bazooka")
	var aa := Equipment.build("anti_air_station")
	var first := bazooka.get_node("ElevationPivot/WeaponAssembly") as MeshInstance3D
	var second := aa.get_node("ElevationPivot/WeaponAssembly") as MeshInstance3D
	check(first.get_aabb().size.x < second.get_aabb().size.x, "Single launcher and wide twin AA have distinct silhouettes")
	bazooka.free()
	aa.free()
	fx.queue_free()
	await process_frame
	print("Combat upgrade: 7 checks, %d failures" % failures)
	quit(0 if failures == 0 else 1)
