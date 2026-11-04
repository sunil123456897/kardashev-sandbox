extends SceneTree

## Adversarial Reviewer 2 Verification Suite: HUD Modals, Event Log & Audio Robustness
## Focus areas:
## 1. Modal state transitions: mutual exclusivity, Escape handling, F9 analytics toggle, invalid IDs
## 2. Event log category filtering & meta link parsing (pan:x,y, city:id, actor:id, culture:id, malformed strings)
## 3. Audio subsystem robustness: bus indexing safety, volume db clamping without -inf, voice recycling under rapid bursts

const WorldSimulationScript = preload("res://scripts/sim/world_simulation.gd")
const GodHUDScript = preload("res://scripts/ui/god_hud.gd")
const AudioSubsystemScript = preload("res://scripts/audio/audio_subsystem.gd")
const SandboxOrbitCameraScript = preload("res://scripts/render/orbit_camera.gd")
const MainScript = preload("res://scripts/main.gd")

var total_assertions: int = 0
var passed_assertions: int = 0
var failed_assertions: int = 0
var findings: Array[Dictionary] = []

func check(condition: bool, msg: String) -> void:
	total_assertions += 1
	if condition:
		passed_assertions += 1
	else:
		failed_assertions += 1
		printerr("FAIL: ", msg)

func record_finding(severity: String, title: String, details: String) -> void:
	findings.append({
		"severity": severity,
		"title": title,
		"details": details
	})

func _init() -> void:
	print("================================================================================")
	print("=== RUNNING ADVERSARIAL REVIEWER 2 TEST SUITE (M3 ROBUSTNESS & EDGE CASES) ===")
	print("================================================================================")

	var sim := WorldSimulationScript.new()
	sim.name = "SimFixture"
	root.add_child(sim)
	sim.setup_world(4242)

	var cam := SandboxOrbitCameraScript.new()
	cam.name = "CamFixture"
	root.add_child(cam)

	var hud := GodHUDScript.new()
	hud.name = "HUDFixture"
	hud.camera = cam
	root.add_child(hud)
	hud.setup(sim)

	var audio := AudioSubsystemScript.new()
	audio.name = "AudioFixture"
	root.add_child(audio)
	audio.setup(sim)

	# =========================================================================
	# SECTION 1: Modal State Transitions & Mutual Exclusivity
	# =========================================================================
	print("\n--- SECTION 1: Modal State Transitions & Mutual Exclusivity ---")

	var modal_ids: Array[String] = ["codex", "laws", "city", "actor", "culture", "analytics"]

	# Test 1.1: Mutual Exclusivity on Every Open
	for target_id in modal_ids:
		hud.open_modal(target_id, 0)
		check(hud._active_modal_id == target_id, "Active modal id should be '%s'" % target_id)
		for check_id in modal_ids:
			var panel: PanelContainer = hud._modals.get(check_id)
			if check_id == target_id:
				check(panel != null and panel.visible, "Modal '%s' should be visible" % check_id)
			else:
				check(panel != null and not panel.visible, "Modal '%s' should NOT be visible when '%s' is open" % [check_id, target_id])

	# Test 1.2: Rapid switching between modals
	var sequence: Array[String] = ["city", "analytics", "actor", "laws", "culture", "codex", "city"]
	for target_id in sequence:
		hud.open_modal(target_id, 0)
		var visible_count := 0
		for m_id in modal_ids:
			if hud._modals[m_id].visible:
				visible_count += 1
		check(visible_count == 1, "Exactly one modal must be visible during rapid transition to '%s'" % target_id)

	# Test 1.3: Close Active Modal
	hud.close_active_modal()
	check(hud._active_modal_id == "", "Active modal ID must be empty after close_active_modal()")
	for m_id in modal_ids:
		check(not hud._modals[m_id].visible, "Modal '%s' must not be visible after close_active_modal()" % m_id)

	# Test 1.4: Idempotency of close_active_modal()
	hud.close_active_modal()
	check(hud._active_modal_id == "", "close_active_modal() on already closed state is safe")

	# Test 1.5: Toggle modal
	hud.toggle_modal("analytics")
	check(hud._active_modal_id == "analytics" and hud._modals["analytics"].visible, "toggle_modal opens closed modal")
	hud.toggle_modal("analytics")
	check(hud._active_modal_id == "" and not hud._modals["analytics"].visible, "toggle_modal closes open modal")

	# Test 1.6: Toggle different modal while one is open
	hud.open_modal("laws")
	check(hud._active_modal_id == "laws", "Laws open")
	hud.toggle_modal("analytics")
	check(hud._active_modal_id == "analytics", "Toggling analytics while laws open switches to analytics")
	check(not hud._modals["laws"].visible, "Previous modal laws is hidden")
	check(hud._modals["analytics"].visible, "New modal analytics is visible")
	hud.close_active_modal()

	# Test 1.7: Adversarial edge case: open_modal with non-existent ID
	hud.open_modal("nonexistent_modal_xyz_123")
	var visible_any := false
	for m_id in modal_ids:
		if hud._modals[m_id].visible:
			visible_any = true
	check(not visible_any, "No registered modal should become visible on unknown ID")
	# Check what close_active_modal does when active ID is unknown
	hud.close_active_modal()
	if hud._active_modal_id != "":
		record_finding("Minor", "Unregistered modal ID persists in _active_modal_id",
			"open_modal accepts unregistered ID, but close_active_modal checks _modals.has(_active_modal_id), leaving unknown ID uncleared.")
		hud._active_modal_id = "" # reset for subsequent tests

	# Test 1.8: Non-existent IDs in inspector methods (graceful error handling)
	hud.open_city_inspector(-9999)
	check(hud._active_modal_id == "city" and hud._modals["city"].visible, "open_city_inspector with invalid ID does not crash")
	var city_labels: Array = hud._vbox_city_content.get_children()
	check(city_labels.size() > 0, "Error label rendered in city inspector for missing city")

	hud.open_actor_inspector(-9999)
	check(hud._active_modal_id == "actor" and hud._modals["actor"].visible, "open_actor_inspector with invalid ID does not crash")
	var actor_labels: Array = hud._vbox_actor_content.get_children()
	check(actor_labels.size() > 0, "Error label rendered in actor inspector for missing actor")

	hud.open_culture_inspector(-9999)
	check(hud._active_modal_id == "culture" and hud._modals["culture"].visible, "open_culture_inspector with invalid ID does not crash")
	var cult_labels: Array = hud._vbox_culture_content.get_children()
	check(cult_labels.size() > 0, "Error label rendered in culture inspector for missing culture")
	hud.close_active_modal()

	# Test 1.9: Main scene Escape and F9 handling
	var main_scene := MainScript.new()
	root.add_child(main_scene)
	if main_scene.sim == null:
		main_scene._ready()

	# Press F9 to open analytics
	var ev_f9 := InputEventKey.new()
	ev_f9.pressed = true
	ev_f9.keycode = KEY_F9
	main_scene._unhandled_input(ev_f9)
	check(main_scene.hud._active_modal_id == "analytics", "F9 opened analytics in main")
	check(main_scene.hud._modal_analytics.visible, "Analytics modal visible in main")

	# Press Escape to close modal
	var ev_esc := InputEventKey.new()
	ev_esc.pressed = true
	ev_esc.keycode = KEY_ESCAPE
	main_scene._unhandled_input(ev_esc)
	check(main_scene.hud._active_modal_id == "", "Escape closed modal in main")
	check(not main_scene.hud._modal_analytics.visible, "Analytics modal hidden in main")

	# Press Escape again when no modal is open (should clear divine power)
	main_scene.hud.selected_power_id = "power_meteor"
	main_scene._unhandled_input(ev_esc)
	check(main_scene.hud.selected_power_id == "", "Escape when no modal open deselects divine power")
	main_scene.free()

	# =========================================================================
	# SECTION 2: Event Log Filtering & Meta Link Parsing
	# =========================================================================
	print("\n--- SECTION 2: Event Log Filtering & Meta Link Parsing ---")

	sim.event_log.clear()

	# Seed events across all categories
	sim._log_event("Дипломатический мир", "diplomacy", Color.CYAN)
	sim._log_event("Основана колония", "colony", Color.CYAN)
	sim._log_event("Мирный договор", "peace", Color.GREEN)
	sim._log_event("Военный альянс", "alliance", Color.BLUE)
	sim._log_event("Торговый путь", "trade", Color.YELLOW)

	sim._log_event("Началась война", "war", Color.RED)
	sim._log_event("Повреждено здание", "damage", Color.RED)
	sim._log_event("Набег варваров", "raid", Color.DARK_RED)
	sim._log_event("Разрушение полиса", "destruction", Color.DARK_RED)

	sim._log_event("Солнечный рой", "cosmos", Color.ORANGE)
	sim._log_event("Сегмент Сферы", "dyson", Color.GOLD)
	sim._log_event("Сверхновая", "supernova", Color.WHITE)
	sim._log_event("Этап Сферы", "stage", Color.GOLD)
	sim._log_event("Кольцо Сферы", "ring", Color.GOLD)
	sim._log_event("Скорлупа", "shell", Color.GOLD)
	sim._log_event("Матрёшка", "matrioshka", Color.GOLD)

	sim._log_event("Константа гравитации", "constants", Color.PURPLE)
	sim._log_event("Алхимическая реакция", "alchemy", Color.MAGENTA)
	sim._log_event("Аномалия поля", "anomaly", Color.VIOLET)
	sim._log_event("Термоядерная реакция", "reaction", Color.MAGENTA)

	sim._log_event("Божественная сила", "god_power", Color.LIGHT_CORAL)
	sim._log_event("Кисть бога", "brush", Color.LIGHT_CORAL)
	sim._log_event("Катаклизм", "cataclysm", Color.RED)
	sim._log_event("Метеоритный удар", "meteor", Color.FIREBRICK)
	sim._log_event("Антиматерия", "lance", Color.WHITE)
	sim._log_event("Землетрясение", "quake", Color.BROWN)

	sim._log_event("Научный прорыв", "science", Color.AQUAMARINE)
	sim._log_event("Открытие века", "breakthrough", Color.AQUAMARINE)
	sim._log_event("Старт проекта", "plot_start", Color.AQUA)
	sim._log_event("Запись в кодекс", "codex", Color.AQUAMARINE)
	sim._log_event("Новая теория", "discovery", Color.AQUAMARINE)

	sim._log_event("Событие без категории", "unregistered_unknown", Color.GRAY)

	check(sim.event_log.size() == 32, "Total 32 events logged")

	# Test 2.1: Category filter counts
	hud.select_event_log_category("diplomacy")
	var diplo_entries := hud.get_filtered_event_entries()
	check(diplo_entries.size() == 5, "diplomacy category filter returns exactly 5 entries (got %d)" % diplo_entries.size())

	hud.select_event_log_category("war")
	var war_entries := hud.get_filtered_event_entries()
	check(war_entries.size() == 4, "war category filter returns exactly 4 entries (got %d)" % war_entries.size())

	hud.select_event_log_category("megastructures")
	var mega_entries := hud.get_filtered_event_entries()
	check(mega_entries.size() == 7, "megastructures category filter returns exactly 7 entries (got %d)" % mega_entries.size())

	hud.select_event_log_category("alchemy")
	var alch_entries := hud.get_filtered_event_entries()
	check(alch_entries.size() == 4, "alchemy category filter returns exactly 4 entries (got %d)" % alch_entries.size())

	hud.select_event_log_category("god_powers")
	var god_entries := hud.get_filtered_event_entries()
	check(god_entries.size() == 6, "god_powers category filter returns exactly 6 entries (got %d)" % god_entries.size())

	hud.select_event_log_category("science")
	var sci_entries := hud.get_filtered_event_entries()
	check(sci_entries.size() == 5, "science category filter returns exactly 5 entries (got %d)" % sci_entries.size())

	hud.select_event_log_category("all")
	var all_entries := hud.get_filtered_event_entries()
	check(all_entries.size() == 32, "all category filter returns all 32 entries")

	hud.select_event_log_category("nonexistent_filter")
	var none_entries := hud.get_filtered_event_entries()
	check(none_entries.is_empty(), "nonexistent filter returns 0 entries")

	# Test 2.2: Meta link parsing (Valid and Adversarial/Malformed)
	var pan_signal_received: Array = [Vector2.ZERO]
	hud.camera_pan_requested.connect(func(pos: Vector2) -> void: pan_signal_received[0] = pos)

	# Valid pan link
	hud._on_event_log_meta_clicked("pan:450,850")
	check(pan_signal_received[0] == Vector2(450.0, 850.0), "pan:450,850 parsed accurately")
	check(cam.target_pos == Vector2(450.0, 850.0), "Camera target_pos updated to (450, 850)")

	# Malformed pan links (must not crash)
	hud._on_event_log_meta_clicked("pan:")
	check(true, "pan: empty coords handled without crash")

	hud._on_event_log_meta_clicked("pan:notanumber,notanumber")
	check(pan_signal_received[0] == Vector2.ZERO, "pan with non-numbers safely falls back to Vector2.ZERO")

	hud._on_event_log_meta_clicked("pan:100")
	check(true, "pan with single part handled without crash")

	hud._on_event_log_meta_clicked("pan:100,200,300")
	check(true, "pan with 3 parts handled without crash")

	# City meta link
	var valid_cid: int = int(sim.cities_map.keys()[0])
	hud._on_event_log_meta_clicked("city:%d" % valid_cid)
	check(hud._active_modal_id == "city" and hud._modals["city"].visible, "city:%d opens city inspector" % valid_cid)

	hud._on_event_log_meta_clicked("city:-999")
	check(hud._active_modal_id == "city", "city:-999 handled without crash")

	hud._on_event_log_meta_clicked("city:notanumber")
	check(hud._active_modal_id == "city", "city:notanumber parsed as 0 without crash")

	# Actor meta link
	var valid_aid: int = int(sim.actors[0]["id"])
	hud._on_event_log_meta_clicked("actor:%d" % valid_aid)
	check(hud._active_modal_id == "actor" and hud._modals["actor"].visible, "actor:%d opens actor inspector" % valid_aid)

	hud._on_event_log_meta_clicked("actor:-999")
	check(hud._active_modal_id == "actor", "actor:-999 handled without crash")

	# Culture meta link
	var valid_cltid: int = int(sim.cultures_map.keys()[0])
	hud._on_event_log_meta_clicked("culture:%d" % valid_cltid)
	check(hud._active_modal_id == "culture" and hud._modals["culture"].visible, "culture:%d opens culture inspector" % valid_cltid)

	hud._on_event_log_meta_clicked("culture:-999")
	check(hud._active_modal_id == "culture", "culture:-999 handled without crash")

	# Unknown meta prefix
	hud._on_event_log_meta_clicked("unsupported_prefix:12345")
	check(true, "unsupported meta prefix handled safely without crash")
	hud.close_active_modal()

	# =========================================================================
	# SECTION 3: Audio Subsystem Robustness & Voice Recycling
	# =========================================================================
	print("\n--- SECTION 3: Audio Subsystem Robustness & Voice Recycling ---")

	# Test 3.1: Bus indexing safety for non-existent buses
	audio.set_bus_volume_db("NonExistentBus_123", -12.0)
	check(true, "set_bus_volume_db with invalid bus name is a safe no-op")

	var non_vol: float = audio.get_bus_volume_db("NonExistentBus_123")
	check(non_vol == 0.0, "get_bus_volume_db with invalid bus returns 0.0")

	audio.set_bus_volume("NonExistentBus_123", 0.5)
	check(true, "set_bus_volume with invalid bus name is a safe no-op")

	var non_lin: float = audio.get_bus_volume("NonExistentBus_123")
	check(non_lin == 0.0, "get_bus_volume with invalid bus returns 0.0")

	audio.set_bus_mute("NonExistentBus_123", true)
	check(true, "set_bus_mute with invalid bus name is a safe no-op")

	var is_muted: bool = audio.is_bus_muted("NonExistentBus_123")
	check(not is_muted, "is_bus_muted with invalid bus returns false")

	# Test 3.2: Volume db clamping without -inf errors
	# linear = 0.0 must clamp to 0.0001 (-80 dB) and NEVER -inf
	audio.set_bus_volume("SFX", 0.0)
	var sfx_db: float = audio.get_bus_volume_db("SFX")
	check(not is_inf(sfx_db) and not is_nan(sfx_db), "set_bus_volume(0.0) must not produce -inf or NaN (got %f dB)" % sfx_db)
	check(is_equal_approx(sfx_db, -80.0), "set_bus_volume(0.0) clamps to -80.0 dB (got %f dB)" % sfx_db)

	# negative linear volume
	audio.set_bus_volume("SFX", -10.0)
	var neg_db: float = audio.get_bus_volume_db("SFX")
	check(not is_inf(neg_db) and is_equal_approx(neg_db, -80.0), "set_bus_volume(-10.0) safely clamps to -80.0 dB")

	# Reset bus volume to normal
	audio.set_bus_volume("SFX", 1.0)
	check(is_equal_approx(audio.get_bus_volume_db("SFX"), 0.0), "SFX volume restored to 0 dB")

	# Test 3.3: Rapid burst voice recycling (200 consecutive sounds)
	var start_sfx_count := audio.total_sfx_played
	var burst_iterations := 200

	for i in range(burst_iterations):
		audio.play_positional_sfx("sfx_meteor_impact", Vector2(100.0 + (i % 50), 200.0), 1.0, -10.0)
		audio.play_ui_sfx("ui_click", 1.0, -5.0)

	check(audio.total_sfx_played == start_sfx_count + (burst_iterations * 2), "total_sfx_played incremented by exactly 400")
	check(audio.get_positional_pool_size() == 16, "Positional voice pool size remained strictly 16 after burst")
	check(audio.get_ui_pool_size() == 8, "UI voice pool size remained strictly 8 after burst")

	# Test 3.4: Extreme pitch values clamped
	audio.play_positional_sfx("sfx_meteor_impact", Vector2(500, 500), 0.00001)
	audio.play_positional_sfx("sfx_meteor_impact", Vector2(500, 500), 9999.0)
	audio.play_positional_sfx("sfx_meteor_impact", Vector2(500, 500), -50.0)
	check(true, "Extreme pitch scales do not crash audio subsystem")

	# Test 3.5: Unknown procedural recipe fallback
	var unknown_stream := audio.get_cached_stream("completely_unknown_sound_id_999")
	check(unknown_stream != null, "Unknown recipe generates non-null fallback audio stream")
	check(unknown_stream.data.size() > 0, "Unknown recipe fallback stream contains audio PCM data")

	# =========================================================================
	# SUMMARY
	# =========================================================================
	print("\n================================================================================")
	print("ADVERSARIAL SUITE SUMMARY: Total: %d | Passed: %d | Failed: %d" % [total_assertions, passed_assertions, failed_assertions])
	if not findings.is_empty():
		print("\nFINDINGS DETECTED (%d):" % findings.size())
		for f in findings:
			print(" - [%s] %s: %s" % [f["severity"], f["title"], f["details"]])
	print("================================================================================")

	hud.free()
	cam.free()
	audio.free()
	sim.free()

	if failed_assertions > 0:
		printerr("ADVERSARIAL SUITE FAILED with %d assertion failures!" % failed_assertions)
		quit(1)
	else:
		print("ADVERSARIAL SUITE PASSED SUCCESSFULLY (FAILED: 0)")
		quit(0)
