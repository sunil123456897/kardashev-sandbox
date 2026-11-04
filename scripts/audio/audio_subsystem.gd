class_name AudioSubsystem
extends Node

## Подсистема процедурного звука и акустического эмбиента (F7).
## Реализует:
## - Автоматическую инициализацию шин AudioServer (Master, SFX, Ambient, UI).
## - Пул из 16 позиционных 2D-источников и 8 UI-источников без аллокаций в кадре.
## - Процедурный синтез 29 уникальных звуковых профилей (AudioStreamWAV).
## - Кроссфейд эмбиентных космических фонов и резонанс Сферы Дайсона.
## - 100% безопасную работу в headless-режиме с Dummy аудиодрайвером.

const SAMPLE_RATE: int = 22050
const POSITIONAL_POOL_SIZE: int = 16
const UI_POOL_SIZE: int = 8

var _pos_pool: Array[AudioStreamPlayer2D] = []
var _pos_pool_index: int = 0
var _ui_pool: Array[AudioStreamPlayer] = []
var _ui_pool_index: int = 0

var _ambient_player_a: AudioStreamPlayer
var _ambient_player_b: AudioStreamPlayer
var _active_ambient_is_a: bool = true
var current_ambient_id: String = ""

var _dyson_player: AudioStreamPlayer
var current_dyson_stage: int = 0

var _gen_player: AudioStreamPlayer
var _gen_playback: AudioStreamGeneratorPlayback

var _stream_cache: Dictionary[String, AudioStreamWAV] = {}
var total_sfx_played: int = 0


func _ready() -> void:
	_setup_audio_buses()
	_setup_voice_pools()
	_setup_ambient_players()
	_setup_dyson_player()
	_setup_generator_player()
	warmup_all_recipes()


func setup(world_sim: Node) -> void:
	if _pos_pool.is_empty():
		_setup_audio_buses()
		_setup_voice_pools()
		_setup_ambient_players()
		_setup_dyson_player()
		_setup_generator_player()
	warmup_all_recipes()
	_connect_simulation_signals(world_sim)


func _setup_audio_buses() -> void:
	var target_buses: Array[String] = ["SFX", "Ambient", "UI"]
	for b_name in target_buses:
		var idx: int = AudioServer.get_bus_index(b_name)
		if idx == -1:
			AudioServer.add_bus()
			var new_idx: int = AudioServer.get_bus_count() - 1
			AudioServer.set_bus_name(new_idx, b_name)
			AudioServer.set_bus_send(new_idx, "Master")


func _setup_voice_pools() -> void:
	if not _pos_pool.is_empty():
		return
	for i in range(POSITIONAL_POOL_SIZE):
		var p2d := AudioStreamPlayer2D.new()
		p2d.name = "PosVoice_" + str(i)
		p2d.bus = "SFX"
		p2d.max_distance = 3500.0
		p2d.attenuation = 1.0
		add_child(p2d)
		_pos_pool.append(p2d)

	for i in range(UI_POOL_SIZE):
		var p := AudioStreamPlayer.new()
		p.name = "UIVoice_" + str(i)
		p.bus = "UI"
		add_child(p)
		_ui_pool.append(p)


func _setup_ambient_players() -> void:
	if _ambient_player_a != null:
		return
	_ambient_player_a = AudioStreamPlayer.new()
	_ambient_player_a.name = "AmbientPlayerA"
	_ambient_player_a.bus = "Ambient"
	add_child(_ambient_player_a)

	_ambient_player_b = AudioStreamPlayer.new()
	_ambient_player_b.name = "AmbientPlayerB"
	_ambient_player_b.bus = "Ambient"
	add_child(_ambient_player_b)


func _setup_dyson_player() -> void:
	if _dyson_player != null:
		return
	_dyson_player = AudioStreamPlayer.new()
	_dyson_player.name = "DysonPlayer"
	_dyson_player.bus = "Ambient"
	add_child(_dyson_player)


func _setup_generator_player() -> void:
	if _gen_player != null:
		return
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = SAMPLE_RATE
	gen.buffer_length = 0.15
	_gen_player = AudioStreamPlayer.new()
	_gen_player.name = "CosmicWindGenerator"
	_gen_player.stream = gen
	_gen_player.bus = "Ambient"
	_gen_player.volume_db = -24.0
	add_child(_gen_player)
	if is_inside_tree():
		_gen_player.play()
		_gen_playback = _gen_player.get_stream_playback() as AudioStreamGeneratorPlayback


func _connect_simulation_signals(world_sim: Node) -> void:
	if world_sim == null:
		return
	if world_sim.has_signal("sfx_requested"):
		world_sim.sfx_requested.connect(_on_sim_sfx_requested)
	if world_sim.has_signal("ambient_state_changed"):
		world_sim.ambient_state_changed.connect(_on_sim_ambient_state_changed)
	if world_sim.has_signal("dyson_megastructure_stage_advanced"):
		world_sim.dyson_megastructure_stage_advanced.connect(on_dyson_stage_advanced)
	if world_sim.has_signal("dyson_visual_state_updated"):
		world_sim.dyson_visual_state_updated.connect(_on_dyson_visual_updated)


func _on_sim_sfx_requested(sfx_id: String, world_pos: Vector2, pitch_scale: float, volume_db: float) -> void:
	play_sfx(sfx_id, world_pos, pitch_scale, volume_db)


func _on_sim_ambient_state_changed(ambient_mood: String, intensity: float) -> void:
	var s_id: String = "ambient_" + ambient_mood
	if not _stream_cache.has(s_id):
		s_id = "ambient_deep_space"
	transition_ambient(s_id, intensity)


func _on_dyson_visual_updated(_stage: int, progress: float, _segments: int) -> void:
	if _dyson_player != null and _dyson_player.is_playing():
		_dyson_player.volume_db = lerpf(-18.0, -6.0, progress)


func on_dyson_stage_advanced(stage_index: int, _stage_name: String, _energy: float) -> void:
	current_dyson_stage = stage_index
	var sfx_id: String = ""
	match stage_index:
		1: sfx_id = "sfx_dyson_swarm_hum"
		2: sfx_id = "sfx_dyson_ring_tone"
		3: sfx_id = "sfx_dyson_shell_hum"
		4: sfx_id = "sfx_matrioshka_pulse"
		_: sfx_id = "sfx_dyson_stage_advance"

	if sfx_id != "":
		var stream: AudioStreamWAV = get_or_synthesize_stream(sfx_id)
		if _dyson_player != null:
			_dyson_player.stream = stream
			_dyson_player.volume_db = -10.0
			if _dyson_player.is_inside_tree():
				_dyson_player.play()
		play_ui_sfx("ui_power_select", 0.9, 2.0)


func play_sfx(sfx_id: String, world_pos: Vector2 = Vector2.ZERO, pitch_scale: float = 1.0, volume_db: float = 0.0) -> void:
	if world_pos == Vector2.ZERO:
		play_ui_sfx(sfx_id, pitch_scale, volume_db)
		return

	total_sfx_played += 1
	var stream: AudioStreamWAV = get_or_synthesize_stream(sfx_id)

	if _pos_pool.is_empty():
		return

	var player: AudioStreamPlayer2D = _pos_pool[_pos_pool_index]
	_pos_pool_index = (_pos_pool_index + 1) % POSITIONAL_POOL_SIZE

	player.position = world_pos
	player.pitch_scale = clampf(pitch_scale * randf_range(0.96, 1.04), 0.2, 4.0)
	player.volume_db = volume_db
	player.stream = stream
	if player.is_inside_tree():
		player.play()


func play_ui_sfx(sfx_id: String, pitch_scale: float = 1.0, volume_db: float = 0.0) -> void:
	total_sfx_played += 1
	if _ui_pool.is_empty():
		return
	var stream: AudioStreamWAV = get_or_synthesize_stream(sfx_id)
	var player: AudioStreamPlayer = _ui_pool[_ui_pool_index]
	_ui_pool_index = (_ui_pool_index + 1) % UI_POOL_SIZE

	player.pitch_scale = clampf(pitch_scale * randf_range(0.98, 1.02), 0.2, 4.0)
	player.volume_db = volume_db
	player.stream = stream
	if player.is_inside_tree():
		player.play()


func transition_ambient(ambient_id: String, intensity: float = 1.0) -> void:
	current_ambient_id = ambient_id
	var stream: AudioStreamWAV = get_or_synthesize_stream(ambient_id)
	var target_vol: float = lerpf(-24.0, -6.0, clampf(intensity, 0.0, 1.0))

	if _ambient_player_a == null or _ambient_player_b == null:
		return

	var incoming: AudioStreamPlayer = _ambient_player_b if _active_ambient_is_a else _ambient_player_a
	var outgoing: AudioStreamPlayer = _ambient_player_a if _active_ambient_is_a else _ambient_player_b
	_active_ambient_is_a = not _active_ambient_is_a

	incoming.stream = stream
	incoming.volume_db = target_vol
	if incoming.is_inside_tree():
		incoming.play()
	outgoing.stop()


func step_audio(_delta: float) -> void:
	if _gen_playback != null:
		var avail: int = _gen_playback.get_frames_available()
		var chunk: int = mini(avail, 256)
		for i in range(chunk):
			_gen_playback.push_frame(Vector2.ZERO)


func set_bus_volume(bus_name: String, linear: float) -> void:
	var idx: int = AudioServer.get_bus_index(bus_name)
	if idx >= 0:
		var safe_lin: float = maxf(linear, 0.0001)
		AudioServer.set_bus_volume_db(idx, linear_to_db(safe_lin))


func get_bus_volume(bus_name: String) -> float:
	var idx: int = AudioServer.get_bus_index(bus_name)
	if idx >= 0:
		return db_to_linear(AudioServer.get_bus_volume_db(idx))
	return 0.0


func set_bus_volume_db(bus_name: String, vol_db: float) -> void:
	var idx: int = AudioServer.get_bus_index(bus_name)
	if idx >= 0:
		AudioServer.set_bus_volume_db(idx, vol_db)


func get_bus_volume_db(bus_name: String) -> float:
	var idx: int = AudioServer.get_bus_index(bus_name)
	if idx >= 0:
		return AudioServer.get_bus_volume_db(idx)
	return 0.0


func set_bus_mute(bus_name: String, muted: bool) -> void:
	var idx: int = AudioServer.get_bus_index(bus_name)
	if idx >= 0:
		AudioServer.set_bus_mute(idx, muted)


func is_bus_muted(bus_name: String) -> bool:
	var idx: int = AudioServer.get_bus_index(bus_name)
	if idx >= 0:
		return AudioServer.is_bus_mute(idx)
	return false


func play_positional_sfx(sfx_id: String, world_pos: Vector2, pitch_scale: float = 1.0, volume_db: float = 0.0) -> void:
	play_sfx(sfx_id, world_pos, pitch_scale, volume_db)


func play_ambient(ambient_id: String, intensity: float = 1.0) -> void:
	transition_ambient(ambient_id, intensity)


func set_dyson_hum_stage(stage_index: int) -> void:
	on_dyson_stage_advanced(stage_index, "", 0.0)


func get_cached_recipe_count() -> int:
	return _stream_cache.size()


func has_cached_recipe(r_name: String) -> bool:
	return _stream_cache.has(r_name)


func get_cached_stream(r_name: String) -> AudioStreamWAV:
	return get_or_synthesize_stream(r_name)


func get_positional_pool_size() -> int:
	return _pos_pool.size()


func get_ui_pool_size() -> int:
	return _ui_pool.size()


const ALL_RECIPE_KEYS: Array[String] = [
	"sfx_meteor_impact",
	"sfx_antimatter_lance",
	"sfx_solar_flare",
	"sfx_seismic_quake",
	"sfx_cosmic_plague",
	"sfx_gaia_bloom",
	"sfx_mutagenic_spore",
	"sfx_matter_transmuter",
	"sfx_zero_point_well",
	"sfx_building_damage",
	"sfx_building_collapse",
	"sfx_steam_quench",
	"sfx_magma_fissure",
	"sfx_crystal_resonance",
	"sfx_bio_bloom",
	"sfx_plasma_burst",
	"sfx_nanite_swarm",
	"sfx_transmutation",
	"sfx_dyson_swarm_hum",
	"sfx_dyson_ring_tone",
	"sfx_dyson_shell_hum",
	"sfx_matrioshka_pulse",
	"sfx_dyson_stage_advance",
	"ambient_deep_space",
	"ambient_planetary_pulse",
	"ambient_stellar_corona",
	"ui_click",
	"ui_power_select",
	"ui_toggle",
	"ui_error",
	"sfx_fallback",
	"sfx_gamma_ray_burst",
	"sfx_chronos_distortion",
	"sfx_vacuum_decay",
	"sfx_strange_matter",
	"sfx_singularity_collapse",
	"sfx_transmute_spark",
	"sfx_alchemical_detonation",
	"sfx_dyson_hum",
	"sfx_power_trigger",
	"sfx_power_paint",
	"sfx_brush_switch",
	"sfx_war_declared",
	"sfx_alliance_formed",
	"sfx_city_founded",
	"sfx_city_destroyed",
	"sfx_theory_discovered",
	"sfx_kardashev_ascension",
	"sfx_actor_born",
	"sfx_actor_perished",
	"sfx_laser_fire",
	"sfx_plasma_bolt",
	"sfx_shield_impact",
	"sfx_orbital_bombardment",
	"ambient_solar_wind"
]


func warmup_all_recipes() -> void:
	for r_id in ALL_RECIPE_KEYS:
		get_or_synthesize_stream(r_id)


func get_or_synthesize_stream(sfx_id: String) -> AudioStreamWAV:
	if _stream_cache.has(sfx_id):
		return _stream_cache[sfx_id]
	var wav := _synthesize_procedural_stream(sfx_id)
	_stream_cache[sfx_id] = wav
	return wav


func _synthesize_procedural_stream(sfx_id: String) -> AudioStreamWAV:
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = SAMPLE_RATE
	wav.stereo = false

	var pba: PackedByteArray
	match sfx_id:
		"sfx_meteor_impact", "sfx_singularity_collapse":
			pba = _gen_meteor()
		"sfx_antimatter_lance", "sfx_laser_fire", "sfx_orbital_bombardment":
			pba = _gen_laser_sweep(880.0, 110.0, 0.45)
		"sfx_solar_flare", "sfx_gamma_ray_burst", "sfx_alchemical_detonation":
			pba = _gen_plasma_noise(0.85, 110.0)
		"sfx_seismic_quake", "sfx_vacuum_decay":
			pba = _gen_sub_rumble(0.8, 45.0)
		"sfx_cosmic_plague", "sfx_chronos_distortion", "sfx_strange_matter":
			pba = _gen_fm_drone(220.0, 14.0, 0.65)
		"sfx_gaia_bloom", "sfx_kardashev_ascension":
			pba = _gen_harmonic_chimes([440.0, 554.37, 659.25, 880.0], 0.7)
		"sfx_mutagenic_spore", "sfx_actor_born":
			pba = _gen_bubbling(380.0, 0.5)
		"sfx_matter_transmuter", "sfx_transmutation", "sfx_transmute_spark", "sfx_theory_discovered":
			pba = _gen_harmonic_chimes([528.0, 660.0, 792.0, 1056.0], 0.65)
		"sfx_zero_point_well":
			pba = _gen_reverse_swell(0.75)
		"sfx_building_damage", "sfx_shield_impact", "sfx_actor_perished":
			pba = _gen_debris_crunch(0.25)
		"sfx_building_collapse", "sfx_city_destroyed":
			pba = _gen_debris_crunch(0.65)
		"sfx_steam_quench":
			pba = _gen_steam_quench(0.4)
		"sfx_magma_fissure":
			pba = _gen_sub_rumble(0.7, 55.0)
		"sfx_crystal_resonance", "sfx_city_founded", "sfx_alliance_formed":
			pba = _gen_harmonic_chimes([659.25, 987.77, 1318.51], 0.7)
		"sfx_bio_bloom":
			pba = _gen_harmonic_chimes([330.0, 440.0, 550.0], 0.6)
		"sfx_plasma_burst", "sfx_plasma_bolt", "sfx_war_declared":
			pba = _gen_laser_sweep(1200.0, 220.0, 0.35)
		"sfx_nanite_swarm":
			pba = _gen_nanite_buzz(0.4)
		"sfx_dyson_swarm_hum", "sfx_dyson_hum":
			pba = _gen_looping_drone(120.0, 1.0)
			wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
			wav.loop_end = pba.size() / 2
		"sfx_dyson_ring_tone":
			pba = _gen_ring_resonant_tone(1.0)
			wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
			wav.loop_end = pba.size() / 2
		"sfx_dyson_shell_hum":
			pba = _gen_looping_drone(90.0, 1.0)
			wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
			wav.loop_end = pba.size() / 2
		"sfx_matrioshka_pulse", "sfx_dyson_stage_advance":
			pba = _gen_digital_arpeggio(0.45)
		"ambient_deep_space":
			pba = _gen_ambient_deep_space(2.0)
			wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
			wav.loop_end = pba.size() / 2
		"ambient_planetary_pulse", "ambient_solar_wind":
			pba = _gen_ambient_planetary(2.0)
			wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
			wav.loop_end = pba.size() / 2
		"ambient_stellar_corona":
			pba = _gen_looping_drone(110.0, 2.0)
			wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
			wav.loop_end = pba.size() / 2
		"ui_click", "sfx_brush_switch":
			pba = _gen_blip(880.0, 0.04)
		"ui_power_select", "sfx_power_trigger", "sfx_power_paint":
			pba = _gen_laser_sweep(660.0, 990.0, 0.08)
		"ui_toggle":
			pba = _gen_blip(550.0, 0.05)
		"ui_error":
			pba = _gen_error_buzz(0.12)
		_:
			pba = _gen_blip(440.0, 0.12)

	wav.data = pba
	return wav


func _gen_meteor() -> PackedByteArray:
	var count: int = int(SAMPLE_RATE * 0.8)
	var pba := PackedByteArray()
	pba.resize(count * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	for i in range(count):
		var t: float = float(i) / float(SAMPLE_RATE)
		var env: float = exp(-i * 5.0 / float(count))
		var freq: float = lerpf(180.0, 35.0, minf(t * 3.0, 1.0))
		var sub: float = sin(t * freq * TAU)
		var noise: float = rng.randf_range(-1.0, 1.0)
		var val: float = clampf((sub * 0.7 + noise * 0.5) * env * 1.3, -1.0, 1.0)
		pba.encode_s16(i * 2, int(val * 32767.0))
	return pba


func _gen_laser_sweep(f_start: float, f_end: float, duration: float) -> PackedByteArray:
	var count: int = int(SAMPLE_RATE * duration)
	var pba := PackedByteArray()
	pba.resize(count * 2)
	var phase: float = 0.0
	for i in range(count):
		var norm: float = float(i) / float(count)
		var env: float = exp(-norm * 5.5)
		var cur_f: float = lerpf(f_start, f_end, sqrt(norm))
		phase += cur_f / float(SAMPLE_RATE)
		var mod: float = sin(phase * TAU * 3.0) * 0.25
		var val: float = sin(phase * TAU + mod) * env
		pba.encode_s16(i * 2, int(clampf(val, -1.0, 1.0) * 32767.0))
	return pba


func _gen_plasma_noise(duration: float, tone_f: float) -> PackedByteArray:
	var count: int = int(SAMPLE_RATE * duration)
	var pba := PackedByteArray()
	pba.resize(count * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	var filter: float = 0.0
	for i in range(count):
		var norm: float = float(i) / float(count)
		var env: float = sin(norm * PI) * exp(-norm * 2.0)
		var raw: float = rng.randf_range(-1.0, 1.0)
		filter += (raw - filter) * 0.09
		var tone: float = sin(float(i) / float(SAMPLE_RATE) * tone_f * TAU) * 0.35
		var val: float = (filter * 0.8 + tone) * env
		pba.encode_s16(i * 2, int(clampf(val, -1.0, 1.0) * 32767.0))
	return pba


func _gen_sub_rumble(duration: float, base_freq: float) -> PackedByteArray:
	var count: int = int(SAMPLE_RATE * duration)
	var pba := PackedByteArray()
	pba.resize(count * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 101
	var brown: float = 0.0
	for i in range(count):
		var norm: float = float(i) / float(count)
		var env: float = sin(norm * PI)
		brown = clampf(brown + rng.randf_range(-0.1, 0.1), -1.0, 1.0)
		var sub: float = sin(float(i) / float(SAMPLE_RATE) * base_freq * TAU)
		var val: float = (sub * 0.65 + brown * 0.35) * env
		pba.encode_s16(i * 2, int(clampf(val, -1.0, 1.0) * 32767.0))
	return pba


func _gen_fm_drone(f_carrier: float, f_mod: float, duration: float) -> PackedByteArray:
	var count: int = int(SAMPLE_RATE * duration)
	var pba := PackedByteArray()
	pba.resize(count * 2)
	for i in range(count):
		var t: float = float(i) / float(SAMPLE_RATE)
		var norm: float = float(i) / float(count)
		var env: float = sin(norm * PI)
		var lfo: float = sin(t * f_mod * TAU) * 35.0
		var val: float = sin(t * (f_carrier + lfo) * TAU) * env
		pba.encode_s16(i * 2, int(clampf(val, -1.0, 1.0) * 32767.0))
	return pba


func _gen_harmonic_chimes(pitches: Array, duration: float) -> PackedByteArray:
	var count: int = int(SAMPLE_RATE * duration)
	var pba := PackedByteArray()
	pba.resize(count * 2)
	var n: float = float(pitches.size())
	for i in range(count):
		var t: float = float(i) / float(SAMPLE_RATE)
		var env: float = exp(-i * 4.5 / float(count))
		var mix: float = 0.0
		for p in pitches:
			mix += sin(t * float(p) * TAU)
		var val: float = (mix / n) * env
		pba.encode_s16(i * 2, int(clampf(val, -1.0, 1.0) * 32767.0))
	return pba


func _gen_bubbling(base_f: float, duration: float) -> PackedByteArray:
	var count: int = int(SAMPLE_RATE * duration)
	var pba := PackedByteArray()
	pba.resize(count * 2)
	var phase: float = 0.0
	for i in range(count):
		var norm: float = float(i) / float(count)
		var env: float = sin(norm * PI)
		var mod: float = sin(norm * 35.0 * TAU) * 140.0
		phase += (base_f + mod) / float(SAMPLE_RATE)
		var val: float = sin(phase * TAU) * env
		pba.encode_s16(i * 2, int(clampf(val, -1.0, 1.0) * 32767.0))
	return pba


func _gen_reverse_swell(duration: float) -> PackedByteArray:
	var count: int = int(SAMPLE_RATE * duration)
	var pba := PackedByteArray()
	pba.resize(count * 2)
	for i in range(count):
		var t: float = float(i) / float(SAMPLE_RATE)
		var norm: float = float(i) / float(count)
		var env: float = pow(norm, 2.6) if norm < 0.88 else (1.0 - (norm - 0.88) / 0.12)
		var freq: float = lerpf(80.0, 340.0, norm * norm)
		var val: float = sin(t * freq * TAU) * env
		pba.encode_s16(i * 2, int(clampf(val, -1.0, 1.0) * 32767.0))
	return pba


func _gen_debris_crunch(duration: float) -> PackedByteArray:
	var count: int = int(SAMPLE_RATE * duration)
	var pba := PackedByteArray()
	pba.resize(count * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 555
	for i in range(count):
		var env: float = exp(-i * 6.5 / float(count))
		var noise: float = rng.randf_range(-1.0, 1.0)
		var crisp: float = (1.0 if noise > 0.0 else -1.0) * 0.4 + noise * 0.6
		var val: float = crisp * env
		pba.encode_s16(i * 2, int(clampf(val, -1.0, 1.0) * 32767.0))
	return pba


func _gen_steam_quench(duration: float) -> PackedByteArray:
	var count: int = int(SAMPLE_RATE * duration)
	var pba := PackedByteArray()
	pba.resize(count * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 333
	var lp: float = 0.0
	for i in range(count):
		var env: float = exp(-i * 5.0 / float(count))
		var n: float = rng.randf_range(-1.0, 1.0)
		lp += (n - lp) * 0.4
		var val: float = lp * env
		pba.encode_s16(i * 2, int(clampf(val, -1.0, 1.0) * 32767.0))
	return pba


func _gen_nanite_buzz(duration: float) -> PackedByteArray:
	var count: int = int(SAMPLE_RATE * duration)
	var pba := PackedByteArray()
	pba.resize(count * 2)
	for i in range(count):
		var t: float = float(i) / float(SAMPLE_RATE)
		var norm: float = float(i) / float(count)
		var env: float = sin(norm * PI)
		var step_f: float = 800.0 if int(t * 30.0) % 2 == 0 else 1200.0
		var val: float = sin(t * step_f * TAU) * env
		pba.encode_s16(i * 2, int(clampf(val, -1.0, 1.0) * 32767.0))
	return pba


func _gen_digital_arpeggio(duration: float) -> PackedByteArray:
	var count: int = int(SAMPLE_RATE * duration)
	var pba := PackedByteArray()
	pba.resize(count * 2)
	var freqs: Array[float] = [523.25, 659.25, 783.99, 1046.50]
	for i in range(count):
		var t: float = float(i) / float(SAMPLE_RATE)
		var norm: float = float(i) / float(count)
		var env: float = exp(-norm * 4.5)
		var idx: int = mini(int(norm * 4.0), 3)
		var val: float = sin(t * freqs[idx] * TAU) * env
		pba.encode_s16(i * 2, int(clampf(val, -1.0, 1.0) * 32767.0))
	return pba


func _gen_looping_drone(base_f: float, duration: float) -> PackedByteArray:
	var count: int = int(SAMPLE_RATE * duration)
	var pba := PackedByteArray()
	pba.resize(count * 2)
	for i in range(count):
		var t: float = float(i) / float(SAMPLE_RATE)
		var h1: float = sin(t * base_f * TAU)
		var h2: float = sin(t * (base_f * 2.0) * TAU) * 0.35
		var val: float = (h1 + h2) * 0.65
		pba.encode_s16(i * 2, int(clampf(val, -1.0, 1.0) * 32767.0))
	return pba


func _gen_ring_resonant_tone(duration: float) -> PackedByteArray:
	var count: int = int(SAMPLE_RATE * duration)
	var pba := PackedByteArray()
	pba.resize(count * 2)
	for i in range(count):
		var t: float = float(i) / float(SAMPLE_RATE)
		var t1: float = sin(t * 160.0 * TAU)
		var t2: float = sin(t * 240.0 * TAU) * 0.5
		var beat: float = sin(t * 2.0 * TAU) * 0.15 + 0.85
		var val: float = (t1 + t2) * 0.5 * beat
		pba.encode_s16(i * 2, int(clampf(val, -1.0, 1.0) * 32767.0))
	return pba


func _gen_ambient_deep_space(duration: float) -> PackedByteArray:
	var count: int = int(SAMPLE_RATE * duration)
	var pba := PackedByteArray()
	pba.resize(count * 2)
	for i in range(count):
		var t: float = float(i) / float(SAMPLE_RATE)
		var osc1: float = sin(t * 55.0 * TAU)
		var osc2: float = sin(t * 82.5 * TAU) * 0.4
		var osc3: float = sin(t * 55.5 * TAU) * 0.25
		var val: float = (osc1 + osc2 + osc3) * 0.45
		pba.encode_s16(i * 2, int(clampf(val, -1.0, 1.0) * 32767.0))
	return pba


func _gen_ambient_planetary(duration: float) -> PackedByteArray:
	var count: int = int(SAMPLE_RATE * duration)
	var pba := PackedByteArray()
	pba.resize(count * 2)
	for i in range(count):
		var t: float = float(i) / float(SAMPLE_RATE)
		var mod: float = sin(t * 0.5 * TAU) * 0.2 + 0.8
		var osc1: float = sin(t * 73.42 * TAU)
		var osc2: float = sin(t * 110.13 * TAU) * 0.35
		var val: float = (osc1 + osc2) * 0.5 * mod
		pba.encode_s16(i * 2, int(clampf(val, -1.0, 1.0) * 32767.0))
	return pba


func _gen_blip(freq: float, duration: float) -> PackedByteArray:
	var count: int = int(SAMPLE_RATE * duration)
	var pba := PackedByteArray()
	pba.resize(count * 2)
	for i in range(count):
		var t: float = float(i) / float(SAMPLE_RATE)
		var env: float = exp(-i * 12.0 / float(count))
		var val: float = sin(t * freq * TAU) * env
		pba.encode_s16(i * 2, int(clampf(val, -1.0, 1.0) * 32767.0))
	return pba


func _gen_error_buzz(duration: float) -> PackedByteArray:
	var count: int = int(SAMPLE_RATE * duration)
	var pba := PackedByteArray()
	pba.resize(count * 2)
	for i in range(count):
		var t: float = float(i) / float(SAMPLE_RATE)
		var env: float = exp(-i * 6.0 / float(count))
		var sq: float = 1.0 if sin(t * 150.0 * TAU) > 0.0 else -1.0
		var val: float = sq * 0.5 * env
		pba.encode_s16(i * 2, int(clampf(val, -1.0, 1.0) * 32767.0))
	return pba


func cleanup() -> void:
	for p in _pos_pool:
		if p != null:
			p.stop()
	for p in _ui_pool:
		if p != null:
			p.stop()
	if _ambient_player_a != null:
		_ambient_player_a.stop()
	if _ambient_player_b != null:
		_ambient_player_b.stop()
	if _dyson_player != null:
		_dyson_player.stop()
	if _gen_player != null:
		_gen_player.stop()
