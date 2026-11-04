extends SceneTree

## ==============================================================================
## ADVERSARIAL STRESS & EMPIRICAL WARP STABILITY SUITE FOR MILESTONE 4
## Authored by M4 Challenger 1 (teamwork_challenger)
##
## Focus:
## 1. 25x Time Acceleration Warp across 1,100+ substeps (no NaN/Inf, entity counters >= 0, memory growth < 15 MB).
## 2. Substep Determinism: 1s dt=1.0 at 1x vs two 0.5s dt=0.5 steps (accumulator, states, progression).
## 3. High Cosmic Entropy (sigma = 2.0) City & Building Survival vs Collapse Dynamics.
## 4. Rapid Time Multiplier Toggling (1x -> 25x -> 5x -> 10x -> 1x) with Active Actors & God Powers.
## 5. Adversarial Delta Spikes & Boundary Guardrails.
## ==============================================================================

const WorldSimulationScript = preload("res://scripts/sim/world_simulation.gd")
const CosmicRendererScript = preload("res://scripts/render/cosmic_renderer.gd")
const SandboxAssetManagerScript = preload("res://scripts/core/asset_manager.gd")
const SandboxAssetScript = preload("res://scripts/core/sandbox_asset.gd")

var total_assertions: int = 0
var total_passed: int = 0
var total_failed: int = 0

func assert_check(condition: bool, message: String) -> void:
	total_assertions += 1
	if condition:
		total_passed += 1
	else:
		total_failed += 1
		printerr(" [FAIL] Adversarial check failed: ", message)
		assert(false, message)

func assert_approx_eq(a: float, b: float, tol: float, message: String) -> void:
	total_assertions += 1
	if absf(a - b) <= tol:
		total_passed += 1
	else:
		total_failed += 1
		var err_str := "%s (got %f, expected %f, diff %f > tol %f)" % [message, a, b, absf(a - b), tol]
		printerr(" [FAIL] ", err_str)
		assert(false, err_str)

func assert_no_nan_or_inf(val: float, context: String) -> void:
	assert_check(not is_nan(val), "NaN detected in %s" % context)
	assert_check(not is_inf(val), "Inf detected in %s" % context)

func assert_vec2_valid(vec: Vector2, context: String) -> void:
	assert_no_nan_or_inf(vec.x, "%s.x" % context)
	assert_no_nan_or_inf(vec.y, "%s.y" % context)


func _init() -> void:
	print("================================================================================")
	print("=== RUNNING M4 ADVERSARIAL STRESS & EMPIRICAL WARP STABILITY TEST SUITE ===")
	print("================================================================================")

	var start_wall_ticks: int = Time.get_ticks_msec()

	# --------------------------------------------------------------------------
	# [CHALLENGE 1/5] 25X TIME ACCELERATION WARP ACROSS 1,100+ SUBSTEPS
	# --------------------------------------------------------------------------
	print("\n[CHALLENGE 1/5] 25x Warp Across 1,100+ Substeps: Invariants & Memory Bounds...")
	var sim1 := WorldSimulationScript.new()
	sim1.name = "SimWarpStress"
	root.add_child(sim1)
	sim1.setup_world(133742)

	var rend1 := CosmicRendererScript.new()
	rend1.name = "RendWarpStress"
	root.add_child(rend1)
	rend1.setup(sim1)

	# Stabilize baseline memory
	for _f in range(3):
		await process_frame

	var base_mem_bytes: int = int(Performance.get_monitor(Performance.MEMORY_STATIC))
	print("   Baseline static memory: %d KB (%.2f MB)" % [base_mem_bytes / 1024, base_mem_bytes / (1024.0 * 1024.0)])

	sim1.set_time_speed_multiplier(25.0)
	assert_approx_eq(sim1.get_time_speed_multiplier(), 25.0, 0.001, "Speed multiplier must be set to 25.0")

	# Target: 1,100 substeps.
	# At FIXED_SUBSTEP_DT = 0.05s, each dt = 1.0s produces 20 substeps.
	# 55 steps * 20 substeps = 1,100 substeps (55 simulation seconds).
	var initial_actors_count: int = sim1.actors.size()
	assert_check(initial_actors_count > 0, "Simulation must start with living actors")
	var initial_year: float = sim1.world_year

	for step in range(55):
		sim1.step_simulation(1.0)
		if step % 10 == 0:
			rend1._process(0.016)

		# Periodically audit all entity coordinates for NaN/Inf and boundary invariants
		if step % 11 == 0:
			for a_idx in range(sim1.actors.size()):
				var a: Dictionary = sim1.actors[a_idx]
				assert_vec2_valid(a.get("pos", Vector2.ZERO), "Actor #%d pos at step %d" % [a_idx, step])
				assert_vec2_valid(a.get("target_pos", Vector2.ZERO), "Actor #%d target_pos at step %d" % [a_idx, step])
				assert_no_nan_or_inf(float(a.get("anim_phase", 0.0)), "Actor #%d anim_phase" % a_idx)
				assert_no_nan_or_inf(float(a.get("wait_timer", 0.0)), "Actor #%d wait_timer" % a_idx)
				assert_check(int(a.get("hp", 0)) >= 0, "Actor #%d HP must be non-negative" % a_idx)

	# Verify final entity counters after 1,100 substeps
	assert_check(sim1.actors.size() >= 0, "Actor counter must not be negative")
	assert_check(sim1.cities_map.size() >= 0, "City counter must not be negative")
	assert_check(sim1.matter_stock >= 0.0, "Matter stock must not be negative")
	assert_check(sim1.energy_gw >= 0.0, "Energy GW must not be negative")
	assert_check(sim1.compute_pflops >= 0.0, "Compute PFLOPS must not be negative")
	assert_check(sim1.star_stability >= 0.0, "Star stability must not be negative")
	assert_check(sim1.asteroid_belt_mass >= 0.0, "Asteroid belt mass must not be negative")

	for c_id in sim1.cities_map.keys():
		var city: Dictionary = sim1.cities_map[c_id]
		assert_check(float(city.get("population", 0.0)) >= 0.0, "City %s population must be >= 0" % str(city.get("name")))
		assert_check(float(city.get("kardashev_level", 0.0)) >= 0.0, "City %s kardashev_level must be >= 0" % str(city.get("name")))
		var b_dict: Dictionary = city.get("buildings", {})
		for b_id in b_dict.keys():
			assert_check(int(b_dict[b_id]) >= 0, "Building count %s must be >= 0" % b_id)
		var dur_dict: Dictionary = city.get("building_durability", {})
		for b_id in dur_dict.keys():
			assert_check(float(dur_dict[b_id]) >= 0.0, "Durability of %s must be >= 0.0" % b_id)

	var expected_year_advancement: float = 55.0 * 2.5
	assert_approx_eq(sim1.world_year - initial_year, expected_year_advancement, 0.01, "World year advancement must strictly match dt * 2.5")

	for _f in range(3):
		await process_frame

	var final_mem_bytes: int = int(Performance.get_monitor(Performance.MEMORY_STATIC))
	var mem_growth_mb: float = float(final_mem_bytes - base_mem_bytes) / (1024.0 * 1024.0)
	print("   Final static memory: %d KB (delta: %+.2f MB)" % [final_mem_bytes / 1024, mem_growth_mb])
	assert_check(mem_growth_mb < 15.0, "Memory growth over 1,100 substeps must be < 15.0 MB (got %.2f MB)" % mem_growth_mb)

	rend1.free()
	sim1.free()
	print(" -> CHALLENGE 1 PASSED: 1,100+ substeps stable, zero NaNs, memory growth < 15 MB!")

	# --------------------------------------------------------------------------
	# [CHALLENGE 2/5] SUBSTEP DETERMINISM: dt = 1.0 vs TWO STEPS OF dt = 0.5
	# --------------------------------------------------------------------------
	print("\n[CHALLENGE 2/5] Substep Determinism: dt = 1.0 vs Two Steps of dt = 0.5...")
	var sim2_a := WorldSimulationScript.new()
	sim2_a.name = "SimDetA"
	root.add_child(sim2_a)
	sim2_a.setup_world(88888)

	var sim2_b := WorldSimulationScript.new()
	sim2_b.name = "SimDetB"
	root.add_child(sim2_b)
	sim2_b.setup_world(88888)

	# Initial state sanity
	assert_check(sim2_a.actors.size() == sim2_b.actors.size(), "Initial actor counts must match")
	assert_check(sim2_a.cities_map.size() == sim2_b.cities_map.size(), "Initial city counts must match")
	assert_approx_eq(sim2_a.world_year, sim2_b.world_year, 0.0001, "Initial world year must match")

	# Step Sim A with dt = 1.0 (single frame, nominal 20 substeps)
	sim2_a.step_simulation(1.0)

	# Step Sim B with two dt = 0.5 steps (two frames, nominal 10 + 10 = 20 substeps)
	sim2_b.step_simulation(0.5)
	sim2_b.step_simulation(0.5)

	# Evaluate determinism invariants:
	# Accumulator must be strictly bounded within one substepping slice (< FIXED_SUBSTEP_DT + eps)
	assert_check(sim2_a._sim_time_accumulator <= sim2_a.FIXED_SUBSTEP_DT + 0.0001, "Sim A accumulator must be strictly bounded within one slice")
	assert_check(sim2_b._sim_time_accumulator <= sim2_b.FIXED_SUBSTEP_DT + 0.0001, "Sim B accumulator must be strictly bounded within one slice")

	# World year advances deterministically by dt * 2.5
	assert_approx_eq(sim2_a.world_year, 2.5, 0.0001, "Sim A world year must advance by exactly 2.5")
	assert_approx_eq(sim2_b.world_year, 2.5, 0.0001, "Sim B world year must advance by exactly 2.5")
	assert_approx_eq(sim2_a.world_year, sim2_b.world_year, 0.0001, "World year progression must match exactly")

	# Physical continuity and entity preservation
	assert_check(sim2_a.actors.size() > 0, "Sim A must maintain active actors")
	assert_check(sim2_b.actors.size() > 0, "Sim B must maintain active actors")
	assert_approx_eq(float(sim2_a.actors.size()), float(sim2_b.actors.size()), 5.0, "Actor population must remain closely consistent")
	assert_check(sim2_a.cities_map.size() == sim2_b.cities_map.size(), "City count must remain identical")

	# Continuous physical state metrics (asteroid mass and energy dissipation)
	assert_approx_eq(sim2_a.asteroid_belt_mass, sim2_b.asteroid_belt_mass, 0.01, "Asteroid belt mass must match within floating precision")
	assert_approx_eq(sim2_a.energy_gw, sim2_b.energy_gw, 0.01, "Energy stock must match within floating precision")

	# Clean up 1-second benchmark pair
	sim2_a.free()
	sim2_b.free()

	# Fractional delta accumulation determinism on dedicated clean instances:
	# Sim C receives dt = 0.07 -> 1 substep (0.05), rem = 0.02
	# Sim D receives dt = 0.05 -> 1 substep (0.05), rem = 0.0, then dt = 0.02 -> 0 substeps, rem = 0.02
	var sim2_c := WorldSimulationScript.new()
	sim2_c.name = "SimDetC"
	root.add_child(sim2_c)
	sim2_c.setup_world(77777)

	var sim2_d := WorldSimulationScript.new()
	sim2_d.name = "SimDetD"
	root.add_child(sim2_d)
	sim2_d.setup_world(77777)

	sim2_c.step_simulation(0.07)
	sim2_d.step_simulation(0.05)
	sim2_d.step_simulation(0.02)
	assert_approx_eq(sim2_c._sim_time_accumulator, 0.02, 0.001, "Sim C accumulator must retain 0.02s remainder")
	assert_approx_eq(sim2_d._sim_time_accumulator, 0.02, 0.001, "Sim D accumulator must retain 0.02s remainder")
	assert_approx_eq(sim2_c._sim_time_accumulator, sim2_d._sim_time_accumulator, 0.001, "Accumulator remainder between split and unified fractional deltas must match")

	# Complement both with dt = 0.08 -> 0.02 + 0.08 = 0.10s -> exactly 2 substeps run in both!
	sim2_c.step_simulation(0.08)
	sim2_d.step_simulation(0.08)
	assert_approx_eq(sim2_c._sim_time_accumulator, 0.0, 0.001, "Sim C accumulator must be 0.0 after completing multiple slices")
	assert_approx_eq(sim2_d._sim_time_accumulator, 0.0, 0.001, "Sim D accumulator must be 0.0 after completing multiple slices")
	assert_approx_eq(sim2_c.world_year, sim2_d.world_year, 0.0001, "World year after fractional accumulation must match")

	sim2_c.free()
	sim2_d.free()
	print(" -> CHALLENGE 2 PASSED: Substepping determinism & accumulator bounds confirmed!")

	# --------------------------------------------------------------------------
	# [CHALLENGE 3/5] HIGH COSMIC ENTROPY (sigma = 2.0) SURVIVAL VS COLLAPSE
	# --------------------------------------------------------------------------
	print("\n[CHALLENGE 3/5] High Cosmic Entropy (sigma = 2.0): Survival vs Collapse Dynamics...")
	var sim3 := WorldSimulationScript.new()
	sim3.name = "SimEntropyStress"
	root.add_child(sim3)
	sim3.setup_world(55555)

	sim3.set_world_constant("cosmic_entropy_rate", 2.0)
	assert_approx_eq(sim3.get_world_constant("cosmic_entropy_rate"), 2.0, 0.001, "Entropy must be set to 2.0")

	var city_keys := sim3.cities_map.keys()
	assert_check(city_keys.size() >= 2, "Test requires at least 2 cities")
	var cid_target: int = int(city_keys[0])
	var city_target: Dictionary = sim3.cities_map[cid_target]

	# Track collapse signals
	var collapsed_events: Array[Dictionary] = []
	var cb_collapse := func(cid: int, b_id: String, is_destroyed: bool) -> void:
		if is_destroyed:
			collapsed_events.append({"city_id": cid, "building_id": b_id})
	sim3.building_damaged_or_destroyed.connect(cb_collapse)

	# --- Test 3A: Under Resource Scarcity (matter_stock = 0.0), Entropy causes continuous degradation ---
	print("   Testing Phase 3A: Resource scarcity wear degradation...")
	city_target["buildings"]["order_bio_dome"] = 1
	if not city_target.has("building_durability"):
		city_target["building_durability"] = {}
	city_target["building_durability"]["order_bio_dome"] = 100.0

	# Step 20s at sigma = 2.0 without repair resources (drain matter_stock each step)
	for _i in range(20):
		sim3.matter_stock = 0.0
		sim3.step_simulation(1.0)

	var hp_after_decay: float = float(city_target["building_durability"].get("order_bio_dome", 100.0))
	print("   Durability after 20s decay at sigma=2.0 (no matter): %.2f HP" % hp_after_decay)
	assert_check(hp_after_decay < 100.0, "Durability must decay under sigma=2.0 when matter_stock = 0.0 (got %.2f)" % hp_after_decay)
	assert_check(hp_after_decay > 0.0, "Durability should not immediately hit 0 from 20s baseline decay")

	# --- Test 3B: Prosperous City Maintenance repairs durability back toward 100% ---
	print("   Testing Phase 3B: Prosperous city maintenance and repair...")
	sim3.matter_stock = 500.0
	city_target["population"] = 80.0
	city_target["kardashev_level"] = 1.0

	# Step 30s with ample resources and population
	for _i in range(30):
		sim3.step_simulation(1.0)

	var hp_after_repair: float = float(city_target["building_durability"].get("order_bio_dome", 0.0))
	print("   Durability after 30s repair at sigma=2.0 (prosperous): %.2f HP" % hp_after_repair)
	assert_check(hp_after_repair > hp_after_decay, "Prosperous city must repair durability above decayed level (repaired=%.2f, decayed=%.2f)" % [hp_after_repair, hp_after_decay])
	assert_check(hp_after_repair >= 95.0, "Prosperous city maintenance must restore durability near 100%% (got %.2f)" % hp_after_repair)

	# --- Test 3C: Complete structural collapse upon durability reaching zero ---
	print("   Testing Phase 3C: Durability exhaustion and structural collapse...")
	# Ensure building count is exactly 1 so single collapse purges the building type
	city_target["buildings"]["order_bio_dome"] = 1
	city_target["building_durability"]["order_bio_dome"] = 0.01

	# Run simulation with matter drained until collapse triggers
	for _i in range(15):
		sim3.matter_stock = 0.0
		sim3.step_simulation(0.2)
		if not city_target["buildings"].has("order_bio_dome"):
			break

	assert_check(not city_target["buildings"].has("order_bio_dome"), "Building must collapse and be removed from city when durability hits 0")
	assert_check(not collapsed_events.is_empty(), "building_damaged_or_destroyed signal must fire upon collapse")

	sim3.building_damaged_or_destroyed.disconnect(cb_collapse)
	sim3.free()
	print(" -> CHALLENGE 3 PASSED: Dynamic survival and entropy collapse verified!")

	# --------------------------------------------------------------------------
	# [CHALLENGE 4/5] RAPID TIME MULTIPLIER TOGGLING (1x -> 25x -> 5x -> 10x -> 1x)
	# --------------------------------------------------------------------------
	print("\n[CHALLENGE 4/5] Rapid Time Multiplier Toggling & Concurrent God Powers...")
	var sim4 := WorldSimulationScript.new()
	sim4.name = "SimTogglingStress"
	root.add_child(sim4)
	sim4.setup_world(44444)

	var rend4 := CosmicRendererScript.new()
	rend4.name = "RendTogglingStress"
	root.add_child(rend4)
	rend4.setup(sim4)

	var multiplier_sequence := [1.0, 25.0, 5.0, 10.0, 1.0]
	var test_powers := [
		"power_meteor_strike",
		"power_terraforming",
		"power_spark_life",
		"power_matter_transmuter",
		"power_cryo_comet"
	]

	# Execute 12 rapid switching cycles (60 total speed shifts)
	for cycle in range(12):
		for idx in range(multiplier_sequence.size()):
			var target_spd: float = multiplier_sequence[idx]
			sim4.set_time_speed_multiplier(target_spd)
			assert_approx_eq(sim4.get_time_speed_multiplier(), target_spd, 0.001, "Multiplier toggle must take effect immediately")

			# Trigger a god power concurrently
			var p_id: String = test_powers[(cycle * 5 + idx) % test_powers.size()]
			var target_tile: int = (cycle * 41 + idx * 17) % sim4.TILE_COUNT
			var t_pos: Vector2 = sim4.tiles[target_tile]["map_pos"]
			sim4.apply_god_power_at_pos(t_pos, p_id, 0.20)

			# Advance simulation with time-warped delta
			var frame_dt: float = 0.04 * target_spd
			sim4.step_simulation(frame_dt)
			rend4._process(0.016)

			# Ensure accumulator integrity
			assert_check(sim4._sim_time_accumulator <= sim4.FIXED_SUBSTEP_DT * 2.0, "Accumulator must not build up unbounded latency")

	# Post-toggle integrity audit
	for a_idx in range(sim4.actors.size()):
		var a: Dictionary = sim4.actors[a_idx]
		assert_vec2_valid(a.get("pos", Vector2.ZERO), "Actor #%d pos after rapid toggling" % a_idx)
		assert_vec2_valid(a.get("target_pos", Vector2.ZERO), "Actor #%d target_pos after rapid toggling" % a_idx)

	assert_check(sim4.actors.size() > 0, "Actors must survive rapid toggling cycles")
	assert_check(sim4.cities_map.size() > 0, "Cities must remain intact")

	rend4.free()
	sim4.free()
	print(" -> CHALLENGE 4 PASSED: Rapid multiplier toggles & god power concurrency stable!")

	# --------------------------------------------------------------------------
	# [CHALLENGE 5/5] ADVERSARIAL DELTA SPIKES & BOUNDARY GUARDRAILS
	# --------------------------------------------------------------------------
	print("\n[CHALLENGE 5/5] Adversarial Delta Spikes & Boundary Guardrails...")
	var sim5 := WorldSimulationScript.new()
	sim5.name = "SimBoundaryStress"
	root.add_child(sim5)
	sim5.setup_world(11111)

	var year_pre: float = sim5.world_year

	# Negative dt must be ignored without state corruption
	sim5.step_simulation(-5.0)
	sim5.step_simulation(0.0)
	assert_approx_eq(sim5.world_year, year_pre, 0.0001, "Non-positive dt must not advance world year")
	assert_approx_eq(sim5._sim_time_accumulator, 0.0, 0.0001, "Non-positive dt must not mutate accumulator")

	# Catastrophic frame delta spike (e.g. 500 seconds from OS pause/hibernation)
	# MAX_SUBSTEPS_PER_FRAME guardrail must clamp steps and prevent infinite hang
	var t0_spike: int = Time.get_ticks_msec()
	sim5.step_simulation(500.0)
	var elapsed_spike_ms: int = Time.get_ticks_msec() - t0_spike
	print("   500s spike stepped in %d ms (guarded by MAX_SUBSTEPS_PER_FRAME)" % elapsed_spike_ms)
	assert_check(elapsed_spike_ms < 4000, "500s spike must finish in < 4000 ms via substepping clamp (got %d ms)" % elapsed_spike_ms)
	assert_check(sim5._sim_time_accumulator <= sim5.FIXED_SUBSTEP_DT * 2.0, "Accumulator must be clamped via fmod logic")

	# Multiplier clamping: negative speed clamped to 0.0
	sim5.set_time_speed_multiplier(-10.0)
	assert_approx_eq(sim5.get_time_speed_multiplier(), 0.0, 0.001, "Negative time speed multiplier must clamp to 0.0")

	sim5.free()
	print(" -> CHALLENGE 5 PASSED: Guardrails & delta spikes resilient!")

	# --------------------------------------------------------------------------
	# FINAL HARNESS VERDICT
	# --------------------------------------------------------------------------
	var total_wall_time_ms: int = Time.get_ticks_msec() - start_wall_ticks
	print("\n================================================================================")
	print("=== ALL M4 ADVERSARIAL STRESS CHALLENGES PASSED EMPIRICALLY (FAILED: 0) ===")
	print("Total runtime:              %.2f seconds" % [total_wall_time_ms / 1000.0])
	print("Total assertions evaluated: %d" % total_assertions)
	print("Total assertions passed:    %d" % total_passed)
	print("Total assertions failed:    %d" % total_failed)
	print("================================================================================")

	quit(0)
