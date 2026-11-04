extends SceneTree

## M3 R2 Challenger 2 Verification Suite
## Focus:
## 1. Camera target_pos, target_zoom, position under NaN/Inf and boundary stress
## 2. Event log category filter 'god_powers' matching and edge cases
## 3. open_modal('city', null), 'actor', 'culture' null-safety & non-existent IDs
## 4. Meta-link parsing safety

const WorldSimulationScript = preload("res://scripts/sim/world_simulation.gd")
const SandboxOrbitCameraScript = preload("res://scripts/render/orbit_camera.gd")
const GodHUDScript = preload("res://scripts/ui/god_hud.gd")

var total_assertions: int = 0
var passed_assertions: int = 0
var failed_assertions: int = 0
var findings: Array[String] = []


func record_assert(condition: bool, msg: String) -> void:
	total_assertions += 1
	if condition:
		passed_assertions += 1
	else:
		failed_assertions += 1
		findings.append(msg)
		printerr("  [FAIL] %s" % msg)


func _init() -> void:
	print("================================================================================")
	print("=== RUNNING M3 R2 CHALLENGER 2: DEEP EMPIRICAL VERIFICATION SUITE ===")
	print("================================================================================")

	var sim = WorldSimulationScript.new()
	sim.name = "SimFixture"
	root.add_child(sim)
	sim.setup_world(9999)

	var cam = SandboxOrbitCameraScript.new()
	cam.name = "CamFixture"
	root.add_child(cam)

	var hud = GodHUDScript.new()
	hud.name = "HUDFixture"
	hud.camera = cam
	root.add_child(hud)
	hud.setup(sim)

	# Run suites
	test_issue_1_camera_nan_inf(cam, hud)
	test_issue_2_filter_god_powers(hud, sim)
	test_issue_3_modal_null_safety(hud, sim)
	test_rapid_concurrency_stress(cam, hud, sim)

	print("\n================================================================================")
	print("=== VERIFICATION SUMMARY: Total: %d | Passed: %d | Failed: %d ===" % [total_assertions, passed_assertions, failed_assertions])
	if findings.is_empty():
		print("=== ALL DEEP EMPIRICAL CHECKS PASSED (FAILED: 0) ===")
	else:
		print("=== FINDINGS DETECTED: ===")
		for f in findings:
			print("  - %s" % f)
	print("================================================================================")

	hud.free()
	cam.free()
	sim.free()

	if failed_assertions > 0:
		assert(failed_assertions == 0, "M3 R2 verification failed with %d findings" % failed_assertions)
	quit(0)


func test_issue_1_camera_nan_inf(cam, hud) -> void:
	print("\n--- 1. Testing Camera NaN/Inf Resilience ---")

	var adversarial_positions := [
		Vector2(NAN, NAN),
		Vector2(NAN, 540.0),
		Vector2(960.0, NAN),
		Vector2(INF, INF),
		Vector2(-INF, -INF),
		Vector2(INF, 540.0),
		Vector2(960.0, -INF),
		Vector2(1e30, -1e30),
		Vector2(-1e30, 1e30),
		Vector2(-999999.0, -999999.0),
		Vector2(999999.0, 999999.0),
	]

	for pos in adversarial_positions:
		cam.pan_to(pos, 2.0)
		record_assert(is_finite(cam.target_pos.x) and is_finite(cam.target_pos.y),
			"Camera target_pos must be finite for input %s, got %s" % [str(pos), str(cam.target_pos)])
		record_assert(cam.target_pos.x >= 0.0 and cam.target_pos.x <= 1920.0,
			"target_pos.x must be within [0, 1920], got %f" % cam.target_pos.x)
		record_assert(cam.target_pos.y >= 0.0 and cam.target_pos.y <= 1080.0,
			"target_pos.y must be within [0, 1080], got %f" % cam.target_pos.y)

		cam.step_camera(0.016)
		record_assert(is_finite(cam.position.x) and is_finite(cam.position.y),
			"Camera position must be finite after step_camera, got %s" % str(cam.position))

	var adversarial_zooms := [
		NAN,
		INF,
		-INF,
		-10.0,
		0.0,
		0.0001,
		1e15,
		-1e15
	]

	for z in adversarial_zooms:
		cam.pan_to(Vector2(960.0, 540.0), z)
		record_assert(is_finite(cam.target_zoom), "target_zoom must be finite for input %s" % str(z))
		record_assert(cam.target_zoom >= cam.MIN_ZOOM and cam.target_zoom <= cam.MAX_ZOOM,
			"target_zoom must be in [%f, %f], got %f" % [cam.MIN_ZOOM, cam.MAX_ZOOM, cam.target_zoom])

		cam.step_camera(0.016)
		record_assert(is_finite(cam.zoom.x) and is_finite(cam.zoom.y),
			"Camera zoom must remain finite, got %s" % str(cam.zoom))

	# Test zoom_step and orbit_drag with NaN/Inf
	cam.zoom_step(NAN)
	cam.zoom_step(INF)
	cam.zoom_step(-INF)
	cam.zoom_step(-5.0)
	cam.zoom_step(0.0)
	record_assert(is_finite(cam.target_zoom), "target_zoom after invalid zoom_step remains finite")

	cam.orbit_drag(Vector2(NAN, NAN))
	cam.orbit_drag(Vector2(INF, -INF))
	record_assert(is_finite(cam.target_pos.x) and is_finite(cam.target_pos.y),
		"target_pos after invalid orbit_drag remains finite")

	# Test HUD meta click pan with NaN / Inf
	hud._on_event_log_meta_clicked("pan:nan,nan")
	hud._on_event_log_meta_clicked("pan:inf,-inf")
	hud._on_event_log_meta_clicked("pan:1e50,-1e50")
	hud._on_event_log_meta_clicked("pan:abc,xyz")
	cam.step_camera(0.016)
	record_assert(is_finite(cam.position.x) and is_finite(cam.position.y),
		"Camera position finite after HUD meta pan events")


func test_issue_2_filter_god_powers(hud, sim) -> void:
	print("\n--- 2. Testing Category Filter 'god_powers' Matching ---")

	var valid_god_power_entries := [
		{"category": "god_powers", "text": "Plural god_powers"},
		{"category": "god_power", "text": "Singular god_power"},
		{"category": "GOD_POWERS", "text": "Uppercase GOD_POWERS"},
		{"category": "GOD_POWER", "text": "Uppercase GOD_POWER"},
		{"category": "brush", "text": "Brush power"},
		{"category": "cataclysm", "text": "Cataclysm power"},
		{"category": "meteor", "text": "Meteor power"},
		{"category": "lance", "text": "Lance power"},
		{"category": "quake", "text": "Quake power"}
	]

	for entry in valid_god_power_entries:
		var matches: bool = hud._is_entry_in_category(entry, "god_powers")
		record_assert(matches, "Entry category '%s' must match filter 'god_powers'" % str(entry.get("category")))

	var non_god_power_entries := [
		{"category": "diplomacy", "text": "Peace treaty"},
		{"category": "war", "text": "Siege"},
		{"category": "megastructures", "text": "Dyson swarm"},
		{"category": "alchemy", "text": "Transmutation"},
		{"category": "science", "text": "Discovery"},
		{"category": "random_unknown", "text": "Unknown"},
		{"category": "", "text": "Empty"},
		{},
	]

	for entry in non_god_power_entries:
		var matches: bool = hud._is_entry_in_category(entry, "god_powers")
		record_assert(not matches, "Entry category '%s' must NOT match filter 'god_powers'" % str(entry.get("category", "<none>")))

	# Populate sim event_log with known distribution
	sim.event_log.clear()
	for entry in valid_god_power_entries:
		sim.event_log.append(entry)
	for entry in non_god_power_entries:
		sim.event_log.append(entry)

	hud.select_event_log_category("god_powers")
	var filtered = hud.get_filtered_event_entries()
	record_assert(filtered.size() == valid_god_power_entries.size(),
		"Filtered god_powers count expected %d, got %d" % [valid_god_power_entries.size(), filtered.size()])

	hud.select_event_log_category("all")
	var all_filtered = hud.get_filtered_event_entries()
	record_assert(all_filtered.size() == valid_god_power_entries.size() + non_god_power_entries.size(),
		"Filter 'all' count expected %d, got %d" % [valid_god_power_entries.size() + non_god_power_entries.size(), all_filtered.size()])


func test_issue_3_modal_null_safety(hud, sim) -> void:
	print("\n--- 3. Testing open_modal Null-Safety and Resiliency ---")

	# Test 3.1: Null target_param on all registered modals
	var modal_ids: Array[String] = ["city", "actor", "culture", "analytics", "codex", "laws"]
	for mid in modal_ids:
		# Calling open_modal with null should NOT crash with Invalid call to 'int' constructor
		hud.open_modal(mid, null)
		record_assert(hud._active_modal_id == mid, "Modal %s opened with null target_param" % mid)
		record_assert(hud._modals[mid].visible, "Modal %s is visible" % mid)

		# Toggling with null
		hud.toggle_modal(mid, null)
		record_assert(hud._active_modal_id == "", "Modal %s closed via toggle with null" % mid)
		record_assert(not hud._modals[mid].visible, "Modal %s is hidden" % mid)

	# Test 3.2: Non-integer target_param values
	var bizarre_params = [
		null,
		0,
		-1,
		-999999,
		999999,
		"42",
		"0",
		"-1",
		3.14,
		-100.5
	]

	for p in bizarre_params:
		hud.open_modal("city", p)
		record_assert(hud._active_modal_id == "city", "Handled param %s without crash" % str(p))
		hud.close_active_modal()

	# Test 3.3: Unknown modal IDs
	hud.open_modal("non_existent_modal_alpha", null)
	record_assert(hud._active_modal_id == "non_existent_modal_alpha", "Unknown modal id recorded")
	for mid in modal_ids:
		record_assert(not hud._modals[mid].visible, "No registered modal visible for unknown id")

	hud.close_active_modal()
	record_assert(hud._active_modal_id == "", "close_active_modal clears unknown _active_modal_id")

	# Test 3.4: Inspect with out of range IDs
	hud.open_city_inspector(-9999)
	record_assert(hud._active_modal_id == "city", "City inspector with -9999 opened")
	var city_children = hud._vbox_city_content.get_children()
	record_assert(city_children.size() > 0, "City inspector fallback rendered")

	hud.open_actor_inspector(-9999)
	record_assert(hud._active_modal_id == "actor", "Actor inspector with -9999 opened")
	var actor_children = hud._vbox_actor_content.get_children()
	record_assert(actor_children.size() > 0, "Actor inspector fallback rendered")

	hud.open_culture_inspector(-9999)
	record_assert(hud._active_modal_id == "culture", "Culture inspector with -9999 opened")
	var cult_children = hud._vbox_culture_content.get_children()
	record_assert(cult_children.size() > 0, "Culture inspector fallback rendered")

	hud.close_active_modal()


func test_rapid_concurrency_stress(cam, hud, sim) -> void:
	print("\n--- 4. Testing Rapid Concurrency / Interleaved Actions ---")

	var modal_ids: Array[String] = ["city", "actor", "culture", "analytics", "codex", "laws"]
	var rng := RandomNumberGenerator.new()
	rng.seed = 123456

	for iter in range(300):
		var action: int = rng.randi_range(0, 4)
		match action:
			0:
				var mid: String = modal_ids[rng.randi_range(0, modal_ids.size() - 1)]
				var param = null if rng.randf() < 0.5 else rng.randi_range(-10, 50)
				hud.open_modal(mid, param)
			1:
				hud.close_active_modal()
			2:
				var x: float = rng.randf_range(-500.0, 2500.0) if rng.randf() > 0.1 else NAN
				var y: float = rng.randf_range(-500.0, 1500.0) if rng.randf() > 0.1 else INF
				var z: float = rng.randf_range(0.5, 5.0) if rng.randf() > 0.1 else NAN
				cam.pan_to(Vector2(x, y), z)
			3:
				cam.step_camera(0.016)
			4:
				var cats := ["all", "god_powers", "diplomacy", "war", "megastructures"]
				hud.select_event_log_category(cats[rng.randi_range(0, cats.size() - 1)])

	record_assert(is_finite(cam.position.x) and is_finite(cam.position.y),
		"Camera position finite after 300 rapid interleaved actions")
	record_assert(is_finite(cam.target_zoom) and is_finite(cam.zoom.x),
		"Camera zoom finite after 300 rapid interleaved actions")

	hud.close_active_modal()
	record_assert(hud._active_modal_id == "", "Active modal clean after stress run")
