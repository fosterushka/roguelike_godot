extends RefCounted
const Ground = preload("res://modules/caravan/terrain_surface.gd")

static func step(person: Dictionary, roster: RefCounted, player: Dictionary, navigation: RefCounted, delta: float) -> void:
	if not person.get("recruit_boarding", false) or person.get("dead", false) or person.get("airborne", false) or float(person.get("tornado_recovery", 0)) > 0:
		return
	var carrier: Dictionary = player if person.carrier_id == "crawler" else roster.find_wagon(person.carrier_id)
	if carrier.is_empty() or carrier.get("dead", false) or not carrier.get("attached", true):
		person.state = "waiting_carrier"
		return
	var anchor: Vector3 = carrier.get("position", player.position)
	var heading := float(carrier.get("heading", 0))
	var side := -1.0 if int(person.seat) == 0 else 1.0
	var offset := Vector3(side * (3.0 if person.carrier_id == "crawler" else 2.65), 0, -1.25).rotated(Vector3.UP, heading)
	var entrance := anchor + offset
	if person.state != "boarding":
		person.state = "approaching"
		var point: Vector3 = navigation.move(person, entrance, 6.0, delta)
		var motion: Vector3 = point - person.position
		if motion.length_squared() > 0.001:
			person.heading = atan2(motion.x, motion.z)
		person.position = point
		if Vector2(point.x - entrance.x, point.z - entrance.z).length() > 1.0:
			return
		person.state = "boarding"
		person.boarding_start = point
		person.boarding_progress = 0.0
	person.boarding_progress = minf(1.0, float(person.boarding_progress) + delta / 0.85)
	if person.boarding_progress >= 1.0:
		person.recruit_boarding = false
		person.boarded = true
		person.state = "boarded"
		person.position = anchor
		person.erase("boarding_start")
