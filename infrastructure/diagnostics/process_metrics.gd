extends RefCounted

const POLL_SECONDS := 1.0
const KIB_PER_MIB := 1024.0
var worker: Thread
var remaining := 0.0
var latest: Dictionary = {}

func poll(delta: float) -> void:
	remaining -= delta
	if worker != null:
		if worker.is_alive():
			return
		latest = worker.wait_to_finish()
		worker = null
	if remaining > 0.0 or OS.get_name() not in ["macOS", "Linux"]:
		return
	remaining = POLL_SECONDS
	worker = Thread.new()
	if worker.start(_sample.bind(OS.get_process_id())) != OK:
		worker = null

# Only OS data here; the worker never accesses nodes or shared mutable state.
static func _sample(pid: int) -> Dictionary:
	var output: Array = []
	if OS.execute("/bin/ps", PackedStringArray(["-p", str(pid), "-o", "%cpu=", "-o", "rss="]), output) != 0 or output.is_empty():
		return {}
	var fields := str(output[0]).strip_edges().replace("\t", " ").split(" ", false)
	if fields.size() != 2 or not fields[0].is_valid_float() or not fields[1].is_valid_int():
		return {}
	return {"cpu_percent": fields[0].to_float(), "rss_mib": fields[1].to_float() / KIB_PER_MIB}

func close() -> void:
	if worker != null:
		worker.wait_to_finish()
		worker = null
