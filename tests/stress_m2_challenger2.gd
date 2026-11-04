extends SceneTree

## Independent Boundary & Concurrency Stress Test Suite (M2 Challenger 2)
## Targets:
## 1. Zero matter stock during Dyson construction (Stages 1, 2, 3, 4) -> Graceful halt, zero crashes, zero negative stock.
## 2. City building annihilation & durability cleanup -> Durability dictionary wiped, city survives as ruinate without nulls.
## 3. Exhaustive alchemical reaction matrix (8x8 biomes + 29 powers x 8 biomes + out-of-bounds tiles).
## 4. Fundamental constant boundaries & clamping (min/max clamping, zero light speed, negative entropy).
## 5. Concurrency & re-entrancy: simultaneous cataclysms during Dyson megastructure transitions.

const WorldSimulationScript = preload("res://scripts/sim/world_simulation.gd")
const SandboxAssetManagerScript = preload("res://scripts/core/asset_manager.gd")
const SandboxAssetScript = preload("res://scripts/core/sandbox_asset.gd")

func _init() -> void:
	print("=== RUNNING M2 CHALLENGER 2: BOUNDARY & CONCURRENCY STRESS SUITE ===")
	var total_tests := 0
	var passed_tests := 0

	# -------------------------------------------------------------------------
	# [CHALLENGE 1] 0 Matter Stock During Dyson Construction (Stages 1, 2, 3, 4)
	# -------------------------------------------------------------------------
	print("\n[CHALLENGE 1] Testing 0 Matter Stock & Starvation on Dyson Megastructure...")
	var sim := WorldSimulationScript.new()
	sim.setup_world(4242)

	# Stage 1: Zero matter, zero sails
	total_tests += 1
	sim.dyson_stage = 1
	sim.matter_stock = 0.0
	sim.energy_gw = 1000.0
	sim.total_dyson_sails = 0
	for _i in range(10):
		sim._advance_dyson_construction_step(1.0)
	assert(not sim.dyson_is_constructing, "Stage 1 must not construct autonomously")
	assert(sim.matter_stock >= 0.0, "Matter stock must not be negative in Stage 1")
	assert(sim.dyson_stage == 1, "Stage 1 must not advance without sails")
	passed_tests += 1
	print("  -> Stage 1 zero-matter / zero-sail boundary passed.")

	# Stage 2: Equatorial Ring Frame Starvation
	total_tests += 1
	var ok_s2 := sim.advance_dyson_stage_manual(2)
	assert(ok_s2 and sim.dyson_stage == 2, "Failed to enter Stage 2")
	sim.matter_stock = 0.0
	sim.energy_gw = 500.0
	sim.dyson_stage_progress = 0.0
	sim.dyson_ring_frame_segments = 0

	# 50 ticks of zero matter construction
	for _i in range(50):
		sim._advance_dyson_construction_step(1.0)
	assert(not sim.dyson_is_constructing, "Stage 2 must stall when matter is 0")
	assert(sim.dyson_stage_progress == 0.0, "Progress must stay 0.0 without matter")
	assert(sim.dyson_ring_frame_segments == 0, "Segments must remain 0 without matter")
	assert(sim.matter_stock == 0.0, "Matter stock must remain exactly 0.0, not underflow")

	# Sub-requirement matter (1.0 matter when 2.0 is required)
	sim.matter_stock = 1.0
	sim._advance_dyson_construction_step(1.0)
	assert(not sim.dyson_is_constructing, "Stage 2 must stall when matter < required")
	assert(sim.matter_stock == 1.0, "Inadequate matter must not be consumed")

	# Supply adequate matter and verify recovery
	sim.matter_stock = 100.0
	sim._advance_dyson_construction_step(1.0)
	assert(sim.dyson_is_constructing, "Stage 2 must resume construction with adequate matter")
	assert(sim.dyson_stage_progress > 0.0, "Progress must advance with adequate matter")
	passed_tests += 1
	print("  -> Stage 2 matter starvation and recovery passed.")

	# Stage 3: Dyson Shell Segments Starvation
	total_tests += 1
	var ok_s3 := sim.advance_dyson_stage_manual(3)
	assert(ok_s3 and sim.dyson_stage == 3, "Failed to enter Stage 3")
	sim.matter_stock = 0.0
	sim.energy_gw = 500.0
	sim.dyson_stage_progress = 0.0
	sim.dyson_shell_active_segments = 0

	for _i in range(50):
		sim._advance_dyson_construction_step(1.0)
	assert(not sim.dyson_is_constructing, "Stage 3 must stall when matter is 0")
	assert(sim.dyson_stage_progress == 0.0, "Stage 3 progress must stay 0.0 without matter")
	assert(sim.dyson_shell_active_segments == 0, "Active shell segments must stay 0 without matter")
	assert(sim.matter_stock == 0.0, "Stage 3 matter must not underflow")

	# Sub-requirement matter (2.5 matter when 3.5 is required)
	sim.matter_stock = 2.5
	sim._advance_dyson_construction_step(1.0)
	assert(not sim.dyson_is_constructing, "Stage 3 must stall when matter < 3.5")
	assert(sim.matter_stock == 2.5, "Sub-requirement matter must not be deducted")

	# Supply matter and verify recovery
	sim.matter_stock = 100.0
	sim._advance_dyson_construction_step(1.0)
	assert(sim.dyson_is_constructing, "Stage 3 must resume construction")
	assert(sim.dyson_stage_progress > 0.0, "Stage 3 progress must advance")
	passed_tests += 1
	print("  -> Stage 3 matter starvation and recovery passed.")

	# Stage 4: Matrioshka Brain Clusters Starvation
	total_tests += 1
	var ok_s4 := sim.advance_dyson_stage_manual(4)
	assert(ok_s4 and sim.dyson_stage == 4, "Failed to enter Stage 4")
	sim.matter_stock = 0.0
	sim.energy_gw = 500.0
	sim.dyson_stage_progress = 0.0

	for _i in range(50):
		sim._advance_dyson_construction_step(1.0)
	assert(not sim.dyson_is_constructing, "Stage 4 must stall when matter is 0")
	assert(sim.matter_stock == 0.0, "Stage 4 matter must not underflow")

	# Sub-requirement matter (4.0 matter when 5.0 is required)
	sim.matter_stock = 4.0
	sim._advance_dyson_construction_step(1.0)
	assert(not sim.dyson_is_constructing, "Stage 4 must stall when matter < 5.0")
	assert(sim.matter_stock == 4.0, "Sub-requirement matter must not be deducted")

	# Supply matter and verify layers construction
	sim.matter_stock = 200.0
	sim._advance_dyson_construction_step(1.0)
	assert(sim.dyson_is_constructing, "Stage 4 must resume construction")
	passed_tests += 1
	print("  -> Stage 4 matter starvation and recovery passed.")

	# -------------------------------------------------------------------------
	# [CHALLENGE 2] Total Building Annihilation & Durability Dictionary Cleanup
	# -------------------------------------------------------------------------
	print("\n[CHALLENGE 2] Testing Total Building Annihilation & Durability Cleanup...")
	total_tests += 1

	var c_ids := sim.cities_map.keys()
	assert(c_ids.size() > 0, "Cities required for cataclysm test")
	var target_cid: int = c_ids[0]
	var target_city: Dictionary = sim.cities_map[target_cid]

	# Clear and populate multiple real building types with multiple instances
	target_city["buildings"].clear()
	target_city["buildings"]["order_bio_dome"] = 3
	target_city["buildings"]["order_geothermal_extractor"] = 2
	target_city["buildings"]["order_cognitive_spire"] = 1
	target_city.erase("building_durability")
	sim._rebuild_city_2d_instances(target_city)
	assert((target_city["building_instances"] as Array).size() == 6, "Expected 6 initial building instances")

	# Track signals
	var destroyed_events: Array[Dictionary] = []
	var sig_con = sim.building_damaged_or_destroyed.connect(
		func(c_id, b_id, dest): destroyed_events.append({"city": c_id, "b_id": b_id, "dest": dest})
	)

	# Inflict lethal damage to one bio dome (partial to full destruction)
	var d1 := sim.damage_city_building(target_cid, "order_bio_dome", 50.0)
	assert(not d1, "50 dmg should not destroy 100 HP bio dome")
	assert(target_city.has("building_durability"), "building_durability dict must exist")
	assert(float(target_city["building_durability"]["order_bio_dome"]) == 50.0, "HP must be 50.0")

	var d2 := sim.damage_city_building(target_cid, "order_bio_dome", 60.0)
	assert(d2, "Exceeding remaining 50 HP must destroy 1 instance")
	assert(int(target_city["buildings"]["order_bio_dome"]) == 2, "Building count must decrement to 2")
	assert(float(target_city["building_durability"]["order_bio_dome"]) == 100.0, "Durability must reset to max_hp for next instance")

	# Now wipe ALL buildings with devastating Antimatter Lance (999.0 damage per hit)
	while not (target_city["buildings"] as Dictionary).is_empty():
		var b_keys := (target_city["buildings"] as Dictionary).keys()
		var b_id: String = b_keys[0]
		sim.damage_city_building(target_cid, b_id, 999.0)

	# Verify complete cleanup
	assert((target_city["buildings"] as Dictionary).is_empty(), "All buildings must be erased from buildings dict")
	assert((target_city["building_durability"] as Dictionary).is_empty(), "building_durability must be completely cleaned up")
	assert((target_city["building_instances"] as Array).is_empty(), "building_instances must be empty")
	print("  -> Durability dictionary wiped cleanly after full building destruction.")

	# Verify city survival as ruinate/depleted
	assert(sim.cities_map.has(target_cid), "City must survive in cities_map as ruinate")
	assert(float(target_city["kardashev_level"]) >= 0.50, "Kardashev level must remain clamped >= 0.50")
	assert(float(target_city["internal_cohesion"]) >= 0.10, "Internal cohesion must remain clamped >= 0.10")

	# Verify detailed inspection doesn't throw null or error
	var city_data := sim.get_detailed_city_data(target_cid)
	assert(not city_data.is_empty(), "get_detailed_city_data must succeed for ruinate city")
	assert(city_data["buildings_count"] == 0, "Detailed data must report 0 buildings")
	assert((city_data["buildings"] as Dictionary).is_empty(), "Detailed data must report empty buildings dict")

	# Attacking already ruined city must gracefully return false and not crash
	var d_overkill := sim.damage_city_building(target_cid, "order_bio_dome", 500.0)
	assert(not d_overkill, "Damage to non-existent building must return false")
	var rad_hits := sim.damage_city_buildings_in_radius(target_city["map_pos"], 100.0, 500.0)
	assert(rad_hits.is_empty(), "Radius damage on 0-building city must produce 0 hit records")

	# 20 simulation ticks on ruined city (verify _tick_city_build_orders survives with empty buildings)
	for _i in range(20):
		sim._tick_city_build_orders(1.0)
	assert(sim.cities_map.has(target_cid), "Ruinate city survived 20 ticks of simulation")

	passed_tests += 1
	print("  -> Total building annihilation & ruinate city survival verified.")

	# -------------------------------------------------------------------------
	# [CHALLENGE 3] Exhaustive Alchemical Reaction Matrix Permutations
	# -------------------------------------------------------------------------
	print("\n[CHALLENGE 3] Testing Exhaustive Alchemical Matrix Permutations...")
	total_tests += 1

	var all_biomes: Array[String] = []
	for b in sim.assets.biome_list:
		all_biomes.append(b.id)
	assert(all_biomes.size() == 8, "Expected 8 biomes")

	var all_powers: Array[String] = []
	for p in sim.assets.get_all_god_powers():
		all_powers.append(p.id)
	assert(all_powers.size() == 29, "Expected 29 god powers")

	# 1. Test all 8x8 = 64 biome permutations
	var known_biome_rx_count := 0
	for b1 in all_biomes:
		for b2 in all_biomes:
			var rx_fwd := sim.evaluate_alchemical_reaction(b1, b2)
			var rx_rev := sim.evaluate_alchemical_reaction(b2, b1)
			# Symmetry check
			if rx_fwd != null:
				assert(rx_rev != null, "Reaction matrix symmetry broken for: %s + %s" % [b1, b2])
				assert(rx_fwd.id == rx_rev.id, "Reaction ID mismatch on reverse lookup: %s vs %s" % [rx_fwd.id, rx_rev.id])
				known_biome_rx_count += 1
			else:
				assert(rx_rev == null, "Reverse found reaction where forward was null: %s + %s" % [b1, b2])

	# 3 bidirectional registered biome-biome reactions = 6 directed matches
	assert(known_biome_rx_count == 6, "Expected exactly 6 directed biome-biome reaction matches, got %d" % known_biome_rx_count)
	print("  -> All 64 biome-biome combinations tested (symmetry verified, unknown return null cleanly).")

	# 2. Test all 29 powers x 8 biomes = 232 permutations
	var known_power_rx_count := 0
	for p_id in all_powers:
		for b_id in all_biomes:
			var rx_pb := sim.evaluate_alchemical_reaction(p_id, b_id)
			var rx_bp := sim.evaluate_alchemical_reaction(b_id, p_id)
			if rx_pb != null:
				assert(rx_bp != null and rx_pb.id == rx_bp.id, "Power reaction symmetry broken for: %s + %s" % [p_id, b_id])
				known_power_rx_count += 1
			else:
				assert(rx_bp == null, "Power reaction reverse asymmetry for: %s + %s" % [p_id, b_id])

	# 4 registered power-biome reactions (seismic, spore, nanite, transmuter)
	assert(known_power_rx_count == 4, "Expected exactly 4 power-biome reaction matches, got %d" % known_power_rx_count)
	print("  -> All 232 power-biome permutations tested with 100% symmetry.")

	# 3. Test tile-index boundary inputs
	var boundary_tiles: Array[int] = [-999, -1, 0, 500, 1023, 1024, 999999]
	for t_idx in boundary_tiles:
		var rx_t := sim.evaluate_alchemical_reaction(t_idx, "biome_plasma_inferno")
		var rx_t_rev := sim.evaluate_alchemical_reaction("biome_plasma_inferno", t_idx)
		if rx_t != null:
			assert(rx_t_rev != null and rx_t.id == rx_t_rev.id, "Tile lookup asymmetry at tile %d" % t_idx)
	print("  -> Out-of-bounds tile indices clamped and resolved without crashes.")

	# 4. Live execution of alchemical reactions on world grid
	sim.tiles[200]["biome_id"] = "biome_plasma_inferno"
	sim.tiles[200]["elevation"] = 0.0
	sim.tiles[200]["temperature_c"] = 800.0
	var res_trans := sim.apply_god_power_to_tile(200, "power_matter_transmuter")
	assert(bool(res_trans["ok"]), "Transmuter power failed")
	assert(sim.tiles[200]["biome_id"] == "biome_actinide_wasteland", "Expected transmutation to actinide wasteland")

	passed_tests += 1
	print("  -> Live alchemical transmutation verified on map grid.")

	# -------------------------------------------------------------------------
	# [CHALLENGE 4] Fundamental Constants Boundaries & Extreme Clamping
	# -------------------------------------------------------------------------
	print("\n[CHALLENGE 4] Testing Fundamental Constants Clamping & Extreme Values...")
	total_tests += 1

	var c_emitted: Array[Dictionary] = []
	sim.world_constant_modified.connect(func(c_id, val): c_emitted.append({"id": c_id, "val": val}))

	# G: min 0.1, max 5.0
	sim.set_world_constant("gravitational_constant", -100.0)
	assert(sim.get_world_constant("gravitational_constant") == 0.1, "G must clamp to min_val 0.1")
	sim.set_world_constant("gravitational_constant", 1000.0)
	assert(sim.get_world_constant("gravitational_constant") == 5.0, "G must clamp to max_val 5.0")

	# c: min 0.2, max 5.0 (Zero light speed boundary test)
	sim.set_world_constant("light_speed", 0.0)
	assert(sim.get_world_constant("light_speed") == 0.2, "Light speed 0.0 must clamp to min_val 0.2")
	sim.set_world_constant("light_speed", -999.0)
	assert(sim.get_world_constant("light_speed") == 0.2, "Negative light speed must clamp to min_val 0.2")
	sim.set_world_constant("light_speed", 999.0)
	assert(sim.get_world_constant("light_speed") == 5.0, "Light speed must clamp to max_val 5.0")

	# sigma: min 0.0, max 5.0 (Negative entropy boundary test)
	sim.set_world_constant("cosmic_entropy_rate", -50.0)
	assert(sim.get_world_constant("cosmic_entropy_rate") == 0.0, "Negative entropy rate must clamp to 0.0")
	sim.set_world_constant("cosmic_entropy_rate", 50.0)
	assert(sim.get_world_constant("cosmic_entropy_rate") == 5.0, "Entropy rate must clamp to max_val 5.0")

	# mu: min 0.1, max 10.0
	sim.set_world_constant("mutation_rate_multiplier", 0.0)
	assert(sim.get_world_constant("mutation_rate_multiplier") == 0.1, "Mutation rate 0.0 must clamp to 0.1")
	sim.set_world_constant("mutation_rate_multiplier", 100.0)
	assert(sim.get_world_constant("mutation_rate_multiplier") == 10.0, "Mutation rate must clamp to 10.0")

	# Adversarial direct injection stress test: Force zeros and negatives directly into dictionary
	sim.world_constants["light_speed"] = 0.0
	sim.world_constants["gravitational_constant"] = 0.0
	sim.world_constants["cosmic_entropy_rate"] = -5.0
	sim.world_constants["mutation_rate_multiplier"] = -1.0

	# Run 20 ticks under sabotaged constants
	for _i in range(20):
		sim.step_simulation(1.0)

	# Verify zero crashes and restore
	sim.set_world_constant("light_speed", 1.0)
	sim.set_world_constant("gravitational_constant", 1.0)
	sim.set_world_constant("cosmic_entropy_rate", 1.0)
	sim.set_world_constant("mutation_rate_multiplier", 1.0)

	passed_tests += 1
	print("  -> Constants boundaries, clamping, and zero/negative tolerance verified.")

	# -------------------------------------------------------------------------
	# [CHALLENGE 5] Concurrency: Simultaneous Cataclysm During Dyson Advancement
	# -------------------------------------------------------------------------
	print("\n[CHALLENGE 5] Testing Simultaneous Cataclysm During Megastructure Stage Advancement...")
	total_tests += 1

	# Re-entrant cataclysm callback: when stage advances, immediately trigger meteor and antimatter lance
	var reentrant_cataclysms: Array[int] = []
	var adv_conn = sim.dyson_megastructure_stage_advanced.connect(func(stg_idx, s_name, e):
		reentrant_cataclysms.append(stg_idx)
		# Fire cataclysms inside signal callback
		var pos_strike := Vector2(960.0, 540.0)
		sim.apply_god_power_to_world("power_meteor_strike", pos_strike)
		sim.apply_god_power_to_world("power_antimatter_lance", pos_strike)
		sim.apply_god_power_to_world("power_solar_flare")
	)

	# Advance stages through all 4 stages while re-entrant cataclysms fire
	sim.dyson_stage = 1
	var ok_adv2 := sim.advance_dyson_stage(2)
	assert(ok_adv2, "Advancement to stage 2 failed during re-entrancy")
	assert(reentrant_cataclysms.size() == 1, "Expected 1 re-entrant cataclysm event")

	var ok_adv3 := sim.advance_dyson_stage(3)
	assert(ok_adv3, "Advancement to stage 3 failed during re-entrancy")
	assert(reentrant_cataclysms.size() == 2, "Expected 2 re-entrant cataclysm events")

	var ok_adv4 := sim.advance_dyson_stage(4)
	assert(ok_adv4, "Advancement to stage 4 failed during re-entrancy")
	assert(reentrant_cataclysms.size() == 3, "Expected 3 re-entrant cataclysm events")

	# High-frequency concurrent interleaved stress:
	# 60 cycles of interleaved simulation ticks, random cataclysms, and Dyson progress
	for step in range(60):
		sim.step_simulation(0.2)
		var rand_tile := (step * 37) % sim.TILE_COUNT
		var powers_to_test := ["power_seismic_quake", "power_cosmic_plague", "power_gaia_bloom", "power_mutagenic_spore"]
		var chosen_p: String = powers_to_test[step % powers_to_test.size()]
		sim.apply_god_power_to_tile(rand_tile, chosen_p)
		sim.add_dyson_construction_progress(0.02)
		var metrics := sim.get_global_world_metrics()
		assert(metrics["dyson_stage"] == 4, "Dyson stage must stay consistent at 4")
		assert(float(metrics["max_kardashev"]) >= 2.5, "Kardashev level must remain high at stage 4")

	passed_tests += 1
	print("  -> Concurrency: re-entrant cataclysms and interleaved construction stress passed.")

	# Clean up
	sim.free()

	# -------------------------------------------------------------------------
	# [CHALLENGE 6] Exact Boundaries for Radius Falloff (0.0, max_range +/- 0.01)
	# -------------------------------------------------------------------------
	print("\n[CHALLENGE 6] Testing Exact Boundaries for Radius Falloff...")
	total_tests += 1

	var sim_falloff := WorldSimulationScript.new()
	sim_falloff.setup_world(12345)

	# Set up a test city at fixed position
	var c_id_falloff: int = sim_falloff.cities_map.keys()[0]
	var city_falloff: Dictionary = sim_falloff.cities_map[c_id_falloff]
	city_falloff["map_pos"] = Vector2(500.0, 500.0)
	city_falloff["buildings"].clear()
	city_falloff["buildings"]["order_bio_dome"] = 1
	city_falloff.erase("building_durability")

	var blast_radius: float = 100.0
	var expected_max_range: float = blast_radius + 80.0 # 180.0
	var base_dmg: float = 50.0

	# 1. dist == 0.0 (Epicenter)
	# factor = clampf(1.0 - 0.0, 0.1, 1.0) = 1.0 -> applied_damage = 50.0
	city_falloff["buildings"]["order_bio_dome"] = 1
	city_falloff.erase("building_durability")
	var recs_0 := sim_falloff.damage_city_buildings_in_radius(Vector2(500.0, 500.0), blast_radius, base_dmg)
	assert(recs_0.size() == 1, "dist == 0.0 must hit city")
	assert(city_falloff["building_durability"].has("order_bio_dome"), "durability recorded")
	var hp_0: float = float(city_falloff["building_durability"]["order_bio_dome"])
	assert(absf(hp_0 - 50.0) < 0.001, "dist == 0.0 must deal 100%% damage (50 HP left, got %f)" % hp_0)

	# 2. dist == max_range - 0.01 (179.99 px) -> Inside boundary, should hit with floor 0.1 factor (5.0 dmg)
	city_falloff["buildings"]["order_bio_dome"] = 1
	city_falloff.erase("building_durability")
	var pos_edge_in := Vector2(500.0 + expected_max_range - 0.01, 500.0)
	var recs_edge_in := sim_falloff.damage_city_buildings_in_radius(pos_edge_in, blast_radius, base_dmg)
	assert(recs_edge_in.size() == 1, "dist == max_range - 0.01 must hit city")
	var hp_edge_in: float = float(city_falloff["building_durability"]["order_bio_dome"])
	# factor is clampf(1.0 - (179.99/180.0), 0.1, 1.0) = 0.1 -> damage = 5.0 -> remaining hp = 95.0
	assert(absf(hp_edge_in - 95.0) < 0.001, "dist == max_range - 0.01 must deal 10%% floor damage (95 HP left, got %f)" % hp_edge_in)

	# 3. dist == max_range (180.00 px) -> Exactly on boundary, dist <= max_range is TRUE, factor 0.1 (5.0 dmg)
	city_falloff["buildings"]["order_bio_dome"] = 1
	city_falloff.erase("building_durability")
	var pos_exact := Vector2(500.0 + expected_max_range, 500.0)
	var recs_exact := sim_falloff.damage_city_buildings_in_radius(pos_exact, blast_radius, base_dmg)
	assert(recs_exact.size() == 1, "dist == max_range must hit city (<= boundary)")
	var hp_exact: float = float(city_falloff["building_durability"]["order_bio_dome"])
	assert(absf(hp_exact - 95.0) < 0.001, "dist == max_range must deal 10%% floor damage (95 HP left, got %f)" % hp_exact)

	# 4. dist == max_range + 0.01 (180.01 px) -> Outside boundary, dist <= max_range is FALSE, 0 damage!
	city_falloff["buildings"]["order_bio_dome"] = 1
	city_falloff.erase("building_durability")
	var pos_edge_out := Vector2(500.0 + expected_max_range + 0.01, 500.0)
	var recs_edge_out := sim_falloff.damage_city_buildings_in_radius(pos_edge_out, blast_radius, base_dmg)
	assert(recs_edge_out.is_empty(), "dist == max_range + 0.01 must NOT hit city")
	assert(not city_falloff.has("building_durability") or city_falloff["building_durability"].is_empty(), "City must take 0 damage outside boundary")

	# 5. dist == max_range + 0.001 (180.001 px) -> Sub-pixel outside boundary, 0 damage!
	var pos_subpixel_out := Vector2(500.0 + expected_max_range + 0.001, 500.0)
	var recs_subpixel_out := sim_falloff.damage_city_buildings_in_radius(pos_subpixel_out, blast_radius, base_dmg)
	assert(recs_subpixel_out.is_empty(), "dist == max_range + 0.001 must NOT hit city")

	# 6. Degenerate negative radius: radius_px = -100.0 -> max_range = maxf(1.0, -20.0) = 1.0
	var recs_neg := sim_falloff.damage_city_buildings_in_radius(Vector2(500.0, 500.0), -100.0, base_dmg)
	assert(recs_neg.size() == 1, "Degenerate negative radius must clamp max_range to 1.0 and hit at dist 0")
	var recs_neg_miss := sim_falloff.damage_city_buildings_in_radius(Vector2(502.0, 500.0), -100.0, base_dmg)
	assert(recs_neg_miss.is_empty(), "Degenerate negative radius must miss at dist 2.0")

	sim_falloff.free()
	passed_tests += 1
	print("  -> Exact radius falloff boundaries (0.0, max_range - 0.01, exact, +0.01, negative radius) passed.")

	# -------------------------------------------------------------------------
	# [CHALLENGE 7] Multi-Building Demolition Scaling (1, 2, 5, 10 Building Types)
	# -------------------------------------------------------------------------
	print("\n[CHALLENGE 7] Testing Multi-Building Demolition Scaling (1, 2, 5, 10 types)...")
	total_tests += 1

	var sim_mb := WorldSimulationScript.new()
	sim_mb.setup_world(54321)

	var target_c_mb: Dictionary = sim_mb.cities_map.values()[0]
	var c_pos_mb: Vector2 = target_c_mb["map_pos"]

	var test_building_types := [
		"order_bio_dome",
		"order_geothermal_extractor",
		"order_cognitive_spire",
		"order_fusion_tokamak",
		"order_planetary_collider",
		"order_orbital_elevator",
		"order_dyson_swarm_launcher",
		"order_custom_habitat",
		"order_custom_nanoforge",
		"order_custom_antimatter_silo"
	]

	var type_scales := [1, 2, 5, 10]
	for type_count in type_scales:
		# PART A: Partial Non-Lethal Damage
		target_c_mb["buildings"].clear()
		target_c_mb.erase("building_durability")
		for i in range(type_count):
			var b_type: String = test_building_types[i]
			target_c_mb["buildings"][b_type] = 2 # 2 instances each
		sim_mb._rebuild_city_2d_instances(target_c_mb)
		assert((target_c_mb["buildings"] as Dictionary).size() == type_count, "Expected %d building types" % type_count)

		# Apply 20.0 direct damage (non-lethal to all types since min HP is 100)
		var partial_recs := sim_mb.damage_city_buildings_in_radius(c_pos_mb, 100.0, 20.0)
		assert(partial_recs.size() == type_count, "Partial AoE must hit all %d building types" % type_count)
		for r in partial_recs:
			assert(not bool(r["is_destroyed"]), "20 damage must not destroy tier >= 1 building")
		assert((target_c_mb["building_durability"] as Dictionary).size() == type_count, "Durability tracked for all %d types" % type_count)

		# PART B: Total Lethal Demolition
		# Apply overwhelming lethal blast (1000.0 damage) to destroy 1 instance of each type
		var lethal_recs1 := sim_mb.damage_city_buildings_in_radius(c_pos_mb, 100.0, 1000.0)
		assert(lethal_recs1.size() == type_count, "Lethal AoE #1 must penetrate and destroy 1 instance of all %d types" % type_count)
		for r in lethal_recs1:
			assert(bool(r["is_destroyed"]), "Lethal damage must destroy instance")
		for i in range(type_count):
			var b_type: String = test_building_types[i]
			assert(int(target_c_mb["buildings"][b_type]) == 1, "Count should decrement to 1 for %s" % b_type)

		# Apply second lethal blast to wipe out remaining instances completely
		var lethal_recs2 := sim_mb.damage_city_buildings_in_radius(c_pos_mb, 100.0, 1000.0)
		assert(lethal_recs2.size() == type_count, "Lethal AoE #2 must penetrate all %d types" % type_count)
		for r in lethal_recs2:
			assert(bool(r["is_destroyed"]), "Final lethal damage must destroy remaining instance")

		# Verify total cleanup for this scale
		assert((target_c_mb["buildings"] as Dictionary).is_empty(), "All buildings must be erased for scale %d" % type_count)
		assert((target_c_mb["building_durability"] as Dictionary).is_empty(), "Durability dict wiped clean for scale %d" % type_count)

	sim_mb.free()
	passed_tests += 1
	print("  -> Multi-building demolition across 1, 2, 5, and 10 types verified 100%.")

	# -------------------------------------------------------------------------
	# [CHALLENGE 8] Alchemical Tile Preservation on Mixed Reactive/Non-Reactive Brush
	# -------------------------------------------------------------------------
	print("\n[CHALLENGE 8] Testing Alchemical Tile Preservation on Mixed Brush...")
	total_tests += 1

	var sim_alc := WorldSimulationScript.new()
	sim_alc.setup_world(9876)

	# Set up a cluster of tiles around tile 500
	var center_tile: int = 500
	var center_pos: Vector2 = sim_alc.tiles[center_tile]["map_pos"]
	var brush_rad_norm: float = 0.08
	var brush_rad_px: float = sim_alc.brush_radius_to_pixels(brush_rad_norm)

	# Find tiles within brush radius
	var in_brush: Array[int] = []
	for i in range(sim_alc.TILE_COUNT):
		if center_pos.distance_to(sim_alc.tiles[i]["map_pos"]) <= brush_rad_px:
			in_brush.append(i)
	assert(in_brush.size() >= 3, "Expected at least 3 tiles in brush radius")

	# Configure half of in_brush tiles as REACTIVE (biome_primordial_ocean)
	# and half as NON-REACTIVE (biome_crystal_lattice)
	var reactive_tiles: Array[int] = []
	var non_reactive_tiles: Array[int] = []
	for idx_i in range(in_brush.size()):
		var t_idx: int = in_brush[idx_i]
		if idx_i % 2 == 0:
			sim_alc.tiles[t_idx]["biome_id"] = "biome_primordial_ocean"
			sim_alc.tiles[t_idx]["temperature_c"] = 15.0
			sim_alc.tiles[t_idx]["elevation"] = -0.20
			reactive_tiles.append(t_idx)
		else:
			sim_alc.tiles[t_idx]["biome_id"] = "biome_crystal_lattice"
			sim_alc.tiles[t_idx]["temperature_c"] = 10.0
			sim_alc.tiles[t_idx]["elevation"] = 0.15
			non_reactive_tiles.append(t_idx)

	# Cast power_solar_plasma (target_biome_id = "biome_plasma_inferno", temp_delta_c = 250.0)
	# Reaction 1: biome_plasma_inferno + biome_primordial_ocean -> biome_barren_crust, temp = 45.0
	# Biome crystal lattice + plasma -> reaction 5 requires cryo_superconductor, so crystal_lattice + plasma has NO reaction!
	var initial_matter: float = sim_alc.matter_stock
	var brush_res := sim_alc.apply_god_power_to_tile(center_tile, "power_solar_plasma", brush_rad_norm)
	assert(bool(brush_res["ok"]), "Brush cast must succeed")

	# Verify reactive tiles: MUST be biome_barren_crust with temp 45.0, NOT overwritten by biome_plasma_inferno
	for r_idx in reactive_tiles:
		var t_r: Dictionary = sim_alc.tiles[r_idx]
		assert(t_r["biome_id"] == "biome_barren_crust", "Reactive tile %d must be biome_barren_crust (got %s)" % [r_idx, t_r["biome_id"]])
		assert(t_r["temperature_c"] == 45.0, "Reactive tile %d temp must be reaction result 45.0 C (got %f)" % [r_idx, float(t_r["temperature_c"])])

	# Verify non-reactive tiles: MUST be painted to target biome biome_plasma_inferno
	for nr_idx in non_reactive_tiles:
		var t_nr: Dictionary = sim_alc.tiles[nr_idx]
		assert(t_nr["biome_id"] == "biome_plasma_inferno", "Non-reactive tile %d must be painted to target biome (got %s)" % [nr_idx, t_nr["biome_id"]])
		assert(float(t_nr["temperature_c"]) > 10.0, "Non-reactive tile %d temp must increase from heat delta" % nr_idx)

	# Verify matter yield was added for all reactive transformations
	assert(sim_alc.matter_stock > initial_matter, "Alchemical reactions must yield matter to stock")

	sim_alc.free()
	passed_tests += 1
	print("  -> Alchemical tile preservation on mixed reactive/non-reactive brush verified 100%.")

	print("\n=== ALL %d BOUNDARY & CONCURRENCY CHALLENGES PASSED (FAILED: 0) ===" % passed_tests)
	quit(0)
