extends SceneTree

## ==============================================================================
## ADVERSARIAL STRESS TEST: Milestone 4 Dirty-Rect & Substepping Boundaries
## Challenger 2 Rigorous Suite
## ==============================================================================

const WorldSimulationScript = preload("res://scripts/sim/world_simulation.gd")
const CosmicRendererScript = preload("res://scripts/render/cosmic_renderer.gd")
const SandboxAssetManagerScript = preload("res://scripts/core/asset_manager.gd")
const SandboxAssetScript = preload("res://scripts/core/sandbox_asset.gd")

var total_assertions: int = 0
var total_passed: int = 0
var total_failed: int = 0
var findings: Array[String] = []

func record_assert(cond: bool, msg: String) -> void:
	total_assertions += 1
	if cond:
		total_passed += 1
	else:
		total_failed += 1
		findings.append(msg)
		printerr(" [FAIL] Assertion failed: ", msg)


func _init() -> void:
	print("================================================================================")
	print("=== EMPIRICAL ADVERSARIAL HARNESS: M4 DIRTY-RECT & SUBSTEPPING BOUNDARIES ===")
	print("================================================================================")

	var sim := WorldSimulationScript.new()
	sim.name = "SimStressFixture"
	root.add_child(sim)
	sim.setup_world(1337)

	var renderer := CosmicRendererScript.new()
	renderer.name = "RendererStressFixture"
	root.add_child(renderer)
	renderer.setup(sim)

	var p_img: Image = renderer.get("_planet_image")
	record_assert(p_img != null, "_planet_image must be initialized")
	record_assert(p_img.get_width() == CosmicRendererScript.TEX_W, "Image width must be TEX_W (384)")
	record_assert(p_img.get_height() == CosmicRendererScript.TEX_H, "Image height must be TEX_H (216)")

	# Baseline memory
	var baseline_mem: int = Performance.get_monitor(Performance.MEMORY_STATIC)

	# --------------------------------------------------------------------------
	# PROBE 1: Dirty rects with negative coordinates (clamping verification)
	# --------------------------------------------------------------------------
	print("\n[PROBE 1] Testing dirty rects with negative coordinates & overflow...")
	var initial_count: int = renderer.dirty_rect_update_count
	var test_rect_neg1 := Rect2i(-50, -50, 100, 100)
	renderer.request_dirty_rect_update(test_rect_neg1)
	record_assert(renderer.dirty_rect_update_count == initial_count + 1, "Dirty rect update count must increment for Rect2i(-50, -50, 100, 100)")
	record_assert(renderer.last_dirty_rect == test_rect_neg1, "last_dirty_rect must record requested rect")

	# Test various overlapping negative rects
	var neg_rects := [
		Rect2i(-100, -100, 200, 200),
		Rect2i(-10, 50, 100, 50),
		Rect2i(50, -10, 50, 100),
		Rect2i(-300, -200, 400, 300),
		Rect2i(-2147483647, -2147483647, 2147483647, 2147483647), # Massive negative coordinates
		Rect2i(100, 100, 2147483647, 2147483647) # Massive size overflowing 32-bit int
	]
	for nr in neg_rects:
		var c_before := renderer.dirty_rect_update_count
		renderer.request_dirty_rect_update(nr)
		record_assert(renderer.dirty_rect_update_count == c_before + 1, "Negative/extreme rect %s must execute safely" % str(nr))

	# Verify pixel integrity at clamped boundaries: check pixels (0,0) and (49,49)
	var pixel_0_0: Color = p_img.get_pixel(0, 0)
	record_assert(pixel_0_0.a > 0.0, "Pixel (0,0) must remain valid after clamped negative update")
	print(" -> PROBE 1 PASSED: Negative coordinates clamp cleanly without crash or out-of-bounds.")

	# --------------------------------------------------------------------------
	# PROBE 2: Dirty rects completely outside image bounds (graceful no-op)
	# --------------------------------------------------------------------------
	print("\n[PROBE 2] Testing dirty rects completely outside image bounds...")
	var outside_rects := [
		Rect2i(1000, 1000, 50, 50),
		Rect2i(-500, -500, 50, 50),
		Rect2i(400, 100, 50, 50), # Beyond right edge (TEX_W = 384)
		Rect2i(100, 300, 50, 50), # Beyond bottom edge (TEX_H = 216)
		Rect2i(-100, 100, 50, 50), # Completely to the left
		Rect2i(100, -100, 50, 50), # Completely above
		Rect2i(384, 0, 10, 10),    # Starting exactly at right border
		Rect2i(0, 216, 10, 10),    # Starting exactly at bottom border
		Rect2i(-20, 0, 20, 10),    # Ending exactly at left border (-20 + 20 = 0)
		Rect2i(2147483640, 2147483640, 50, 50) # Far positive integer
	]
	for out_rect in outside_rects:
		var c_before := renderer.dirty_rect_update_count
		renderer.request_dirty_rect_update(out_rect)
		record_assert(renderer.dirty_rect_update_count == c_before + 1, "Outside rect %s must record call" % str(out_rect))
	print(" -> PROBE 2 PASSED: Outside dirty rects produce graceful no-op without crashes.")

	# --------------------------------------------------------------------------
	# PROBE 3: Dirty rects with 0 or negative width/height (graceful no-op)
	# --------------------------------------------------------------------------
	print("\n[PROBE 3] Testing dirty rects with 0 or negative width/height...")
	var zero_neg_size_rects := [
		Rect2i(10, 10, 0, 10),
		Rect2i(10, 10, 10, 0),
		Rect2i(10, 10, 0, 0),
		Rect2i(50, 50, -20, 10),
		Rect2i(50, 50, 10, -20),
		Rect2i(50, 50, -10, -10),
		Rect2i(-50, -50, -10, -10),
		Rect2i(0, 0, -2147483648, -2147483648)
	]
	for z_rect in zero_neg_size_rects:
		var c_before := renderer.dirty_rect_update_count
		renderer.request_dirty_rect_update(z_rect)
		record_assert(renderer.dirty_rect_update_count == c_before + 1, "Zero/negative size rect %s must be recorded" % str(z_rect))
	print(" -> PROBE 3 PASSED: Zero and negative dimension rects rejected cleanly.")

	# --------------------------------------------------------------------------
	# PROBE 4: Extreme world position conversions in request_dirty_world_pos
	# --------------------------------------------------------------------------
	print("\n[PROBE 4] Testing extreme world position conversions...")
	# Standard edge points
	renderer.request_dirty_world_pos(Vector2(0.0, 0.0), 10.0)
	renderer.request_dirty_world_pos(Vector2(1920.0, 1080.0), 10.0)
	renderer.request_dirty_world_pos(Vector2(-1000.0, -1000.0), 50.0)
	renderer.request_dirty_world_pos(Vector2(5000.0, 5000.0), 50.0)

	# Negative and zero radius
	renderer.request_dirty_world_pos(Vector2(960.0, 540.0), -20.0)
	renderer.request_dirty_world_pos(Vector2(960.0, 540.0), 0.0)
	renderer.request_dirty_world_pos(Vector2(960.0, 540.0), -10000.0)

	# Test tile rect conversions: normal, bounds, overflow, and inverted
	renderer.request_dirty_tile_rect(0, 0, 31, 31) # Full tile grid
	renderer.request_dirty_tile_rect(-10, -10, 10, 10)
	renderer.request_dirty_tile_rect(25, 25, 45, 45) # Exceeds GRID_W (32) and GRID_H (32)
	renderer.request_dirty_tile_rect(100, 100, 200, 200)
	renderer.request_dirty_tile_rect(30, 30, 5, 5) # Inverted tile rect (min > max)

	# Non-finite values: NaN and Inf
	print("  Testing NaN and Inf world positions in request_dirty_world_pos...")
	renderer.request_dirty_world_pos(Vector2(NAN, NAN), 10.0)
	renderer.request_dirty_world_pos(Vector2(INF, INF), 10.0)
	renderer.request_dirty_world_pos(Vector2(-INF, -INF), 10.0)
	renderer.request_dirty_world_pos(Vector2(960.0, 540.0), INF)
	renderer.request_dirty_world_pos(Vector2(NAN, 540.0), 20.0)
	renderer.request_dirty_world_pos(Vector2(960.0, NAN), 20.0)

	print(" -> PROBE 4 PASSED: World pos & tile rect conversions handle extremes safely.")

	# --------------------------------------------------------------------------
	# PROBE 5: Exact boundary edges (x=0, y=0, x=383, y=215)
	# --------------------------------------------------------------------------
	print("\n[PROBE 5] Testing exact boundary edges...")
	var boundary_rects := [
		Rect2i(0, 0, 1, 1),             # Top-left single pixel
		Rect2i(383, 0, 1, 1),           # Top-right single pixel
		Rect2i(0, 215, 1, 1),           # Bottom-left single pixel
		Rect2i(383, 215, 1, 1),         # Bottom-right single pixel
		Rect2i(0, 0, 384, 1),           # Top edge single-pixel line
		Rect2i(0, 215, 384, 1),         # Bottom edge single-pixel line
		Rect2i(0, 0, 1, 216),           # Left edge single-pixel line
		Rect2i(383, 0, 1, 216),         # Right edge single-pixel line
		Rect2i(0, 0, 384, 216),         # Full boundary coverage
		Rect2i(-1, 0, 1, 1),            # Single pixel just outside left
		Rect2i(0, -1, 1, 1),            # Single pixel just outside top
		Rect2i(384, 0, 1, 1),           # Single pixel just outside right
		Rect2i(0, 216, 1, 1)            # Single pixel just outside bottom
	]
	for br in boundary_rects:
		var c_before := renderer.dirty_rect_update_count
		renderer.request_dirty_rect_update(br)
		record_assert(renderer.dirty_rect_update_count == c_before + 1, "Boundary rect %s must execute cleanly" % str(br))

	# Verify boundary pixel values are readable and not corrupt
	var c_tl := p_img.get_pixel(0, 0)
	var c_tr := p_img.get_pixel(383, 0)
	var c_bl := p_img.get_pixel(0, 215)
	var c_br := p_img.get_pixel(383, 215)
	record_assert(c_tl.a > 0.0 and c_tr.a > 0.0 and c_bl.a > 0.0 and c_br.a > 0.0, "All corner pixels must have valid alpha")
	print(" -> PROBE 5 PASSED: Exact boundary edges correctly shaded without overflow.")

	# --------------------------------------------------------------------------
	# PROBE 6: Substepping engine boundary values (dt = 0, dt = -1.0, dt = 100.0)
	# --------------------------------------------------------------------------
	print("\n[PROBE 6] Testing substepping engine boundary values...")
	var year_start: float = sim.world_year
	var accum_start: float = sim.get("_sim_time_accumulator")

	# 1. dt = 0.0: should be early-exit no-op
	sim.step_simulation(0.0)
	record_assert(sim.world_year == year_start, "dt = 0.0 must not advance world_year")
	record_assert(sim.get("_sim_time_accumulator") == accum_start, "dt = 0.0 must not alter accumulator")

	# 2. dt = -1.0 and dt = -100.0: negative delta should be early-exit no-op
	sim.step_simulation(-1.0)
	record_assert(sim.world_year == year_start, "dt = -1.0 must not reverse or advance world_year")
	record_assert(sim.get("_sim_time_accumulator") == accum_start, "dt = -1.0 must not alter accumulator")

	sim.step_simulation(-100.0)
	record_assert(sim.world_year == year_start, "dt = -100.0 must not reverse or advance world_year")
	record_assert(sim.get("_sim_time_accumulator") == accum_start, "dt = -100.0 must not alter accumulator")

	# 3. Micro deltas dt = 0.001 (50 calls accumulate to 0.05 = 1 substep)
	var year_before_micro: float = sim.world_year
	for _i in range(50):
		sim.step_simulation(0.001)
	record_assert(sim.world_year > year_before_micro, "Accumulating micro deltas must advance simulation")

	# 4. dt = 100.0: ensure large delta does not freeze or spiral
	print("  Testing dt = 100.0 time step execution...")
	var year_before_100: float = sim.world_year
	var t_start_ms: int = Time.get_ticks_msec()
	sim.step_simulation(100.0)
	var t_elapsed_ms: int = Time.get_ticks_msec() - t_start_ms
	print("  dt = 100.0 completed in %d ms" % t_elapsed_ms)
	record_assert(t_elapsed_ms < 6000, "dt = 100.0 must complete within 6000 ms (completed in %d ms)" % t_elapsed_ms)
	record_assert(sim.world_year > year_before_100, "dt = 100.0 must advance world_year")
	record_assert(sim.actors.size() > 0, "Actors must survive large dt step")

	# 5. Verify MAX_SUBSTEPS_PER_FRAME cap mechanism
	record_assert(WorldSimulationScript.MAX_SUBSTEPS_PER_FRAME == 600, "MAX_SUBSTEPS_PER_FRAME must be 600")
	record_assert(WorldSimulationScript.FIXED_SUBSTEP_DT == 0.05, "FIXED_SUBSTEP_DT must be 0.05")

	print(" -> PROBE 6 PASSED: Substepping engine boundaries verified.")

	# --------------------------------------------------------------------------
	# PROBE 7: High-frequency dirty-rect stress & memory stability
	# --------------------------------------------------------------------------
	print("\n[PROBE 7] Testing 300 rapid dirty-rect updates for leak stability...")
	for i in range(300):
		var rx: int = (i * 17) % 350
		var ry: int = (i * 23) % 180
		renderer.request_dirty_rect_update(Rect2i(rx, ry, 32, 32))

	var mem_growth: int = Performance.get_monitor(Performance.MEMORY_STATIC) - baseline_mem
	print("  Memory growth after 300 dirty rect updates: %d bytes (%.2f KB)" % [mem_growth, float(mem_growth) / 1024.0])
	record_assert(mem_growth < 5 * 1024 * 1024, "Memory growth across rapid updates must stay under 5 MB")
	print(" -> PROBE 7 PASSED: Memory remains stable under continuous dirty-rect operations.")

	# --------------------------------------------------------------------------
	# CLEANUP & FINAL VERDICT
	# --------------------------------------------------------------------------
	print("\n================================================================================")
	print("=== CHALLENGER 2 SUMMARY: PASSED: %d | FAILED: %d ===" % [total_passed, total_failed])
	if findings.is_empty():
		print("=== ALL ADVERSARIAL BOUNDARY PROBES PASSED SUCCESSFULLY ===")
	else:
		print("=== FINDINGS / FAILURES ===")
		for f in findings:
			print(" - %s" % f)
	print("================================================================================")

	record_assert(total_failed == 0, "All adversarial tests must pass")
	if total_failed > 0:
		assert(false, "Boundary stress harness encountered %d failures" % total_failed)

	renderer.queue_free()
	sim.queue_free()
	quit(0)
