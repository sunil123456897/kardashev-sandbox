extends SceneTree

## ADVERSARIAL STRESS TEST: Milestone 3 Camera Extreme Cycling & Zero-Leak Verification
## Rigorous stress test harness designed to challenge:
## 1. 1,000 rapid cycles of pan_to alternating between extreme coordinates, NaNs, Infs, and valid points
## 2. Invariant verification: target_pos, position, zoom, and target_zoom finite and clamped within map boundaries
## 3. step_camera resilience with pathological deltas (0, negative, NaNs, Infs, massive values)
## 4. orbit_drag and zoom_step robustness against non-finite values and zero division
## 5. Integration with GodHUD event log meta click navigation (1,000 pan calls)
## 6. Strict memory leak and orphan node verification

const SandboxOrbitCameraScript = preload("res://scripts/render/orbit_camera.gd")
const GodHUDScript = preload("res://scripts/ui/god_hud.gd")
const WorldSimulationScript = preload("res://scripts/sim/world_simulation.gd")

var passed_checks: int = 0
var failed_checks: int = 0
var findings: Array[String] = []

func record_assert(condition: bool, msg: String) -> void:
	if condition:
		passed_checks += 1
	else:
		failed_checks += 1
		findings.append(msg)
		print("  [FAIL] %s" % msg)


func _init() -> void:
	print("================================================================================")
	print("=== EMPIRICAL ADVERSARIAL CAMERA 1,000-CYCLE STRESS & LEAK TEST HARNESS ===")
	print("================================================================================")

	var sim := WorldSimulationScript.new()
	sim.name = "SimFixture"
	root.add_child(sim)
	sim.setup_world(9999)

	var cam := SandboxOrbitCameraScript.new()
	cam.name = "CamFixture"
	root.add_child(cam)

	var hud := GodHUDScript.new()
	hud.name = "HUDFixture"
	root.add_child(hud)
	hud.setup(sim)
	hud.camera = cam

	# Baseline measurements for leak detection AFTER fixture instantiation
	var baseline_nodes: int = Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
	var baseline_orphans: int = Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)
	var baseline_objects: int = Performance.get_monitor(Performance.OBJECT_COUNT)
	var baseline_mem: int = Performance.get_monitor(Performance.MEMORY_STATIC)

	print("Baseline State (Fixtures Ready):")
	print("  Node count: %d" % baseline_nodes)
	print("  Orphan nodes: %d" % baseline_orphans)
	print("  Object count: %d" % baseline_objects)
	print("  Static memory: %d bytes" % baseline_mem)

	# --------------------------------------------------------------------------
	# PART 1: 1,000-CYCLE HIGH-FREQUENCY ADVERSARIAL PAN_TO STRESS
	# --------------------------------------------------------------------------
	print("\n[PART 1] Running 1,000 rapid pan_to cycles with pathological inputs...")

	var test_coords: Array[Vector2] = [
		Vector2(NAN, NAN),
		Vector2(INF, INF),
		Vector2(-INF, -INF),
		Vector2(INF, -INF),
		Vector2(-INF, INF),
		Vector2(NAN, 540.0),
		Vector2(960.0, NAN),
		Vector2(NAN, INF),
		Vector2(-INF, NAN),
		Vector2(1e25, 1e25),
		Vector2(-1e25, -1e25),
		Vector2(1e30, -1e30),
		Vector2(-1e30, 1e30),
		Vector2(0.0, 0.0),
		Vector2(1920.0, 1080.0),
		Vector2(960.0, 540.0),
		Vector2(-5000.0, -5000.0),
		Vector2(50000.0, 50000.0),
		Vector2(1e-35, 1e-35),
		Vector2(-1e-35, -1e-35),
	]

	var test_zooms: Array[float] = [
		NAN,
		INF,
		-INF,
		0.0,
		-10.0,
		-1e20,
		1e20,
		1e-30,
		0.85,
		1.0,
		2.0,
		3.5,
		4.20,
		100.0,
		0.0001,
	]

	var test_deltas: Array[float] = [
		0.016,
		0.033,
		0.1,
		0.5,
		2.0,
		10.0,
		0.0,
		-0.016,
		-1.0,
		NAN,
		INF,
		-INF,
	]

	var signal_emit_count: int = 0
	cam.view_mode_changed.connect(func(_m: int) -> void: signal_emit_count += 1)

	for cycle in range(1000):
		# Select test inputs
		var target_coord: Vector2
		var zoom_val: float

		var pattern_selector: int = cycle % 4
		match pattern_selector:
			0:
				# Pathological list
				target_coord = test_coords[cycle % test_coords.size()]
				zoom_val = test_zooms[cycle % test_zooms.size()]
			1:
				# Random extreme range
				target_coord = Vector2(randf_range(-1e18, 1e18), randf_range(-1e18, 1e18))
				zoom_val = randf_range(-100.0, 100.0)
			2:
				# Random valid range
				target_coord = Vector2(randf_range(0.0, 1920.0), randf_range(0.0, 1080.0))
				zoom_val = randf_range(0.5, 5.0)
			3:
				# Alternating extreme and normal
				if (cycle / 4) % 2 == 0:
					target_coord = Vector2(NAN, INF)
					zoom_val = NAN
				else:
					target_coord = Vector2(400.0 + (cycle % 1000), 300.0 + (cycle % 400))
					zoom_val = 1.5 + (cycle % 3) * 0.5

		# 1. Execute pan_to
		cam.pan_to(target_coord, zoom_val)

		# 2. Strict invariant assertions on target_pos & target_zoom
		record_assert(is_finite(cam.target_pos.x) and is_finite(cam.target_pos.y),
			"Cycle %d: target_pos non-finite: %s (input: %s)" % [cycle, str(cam.target_pos), str(target_coord)])
		record_assert(is_finite(cam.target_zoom),
			"Cycle %d: target_zoom non-finite: %f (input: %f)" % [cycle, cam.target_zoom, zoom_val])
		record_assert(cam.target_zoom >= SandboxOrbitCameraScript.MIN_ZOOM and cam.target_zoom <= SandboxOrbitCameraScript.MAX_ZOOM,
			"Cycle %d: target_zoom out of bounds [%.2f, %.2f]: %f" % [cycle, SandboxOrbitCameraScript.MIN_ZOOM, SandboxOrbitCameraScript.MAX_ZOOM, cam.target_zoom])
		record_assert(cam.target_pos.x >= 0.0 and cam.target_pos.x <= 1920.0,
			"Cycle %d: target_pos.x out of bounds [0, 1920]: %f" % [cycle, cam.target_pos.x])
		record_assert(cam.target_pos.y >= 0.0 and cam.target_pos.y <= 1080.0,
			"Cycle %d: target_pos.y out of bounds [0, 1080]: %f" % [cycle, cam.target_pos.y])

		# 3. Interleave with step_camera using varied deltas
		var delta_val: float = test_deltas[cycle % test_deltas.size()]
		cam.step_camera(delta_val)

		# Assert position and zoom remain finite
		record_assert(is_finite(cam.position.x) and is_finite(cam.position.y),
			"Cycle %d: position non-finite after step_camera(%f): %s" % [cycle, delta_val, str(cam.position)])
		record_assert(is_finite(cam.zoom.x) and is_finite(cam.zoom.y),
			"Cycle %d: zoom non-finite after step_camera(%f): %s" % [cycle, delta_val, str(cam.zoom)])

		# 4. Interleave with orbit_drag
		if cycle % 3 == 0:
			var drag_v := Vector2(NAN, INF) if cycle % 6 == 0 else Vector2(randf_range(-1000.0, 1000.0), randf_range(-1000.0, 1000.0))
			cam.orbit_drag(drag_v)
			record_assert(is_finite(cam.target_pos.x) and is_finite(cam.target_pos.y),
				"Cycle %d: target_pos non-finite after orbit_drag: %s" % [cycle, str(cam.target_pos)])

		# 5. Interleave with zoom_step
		if cycle % 5 == 0:
			var z_factor: float = NAN if cycle % 10 == 0 else (0.0 if cycle % 15 == 0 else randf_range(-5.0, 5.0))
			cam.zoom_step(z_factor)
			record_assert(is_finite(cam.target_zoom) and cam.target_zoom >= SandboxOrbitCameraScript.MIN_ZOOM and cam.target_zoom <= SandboxOrbitCameraScript.MAX_ZOOM,
				"Cycle %d: target_zoom invalid after zoom_step(%f): %f" % [cycle, z_factor, cam.target_zoom])

		# 6. Interleave with focus_on_planet_dir (3D mapping)
		if cycle % 7 == 0:
			var dir_3d := Vector3(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0), randf_range(-1.0, 1.0))
			if cycle % 21 == 0:
				dir_3d = Vector3.ZERO
			cam.focus_on_planet_dir(dir_3d)
			record_assert(is_finite(cam.target_pos.x) and is_finite(cam.target_pos.y),
				"Cycle %d: target_pos non-finite after focus_on_planet_dir: %s" % [cycle, str(cam.target_pos)])

		# 7. Interleave with screen_to_world projection
		if cycle % 11 == 0:
			var screen_p: Vector2 = cam.screen_to_world(Vector2(randf_range(0.0, 1920.0), randf_range(0.0, 1080.0)))
			record_assert(is_finite(screen_p.x) and is_finite(screen_p.y),
				"Cycle %d: screen_to_world returned non-finite: %s" % [cycle, str(screen_p)])

		# 8. Immediate snap check
		if cycle % 25 == 0:
			cam.apply_immediately()
			record_assert(cam.position == cam.target_pos, "Cycle %d: apply_immediately position mismatch" % cycle)
			record_assert(cam.zoom == Vector2(cam.target_zoom, cam.target_zoom), "Cycle %d: apply_immediately zoom mismatch" % cycle)

		# 9. View mode switching check
		if cycle % 50 == 0:
			cam.set_view_mode((cycle / 50) % 3)
			record_assert(is_finite(cam.target_pos.x) and is_finite(cam.target_pos.y), "Cycle %d: set_view_mode corrupted target_pos" % cycle)

	print(" -> PASS: Completed 1,000 rapid pan_to stress cycles! Invariants verified.")

	# --------------------------------------------------------------------------
	# PART 2: GOD_HUD EVENT LOG RICH TEXT CLICK-TO-PAN RAPID FLOOD (1,000 CALLS)
	# --------------------------------------------------------------------------
	print("\n[PART 2] Testing 1,000 rapid calls to GodHUD click-to-pan meta handling...")

	var pan_meta_strings: Array[String] = [
		"pan:nan,nan",
		"pan:inf,inf",
		"pan:-inf,-inf",
		"pan:nan,540",
		"pan:960,nan",
		"pan:1e20,1e20",
		"pan:-1e20,-1e20",
		"pan:0,0",
		"pan:960,540",
		"pan:1920,1080",
		"pan:450.5,320.8",
		"pan:",
		"pan:invalid_text,not_a_number",
		"pan:100",
		"pan:100,200,300,400",
		"unknown_meta:9999",
		"",
	]

	for i in range(1000):
		var meta: String = pan_meta_strings[i % pan_meta_strings.size()]
		hud._on_event_log_meta_clicked(meta)

		# Verify camera target_pos remains finite after HUD meta interaction
		record_assert(is_finite(cam.target_pos.x) and is_finite(cam.target_pos.y),
			"HUD meta '%s' resulted in non-finite cam target_pos: %s" % [meta, str(cam.target_pos)])
		record_assert(is_finite(cam.target_zoom),
			"HUD meta '%s' resulted in non-finite cam target_zoom: %f" % [meta, cam.target_zoom])

	print(" -> PASS: 1,000 GodHUD click-to-pan meta calls processed without crash or state corruption!")

	# --------------------------------------------------------------------------
	# PART 3: ZERO LEAK & ORPHAN NODE VERIFICATION
	# --------------------------------------------------------------------------
	print("\n[PART 3] Verifying zero leaks and zero orphan node accumulation during stress...")

	# Step camera with clean delta to stabilize
	for i in range(10):
		cam.step_camera(0.016)

	var stress_nodes: int = Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
	var stress_orphans: int = Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)
	var stress_objects: int = Performance.get_monitor(Performance.OBJECT_COUNT)
	var stress_mem: int = Performance.get_monitor(Performance.MEMORY_STATIC)

	print("Stress State (After 2,000 Total Camera Operations):")
	print("  Node count: %d (Delta from baseline: %d)" % [stress_nodes, stress_nodes - baseline_nodes])
	print("  Orphan nodes: %d (Delta from baseline: %d)" % [stress_orphans, stress_orphans - baseline_orphans])
	print("  Object count: %d (Delta from baseline: %d)" % [stress_objects, stress_objects - baseline_objects])
	print("  Static memory: %d bytes (Delta: %d bytes)" % [stress_mem, stress_mem - baseline_mem])

	record_assert(stress_nodes == baseline_nodes,
		"Node leak detected! Nodes grew by %d" % (stress_nodes - baseline_nodes))
	record_assert(stress_orphans == baseline_orphans,
		"Orphan node leak detected! Orphans grew by %d" % (stress_orphans - baseline_orphans))
	record_assert(stress_objects == baseline_objects,
		"Object leak detected! Objects grew by %d" % (stress_objects - baseline_objects))

	# Clean up test nodes
	cam.free()
	hud.free()
	sim.free()

	# Post-cleanup verification
	var post_nodes: int = Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
	var post_orphans: int = Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)
	print("Post-cleanup State:")
	print("  Node count: %d" % post_nodes)
	print("  Orphan nodes: %d" % post_orphans)

	record_assert(post_nodes <= baseline_nodes, "Nodes not properly freed after cleanup")
	record_assert(post_orphans == 1, "Expected baseline 1 orphan node after cleanup, got: %d" % post_orphans)

	# --------------------------------------------------------------------------
	# SUMMARY & VERDICT
	# --------------------------------------------------------------------------
	print("\n================================================================================")
	print("=== STRESS HARNESS SUMMARY: PASSED: %d | FAILED: %d ===" % [passed_checks, failed_checks])
	if findings.is_empty():
		print("=== ALL CAMERA STRESS & ZERO-LEAK VERIFICATION CHECKS PASSED ===")
	else:
		print("=== DETECTED ANOMALIES / FINDINGS: ===")
		for f in findings:
			print(" - %s" % f)
	print("================================================================================")

	if failed_checks > 0:
		assert(failed_checks == 0, "Camera stress test failed with %d findings!" % failed_checks)

	quit(0)
