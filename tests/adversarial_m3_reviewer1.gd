extends SceneTree

## Стресс-тест и поиск уязвимостей для Майлстоуна 3 (Reviewer 1 Adversarial Suite).

const WorldSimulationScript = preload("res://scripts/sim/world_simulation.gd")
const CosmicRendererScript = preload("res://scripts/render/cosmic_renderer.gd")
const SandboxOrbitCameraScript = preload("res://scripts/render/orbit_camera.gd")
const GodHUDScript = preload("res://scripts/ui/god_hud.gd")
const AudioSubsystemScript = preload("res://scripts/audio/audio_subsystem.gd")

func _init() -> void:
	print("=== RUNNING M3 ADVERSARIAL STRESS TEST SUITE ===")

	var sim := WorldSimulationScript.new()
	sim.name = "SimFixture"
	root.add_child(sim)
	sim.setup_world(42)

	# -------------------------------------------------------------------------
	# ADV-1: Audio Subsystem Boundary & Resiliency Stress Test
	# -------------------------------------------------------------------------
	print("\n[ADV-1] Audio Subsystem Resiliency under Adversarial Inputs...")
	var audio := AudioSubsystemScript.new()
	root.add_child(audio)
	audio.setup(sim)

	# Test 1.1: Unknown / Invalid SFX ID fallback
	var fallback_wav = audio.get_or_synthesize_stream("completely_unknown_sfx_nonexistent_123")
	assert(fallback_wav != null, "AudioSubsystem must synthesize fallback stream for unknown SFX IDs")
	assert(fallback_wav.data.size() > 0, "Fallback stream data must not be empty")

	# Test 1.2: Extreme pitch and volume values
	audio.play_sfx("sfx_meteor_impact", Vector2(100.0, 100.0), -100.0, -120.0)
	audio.play_sfx("sfx_meteor_impact", Vector2(100.0, 100.0), 999.0, 24.0)
	audio.play_ui_sfx("ui_click", 0.0, -80.0)

	# Test 1.3: Audio pool saturation burst (200 sounds in single frame)
	for i in range(200):
		audio.play_sfx("sfx_laser_fire", Vector2(float(i * 10), 100.0))
		audio.play_ui_sfx("ui_toggle")
	assert(audio.total_sfx_played >= 400, "Audio counter must survive 200 bursts without leaking or crashing")

	# Test 1.4: Invalid bus operations
	audio.set_bus_volume_db("NonExistentBus", -10.0)
	var db_val = audio.get_bus_volume_db("NonExistentBus")
	assert(db_val == 0.0, "Invalid bus should return 0.0 dB safely")
	audio.set_bus_mute("NonExistentBus", true)
	assert(not audio.is_bus_muted("NonExistentBus"), "Invalid bus mute should return false safely")

	# Test 1.5: Generator audio step with null or dummy playback
	audio.step_audio(0.016)

	# Test 1.6: Ambient mood fallback
	audio._on_sim_ambient_state_changed("invalid_mood_xyz", 0.8)
	assert(audio.current_ambient_id == "ambient_deep_space", "Invalid ambient mood must fall back to deep space")

	# Test 1.7: Cleanup and double setup
	audio.cleanup()
	audio.setup(sim)
	print(" -> ADV-1 Audio Subsystem Resiliency PASSED!")

	# -------------------------------------------------------------------------
	# ADV-2: Cosmic Renderer Shockwave Saturation & Shader Uniform Safety
	# -------------------------------------------------------------------------
	print("\n[ADV-2] Cosmic Renderer Shockwave Saturation & Dyson Boundary Stress...")
	var renderer := CosmicRendererScript.new()
	root.add_child(renderer)
	renderer.setup(sim)

	# Test 2.1: Shockwave flooding (100 rapid triggers)
	for i in range(100):
		sim.shockwave_triggered.emit(Vector2(float(i * 15), 500.0), float(50 + i), Color(1.0, 0.0, 0.0))
	assert(renderer.rendered_shockwave_count <= 16, "Shockwaves must be capped at 16 to prevent OOM/render overload, got %d" % renderer.rendered_shockwave_count)

	# Test 2.2: Extreme delta in _process
	renderer._process(1000.0)
	assert(renderer._active_shockwaves.is_empty(), "All shockwaves must safely expire under large delta")
	assert(renderer.rendered_shockwave_count == 0, "Rendered shockwaves count must be 0 after large delta")

	# Test 2.3: Dyson visual state with edge values
	sim.dyson_visual_state_updated.emit(-1, -0.5, -10)
	assert(renderer._dyson_visual_stage == -1, "Renderer must accept stage update")
	sim.dyson_visual_state_updated.emit(99, 2.5, 999)
	assert(renderer._dyson_visual_stage == 99, "Renderer must handle out-of-range stage without crash")
	# Reset to valid state
	sim.dyson_visual_state_updated.emit(2, 0.5, 6)

	# Test 2.4: Cosmic lens shader material parameters when shockwave triggered at screen edges
	sim.shockwave_triggered.emit(Vector2(-500.0, -500.0), 50.0, Color.BLUE)
	sim.shockwave_triggered.emit(Vector2(3000.0, 3000.0), 50.0, Color.GREEN)
	renderer._process(0.016)
	print(" -> ADV-2 Cosmic Renderer & Shader Safety PASSED!")

	# -------------------------------------------------------------------------
	# ADV-3: Orbit Camera Extreme Coordinates & Pan Clamping
	# -------------------------------------------------------------------------
	print("\n[ADV-3] Orbit Camera Pan Boundaries & Zoom Clamping...")
	var cam := SandboxOrbitCameraScript.new()
	root.add_child(cam)

	# Test 3.1: Extreme pan_to coordinates
	cam.pan_to(Vector2(-99999.0, -99999.0), -10.0)
	# Check target_pos is clamped within valid bounds
	assert(cam.target_pos.x >= 0.0 and cam.target_pos.y >= 0.0, "Camera pan_to must clamp negative coords")
	assert(cam.target_zoom >= SandboxOrbitCameraScript.MIN_ZOOM, "Camera zoom must clamp to MIN_ZOOM")

	cam.pan_to(Vector2(99999.0, 99999.0), 100.0)
	assert(cam.target_pos.x <= 1920.0 and cam.target_pos.y <= 1080.0, "Camera pan_to must clamp excessive coords")
	assert(cam.target_zoom <= SandboxOrbitCameraScript.MAX_ZOOM, "Camera zoom must clamp to MAX_ZOOM")

	# Test 3.2: 3D focus_on_planet_dir with edge vector
	cam.focus_on_planet_dir(Vector3.ZERO)
	cam.focus_on_planet_dir(Vector3(0.0, 1.0, 0.0))
	cam.focus_on_planet_dir(Vector3(0.0, -1.0, 0.0))
	print(" -> ADV-3 Orbit Camera Clamping PASSED!")

	# -------------------------------------------------------------------------
	# ADV-4: God HUD Inspector Boundary & Corrupt Meta Links
	# -------------------------------------------------------------------------
	print("\n[ADV-4] God HUD Inspectors & Corrupt Meta Links Resiliency...")
	var hud := GodHUDScript.new()
	hud.camera = cam
	root.add_child(hud)
	hud.setup(sim)

	# Test 4.1: Open city inspector with non-existent city ID
	hud.open_city_inspector(-999)
	assert(hud._active_modal_id == "city", "Active modal must be city")
	assert(hud._vbox_city_content.get_child_count() > 0, "City inspector must show error label for missing city")

	# Test 4.2: Open actor inspector with non-existent actor ID
	hud.open_actor_inspector(-999)
	assert(hud._active_modal_id == "actor", "Active modal must be actor")
	assert(hud._vbox_actor_content.get_child_count() > 0, "Actor inspector must show error label for missing actor")

	# Test 4.3: Open culture inspector with non-existent culture ID
	hud.open_culture_inspector(-999)
	assert(hud._active_modal_id == "culture", "Active modal must be culture")
	assert(hud._vbox_culture_content.get_child_count() > 0, "Culture inspector must show error label for missing culture")

	# Test 4.4: Corrupt / Malformed BBCode Meta strings
	hud._on_event_log_meta_clicked("pan:invalid_coords")
	hud._on_event_log_meta_clicked("pan:100")
	hud._on_event_log_meta_clicked("city:not_an_int")
	hud._on_event_log_meta_clicked("actor:abc")
	hud._on_event_log_meta_clicked("culture:xyz")
	hud._on_event_log_meta_clicked("completely_unknown_meta_type:123")
	hud._on_event_log_meta_clicked("")

	# Test 4.5: Tile scanner with invalid tile index
	hud.update_tile_scanner(-1)
	hud.update_tile_scanner(999999)

	# Test 4.6: Rapid modal switching mutual exclusion
	hud.open_modal("codex")
	assert(hud._modal_codex.visible and not hud._modal_city.visible, "Codex must be visible, city hidden")
	hud.open_modal("analytics")
	assert(hud._modal_analytics.visible and not hud._modal_codex.visible, "Analytics must be visible, codex hidden")
	hud.open_modal("laws")
	assert(hud._modal_laws.visible and not hud._modal_analytics.visible, "Laws must be visible, analytics hidden")
	hud.close_active_modal()
	assert(not hud._modal_laws.visible, "Laws must be closed")

	print(" -> ADV-4 God HUD Inspectors & Corrupt Meta Links PASSED!")

	# Clean up
	cam.free()
	hud.free()
	renderer.free()
	audio.free()
	sim.free()

	print("\n=== ALL M3 ADVERSARIAL STRESS TESTS COMPLETED SUCCESSFULLY ===")
	quit(0)
