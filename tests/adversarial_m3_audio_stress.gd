extends SceneTree

## ADVERSARIAL STRESS TEST: Milestone 3 Audio Voice Pool & Shockwave Queue
## Empirical stress harness designed to break:
## 1. AudioSubsystem voice pool recycling under 100+ to 500+ rapid bursts
## 2. CosmicRenderer shockwave queue under 50+ to 100+ rapid triggers
## 3. Headless Dummy audio driver buffer handling and stream synthesis
## 4. Memory leaks and orphan node accumulation

const WorldSimulationScript = preload("res://scripts/sim/world_simulation.gd")
const CosmicRendererScript = preload("res://scripts/render/cosmic_renderer.gd")
const AudioSubsystemScript = preload("res://scripts/audio/audio_subsystem.gd")

func _init() -> void:
	print("================================================================================")
	print("=== EMPIRICAL ADVERSARIAL STRESS TEST: M3 AUDIO & SHOCKWAVE QUEUES ===")
	print("================================================================================")

	var sim := WorldSimulationScript.new()
	sim.name = "SimStressFixture"
	root.add_child(sim)
	sim.setup_world(4242)

	var audio := AudioSubsystemScript.new()
	audio.name = "AudioStressFixture"
	root.add_child(audio)
	audio.setup(sim)

	var renderer := CosmicRendererScript.new()
	renderer.name = "RendererStressFixture"
	root.add_child(renderer)
	renderer.setup(sim)

	# --------------------------------------------------------------------------
	# [TEST SUITE 1] AUDIO VOICE POOL RAPID BURST & RECYCLING STRESS
	# --------------------------------------------------------------------------
	print("\n[STRESS 1] Testing AudioSubsystem voice pool recycling under massive bursts...")

	var initial_audio_child_count: int = audio.get_child_count()
	# Expect 16 positional + 8 UI + 2 ambient + 1 dyson + 1 generator = 28
	assert(initial_audio_child_count == 28, "Expected exactly 28 child players in AudioSubsystem, got %d" % initial_audio_child_count)
	assert(audio.get_positional_pool_size() == 16, "Positional pool must have 16 players")
	assert(audio.get_ui_pool_size() == 8, "UI pool must have 8 players")

	# Test 1.1: 128 rapid positional SFX requests
	var sfx_names: Array[String] = [
		"sfx_meteor_impact", "sfx_antimatter_lance", "sfx_plasma_burst",
		"sfx_seismic_quake", "sfx_building_damage", "sfx_laser_fire"
	]
	var initial_sfx_count: int = audio.total_sfx_played

	for i in range(128):
		var sfx_id: String = sfx_names[i % sfx_names.size()]
		var pos: Vector2 = Vector2(randf_range(10.0, 1900.0), randf_range(10.0, 1000.0))
		var pitch: float = randf_range(0.5, 2.0)
		var vol: float = randf_range(-12.0, 0.0)
		audio.play_sfx(sfx_id, pos, pitch, vol)

	assert(audio.total_sfx_played == initial_sfx_count + 128, "Total SFX count mismatch after 128 positional bursts")
	assert(audio._pos_pool_index == (128 % 16), "Positional pool index must wrap modulo 16 cleanly")
	assert(audio.get_child_count() == initial_audio_child_count, "AudioSubsystem allocated orphan nodes during burst!")

	# Verify all 16 positional players are in a valid state
	for i in range(16):
		var p2d: AudioStreamPlayer2D = audio._pos_pool[i]
		assert(p2d != null, "Positional player %d is null" % i)
		assert(p2d.stream != null, "Positional player %d stream is null" % i)
		assert(p2d.pitch_scale >= 0.2 and p2d.pitch_scale <= 4.0, "Player pitch scale not clamped properly")
		assert(p2d.bus == "SFX", "Player bus corrupted")

	# Test 1.2: 128 rapid UI SFX requests
	var ui_sfx_names: Array[String] = ["ui_click", "ui_power_select", "ui_toggle", "ui_error"]
	var sfx_before_ui: int = audio.total_sfx_played

	for i in range(128):
		var sfx_id: String = ui_sfx_names[i % ui_sfx_names.size()]
		var pitch: float = randf_range(0.8, 1.2)
		var vol: float = randf_range(-6.0, 2.0)
		audio.play_ui_sfx(sfx_id, pitch, vol)

	assert(audio.total_sfx_played == sfx_before_ui + 128, "Total SFX count mismatch after 128 UI bursts")
	assert(audio._ui_pool_index == (128 % 8), "UI pool index must wrap modulo 8 cleanly")
	assert(audio.get_child_count() == initial_audio_child_count, "AudioSubsystem allocated orphan nodes during UI burst!")

	for i in range(8):
		var p: AudioStreamPlayer = audio._ui_pool[i]
		assert(p != null, "UI player %d is null" % i)
		assert(p.stream != null, "UI player %d stream is null" % i)
		assert(p.pitch_scale >= 0.2 and p.pitch_scale <= 4.0, "UI Player pitch scale not clamped properly")
		assert(p.bus == "UI", "UI Player bus corrupted")

	# Test 1.3: Vector2.ZERO routing to UI pool
	var ui_idx_before: int = audio._ui_pool_index
	audio.play_sfx("ui_click", Vector2.ZERO, 1.0, 0.0)
	assert(audio._ui_pool_index == (ui_idx_before + 1) % 8, "play_sfx with Vector2.ZERO must route to UI pool")

	# Test 1.4: Simulation signal flooding (200 signals)
	var sfx_before_sig: int = audio.total_sfx_played
	for i in range(200):
		sim.sfx_requested.emit("sfx_antimatter_lance", Vector2(100.0 + i, 200.0), 1.0, -3.0)
	assert(audio.total_sfx_played == sfx_before_sig + 200, "Signal flood did not process all 200 requests")

	print(" -> PASS: Voice pool recycling handled 457 rapid SFX calls with zero node allocations!")

	# --------------------------------------------------------------------------
	# [TEST SUITE 2] ADVERSARIAL INPUT HANDLING & HEADLESS DRIVER SAFETY
	# --------------------------------------------------------------------------
	print("\n[STRESS 2] Testing adversarial audio parameters and headless driver stability...")

	# 2.1 Unknown and malformed sound keys
	var fallback_count_before: int = audio.get_cached_recipe_count()
	var bogus_keys: Array[String] = [
		"unknown_sound_id_12345",
		"",
		"sfx_non_existent_void_destroyer",
		"!@#$%^&*()",
		"sfx_very_long_string_name_overflow_attempt_xyz_9999999999999999999999"
	]
	for b_key in bogus_keys:
		audio.play_sfx(b_key, Vector2(500.0, 500.0))
		audio.play_ui_sfx(b_key)
		assert(audio.has_cached_recipe(b_key), "Subsystem must generate fallback stream for unknown key: %s" % b_key)
		var fb_stream: AudioStreamWAV = audio.get_cached_stream(b_key)
		assert(fb_stream != null, "Fallback stream must not be null")
		assert(fb_stream.data.size() > 0, "Fallback stream data must not be empty")

	# 2.2 Extreme pitch scale values
	audio.play_sfx("sfx_meteor_impact", Vector2(100.0, 100.0), -100.0)
	audio.play_sfx("sfx_meteor_impact", Vector2(100.0, 100.0), 0.0)
	audio.play_sfx("sfx_meteor_impact", Vector2(100.0, 100.0), 100000.0)
	audio.play_ui_sfx("ui_click", -10.0)
	audio.play_ui_sfx("ui_click", 0.000001)
	audio.play_ui_sfx("ui_click", 99999.0)

	# 2.3 Extreme volume settings & bus volume zero/negative checks
	audio.set_bus_volume("SFX", 0.0) # linear 0.0 must be safely clamped
	assert(audio.get_bus_volume("SFX") >= 0.0, "Bus volume must remain non-negative")
	audio.set_bus_volume("SFX", -50.0) # negative linear
	audio.set_bus_volume("SFX", 1.0) # restore
	audio.set_bus_volume_db("SFX", -120.0)
	audio.set_bus_volume_db("SFX", 24.0)
	audio.set_bus_mute("SFX", true)
	assert(audio.is_bus_muted("SFX") == true, "Bus mute failed")
	audio.set_bus_mute("SFX", false)
	assert(audio.is_bus_muted("SFX") == false, "Bus unmute failed")

	# 2.4 Rapid ambient crossfade thrashing (50 rapid switches)
	var amb_keys: Array[String] = [
		"ambient_deep_space", "ambient_planetary_pulse", "ambient_stellar_corona", "ambient_solar_wind"
	]
	for i in range(50):
		var amb_id: String = amb_keys[i % amb_keys.size()]
		var intensity: float = randf()
		audio.transition_ambient(amb_id, intensity)
		assert(audio.current_ambient_id == amb_id, "Ambient id mismatch during thrash")

	# 2.5 Rapid Dyson hum stage advancement thrashing
	for stg in [-1, 0, 1, 2, 3, 4, 5, 10, 99]:
		audio.set_dyson_hum_stage(stg)
		assert(audio.current_dyson_stage == stg, "Dyson hum stage mismatch: %d" % stg)

	# 2.6 Stepping audio generator buffer under headless driver (300 frames)
	for i in range(300):
		audio.step_audio(0.016)

	print(" -> PASS: Adversarial parameters, fallback synthesis, and audio driver stepping survived!")

	# --------------------------------------------------------------------------
	# [TEST SUITE 3] COSMIC RENDERER SHOCKWAVE QUEUE BURST & DECAY STRESS
	# --------------------------------------------------------------------------
	print("\n[STRESS 3] Testing CosmicRenderer shockwave queue capacity and lifespan decay...")

	# 3.1 Initial state check
	assert(renderer._active_shockwaves.is_empty(), "Shockwave queue must start empty")
	assert(renderer.rendered_shockwave_count == 0, "Shockwave counter must start at 0")

	# 3.2 Burst trigger: 64 shockwaves in rapid succession
	for i in range(64):
		var pos := Vector2(randf_range(100.0, 1800.0), randf_range(100.0, 900.0))
		var radius: float = randf_range(50.0, 500.0)
		var col := Color(randf(), randf(), randf(), 1.0)
		sim.shockwave_triggered.emit(pos, radius, col)

	# The shockwave queue in CosmicRenderer is explicitly capped at 16 (FIFO eviction)
	assert(renderer._active_shockwaves.size() == 16, "Shockwave queue size must be strictly capped at 16! Got: %d" % renderer._active_shockwaves.size())
	assert(renderer.rendered_shockwave_count == 16, "rendered_shockwave_count mismatch under 64 burst: %d" % renderer.rendered_shockwave_count)
	assert(renderer._shockwave_lens_rect.visible == true, "Shockwave lens overlay must be visible when shockwaves active")

	# 3.3 Progressive time stepping and decay verification
	# Step 1: 0.15s
	renderer._process(0.15)
	assert(renderer._active_shockwaves.size() == 16, "Queue size should still be 16 after 0.15s (lifespan is 0.75s)")
	for sw in renderer._active_shockwaves:
		assert(sw["progress"] > 0.0, "Shockwave progress must advance with delta")
		assert(float(sw["current_radius"]) > 4.0, "Shockwave radius must expand with delta")

	# Step 2: 0.35s (total 0.50s elapsed)
	renderer._process(0.35)
	assert(renderer._active_shockwaves.size() <= 16, "Queue size must remain <= 16")

	# Step 3: 0.60s (total 1.10s elapsed > 0.75s max life)
	renderer._process(0.60)
	assert(renderer._active_shockwaves.is_empty(), "All shockwaves must expire and be cleanly removed after 1.10s! Left: %d" % renderer._active_shockwaves.size())
	assert(renderer.rendered_shockwave_count == 0, "rendered_shockwave_count must return to 0")
	assert(renderer._shockwave_lens_rect.visible == false, "Shockwave lens overlay must hide when queue is empty")

	# 3.4 Adversarial shockwave arguments
	# Negative radius, zero radius, colossal radius, offscreen coordinates
	sim.shockwave_triggered.emit(Vector2(-5000.0, -5000.0), 0.0, Color.BLACK)
	sim.shockwave_triggered.emit(Vector2(99999.0, 99999.0), -100.0, Color.TRANSPARENT)
	sim.shockwave_triggered.emit(Vector2(960.0, 540.0), 500000.0, Color(5.0, 5.0, 5.0, 1.0))
	assert(renderer._active_shockwaves.size() == 3, "Adversarial shockwaves must be enqueued safely")
	renderer._process(1.5)
	assert(renderer._active_shockwaves.is_empty(), "Adversarial shockwaves must cleanly expire without crash")

	print(" -> PASS: Shockwave queue saturation cap (16) and lifecycle decay fully verified!")

	# --------------------------------------------------------------------------
	# [TEST SUITE 4] CONCURRENT HIGH-FREQUENCY AUDIO & SHOCKWAVE LOAD
	# --------------------------------------------------------------------------
	print("\n[STRESS 4] Testing sustained concurrent audio + shockwave multi-frame load...")

	var total_frames: int = 30
	var total_sfx_in_run: int = 0
	var total_shocks_in_run: int = 0

	for frame in range(total_frames):
		# Trigger 4 shockwaves per frame
		for s in range(4):
			sim.shockwave_triggered.emit(Vector2(500.0 + s * 50.0, 300.0), 120.0, Color(0.2, 0.8, 1.0))
			total_shocks_in_run += 1

		# Trigger 8 positional SFX and 4 UI SFX per frame
		for a in range(8):
			sim.sfx_requested.emit("sfx_plasma_burst", Vector2(100.0 + a * 20.0, 150.0), 1.0, 0.0)
			total_sfx_in_run += 1
		for u in range(4):
			audio.play_ui_sfx("ui_click")
			total_sfx_in_run += 1

		# Step both systems
		audio.step_audio(0.033)
		renderer._process(0.033)

		# Verify queue bounds during continuous influx
		assert(renderer._active_shockwaves.size() <= 16, "Shockwave queue exceeded max capacity of 16 during frame %d" % frame)
		assert(audio.get_child_count() == initial_audio_child_count, "AudioSubsystem child count leaked during frame %d" % frame)

	# Flush remaining shockwaves
	renderer._process(1.5)
	assert(renderer._active_shockwaves.is_empty(), "Shockwaves must clear completely after load cessation")
	assert(renderer.rendered_shockwave_count == 0, "Shockwave counter must be 0 after flush")

	print(" -> PASS: Sustained load of %d SFX requests and %d shockwaves handled stably!" % [total_sfx_in_run, total_shocks_in_run])

	# --------------------------------------------------------------------------
	# [TEST SUITE 5] EXTREME SCALE BURST: 1000 SFX & 500 SHOCKWAVES
	# --------------------------------------------------------------------------
	print("\n[STRESS 5] Testing extreme scale: 1000 SFX burst and 500 shockwaves burst...")

	# 5.1 1000 SFX burst
	var sfx_extreme_start: int = audio.total_sfx_played
	for i in range(1000):
		var s_id: String = sfx_names[i % sfx_names.size()]
		audio.play_sfx(s_id, Vector2(float(i % 1920), float((i * 7) % 1080)))

	assert(audio.total_sfx_played == sfx_extreme_start + 1000, "1000 SFX burst counter mismatch")
	assert(audio.get_child_count() == initial_audio_child_count, "AudioSubsystem child count leaked during 1000 SFX burst!")

	# 5.2 500 shockwaves burst + view mode switching under active load
	for i in range(500):
		var pos := Vector2(float((i * 13) % 1920), float((i * 17) % 1080))
		sim.shockwave_triggered.emit(pos, 150.0 + float(i % 100), Color(0.1, 0.7, 1.0))
		if i % 100 == 0:
			renderer.set_view_mode(i % 3)
			renderer._process(0.01)

	assert(renderer._active_shockwaves.size() == 16, "Queue size must remain exactly 16 even under 500 shockwaves!")
	assert(renderer.rendered_shockwave_count == 16, "rendered_shockwave_count must be 16")

	# Decay and flush
	renderer._process(2.0)
	assert(renderer._active_shockwaves.is_empty(), "All shockwaves must flush after 2.0s")
	assert(renderer.rendered_shockwave_count == 0, "rendered_shockwave_count must be 0")

	# 5.3 Warmup idempotency check
	var cache_size_before_warmup: int = audio.get_cached_recipe_count()
	audio.warmup_all_recipes()
	audio.warmup_all_recipes()
	assert(audio.get_cached_recipe_count() == cache_size_before_warmup, "Calling warmup_all_recipes must be idempotent")

	print(" -> PASS: 1000 SFX and 500 shockwaves processed with zero memory or queue overflow!")

	# --------------------------------------------------------------------------
	# [TEST SUITE 6] HEAP MEMORY & ORPHAN NODE LEAK VERIFICATION
	# --------------------------------------------------------------------------
	print("\n[STRESS 6] Verifying heap memory stability and zero node leakage...")

	var nodes_before: int = Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
	var objects_before: int = Performance.get_monitor(Performance.OBJECT_COUNT)

	# Run 200 rapid cycles of mixed operations
	for cycle in range(200):
		audio.play_sfx("sfx_meteor_impact", Vector2(cycle * 5.0, 100.0))
		audio.play_ui_sfx("ui_click")
		sim.shockwave_triggered.emit(Vector2(200.0, 200.0), 100.0, Color.RED)
		renderer._process(0.01)
		audio.step_audio(0.01)

	# Flush renderer
	renderer._process(2.0)

	var nodes_after: int = Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
	var objects_after: int = Performance.get_monitor(Performance.OBJECT_COUNT)

	print("   Node count before: %d, after: %d" % [nodes_before, nodes_after])
	print("   Object count before: %d, after: %d" % [objects_before, objects_after])

	assert(nodes_after == nodes_before, "Node leak detected! Node count increased by %d" % (nodes_after - nodes_before))
	# Note: Small fluctuation in object count is normal for Godot internal caches, but must not explode
	assert(abs(objects_after - objects_before) < 100, "Unbounded object growth detected! Delta: %d" % (objects_after - objects_before))

	# Cleanup test nodes
	renderer.free()
	audio.free()
	sim.free()

	print("\n================================================================================")
	print("=== EMPIRICAL ADVERSARIAL STRESS TEST: ALL CHECKS PASSED (FAILED: 0) ===")
	print("================================================================================")
	quit(0)
