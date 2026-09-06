extends Node

const MAX_VOICES := 16
const ENGINE_RATE := 22050.0
const COOLDOWNS := {"shot": 0.042, "enemyShot": 0.072, "hit": 0.068, "crush": 0.085, "bumper": 0.11, "pickup": 0.06, "explosion": 0.125, "thunder": 0.5, "horn": 0.28, "nitro": 0.18, "lowHp": 0.38, "mineDrop": 0.26, "mineTrigger": 0.12}
var enabled := true
var running := false
var streams: Dictionary = {}
var voices: Array[AudioStreamPlayer] = []
var last_events: Dictionary = {}
var accepted_events := 0
var pending_thunder: Array[Dictionary] = []
var _cursor := 0
var _engine: AudioStreamPlayer
var _playback: AudioStreamGeneratorPlayback
var _speed := 0.0
var _load := 0.0
var _rpm := 42.0
var _phase := Vector3.ZERO
var _filter := 0.0
var _noise := 0.0
var _random := RandomNumberGenerator.new()

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_random.seed = 81173
	var bus := AudioServer.get_bus_index("Caravan")
	if bus < 0:
		AudioServer.add_bus()
		bus = AudioServer.bus_count - 1
		AudioServer.set_bus_name(bus, "Caravan")
		AudioServer.set_bus_volume_db(bus, linear_to_db(0.72 * 0.86))
		var compressor := AudioEffectCompressor.new()
		compressor.threshold = -18
		compressor.ratio = 8
		compressor.attack_us = 3000
		compressor.release_ms = 180
		AudioServer.add_bus_effect(bus, compressor)
	for index in MAX_VOICES:
		var voice := AudioStreamPlayer.new()
		voice.bus = "Caravan"
		add_child(voice)
		voices.append(voice)
	_engine = AudioStreamPlayer.new()
	_engine.bus = "Caravan"
	var generator := AudioStreamGenerator.new()
	generator.mix_rate = ENGINE_RATE
	generator.buffer_length = 0.15
	_engine.stream = generator
	add_child(_engine)
	var recipes: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/audio_recipes.json"))
	for id: String in recipes.recipes:
		streams[id] = load("res://assets/audio/%s.wav" % id)

func set_enabled(value: bool) -> void:
	enabled = value
	if not enabled:
		stop_all()

func set_running(value: bool) -> void:
	running = value
	if not running:
		stop_all()

func stop_all() -> void:
	pending_thunder.clear()
	for voice in voices:
		voice.stop()
	_engine.stop()
	_playback = null

func reset_run() -> void:
	stop_all()
	last_events.clear()
	_phase = Vector3.ZERO
	_rpm = 42.0

func play_cue(id: String, ui: bool = false, start_offset: float = 0.0) -> bool:
	if not enabled or (not running and not ui) or not streams.has(id):
		return false
	var family := id.get_slice("_", 0)
	var now := Time.get_ticks_msec() / 1000.0
	if now - float(last_events.get(family, -1000.0)) < float(COOLDOWNS.get(family, 0.0)):
		return false
	last_events[family] = now
	var voice := voices[_cursor]
	_cursor = (_cursor + 1) % MAX_VOICES
	voice.stop()
	voice.stream = streams[id]
	if DisplayServer.get_name() != "headless":
		voice.play(start_offset)
	accepted_events += 1
	return true

func engine(speed_ratio: float, engine_load: float) -> void:
	_speed = clampf(speed_ratio, 0.0, 1.7)
	_load = clampf(engine_load, 0.0, 1.0)

func _process(delta: float) -> void:
	if enabled and running:
		for pending: Dictionary in pending_thunder:
			pending.remaining -= delta
			if pending.remaining <= 0:
				play_cue(pending.id, false, pending.offset)
		pending_thunder = pending_thunder.filter(func(item: Dictionary) -> bool: return item.remaining > 0)
	if not enabled or not running or DisplayServer.get_name() == "headless":
		return
	if not _engine.playing:
		_engine.play()
		_playback = _engine.get_stream_playback()
	if _playback == null:
		return
	var frames := _playback.get_frames_available()
	var buffer := PackedVector2Array()
	buffer.resize(frames)
	var cutoff := 300.0 + _speed * 1080.0 + _load * 720.0
	var alpha := 1.0 - exp(-TAU * cutoff / ENGINE_RATE)
	for index in frames:
		_rpm = lerpf(_rpm, 42.0 + _speed * 84.0, 1.0 / (0.08 * ENGINE_RATE))
		_phase += Vector3(_rpm, _rpm * 2.03, _rpm * 0.51) / ENGINE_RATE
		_phase = Vector3(fposmod(_phase.x, 1.0), fposmod(_phase.y, 1.0), fposmod(_phase.z, 1.0))
		var primary := _phase.x * 2.0 - 1.0
		var harmonic := (1.0 - absf(_phase.y - 0.5) * 4.0) * (0.002 + _speed * 0.004 + _load * 0.004)
		var pulse := (1.0 if _phase.z < 0.5 else -1.0) * (0.0008 + _load * 0.0035)
		_filter = lerpf(_filter, primary + harmonic + pulse, alpha)
		_noise = _noise * 0.74 + _random.randf_range(-1.0, 1.0) * 0.26
		var value := (_filter + _noise * (0.001 + _speed * 0.002 + _load * 0.006)) * (0.008 + _speed * 0.012 + _load * 0.006)
		buffer[index] = Vector2(value, value)
	_playback.push_buffer(buffer)

func on_combat_event(event: Dictionary) -> void:
	match str(event.get("kind", "")):
		"shot": play_cue(("shot_" if event.get("team", "") == "player" else "enemyShot_") + str(event.get("projectile_kind", "bullet")))
		"player_hit": play_cue("hit")
		"low_hp": play_cue("lowHp")
		"roadkill_impact": play_cue("crush")
		"ram_impact": play_cue("bumper" if event.get("bumper", false) else "explosion")
		"death": play_cue("crush" if event.get("type") == "soldier" else "explosion")
		"boss_component_destroyed", "death_started": play_cue("explosion")
		"telegraph": play_cue("spawnWarning_true")
		"explosion": play_cue("explosion")
		"pickup": play_cue("pickup")
		"mine_drop": play_cue("mineDrop")
		"mine_explosion": play_cue("mineTrigger")
		"mine_hacked": play_cue("mineHack")
		"ability":
			var slot := int(event.get("slot", -1))
			play_cue("nitro" if slot == 0 else "bumper" if slot == 1 else "repairAbility")
		"spawn":
			var kind := str(event.get("enemy_kind", ""))
			if kind in ["jammerTruck", "repairCrawler", "minelayer"]:
				play_cue("priorityWarning_" + (kind if kind != "minelayer" else "priority"))
		"wave": play_cue("spawnWarning_false")
		"boss_phase": play_cue("explosion")

func on_world_event(event: Dictionary) -> void:
	match str(event.get("kind", "")):
		"lightning":
			var distance := float(event.get("distance", 260.0))
			var bucket := 0 if distance < 65 else 130 if distance < 195 else 260 if distance < 390 else 520
			if enabled and running and pending_thunder.size() < 4:
				pending_thunder.append({"id": "thunder_%d" % bucket, "remaining": minf(1.8, maxf(0, distance / 343.0)), "offset": minf(1.8, bucket / 343.0)})
		"prop_destroyed": play_cue("crush")
		"village_consumed": play_cue("horn")
		"extraction_started": play_cue("activityAnnouncement_true")
		"extraction_failed": play_cue("activityOutcome_false")
		"extracted": play_cue("activityOutcome_true", true)
		"activity_announced": play_cue("activityAnnouncement_true" if event.get("activity_type", "") in ["raiderSupplyConvoy", "settlementDistress", "foundryDispatch"] else "activityAnnouncement_false")
		"activity_completed": play_cue("activityOutcome_true")
		"activity_failed": play_cue("activityOutcome_false")

func _exit_tree() -> void:
	stop_all()
	for voice in voices:
		voice.stream = null
	voices.clear()
	_engine.stream = null
	streams.clear()
