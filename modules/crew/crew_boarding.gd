extends RefCounted
const Encounter = preload("res://modules/crew/crew_encounter.gd")
const Policy = preload("res://modules/world/destruction_policy.gd")
const WALK_SPEED := 6.0
const CLIMB_DURATION := 0.85
const ENTRANCE_REACH := 1.0
const CLIMB_BREAK_DISTANCE := 2.5
const TROLLING_PATIENCE := 3.0
const MOVING_SPEED := 2.0
const OFFENDED_MIN := 5.0
const OFFENDED_MAX := 10.0

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
	if float(person.get("boarding_refusal", 0)) > 0:
		person.boarding_refusal = maxf(0, float(person.boarding_refusal) - delta)
		person.state = "offended"
		person.boarding_last_entrance = entrance
		return
	var last_entrance: Vector3 = person.get("boarding_last_entrance", entrance)
	person.boarding_last_entrance = entrance
	var moving := Encounter.flat_distance(entrance, last_entrance) > MOVING_SPEED * delta
	person.boarding_chase = maxf(0, float(person.get("boarding_chase", 0)) + (delta if moving else -delta))
	if float(person.boarding_chase) >= TROLLING_PATIENCE:
		_offend(person)
		return
	if person.state == "boarding" and Encounter.flat_distance(person.position, entrance) > CLIMB_BREAK_DISTANCE:
		person.state = "approaching"
		person.erase("boarding_start")
		person.boarding_progress = 0.0
	if person.state != "boarding":
		person.state = "approaching"
		var point: Vector3 = navigation.move(person, entrance, WALK_SPEED, delta)
		var motion: Vector3 = point - person.position
		if motion.length_squared() > 0.001:
			person.heading = atan2(motion.x, motion.z)
		person.position = point
		if Vector2(point.x - entrance.x, point.z - entrance.z).length() > ENTRANCE_REACH:
			return
		person.state = "boarding"
		person.boarding_start = point
		person.boarding_progress = 0.0
	person.boarding_progress = minf(1.0, float(person.boarding_progress) + delta / CLIMB_DURATION)
	if person.boarding_progress >= 1.0:
		person.recruit_boarding = false
		person.boarded = true
		person.state = "boarded"
		person.position = anchor
		person.erase("boarding_start")

static func _offend(person: Dictionary) -> void:
	var count := int(person.get("boarding_offenses", 0)) + 1
	person.boarding_offenses = count
	var key := str(person.id) + ":offended:" + str(count)
	var duration := lerpf(OFFENDED_MIN, OFFENDED_MAX, Policy.roll(key))
	person.boarding_refusal = duration
	person.boarding_chase = 0.0
	person.boarding_progress = 0.0
	person.erase("boarding_start")
	person.state = "offended"
	person.reaction_time = duration
	person.reaction_text = Encounter.OFFENDED_LINES[posmod(Encounter.identity(str(person.id)) + count, Encounter.OFFENDED_LINES.size())]
