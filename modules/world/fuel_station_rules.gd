extends RefCounted

## Station behavior belongs to the landmark definition, shared by every layout.
const REFILL_RADIUS := 11.0
const REFILL_PER_SECOND := 24.0
const PUMP_FUEL_DROP := 36
const DEFINITIONS := {
	"pumpjack": {"drops": {"fuel": PUMP_FUEL_DROP}},
	"refinery": {"drops": {}},
}

static func is_station(kind: String) -> bool:
	return DEFINITIONS.has(kind)

static func prop_metadata(layout: Dictionary) -> Dictionary:
	var result := {}
	for landmark: Dictionary in layout.get("landmarks", []):
		var kind := str(landmark.get("type", ""))
		if is_station(kind):
			result["prop:" + str(landmark.id)] = {"station_kind": kind, "drops": DEFINITIONS[kind].drops.duplicate(true)}
	return result
