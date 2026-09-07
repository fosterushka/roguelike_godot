extends Node3D
const Encounter = preload("res://modules/crew/crew_encounter.gd")
const Source = preload("res://presentation/combat/source_model.gd")
const Seats = preload("res://presentation/crew/crew_seats.gd")
const Ground = preload("res://modules/caravan/terrain_surface.gd")
const Locale = preload("res://presentation/ui/ui_locale.gd")
const Speech = preload("res://presentation/crew/crew_speech.gd")
var speech_layer: CanvasLayer
var reaction_views: Array[Dictionary] = []
var views: Array[Dictionary] = []
var clock := 0.0
var _warmup_restore: Array[Dictionary] = []
var _vehicle: Node3D
var _carrier_visuals: Dictionary = {}

func _ready() -> void:
	process_priority = 20

func _process(_delta: float) -> void:
	var camera := get_viewport().get_camera_3d()
	for view: Dictionary in views:
		var carrier := view.get("carrier") as Node3D
		if is_instance_valid(carrier) and bool(view.get("is_seated", false)) and view.root.visible:
			view.root.global_transform = carrier.global_transform * view.seat_transform
		if view.get("show_speech", false) and view.root.visible:
			view.speech.follow(camera, view.root.global_position + Vector3.UP * 3.3)
		else:
			view.speech.hide()
	for entry: Dictionary in reaction_views:
		var actor: Dictionary = entry.actor
		if actor.get("dead", false):
			entry.speech.hide()
		else:
			var point: Vector3 = actor.position
			point.y = Ground.height_at(point.x, point.z) + 3.2
			entry.speech.follow(camera, point)

func update_reactions(reactions: Array) -> void:
	for entry: Dictionary in reaction_views:
		entry.speech.queue_free()
	reaction_views.clear()
	for reaction: Dictionary in reactions:
		var bubble := Speech.new()
		speech_layer.add_child(bubble)
		bubble.show_message(reaction.text[0 if Locale.language == "ru" else 1])
		reaction_views.append({"speech": bubble, "actor": reaction.actor})

func set_vehicle(vehicle: Node3D) -> void:
	_vehicle = vehicle

func set_carrier_visuals(values: Dictionary) -> void:
	_carrier_visuals = values

func prepare() -> void:
	if not views.is_empty():
		return
	speech_layer = CanvasLayer.new()
	speech_layer.layer = 5
	add_child(speech_layer)
	for index in 32:
		var body := Source.instantiate("rifleman")
		var root := Node3D.new()
		root.name = "CrewVisual"
		root.add_child(body)
		var seated := Seats.build()
		seated.visible = false
		root.add_child(seated)
		# Keep the authored palette on standing crew: an all-part override hid the
		# face, vest, helmet and weapon detail from the new military people asset.
		var label := Label3D.new()
		label.position.y = 2.3
		label.font_size = 28
		label.pixel_size = 0.014
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.modulate = Color("d1efb4")
		root.add_child(label)
		var speech := Speech.new()
		speech_layer.add_child(speech)
		root.visible = false
		add_child(root)
		views.append({"root": root, "body": body, "seated": seated, "label": label, "speech": speech, "show_speech": false, "last": Vector3.ZERO, "id": ""})

func update_people(people: Array, delta: float) -> void:
	prepare()
	clock += delta
	for index in views.size():
		var view: Dictionary = views[index]
		if index >= people.size():
			view.root.visible = false
			continue
		var person: Dictionary = people[index]
		var seated: bool = bool(person.get("boarded", false)) and not person.get("dead", false) and not person.get("airborne", false)
		var climbing: bool = person.get("state", "") == "boarding" and not person.get("dead", false) and not person.get("airborne", false)
		var carrier := _carrier_visual(str(person.get("carrier_id", "crawler"))) if seated or climbing else null
		if carrier == null:
			seated = false
		var point: Vector3 = person.position
		point.y = Ground.height_at(point.x, point.z) + float(person.get("lift_height", 0))
		if seated:
			view.seat_transform = Transform3D(Basis.IDENTITY, Seats.anchor(str(person.get("carrier_id", "crawler")), int(person.get("seat", 0))))
			view.carrier = carrier
			view.root.global_transform = carrier.global_transform * view.seat_transform
		else:
			view.carrier = null
			view.root.scale = Vector3.ONE
			view.root.position = point
			view.root.rotation = Vector3(0, float(person.get("heading", 0)), PI * 0.5 if person.get("dead", false) else float(person.get("roll", 0)))
		if climbing and carrier != null:
			var origin: Vector3 = person.get("boarding_start", person.position)
			origin.y = Ground.height_at(origin.x, origin.z)
			var target: Vector3 = carrier.global_transform * Seats.anchor(str(person.carrier_id), int(person.seat))
			var progress := clampf(float(person.get("boarding_progress", 0)), 0, 1)
			view.root.global_position = origin.lerp(target, smoothstep(0, 1, progress)) + Vector3.UP * sin(progress * PI) * 0.45
			view.root.rotation.y = carrier.global_rotation.y
		var moving: bool = view.id == str(person.id) and Vector3(view.last).distance_squared_to(point) > 0.00001 and not seated
		view.root.visible = true
		view.body.visible = not seated
		view.seated.visible = seated
		view.is_seated = seated
		if seated:
			view.seated.get_node("PickupBench").visible = str(person.get("carrier_id", "crawler")) == "crawler"
			var appearance := str(person.get("role", "")) + ":" + str(person.get("faction", "ally"))
			if str(view.seated.get_meta("appearance", "")) != appearance:
				Seats.apply_role(view.seated, str(person.get("role", "")), str(person.get("faction", "ally")))
				view.seated.set_meta("appearance", appearance)
		var calling: bool = person.get("faction", "") == "neutral" and person.get("state", "") == "stranded" and not person.get("dead", false) and not person.get("airborne", false)
		var phase := clock + float(person.get("identity", index)) * 0.63
		var nearby := _vehicle == null or Encounter.flat_distance(person.position, _vehicle.global_position) < 40
		var happy: bool = float(person.get("reaction_time", 0)) > 0 and person.get("faction", "") == "ally" and not person.get("dead", false)
		var reply: bool = float(person.get("reaction_time", 0)) > 0 and person.has("reaction_text") and not person.get("dead", false)
		view.show_speech = happy or reply or (calling and nearby)
		var words: String = Encounter.CALLS[posmod(int(phase / 6) + int(person.get("identity", 0)), Encounter.CALLS.size())][0 if Locale.language == "ru" else 1]
		if reply:
			words = person.reaction_text[0 if Locale.language == "ru" else 1]
		elif calling:
			words += "\nE · " + str(person.get("name" if Locale.language == "ru" else "name_en", person.role))
		if view.speech.label.text != words or view.speech.positive != happy:
			view.speech.show_message(words, happy)
		view.label.visible = false

		if calling:
			view.root.position.y += pow(maxf(0, sin(phase * 3.5)), 2) * 0.42
		view.label.text = ("E · " if calling else "") + str(person.get("name" if Locale.language == "ru" else "name_en", person.role))
		view.label.modulate = Color("ad766c") if person.get("dead", false) else Color("d1efb4")
		for part in view.body.get_children():
			if part is GeometryInstance3D and part.has_meta("source_part") and part.get_meta("source_part").get("rig", {}).get("role", "") == "weapon":
				part.visible = str(person.role) in ["shooter", "anti_tank", "anti_air"]
		if not seated:
			Source.animate_instance(view.body, {"move_blend": 1.0 if moving and not person.get("airborne", false) else 0.0, "phase": clock * 9, "animation_time": clock, "instance_index": index, "attack_animation": minf(1, float(person.get("cooldown", 0))), "wave": calling, "climbing": climbing})
		view.id = str(person.id)
		view.last = point

func _carrier_visual(carrier_id: String) -> Node3D:
	if _carrier_visuals.has(carrier_id):
		return _carrier_visuals[carrier_id] as Node3D
	if _vehicle == null:
		return null
	var vehicle_view := _vehicle.get_node_or_null("VehicleView") as Node3D
	if vehicle_view == null:
		return null
	if carrier_id == "crawler":
		return vehicle_view
	var trailers: Dictionary = vehicle_view.get("_trailers")
	return trailers.get(carrier_id) as Node3D

func set_warmup(enabled: bool, point: Vector3) -> void:
	prepare()
	if enabled:
		if not _warmup_restore.is_empty():
			return
		for index in views.size():
			var body: Node3D = views[index].root
			_warmup_restore.append({"transform": body.transform, "visible": body.visible, "body_visible": views[index].body.visible, "seated_visible": views[index].seated.visible, "text": views[index].label.text})
			body.visible = true
			views[index].body.visible = true
			views[index].seated.visible = true
			views[index].label.text = "Механик · Mechanic · Сборщик · Scavenger"
			body.position = point + Vector3((index % 7) * 1.3 - 4, 0, (index / 7) * 1.3)
	else:
		for index in _warmup_restore.size():
			views[index].root.transform = _warmup_restore[index].transform
			views[index].root.visible = _warmup_restore[index].visible
			views[index].body.visible = _warmup_restore[index].body_visible
			views[index].seated.visible = _warmup_restore[index].seated_visible
			views[index].label.text = _warmup_restore[index].text
		_warmup_restore.clear()
