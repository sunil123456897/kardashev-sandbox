extends SceneTree

const WorldSimulationScript = preload("res://scripts/sim/world_simulation.gd")
const SandboxAssetManagerScript = preload("res://scripts/core/asset_manager.gd")
const SandboxAssetScript = preload("res://scripts/core/sandbox_asset.gd")

func _init() -> void:
	print("=== RUNNING MILESTONE 2 (MEGASTRUCTURES, LAWS & ARSENAL) TEST SUITE ===")

	var am := SandboxAssetManagerScript.new()
	var sim := WorldSimulationScript.new()
	sim.setup_world(1337)

	# -------------------------------------------------------------------------
	# [1/6] Asset Manager Dual-Indexing & Registry Non-Regression
	# -------------------------------------------------------------------------
	print("[1/6] Verifying Asset Manager Dual-Indexing & Registries...")
	assert(am.god_power_list.size() == 20, "CRITICAL: Base god_power_list size must remain exactly 20!")
	assert(am.cataclysm_power_list.size() == 7, "Expected 7 cataclysm powers")
	assert(am.transmutation_power_list.size() == 2, "Expected 2 transmutation powers")
	assert(am.get_all_god_powers().size() == 29, "Expected 29 total god powers (20 base + 7 cataclysm + 2 transmutation)")
	assert(am.physical_constant_list.size() == 4, "Expected 4 physical constants (G, c, sigma, mu)")
	assert(am.alchemical_reaction_list.size() == 7, "Expected 7 alchemical reactions in matrix")

	# Verify physical constants
	var cg: SandboxAssetScript.PhysicalConstantAsset = am.physical_constants.get("gravitational_constant")
	assert(cg != null and cg.symbol == "G" and cg.unit == "G₀", "G constant asset invalid")
	var cc: SandboxAssetScript.PhysicalConstantAsset = am.physical_constants.get("light_speed")
	assert(cc != null and cc.symbol == "c" and cc.unit == "c₀", "c constant asset invalid")
	var cs: SandboxAssetScript.PhysicalConstantAsset = am.physical_constants.get("cosmic_entropy_rate")
	assert(cs != null and cs.symbol == "σ" and cs.unit == "σ₀", "sigma constant asset invalid")
	var cm: SandboxAssetScript.PhysicalConstantAsset = am.physical_constants.get("mutation_rate_multiplier")
	assert(cm != null and cm.symbol == "μ" and cm.unit == "μ₀", "mu constant asset invalid")

	# Verify bidirectional alchemical reaction keys
	assert(am.alchemical_reactions.has("biome_plasma_inferno+biome_primordial_ocean"), "Reaction key forward missing")
	assert(am.alchemical_reactions.has("biome_primordial_ocean+biome_plasma_inferno"), "Reaction key reverse missing")
	print(" -> Asset registries & dual-indexing PASSED!")

	# -------------------------------------------------------------------------
	# [2/6] F4: 4-Stage Dyson Megastructure Lifecycle & Energy Curves
	# -------------------------------------------------------------------------
	print("[2/6] Verifying F4: 4-Stage Dyson Megastructure Lifecycle...")
	assert(sim.dyson_stage == 1, "Initial stage must be 1 (Swarm Collectors)")
	assert(sim.get_dyson_stage_name() == "Swarm Collectors", "Stage 1 name mismatch")
	assert(sim.total_dyson_sails >= 24, "Initial sails expected")

	var advanced_stages: Array[int] = []
	var visual_updates: Array[Dictionary] = []
	sim.dyson_megastructure_stage_advanced.connect(func(idx, s_name, e): advanced_stages.append(idx))
	sim.dyson_visual_state_updated.connect(func(stg, prog, segs): visual_updates.append({"stage": stg, "progress": prog, "segments": segs}))

	# Stage 1 Energy
	var e_stage1: float = sim.get_dyson_energy_output()
	assert(e_stage1 > 0.0, "Stage 1 energy output must be positive")
	var eclipse1: float = sim.get_dyson_eclipse_ratio()
	assert(eclipse1 <= 0.25, "Stage 1 eclipse ratio must not exceed 25%")

	# Advance to Stage 2: Equatorial Ring Frame
	var ok_s2: bool = sim.advance_dyson_stage_manual(2)
	assert(ok_s2, "Manual advancement to Stage 2 failed")
	assert(sim.dyson_stage == 2, "Expected dyson_stage == 2")
	assert(sim.get_dyson_stage_name() == "Equatorial Ring Frame", "Stage 2 name mismatch")
	assert(advanced_stages.has(2), "Stage 2 advancement signal not received")
	var e_stage2: float = sim.get_dyson_energy_output()
	assert(e_stage2 > e_stage1, "Stage 2 energy must exceed Stage 1")
	var eclipse2: float = sim.get_dyson_eclipse_ratio()
	assert(eclipse2 >= 0.25 and eclipse2 <= 0.40, "Stage 2 eclipse ratio must be between 25% and 40%")

	# Construction progress in Stage 2
	sim.dyson_stage_progress = 0.5
	sim._advance_dyson_construction_step(0.0)
	assert(sim.dyson_ring_frame_segments == 6, "Expected 6 ring frame segments at 50% progress")

	# Advance to Stage 3: Dyson Shell Segments
	var ok_s3: bool = sim.advance_dyson_stage_manual(3)
	assert(ok_s3, "Manual advancement to Stage 3 failed")
	assert(sim.dyson_stage == 3, "Expected dyson_stage == 3")
	assert(sim.get_dyson_stage_name() == "Dyson Shell Segments", "Stage 3 name mismatch")
	var e_stage3: float = sim.get_dyson_energy_output()
	assert(e_stage3 > e_stage2, "Stage 3 energy must exceed Stage 2")
	var eclipse3: float = sim.get_dyson_eclipse_ratio()
	assert(eclipse3 >= 0.40 and eclipse3 <= 0.75, "Stage 3 eclipse ratio must be between 40% and 75%")

	# Advance to Stage 4: Matrioshka Brain Clusters
	var ok_s4: bool = sim.advance_dyson_stage_manual(4)
	assert(ok_s4, "Manual advancement to Stage 4 failed")
	assert(sim.dyson_stage == 4, "Expected dyson_stage == 4")
	assert(sim.get_dyson_stage_name() == "Matrioshka Brain Clusters", "Stage 4 name mismatch")
	var e_stage4: float = sim.get_dyson_energy_output()
	assert(e_stage4 > e_stage3, "Stage 4 energy must exceed Stage 3")
	var c_stage4: float = sim.get_dyson_compute_output()
	assert(c_stage4 > 0.0, "Stage 4 must produce compute power (Matrioshka brain)")
	var eclipse4: float = sim.get_dyson_eclipse_ratio()
	assert(eclipse4 >= 0.75 and eclipse4 <= 0.98, "Stage 4 eclipse ratio must be between 75% and 98%")
	var kard_lvl: float = sim.get_max_kardashev_level()
	assert(kard_lvl >= 2.50, "Stage 4 Kardashev level must scale to 2.5..3.0")

	# Resource drain & graceful stall test
	sim.matter_stock = 0.0
	sim._advance_dyson_construction_step(1.0)
	assert(not sim.dyson_is_constructing, "Construction must stall when matter is exhausted")
	assert(sim.matter_stock >= 0.0, "Matter stock must never become negative")
	print(" -> F4 Dyson Megastructure 4-Stage Lifecycle PASSED!")

	# -------------------------------------------------------------------------
	# [3/6] F5: Divine Arsenal Execution Handlers & Effects
	# -------------------------------------------------------------------------
	print("[3/6] Verifying F5: Divine Arsenal Handlers & Effects...")
	var shockwaves: Array[Vector2] = []
	var sfx_events: Array[String] = []
	sim.shockwave_triggered.connect(func(pos, rad, col): shockwaves.append(pos))
	sim.sfx_requested.connect(func(id, pos, p, v): sfx_events.append(id))

	# 1. Meteor Strike
	var center_tile: int = 500
	var pos_m: Vector2 = sim.tiles[center_tile]["map_pos"]
	var r_meteor := sim.apply_god_power_to_tile(center_tile, "power_meteor_strike")
	assert(bool(r_meteor["ok"]), "Meteor strike failed")
	assert(sim.tiles[center_tile]["elevation"] < -0.10, "Meteor must create crater")
	assert(shockwaves.size() >= 1, "Shockwave must trigger on meteor strike")
	assert(sfx_events.has("sfx_meteor_impact"), "Meteor SFX must be requested")

	# 2. Antimatter Lance
	var r_lance := sim.apply_god_power_to_world("power_antimatter_lance", pos_m)
	assert(bool(r_lance["ok"]), "Antimatter lance failed")
	assert(sim.tiles[center_tile]["elevation"] <= -0.30, "Antimatter lance must vaporize elevation")
	assert(sfx_events.has("sfx_antimatter_lance"), "Antimatter SFX missing")

	# 3. Solar Flare
	var r_flare := sim.apply_god_power_to_world("power_solar_flare")
	assert(bool(r_flare["ok"]), "Solar flare failed")
	assert(sfx_events.has("sfx_solar_flare"), "Solar flare SFX missing")

	# 4. Seismic Quake
	var r_quake := sim.apply_god_power_to_world("power_seismic_quake", pos_m)
	assert(bool(r_quake["ok"]), "Seismic quake failed")
	assert(sfx_events.has("sfx_seismic_quake"), "Seismic quake SFX missing")

	# 5. Cosmic Plague
	var r_plague := sim.apply_god_power_to_world("power_cosmic_plague", pos_m)
	assert(bool(r_plague["ok"]), "Cosmic plague failed")
	assert(sfx_events.has("sfx_cosmic_plague"), "Plague SFX missing")

	# 6. Gaia Bloom
	sim.tiles[center_tile]["radiation"] = 0.75
	var r_bloom := sim.apply_god_power_to_world("power_gaia_bloom", pos_m)
	assert(bool(r_bloom["ok"]), "Gaia bloom failed")
	assert(float(sim.tiles[center_tile]["radiation"]) == 0.0, "Gaia bloom must cleanse radiation")
	assert(sfx_events.has("sfx_gaia_bloom"), "Gaia bloom SFX missing")

	# 7. Mutagenic Spore
	var r_spore := sim.apply_god_power_to_world("power_mutagenic_spore", pos_m)
	assert(bool(r_spore["ok"]), "Mutagenic spore failed")
	assert(sfx_events.has("sfx_mutagenic_spore"), "Mutagenic spore SFX missing")

	# 8. Matter Transmuter
	var prev_matter: float = sim.matter_stock
	var r_trans := sim.apply_god_power_to_world("power_matter_transmuter", pos_m)
	assert(bool(r_trans["ok"]), "Matter transmuter failed")
	assert(sim.matter_stock > prev_matter, "Matter transmuter must increase matter stock")

	# 9. Zero-Point Well (with negative matter clamping verification)
	sim.matter_stock = 5.0 # Set low matter stock (< 15.0 required by zero-point well)
	var prev_energy: float = sim.energy_gw
	var r_well := sim.apply_god_power_to_world("power_zero_point_well", pos_m)
	assert(bool(r_well["ok"]), "Zero-point well failed")
	assert(sim.energy_gw > prev_energy, "Zero-point well must inject energy")
	assert(sim.matter_stock >= 0.0, "Matter stock must not be negative after zero-point well execution")
	assert(sim.matter_stock == 0.0, "Negative matter must be clamped to floor 0.0 when drain exceeds current stock")
	print(" -> F5 Divine Arsenal execution handlers PASSED!")

	# -------------------------------------------------------------------------
	# [4/6] F5: Building Durability & Damage System
	# -------------------------------------------------------------------------
	print("[4/6] Verifying F5: Building Durability & Destruction Mechanics...")
	var damaged_buildings: Array[Dictionary] = []
	sim.building_damaged_or_destroyed.connect(func(c_id, b_id, dest): damaged_buildings.append({"city_id": c_id, "building_id": b_id, "destroyed": dest}))

	var c_ids := sim.cities_map.keys()
	assert(c_ids.size() > 0, "Expected at least 1 city")
	var test_cid: int = c_ids[0]
	var test_city: Dictionary = sim.cities_map[test_cid]
	test_city["buildings"]["order_bio_dome"] = 2

	# Partial damage: should NOT destroy building
	var destroyed1 := sim.damage_city_building(test_cid, "order_bio_dome", 30.0)
	assert(not destroyed1, "30 damage should not destroy a tier 1 building with 100 HP")
	assert(int(test_city["buildings"]["order_bio_dome"]) == 2, "Building count should remain 2")
	assert(damaged_buildings.size() >= 1 and not damaged_buildings[damaged_buildings.size() - 1]["destroyed"], "Signal must report is_destroyed=false")

	# Lethal damage: should destroy 1 building instance
	var destroyed2 := sim.damage_city_building(test_cid, "order_bio_dome", 150.0)
	assert(destroyed2, "150 damage should destroy the damaged building")
	assert(int(test_city["buildings"]["order_bio_dome"]) == 1, "Building count should decrement to 1")
	assert(damaged_buildings[damaged_buildings.size() - 1]["destroyed"], "Signal must report is_destroyed=true")

	# -------------------------------------------------------------------------
	# Radius damage: Multi-Building Penetration & Distance Falloff
	# -------------------------------------------------------------------------
	# Setup test city with 2 distinct building types for multi-building penetration test
	test_city["buildings"].clear()
	(test_city["building_durability"] as Dictionary).clear()
	test_city["buildings"]["order_bio_dome"] = 1
	test_city["buildings"]["order_cognitive_spire"] = 1
	test_city["building_durability"]["order_bio_dome"] = 100.0
	test_city["building_durability"]["order_cognitive_spire"] = 200.0

	# 1. Non-vacuous assertion and multi-building penetration (both buildings damaged)
	var r_dmg := sim.damage_city_buildings_in_radius(test_city["map_pos"], 150.0, 25.0)
	assert(r_dmg.size() > 0, "CRITICAL: damage_city_buildings_in_radius must return non-empty array (r_dmg.size() > 0)")
	assert(r_dmg.size() == 2, "Radius damage must penetrate and damage all buildings in city (expected 2 records)")
	assert(float(test_city["building_durability"]["order_bio_dome"]) == 75.0, "Bio dome took 25 damage at center")
	assert(float(test_city["building_durability"]["order_cognitive_spire"]) == 175.0, "Cognitive spire took 25 damage at center")

	# 2. Multi-building lethal blast penetration (no premature loop break on destruction)
	var r_dmg_lethal := sim.damage_city_buildings_in_radius(test_city["map_pos"], 150.0, 500.0)
	assert(r_dmg_lethal.size() == 2, "Lethal AoE blast must destroy all buildings in city without premature loop break")
	assert(r_dmg_lethal[0]["is_destroyed"] and r_dmg_lethal[1]["is_destroyed"], "Both buildings must be reported destroyed")
	assert(test_city["buildings"].is_empty(), "All buildings in city must be destroyed after lethal AoE blast")

	# 3. Real distance falloff verification (closer target takes strictly more damage than farther target)
	test_city["buildings"]["order_cognitive_spire"] = 1
	test_city["building_durability"]["order_cognitive_spire"] = 200.0

	# Distant explosion (edge of effective radius, dist = 200 px, radius_px = 200.0, max_radius = 280.0)
	var distant_pos: Vector2 = (test_city["map_pos"] as Vector2) + Vector2(200.0, 0.0)
	var r_distant := sim.damage_city_buildings_in_radius(distant_pos, 200.0, 50.0)
	assert(r_distant.size() > 0, "Distant explosion within radius must affect building")
	var hp_after_distant: float = float(test_city["building_durability"]["order_cognitive_spire"])
	var distant_damage_taken: float = 200.0 - hp_after_distant

	# Direct hit explosion (epicenter at dist = 0 px, same base damage 50.0)
	test_city["building_durability"]["order_cognitive_spire"] = 200.0
	var r_direct := sim.damage_city_buildings_in_radius(test_city["map_pos"], 200.0, 50.0)
	assert(r_direct.size() > 0, "Direct explosion must affect building")
	var hp_after_direct: float = float(test_city["building_durability"]["order_cognitive_spire"])
	var direct_damage_taken: float = 200.0 - hp_after_direct

	# Falloff invariants
	assert(direct_damage_taken > distant_damage_taken, "Direct hit must deal strictly more damage than distant hit (real distance falloff)")
	assert(hp_after_direct < hp_after_distant, "Building closer to blast epicenter must have strictly lower remaining HP")
	assert(direct_damage_taken == 50.0, "Direct hit at epicenter must deal 100% full damage (50.0)")
	assert(distant_damage_taken < 50.0 and distant_damage_taken > 0.0, "Distant hit within radius must deal non-zero attenuated damage")
	print(" -> Building durability and damage mechanics PASSED!")

	# -------------------------------------------------------------------------
	# [5/6] F6: Fundamental World Constants & Alchemical Reaction Matrix
	# -------------------------------------------------------------------------
	print("[5/6] Verifying F6: World Constants & Alchemical Matrix...")
	var modified_constants: Array[String] = []
	sim.world_constant_modified.connect(func(c_id, val): modified_constants.append(c_id))

	assert(sim.get_world_constant("gravitational_constant") == 1.0, "Default G must be 1.0")
	sim.set_world_constant("gravitational_constant", 2.5)
	assert(sim.get_world_constant("gravitational_constant") == 2.5, "Modified G must be 2.5")
	assert(modified_constants.has("gravitational_constant"), "Constant modified signal not emitted")

	# Clamping test
	sim.set_world_constant("gravitational_constant", 99.0)
	assert(sim.get_world_constant("gravitational_constant") <= 5.0, "G constant must clamp to max_val 5.0")

	# Alchemical reaction evaluation
	var rx_test1 := sim.evaluate_alchemical_reaction("biome_plasma_inferno", "biome_primordial_ocean")
	assert(rx_test1 != null, "Reaction thermal quench not found")
	assert(rx_test1.output_biome_id == "biome_barren_crust", "Thermal quench must produce barren crust")

	# Reverse lookup test
	var rx_test2 := sim.evaluate_alchemical_reaction("biome_primordial_ocean", "biome_plasma_inferno")
	assert(rx_test2 != null and rx_test2.id == rx_test1.id, "Reverse reaction lookup must resolve to same reaction")

	# Tile index reaction evaluation
	sim.tiles[100]["biome_id"] = "biome_primordial_ocean"
	var rx_tile := sim.evaluate_alchemical_reaction(100, "biome_plasma_inferno")
	assert(rx_tile != null, "Tile-based reaction evaluation failed")

	# Live brush power alchemical transformation & preservation test
	sim.tiles[100]["biome_id"] = "biome_primordial_ocean"
	sim.tiles[100]["temperature_c"] = 15.0
	var r_brush := sim.apply_god_power_to_tile(100, "power_solar_plasma")
	assert(bool(r_brush["ok"]), "Solar plasma cast failed")
	assert(sim.tiles[100]["biome_id"] == "biome_barren_crust", "Alchemical reaction result (biome_barren_crust) must be preserved from brush overwrite")
	assert(sim.tiles[100]["temperature_c"] == 45.0, "Alchemical reaction result temperature must be preserved")
	print(" -> World constants API & alchemical reactions matrix PASSED!")

	# -------------------------------------------------------------------------
	# [6/6] M1 Adversarial Review Hardening
	# -------------------------------------------------------------------------
	print("[6/6] Verifying M1 Hardening Fixes...")
	# 1. War exhaustion symmetry
	if c_ids.size() >= 2:
		var c1: int = c_ids[0]
		var c2: int = c_ids[1]
		var id_low := mini(c1, c2)
		var id_high := maxi(c1, c2)
		sim.set_diplomacy_status(id_low, id_high, "WAR")
		var rel := sim.get_diplomacy_relation(id_low, id_high)
		assert(rel.get("status") == "WAR", "War status must be active")
		rel["war_exhaustion_a"] = 0.0
		rel["war_exhaustion_b"] = 0.0

		sim.actors.clear()
		var act_low := sim._spawn_actor_unit(int(sim.cities_map[id_low]["subspecies_id"]), int(sim.cities_map[id_low]["center_tile"]), id_low, "warrior")
		var act_high := sim._spawn_actor_unit(int(sim.cities_map[id_high]["subspecies_id"]), int(sim.cities_map[id_high]["center_tile"]), id_high, "warrior")
		act_low["pos"] = Vector2(500, 500)
		act_high["pos"] = Vector2(505, 505)
		act_low["hp"] = 1000
		act_high["hp"] = 1000

		sim._step_actor_combat(1.0)
		var low_hp_lost := 1000 - int(act_low["hp"])
		var high_hp_lost := 1000 - int(act_high["hp"])
		if low_hp_lost > 0:
			assert(float(rel["war_exhaustion_a"]) > 0.0, "Low ID took damage, so war_exhaustion_a must increase")
		if high_hp_lost > 0:
			assert(float(rel["war_exhaustion_b"]) > 0.0, "High ID took damage, so war_exhaustion_b must increase")

		# 2. Peace 15s armistice buffer
		sim.set_diplomacy_status(c1, c2, "PEACE")
		assert(float(rel["war_exhaustion_a"]) >= 10.0 and float(rel["war_exhaustion_b"]) >= 10.0, "PEACE must maintain armistice buffer >= 10.0s")
		sim._tick_city_diplomacy(1.0)
		assert(rel.get("status") == "PEACE", "PEACE must NOT immediately revert to NEUTRAL on first tick")

		# 3. Alliance trade flow
		sim.set_diplomacy_status(c1, c2, "ALLIANCE")
		var m_before: float = sim.matter_stock
		sim._tick_city_diplomacy(1.0)
		assert(sim.matter_stock > m_before, "ALLIANCE must generate bilateral trade yield")
	print(" -> M1 Hardening review fixes PASSED!")

	# Clean up
	sim.free()

	print("=== ALL MILESTONE 2 (MEGASTRUCTURES, LAWS & ARSENAL) CHECKS PASSED (FAILED: 0) ===")
	quit(0)
