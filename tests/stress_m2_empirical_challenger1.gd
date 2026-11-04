extends SceneTree

## Empirical Challenger 1 Verification Harness:
## 1. Distance Falloff Under 1,000 Strikes (Monotonicity, Boundary Clamping, Multi-Building Blast)
## 2. Zero Matter Stability During Rapid Zero-Point Well Injections (1,000+ Executions, Underflow Prevention)

const WorldSimulationScript = preload("res://scripts/sim/world_simulation.gd")
const SandboxAssetManagerScript = preload("res://scripts/core/asset_manager.gd")
const SandboxAssetScript = preload("res://scripts/core/sandbox_asset.gd")

var total_assertions: int = 0
var total_passed: int = 0
var total_failed: int = 0

func check(condition: bool, message: String) -> void:
	total_assertions += 1
	if condition:
		total_passed += 1
	else:
		total_failed += 1
		printerr("CHALLENGER 1 FAIL: ", message)

func check_no_nan_or_inf(val: float, context: String) -> void:
	check(not is_nan(val), "NaN detected in: " + context)
	check(not is_inf(val), "Inf detected in: " + context)

func _init() -> void:
	print("================================================================================")
	print("=== RUNNING CHALLENGER 1 EMPIRICAL HARNESS: 1,000 STRIKES & ZERO-POINT STRESS ===")
	print("================================================================================")

	var sim := WorldSimulationScript.new()
	sim.setup_world(123456)

	var city_ids := sim.cities_map.keys()
	check(city_ids.size() > 0, "Initial world must contain at least 1 city")
	var target_cid: int = int(city_ids[0])
	var target_city: Dictionary = sim.cities_map[target_cid]
	var c_pos: Vector2 = target_city["map_pos"]

	# ==============================================================================
	# PART 1: DISTANCE FALLOFF STRESS TEST UNDER 1,000 STRIKES
	# ==============================================================================
	print("\n--- PART 1: Distance Falloff Under 1,000 Parameterized Strikes ---")

	var direct_hits_count := 0
	var edge_hits_count := 0
	var out_of_bounds_count := 0
	var intermediate_hits_count := 0

	for strike_idx in range(1000):
		# Fresh buildings setup for target city on each strike
		target_city["buildings"].clear()
		target_city["buildings"]["order_bio_dome"] = 5 # Tier 1 -> max HP 100
		target_city["buildings"]["order_cognitive_spire"] = 3 # Tier 2 -> max HP 200
		if not target_city.has("building_durability"):
			target_city["building_durability"] = {}
		(target_city["building_durability"] as Dictionary).clear()
		target_city["building_durability"]["order_bio_dome"] = 100.0
		target_city["building_durability"]["order_cognitive_spire"] = 200.0

		var radius_px: float = randf_range(30.0, 500.0)
		var base_dmg: float = randf_range(10.0, 80.0) # non-lethal base damage
		var max_range: float = maxf(1.0, radius_px + 80.0)

		# Test varied distance distribution: direct (0), edge (~1.0), beyond (>1.0), and intermediate
		var r_type: int = strike_idx % 4
		var dist: float = 0.0
		match r_type:
			0:
				dist = 0.0
				direct_hits_count += 1
			1:
				dist = max_range * randf_range(0.95, 1.0)
				edge_hits_count += 1
			2:
				dist = max_range * randf_range(1.02, 1.5)
				out_of_bounds_count += 1
			3:
				dist = max_range * randf_range(0.1, 0.9)
				intermediate_hits_count += 1

		var angle: float = randf_range(0.0, TAU)
		var strike_pos: Vector2 = c_pos + Vector2(cos(angle), sin(angle)) * dist

		var recs := sim.damage_city_buildings_in_radius(strike_pos, radius_px, base_dmg)
		var target_recs: Array[Dictionary] = []
		for r in recs:
			if int(r["city_id"]) == target_cid:
				target_recs.append(r)
			else:
				var other_city: Dictionary = sim.cities_map[int(r["city_id"])]
				var other_dist: float = (other_city["map_pos"] as Vector2).distance_to(strike_pos)
				check(other_dist <= max_range, "Collateral damaged city #%d must be within max_range" % int(r["city_id"]))

		if dist > max_range:
			check(target_recs.is_empty(), "Strike #%d at dist %.1f > max_range %.1f must damage 0 buildings in target city" % [strike_idx, dist, max_range])
			check(float(target_city["building_durability"]["order_bio_dome"]) == 100.0, "Building HP must be undamaged when out of range")
			check(float(target_city["building_durability"]["order_cognitive_spire"]) == 200.0, "Building HP must be undamaged when out of range")
		else:
			var expected_factor: float = clampf(1.0 - (dist / max_range), 0.1, 1.0)
			var expected_damage: float = base_dmg * expected_factor
			check(target_recs.size() == 2, "Strike #%d within range must damage all 2 building types in target city" % strike_idx)

			var actual_bio_hp: float = float(target_city["building_durability"]["order_bio_dome"])
			var actual_cog_hp: float = float(target_city["building_durability"]["order_cognitive_spire"])

			var taken_bio_dmg: float = 100.0 - actual_bio_hp
			var taken_cog_dmg: float = 200.0 - actual_cog_hp

			check(absf(taken_bio_dmg - expected_damage) < 0.001, "Bio Dome damage took %.4f vs expected %.4f" % [taken_bio_dmg, expected_damage])
			check(absf(taken_cog_dmg - expected_damage) < 0.001, "Cognitive Spire damage took %.4f vs expected %.4f" % [taken_cog_dmg, expected_damage])

			# Verify boundary factors
			if dist == 0.0:
				check(absf(taken_bio_dmg - base_dmg) < 0.001, "Direct hit must apply 100% base damage")
			elif dist >= max_range * 0.9999:
				check(absf(taken_bio_dmg - (base_dmg * 0.1)) < 0.001, "Edge hit must apply 10% floor damage")

	print("1,000 Strikes Distribution: %d direct, %d intermediate, %d edge, %d out-of-range" % [
		direct_hits_count, intermediate_hits_count, edge_hits_count, out_of_bounds_count
	])

	# 1.2 Strict Monotonicity Sweep Across 100 Distance Steps
	print("Executing strict monotonicity check across 100 discrete radial distance steps...")
	var mono_radius: float = 200.0
	var mono_max_range: float = mono_radius + 80.0
	var mono_base_dmg: float = 50.0
	var prev_dmg: float = 99999.0

	for step in range(101):
		var test_dist: float = (mono_max_range / 100.0) * float(step)
		var test_pos := c_pos + Vector2(test_dist, 0.0)

		target_city["buildings"].clear()
		target_city["buildings"]["order_bio_dome"] = 1
		target_city["building_durability"]["order_bio_dome"] = 100.0

		var r := sim.damage_city_buildings_in_radius(test_pos, mono_radius, mono_base_dmg)
		check(r.size() == 1, "Must hit 1 building at step %d" % step)
		var taken_dmg: float = 100.0 - float(target_city["building_durability"]["order_bio_dome"])

		check(taken_dmg <= prev_dmg + 0.0001, "Monotonicity violated at step %d: %.4f > prev %.4f" % [step, taken_dmg, prev_dmg])
		check(taken_dmg >= mono_base_dmg * 0.1 - 0.0001, "Damage at step %d fell below 10%% floor" % step)
		check(taken_dmg <= mono_base_dmg + 0.0001, "Damage at step %d exceeded 100%% base damage" % step)
		prev_dmg = taken_dmg

	print(" -> Distance Falloff 1,000 strikes + monotonicity check PASSED!")

	# ==============================================================================
	# PART 2: ZERO MATTER STABILITY UNDER RAPID ZERO-POINT WELL INJECTIONS
	# ==============================================================================
	print("\n--- PART 2: Zero Matter Stability During Zero-Point Well Injections ---")

	var well_power_id := "power_zero_point_well"
	var well_asset: SandboxAssetScript.GodPowerAsset = sim.assets.god_powers.get(well_power_id)
	check(well_asset != null, "power_zero_point_well must be registered in SandboxAssetManager")
	check(well_asset.matter_injection < 0.0, "power_zero_point_well must have negative matter injection (-15.0)")
	check(well_asset.energy_injection > 0.0, "power_zero_point_well must have positive energy injection (+80.0)")

	# 2.1 1,000 Consecutive Casts Starting From 0.0 Matter Stock
	print("Bombarding world with 1,000 rapid consecutive zero-point well injections from 0.0 matter stock...")
	sim.matter_stock = 0.0
	sim.energy_gw = 0.0

	var center_pos := Vector2(sim.MAP_PIXEL_W * 0.5, sim.MAP_PIXEL_H * 0.5)

	for cast_idx in range(1000):
		var res: Dictionary = sim.apply_god_power_to_world(well_power_id, center_pos)
		check(bool(res.get("ok", false)), "Zero-point well cast #%d failed" % cast_idx)

		check_no_nan_or_inf(sim.matter_stock, "matter_stock after well cast #%d" % cast_idx)
		check_no_nan_or_inf(sim.energy_gw, "energy_gw after well cast #%d" % cast_idx)

		check(sim.matter_stock == 0.0, "Matter stock must remain EXACTLY 0.0 (got %f) on cast #%d" % [sim.matter_stock, cast_idx])
		check(sim.energy_gw > 0.0, "Energy stock must be positive on cast #%d" % cast_idx)

	var final_energy: float = sim.energy_gw
	var expected_energy_approx: float = 1000.0 * well_asset.energy_injection # 80,000 GW base
	check(final_energy >= expected_energy_approx * 0.99, "Energy must scale cleanly across 1,000 casts (got %.1f)" % final_energy)
	print("  -> 1,000 casts completed: Matter stock remained 0.0 at all times, energy accumulated to %.1f GW." % final_energy)

	# 2.2 Boundary Float Tests for Partial Underflow
	print("Testing boundary matter stocks below consumption threshold (15.0)...")
	var test_sub_stocks: Array[float] = [0.00001, 0.01, 0.5, 1.0, 5.0, 7.5, 14.0, 14.9999, 15.0]
	for init_m in test_sub_stocks:
		sim.matter_stock = init_m
		sim.apply_god_power_to_world(well_power_id, center_pos)
		check(sim.matter_stock == 0.0, "Initial matter %.5f after -15.0 injection must clamp to 0.0 (got %f)" % [init_m, sim.matter_stock])

	# 2.3 Stocks Above Consumption Threshold
	var test_above_stocks: Array[float] = [15.0001, 16.0, 20.0, 30.0, 100.0, 500.0]
	for init_m in test_above_stocks:
		sim.matter_stock = init_m
		var expected_m: float = init_m + well_asset.matter_injection # -15.0
		sim.apply_god_power_to_world(well_power_id, center_pos)
		check(absf(sim.matter_stock - expected_m) < 0.001, "Initial matter %.2f after -15.0 injection must equal %.2f (got %f)" % [init_m, expected_m, sim.matter_stock])

	# 2.4 Corrupted/Negative Initial Matter Recovery
	print("Testing negative initial matter recovery...")
	sim.matter_stock = -999.0
	sim.apply_god_power_to_world(well_power_id, center_pos)
	check(sim.matter_stock == 0.0, "Negative initial matter (-999.0) must clamp cleanly to 0.0 after well cast")

	# 2.5 Interleaved Dyson Construction & Zero-Point Well Under Zero Matter
	print("Testing interleaved Dyson construction and zero-point well execution under zero matter...")
	sim.matter_stock = 0.0
	sim.dyson_stage = 2
	sim.dyson_stage_progress = 0.0
	sim.dyson_ring_frame_segments = 0

	for cycle in range(50):
		# Cast zero-point well (matter stays 0, energy rises)
		sim.apply_god_power_to_world(well_power_id, center_pos)
		check(sim.matter_stock == 0.0, "Matter must remain 0.0 in cycle %d" % cycle)

		# Advance Dyson construction step
		sim._advance_dyson_construction_step(1.0)
		check(not sim.dyson_is_constructing, "Dyson must not construct without matter in cycle %d" % cycle)
		check(sim.matter_stock == 0.0, "Matter must not underflow during stalled construction in cycle %d" % cycle)

	print(" -> Zero matter stability & zero-point well execution PASSED!")

	# ==============================================================================
	# FINAL HARNESS VERDICT
	# ==============================================================================
	print("\n================================================================================")
	print("=== CHALLENGER 1 EMPIRICAL HARNESS COMPLETE ===")
	print("Total assertions evaluated: %d" % total_assertions)
	print("Total checks passed:        %d" % total_passed)
	print("Total checks failed:        %d" % total_failed)
	print("================================================================================")

	sim.free()

	if total_failed == 0:
		print("VERDICT: EMPIRICAL STRESS TESTS 100% PASSED (APPROVE)")
		quit(0)
	else:
		printerr("VERDICT: EMPIRICAL STRESS TESTS FAILED (REQUEST_CHANGES)")
		quit(1)
