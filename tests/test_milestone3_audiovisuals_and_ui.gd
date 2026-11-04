extends SceneTree

## Автоматизированный тестовый набор Майлстоуна 3:
## Аудиовизуальная атмосфера (F7), 2D Шейдеры (F8) и Продвинутые Инспекторы Бога (F9).

const WorldSimulationScript = preload("res://scripts/sim/world_simulation.gd")
const CosmicRendererScript = preload("res://scripts/render/cosmic_renderer.gd")
const SandboxOrbitCameraScript = preload("res://scripts/render/orbit_camera.gd")
const GodHUDScript = preload("res://scripts/ui/god_hud.gd")
const AudioSubsystemScript = preload("res://scripts/audio/audio_subsystem.gd")
const MainScript = preload("res://scripts/main.gd")


func _init() -> void:
	print("================================================================================")
	print("=== RUNNING MILESTONE 3 (AUDIOVISUALS, SHADERS & GOD INSPECTORS) TEST SUITE ===")
	print("================================================================================")

	var sim := WorldSimulationScript.new()
	sim.name = "SimFixture"
	root.add_child(sim)
	sim.setup_world(1337)

	# -------------------------------------------------------------------------
	# [1/6] F7: Audio Subsystem Programmatic Buses, Stream Cache & Voice Pools
	# -------------------------------------------------------------------------
	print("\n[1/6] Verifying F7: Audio Subsystem Buses, Cache & Voice Pools...")

	var audio := AudioSubsystemScript.new()
	audio.name = "AudioSubsystemFixture"
	root.add_child(audio)
	audio.setup(sim)

	# 1.1 AudioServer Buses
	assert(AudioServer.get_bus_count() >= 4, "Expected at least 4 audio buses")
	var bus_names: Array[String] = []
	for i in range(AudioServer.get_bus_count()):
		bus_names.append(AudioServer.get_bus_name(i))
	assert(bus_names.has("Master"), "Master bus missing from AudioServer")
	assert(bus_names.has("SFX"), "SFX bus missing from AudioServer")
	assert(bus_names.has("Ambient"), "Ambient bus missing from AudioServer")
	assert(bus_names.has("UI"), "UI bus missing from AudioServer")

	# Volume test
	var sfx_idx: int = AudioServer.get_bus_index("SFX")
	var original_vol: float = AudioServer.get_bus_volume_db(sfx_idx)
	audio.set_bus_volume_db("SFX", -6.0)
	assert(is_equal_approx(AudioServer.get_bus_volume_db(sfx_idx), -6.0), "SFX volume setting failed")
	audio.set_bus_volume_db("SFX", original_vol)

	# 1.2 Procedural Stream Cache verification (29 sound profiles)
	assert(audio.get_cached_recipe_count() >= 29, "Expected at least 29 procedural sound recipes cached, got %d" % audio.get_cached_recipe_count())
	var test_recipes: Array[String] = [
		"sfx_meteor_impact",
		"sfx_antimatter_lance",
		"sfx_gamma_ray_burst",
		"sfx_chronos_distortion",
		"sfx_vacuum_decay",
		"sfx_strange_matter",
		"sfx_singularity_collapse",
		"sfx_transmute_spark",
		"sfx_alchemical_detonation",
		"sfx_dyson_stage_advance",
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
		"ambient_deep_space",
		"ambient_solar_wind",
		"ui_click",
	]
	for r_name in test_recipes:
		assert(audio.has_cached_recipe(r_name), "Recipe '%s' missing from stream cache!" % r_name)
		var stream: AudioStreamWAV = audio.get_cached_stream(r_name)
		assert(stream != null, "Cached stream for '%s' is null!" % r_name)
		assert(stream.mix_rate == 22050, "Expected mix_rate 22050 Hz for '%s'" % r_name)
		assert(stream.data.size() > 0, "Audio data buffer for '%s' must not be empty!" % r_name)

	# 1.3 Voice Pool Round-Robin Playback Under Dummy Driver
	assert(audio.get_positional_pool_size() == 16, "Positional pool size must be exactly 16")
	assert(audio.get_ui_pool_size() == 8, "UI pool size must be exactly 8")

	# Play 32 sounds consecutively to verify voice recycling & headless stability
	for i in range(32):
		audio.play_positional_sfx("sfx_meteor_impact", Vector2(100.0 + i * 20.0, 200.0), 0.8, 0.05 * (i % 5))
		audio.play_ui_sfx("ui_click")
	assert(audio.total_sfx_played >= 64, "Total SFX played counter must reflect played count")

	# Test ambient and Dyson resonator triggers
	audio.play_ambient("ambient_solar_wind", 0.0)
	assert(audio.current_ambient_id == "ambient_solar_wind", "Ambient sound not updated")
	audio.set_dyson_hum_stage(3)
	assert(audio.current_dyson_stage == 3, "Dyson hum stage not updated")

	# 1.4 Simulation Signal Wiring
	var sfx_count_before: int = audio.total_sfx_played
	sim.sfx_requested.emit("sfx_antimatter_lance", Vector2(960.0, 540.0), 1.0, 0.0)
	assert(audio.total_sfx_played == sfx_count_before + 1, "Simulation sfx_requested signal must trigger audio playback")

	sim.dyson_megastructure_stage_advanced.emit(2, "Equatorial Ring Frame", 1500.0)
	assert(audio.current_dyson_stage == 2, "Dyson stage advance signal must update audio dyson stage")

	print(" -> F7 Audio Subsystem tests PASSED!")

	# -------------------------------------------------------------------------
	# [2/6] F8: 2D Shaders Compilation & Cosmic Renderer Feedback Hooks
	# -------------------------------------------------------------------------
	print("\n[2/6] Verifying F8: 2D Shaders & Cosmic Renderer Visuals...")

	# 2.1 Shader file loading and Material verification
	var dyson_shader: Shader = load("res://shaders/dyson_aura.gdshader")
	assert(dyson_shader != null, "Failed to load res://shaders/dyson_aura.gdshader")
	var dyson_mat := ShaderMaterial.new()
	dyson_mat.shader = dyson_shader
	dyson_mat.set_shader_parameter("corona_color", Color(1.0, 0.8, 0.2))
	dyson_mat.set_shader_parameter("absorption_power", 1.8)
	dyson_mat.set_shader_parameter("swirl_speed", 1.5)

	var lens_shader: Shader = load("res://shaders/cosmic_lens.gdshader")
	assert(lens_shader != null, "Failed to load res://shaders/cosmic_lens.gdshader")
	var lens_mat := ShaderMaterial.new()
	lens_mat.shader = lens_shader
	lens_mat.set_shader_parameter("shockwave_center", Vector2(0.5, 0.5))
	lens_mat.set_shader_parameter("shockwave_progress", 0.45)
	lens_mat.set_shader_parameter("refraction_strength", 0.06)

	# 2.2 CosmicRenderer Setup & Signal Hooks
	var renderer := CosmicRendererScript.new()
	renderer.name = "CosmicRendererFixture"
	root.add_child(renderer)
	renderer.setup(sim)

	# Shockwave queue test
	assert(renderer._active_shockwaves.is_empty(), "Initial shockwave queue must be empty")
	sim.shockwave_triggered.emit(Vector2(640.0, 360.0), 180.0, Color(0.2, 0.9, 1.0))
	assert(renderer._active_shockwaves.size() == 1, "Renderer must enqueue triggered shockwave")
	assert(renderer.rendered_shockwave_count == 1, "Shockwave counter mismatch")

	# Step renderer process to verify shockwave animation progress and expiration
	renderer._process(0.2)
	assert(renderer._active_shockwaves[0]["progress"] > 0.0, "Shockwave progress must advance with delta")
	renderer._process(1.5)
	assert(renderer._active_shockwaves.is_empty(), "Shockwave must expire and be removed after completion")
	assert(renderer.rendered_shockwave_count == 0, "Shockwave counter must be 0 after expiration")

	# Dyson visual state signal test
	sim.dyson_visual_state_updated.emit(4, 0.85, 3)
	assert(renderer._dyson_visual_stage == 4, "Renderer must mirror dyson stage 4")
	assert(is_equal_approx(renderer._dyson_visual_progress, 0.85), "Renderer must mirror dyson progress")
	assert(renderer._dyson_segment_count == 3, "Renderer segment count mismatch")
	assert(renderer.rendered_dyson_segment_count == 3, "Renderer rendered_dyson_segment_count mismatch")

	# 2.3 Real-Time Civilization Overlays (Wars, Alliances, Trade routes)
	var city_ids: Array = sim.cities_map.keys()
	assert(city_ids.size() >= 2, "Simulation must contain at least 2 cities for diplomacy visuals")
	var c1: int = int(city_ids[0])
	var c2: int = int(city_ids[1])

	# Set WAR
	sim.set_diplomacy_status(c1, c2, "WAR")
	renderer._refresh_counts()
	assert(renderer.rendered_active_war_count >= 1, "Renderer must register at least 1 active war overlay")

	# Set ALLIANCE
	sim.set_diplomacy_status(c1, c2, "ALLIANCE")
	renderer._refresh_counts()
	assert(renderer.rendered_alliance_count >= 1, "Renderer must register alliance arc overlay")
	assert(renderer.rendered_trade_route_count >= 1, "Renderer must register animated trade route overlay")

	# Set PEACE
	sim.set_diplomacy_status(c1, c2, "PEACE")
	renderer._refresh_counts()
	assert(renderer.rendered_active_war_count == 0, "Active war overlay must clear on peace")

	# Verify view mode switching without errors
	renderer.set_view_mode(SandboxOrbitCameraScript.ViewMode.MODE_PLANET)
	assert(renderer.view_mode == SandboxOrbitCameraScript.ViewMode.MODE_PLANET)
	renderer.set_view_mode(SandboxOrbitCameraScript.ViewMode.MODE_STAR_DYSON)
	assert(renderer.view_mode == SandboxOrbitCameraScript.ViewMode.MODE_STAR_DYSON)
	renderer.set_view_mode(SandboxOrbitCameraScript.ViewMode.MODE_SYSTEM_OVERVIEW)
	assert(renderer.view_mode == SandboxOrbitCameraScript.ViewMode.MODE_SYSTEM_OVERVIEW)

	print(" -> F8 2D Shaders & Cosmic Renderer tests PASSED!")

	# -------------------------------------------------------------------------
	# [3/6] F9: God HUD Modal Architecture & Inspectors
	# -------------------------------------------------------------------------
	print("\n[3/6] Verifying F9: God HUD Modals & Inspectors...")

	var hud := GodHUDScript.new()
	hud.name = "GodHUDFixture"
	root.add_child(hud)
	hud.setup(sim)

	# 3.1 Modal registration and state checks
	var expected_modals: Array[String] = ["codex", "laws", "city", "actor", "culture", "analytics"]
	for m_id in expected_modals:
		assert(hud._modal_nodes.has(m_id), "Modal '%s' was not registered in GodHUD" % m_id)

	assert(hud._active_modal_id == "", "Initial active modal must be empty")
	hud.open_modal("codex")
	assert(hud._active_modal_id == "codex", "Active modal must be 'codex'")
	assert(hud._modal_codex.visible, "Codex modal must be visible")

	hud.close_active_modal()
	assert(hud._active_modal_id == "", "Active modal must be empty after closing")
	assert(not hud._modal_codex.visible, "Codex modal must be hidden after closing")

	# 3.2 Polis Inspector (_modal_city)
	var test_city_id: int = int(city_ids[0])
	var city_data: Dictionary = sim.get_detailed_city_data(test_city_id)
	assert(city_data.has("name") and city_data["name"] != "", "City detailed data missing name")
	assert(city_data.has("buildings") and city_data["buildings"] is Dictionary, "City buildings dict missing")
	assert(city_data.has("relations") and city_data["relations"] is Dictionary, "City relations dict missing")

	hud.open_city_inspector(test_city_id)
	assert(hud._active_modal_id == "city", "Active modal must be 'city'")
	assert(hud._modal_city.visible, "City inspector modal must be visible")

	# 3.3 Actor Inspector (_modal_actor)
	assert(not sim.actors.is_empty(), "Simulation must contain actors")
	var test_actor_id: int = int(sim.actors[0]["id"])
	var actor_data: Dictionary = sim.get_detailed_actor_data(test_actor_id)
	assert(actor_data.has("name") and actor_data["name"] != "", "Actor detailed data missing name")
	assert(actor_data.has("hp") and int(actor_data["hp"]) > 0, "Actor HP must be positive")
	assert(actor_data.has("thought"), "Actor detailed data missing thought")
	assert(actor_data.has("pos"), "Actor detailed data missing pos")

	hud.open_actor_inspector(test_actor_id)
	assert(hud._active_modal_id == "actor", "Active modal must be 'actor'")
	assert(hud._modal_actor.visible, "Actor inspector modal must be visible")

	# 3.4 Culture Inspector (_modal_culture)
	var cult_id: int = int(sim.cities_map[test_city_id]["culture_id"])
	var culture_data: Dictionary = hud.get_detailed_culture_data(cult_id)
	assert(culture_data.has("id") and culture_data["id"] == cult_id, "Culture ID mismatch")
	assert(culture_data.has("name") and culture_data["name"] != "", "Culture name missing")
	assert(culture_data.has("subspecies_name"), "Subspecies name missing")
	assert(culture_data.has("traits") and culture_data["traits"] is Array, "Culture traits missing")
	assert(culture_data.has("cohesion") and float(culture_data["cohesion"]) >= 0.0, "Culture cohesion missing")
	assert(culture_data.has("member_cities") and culture_data["member_cities"] is Array, "Member cities missing")

	hud.open_culture_inspector(cult_id)
	assert(hud._active_modal_id == "culture", "Active modal must be 'culture'")
	assert(hud._modal_culture.visible, "Culture inspector modal must be visible")

	print(" -> F9 God HUD Inspectors tests PASSED!")

	# -------------------------------------------------------------------------
	# [4/6] F9: Global World Analytics Dashboard (F9)
	# -------------------------------------------------------------------------
	print("\n[4/6] Verifying F9: Global World Analytics Dashboard...")

	var metrics: Dictionary = sim.get_global_world_metrics()
	assert(metrics.has("total_population") and float(metrics["total_population"]) > 0.0, "Global population invalid")
	assert(metrics.has("max_kardashev") and float(metrics["max_kardashev"]) >= 0.5, "Kardashev tier invalid")
	assert(metrics.has("dyson_stage") and int(metrics["dyson_stage"]) >= 1, "Dyson stage invalid")
	assert(metrics.has("dyson_stage_name") and metrics["dyson_stage_name"] != "", "Dyson stage name invalid")
	assert(metrics.has("active_wars_count") and int(metrics["active_wars_count"]) >= 0, "Active wars count invalid")
	assert(metrics.has("active_alliances_count") and int(metrics["active_alliances_count"]) >= 0, "Alliances count invalid")
	assert(metrics.has("total_cities") and int(metrics["total_cities"]) == sim.cities_map.size(), "City count mismatch")

	# Open analytics modal
	hud.toggle_analytics_modal()
	assert(hud._active_modal_id == "analytics", "Active modal must be 'analytics'")
	assert(hud._modal_analytics.visible, "Analytics modal must be visible")

	# Toggle off
	hud.toggle_analytics_modal()
	assert(hud._active_modal_id == "", "Analytics modal must close on toggle")
	assert(not hud._modal_analytics.visible, "Analytics modal must be hidden after toggle")

	print(" -> F9 Global World Analytics Dashboard tests PASSED!")

	# -------------------------------------------------------------------------
	# [5/6] F9: Interactive Event Log Categories & Click-to-Pan Navigation
	# -------------------------------------------------------------------------
	print("\n[5/6] Verifying F9: Event Log Filtering & Click-to-Pan Navigation...")

	# Log events across multiple categories
	sim._log_event("Мирный договор подписан на саммите", "diplomacy", Color.CYAN)
	sim._log_event("Вражеский легион осаждает цитадель", "war", Color.RED)
	sim._log_event("Сборщик Сферы Дайсона введен в строй", "megastructures", Color.YELLOW)
	sim._log_event("Алхимическая реакция плазмы и океана", "alchemy", Color.GREEN)
	sim._log_event("Божественная длань применила Антиматерию", "god_powers", Color.PURPLE)
	sim._log_event("Открыта квантовая теория гравитации", "science", Color.LIGHT_BLUE)

	assert(hud._event_log_items.size() >= 6, "Expected at least 6 event log items")

	# Category filtering test: WAR
	hud.select_event_log_category("war")
	assert(hud._event_filter_category == "war", "Category filter state mismatch")
	var war_entries: Array[Dictionary] = hud.get_filtered_event_entries()
	assert(not war_entries.is_empty(), "Filtered war entries must not be empty")
	for entry in war_entries:
		assert(hud._is_entry_in_category(entry, "war"), "Entry category '%s' does not match filter 'war'" % entry.get("category", ""))

	# Category filtering test: MEGASTRUCTURES
	hud.select_event_log_category("megastructures")
	var mega_entries: Array[Dictionary] = hud.get_filtered_event_entries()
	assert(not mega_entries.is_empty(), "Filtered megastructures entries must not be empty")
	for entry in mega_entries:
		assert(hud._is_entry_in_category(entry, "megastructures"), "Entry category mismatch for megastructures")

	# Category filtering test: ALL
	hud.select_event_log_category("all")
	var all_entries: Array[Dictionary] = hud.get_filtered_event_entries()
	assert(all_entries.size() == hud._event_log_items.size(), "Filter 'all' must return all logged items")

	# Camera pan and click-to-pan test
	var cam := SandboxOrbitCameraScript.new()
	cam.name = "TestCam"
	root.add_child(cam)
	cam.position = Vector2(960.0, 540.0)
	cam.target_pos = Vector2(960.0, 540.0)

	# Direct cam.pan_to test
	cam.pan_to(Vector2(400.0, 300.0), 2.2)
	assert(cam.target_pos == Vector2(400.0, 300.0), "Camera target_pos must update to (400, 300)")
	assert(is_equal_approx(cam.target_zoom, 2.2), "Camera target_zoom must update to 2.2")

	# GodHUD camera hook test
	hud.camera = cam
	var received_pan: Array = [Vector2.ZERO]
	hud.camera_pan_requested.connect(func(pos: Vector2) -> void: received_pan[0] = pos)

	# Simulate rich text metadata click: pan:720,480
	hud._on_event_log_meta_clicked("pan:720,480")
	assert(received_pan[0] == Vector2(720.0, 480.0), "camera_pan_requested signal payload mismatch")
	assert(cam.target_pos == Vector2(720.0, 480.0), "Camera target_pos must update via meta click")

	# Simulate rich text metadata click: city:<id>
	hud._on_event_log_meta_clicked("city:%d" % test_city_id)
	assert(hud._active_modal_id == "city", "Clicking city meta link must open city inspector modal")
	assert(hud._modal_city.visible, "City inspector modal must be visible")

	print(" -> F9 Event Log Filtering & Navigation tests PASSED!")

	# -------------------------------------------------------------------------
	# [6/6] Full Scene Integration & Hotkey Smoke Test (main.gd)
	# -------------------------------------------------------------------------
	print("\n[6/6] Verifying Full Scene Integration & Hotkeys in main.gd...")

	var main_scene := MainScript.new()
	main_scene.name = "MainSceneFixture"
	root.add_child(main_scene)
	if main_scene.sim == null:
		main_scene._ready()

	assert(main_scene.sim != null, "main.sim must be instantiated")
	assert(main_scene.renderer != null, "main.renderer must be instantiated")
	assert(main_scene.camera != null, "main.camera must be instantiated")
	assert(main_scene.hud != null, "main.hud must be instantiated")
	assert(main_scene.audio != null, "main.audio must be instantiated")
	assert(main_scene.hud.camera == main_scene.camera, "main.hud.camera must point to main.camera")

	# Test F9 hotkey input event
	var ev_f9 := InputEventKey.new()
	ev_f9.pressed = true
	ev_f9.keycode = KEY_F9
	main_scene._unhandled_input(ev_f9)
	assert(main_scene.hud._active_modal_id == "analytics", "F9 key must open analytics modal")
	assert(main_scene.hud._modal_analytics.visible, "Analytics modal must be visible on F9")

	# Test Escape key closes modal
	var ev_esc := InputEventKey.new()
	ev_esc.pressed = true
	ev_esc.keycode = KEY_ESCAPE
	main_scene._unhandled_input(ev_esc)
	assert(main_scene.hud._active_modal_id == "", "Escape key must close active modal")
	assert(not main_scene.hud._modal_analytics.visible, "Analytics modal must be hidden after Escape")

	# Test T hotkey (Codex)
	var ev_t := InputEventKey.new()
	ev_t.pressed = true
	ev_t.keycode = KEY_T
	main_scene._unhandled_input(ev_t)
	assert(main_scene.hud._active_modal_id == "codex", "T key must toggle codex modal")
	main_scene._unhandled_input(ev_esc)
	assert(main_scene.hud._active_modal_id == "", "Escape must close codex")

	# Test L hotkey (Laws)
	var ev_l := InputEventKey.new()
	ev_l.pressed = true
	ev_l.keycode = KEY_L
	main_scene._unhandled_input(ev_l)
	assert(main_scene.hud._active_modal_id == "laws", "L key must toggle laws modal")
	main_scene._unhandled_input(ev_esc)
	assert(main_scene.hud._active_modal_id == "", "Escape must close laws")

	# Clean up test nodes
	main_scene.free()
	cam.free()
	hud.free()
	renderer.free()
	audio.free()
	sim.free()

	print("\n================================================================================")
	print("=== ALL MILESTONE 3 (AUDIOVISUALS, SHADERS & GOD INSPECTORS) CHECKS PASSED (FAILED: 0) ===")
	print("================================================================================")
	quit(0)
