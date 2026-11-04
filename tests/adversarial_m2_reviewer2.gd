extends SceneTree

## Adversarial Reviewer 2 Verification Suite: Simulation Robustness & Edge Cases
## Focus areas:
## 1. Dyson stage transitions under resource starvation (matter = 0, negative matter, sail thresholds)
## 2. Building durability: multiple damage sources, demolition at 0 count, spatial radius falloff examination
## 3. God powers: cataclysms on empty ocean, extreme & negative world constants

const WorldSimulationScript = preload("res://scripts/sim/world_simulation.gd")
const SandboxAssetManagerScript = preload("res://scripts/core/asset_manager.gd")
const SandboxAssetScript = preload("res://scripts/core/sandbox_asset.gd")

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
	print("=== RUNNING ADVERSARIAL REVIEWER 2 TEST SUITE ===")
	var sim := WorldSimulationScript.new()
	sim.setup_world(9999)

	# =========================================================================
	# SECTION 1: Dyson Stage Transitions Under Resource Starvation
	# =========================================================================
	print("\n--- SECTION 1: Dyson Starvation & Stage Transitions ---")
	
	# Test 1.1: Stage 1 to 2 transition without matter
	sim.dyson_stage = 1
	sim.matter_stock = 0.0
	sim.energy_gw = 0.0
	sim.total_dyson_sails = 99
	sim._advance_dyson_construction_step(1.0)
	check(sim.dyson_stage == 1, "Stage 1 should not advance at 99 sails")
	
	sim.total_dyson_sails = 150
	sim._advance_dyson_construction_step(1.0)
	check(sim.dyson_stage == 2, "Stage 1 advances to Stage 2 at 150 sails even with 0 matter")
	check(sim.matter_stock == 0.0, "Matter stock remained 0.0 during Stage 1->2 advance")

	# Test 1.2: Stage 2 construction under 0 matter stock
	sim.matter_stock = 0.0
	sim.energy_gw = 50.0
	sim.dyson_stage_progress = 0.0
	sim.dyson_ring_frame_segments = 0
	
	for _i in range(100):
		sim._advance_dyson_construction_step(1.0)
	check(not sim.dyson_is_constructing, "Dyson must not construct while matter is 0.0")
	check(sim.dyson_stage_progress == 0.0, "Progress must stay 0.0 with 0 matter")
	check(sim.dyson_ring_frame_segments == 0, "Segments must remain 0 with 0 matter")
	check(sim.matter_stock == 0.0, "Matter stock must not become negative")
	check(sim.dyson_stage == 2, "Stage must not advance while stalled at 0 progress")

	# Test 1.3: Energy output during starvation
	var stall_energy: float = sim.get_dyson_energy_output()
	check(stall_energy > 0.0, "Existing Dyson structure generates energy even when construction stalls: %.2f GW" % stall_energy)

	# Test 1.4: Starvation with Negative Matter
	sim.matter_stock = -50.0
	sim._advance_dyson_construction_step(1.0)
	check(not sim.dyson_is_constructing, "Dyson must not construct with negative matter")
	check(sim.matter_stock == -50.0, "Negative matter is not further drained")

	# Test 1.5: Transition from Stage 2 to 3 under starvation
	sim.matter_stock = 0.0
	sim.total_dyson_sails = 400
	sim._advance_dyson_construction_step(1.0)
	check(sim.dyson_stage == 2, "Stage 2 does not advance to Stage 3 when matter is 0, even if sails >= 350")

	# Now give matter and verify recovery and advance
	sim.matter_stock = 100.0
	sim._advance_dyson_construction_step(1.0)
	check(sim.dyson_stage == 3, "Stage 2 advances to Stage 3 once matter is restored and sails condition is met")

	# Test 1.6: Stage 3 to 4 starvation
	sim.matter_stock = 0.0
	sim.dyson_stage_progress = 0.0
	sim.dyson_shell_active_segments = 0
	for _i in range(50):
		sim._advance_dyson_construction_step(1.0)
	check(not sim.dyson_is_constructing, "Stage 3 stalls at 0 matter")
	check(sim.dyson_shell_active_segments == 0, "Stage 3 segments remain 0 at 0 matter")

	# Restore and advance to Stage 4
	sim.matter_stock = 500.0
	sim.total_dyson_sails = 700
	sim._advance_dyson_construction_step(1.0)
	check(sim.dyson_stage == 4, "Stage 3 advances to Stage 4 with adequate matter and sails")

	# Test 1.7: Stage 4 starvation
	sim.matter_stock = 0.0
	sim.dyson_stage_progress = 0.0
	var layers_before: int = sim.dyson_matrioshka_layers
	for _i in range(50):
		sim._advance_dyson_construction_step(1.0)
	check(not sim.dyson_is_constructing, "Stage 4 stalls at 0 matter")
	check(sim.dyson_matrioshka_layers == layers_before, "Matrioshka layers do not increase without matter")
	check(sim.matter_stock == 0.0, "Matter does not go negative in Stage 4 stall")

	# =========================================================================
	# SECTION 2: Building Durability & Spatial Radius Falloff
	# =========================================================================
	print("\n--- SECTION 2: Building Durability & Spatial Damage Mechanics ---")
	
	var c_ids := sim.cities_map.keys()
	check(c_ids.size() > 0, "At least one city exists in world")
	var c_id: int = c_ids[0]
	var city: Dictionary = sim.cities_map[c_id]

	# Test 2.1: Initialize clean building set with valid build orders
	city["buildings"].clear()
	if city.has("building_durability"):
		(city["building_durability"] as Dictionary).clear()
	city["buildings"]["order_bio_dome"] = 3
	city["buildings"]["order_cognitive_spire"] = 2
	sim._rebuild_city_2d_instances(city)
	check((city["building_instances"] as Array).size() == 5, "Building instances reconstructed to 5")

	# Test 2.2: Multiple simultaneous damage sources to same building
	# Bio Dome is tier 1 -> 100 HP max
	var d1 := sim.damage_city_building(c_id, "order_bio_dome", 25.0) # 75 HP remaining
	check(not d1, "25 damage does not destroy bio dome")
	check(float(city["building_durability"]["order_bio_dome"]) == 75.0, "Bio dome durability is 75")

	var d2 := sim.damage_city_building(c_id, "order_bio_dome", 35.0) # 40 HP remaining
	check(not d2, "Additional 35 damage does not destroy bio dome")
	check(float(city["building_durability"]["order_bio_dome"]) == 40.0, "Bio dome durability is 40")

	var d3 := sim.damage_city_building(c_id, "order_bio_dome", 45.0) # Exceeds 40 HP -> destruction of 1 instance!
	check(d3, "45 damage destroys currently damaged instance")
	check(int(city["buildings"]["order_bio_dome"]) == 2, "Bio dome count decrements from 3 to 2")
	check(float(city["building_durability"]["order_bio_dome"]) == 100.0, "Next bio dome instance durability reset to 100.0")

	# Test 2.3: Demolition down to 0 count
	var d4 := sim.damage_city_building(c_id, "order_bio_dome", 100.0)
	check(d4, "Instance 2 destroyed")
	check(int(city["buildings"]["order_bio_dome"]) == 1, "Count decrements to 1")

	var d5 := sim.damage_city_building(c_id, "order_bio_dome", 100.0)
	check(d5, "Final instance destroyed")
	check(not (city["buildings"] as Dictionary).has("order_bio_dome"), "Building key erased from buildings dict when count reaches 0")
	check(not (city["building_durability"] as Dictionary).has("order_bio_dome"), "Key erased from building_durability dict when count reaches 0")

	# Test 2.4: Damage when building count is 0 / non-existent
	var d6 := sim.damage_city_building(c_id, "order_bio_dome", 50.0)
	check(not d6, "Damage to non-existent building gracefully returns false")

	# Test 2.5: SPATIAL RADIUS FALLOFF INVESTIGATION
	var c_pos: Vector2 = city["map_pos"]
	# Cognitive Spire is tier 2 -> 200 HP max
	city["buildings"].clear()
	(city["building_durability"] as Dictionary).clear()
	city["buildings"]["order_cognitive_spire"] = 1

	# Direct hit (distance = 0): 50 damage
	var recs_direct := sim.damage_city_buildings_in_radius(c_pos, 200.0, 50.0)
	var hp_after_direct: float = float(city["building_durability"]["order_cognitive_spire"])
	check(hp_after_direct == 150.0, "Direct hit: took exactly 50 damage (HP 200 -> 150)")

	# Reset HP to 200
	city["building_durability"]["order_cognitive_spire"] = 200.0
	# Edge hit (distance = 250 px, within radius 200 + 80 = 280)
	var edge_pos := c_pos + Vector2(250.0, 0.0)
	var recs_edge := sim.damage_city_buildings_in_radius(edge_pos, 200.0, 50.0)
	var hp_after_edge: float = float(city["building_durability"]["order_cognitive_spire"])
	check(hp_after_edge > hp_after_direct, "Edge hit took strictly less damage than direct hit due to radius falloff (HP %.2f > %.2f)" % [hp_after_edge, hp_after_direct])
	check(recs_edge.size() > 0, "Edge hit returned valid damage records")
	
	if hp_after_edge == hp_after_direct:
		record_finding("Major", "Missing Spatial Radius Falloff", "damage_city_buildings_in_radius applies flat damage regardless of distance. Both 0px distance and 250px distance dealt identical 50.0 damage.")

	# Test 2.6: Multi-building damage penetration
	city["buildings"].clear()
	(city["building_durability"] as Dictionary).clear()
	city["buildings"]["order_bio_dome"] = 1
	city["buildings"]["order_cognitive_spire"] = 1
	var multi_dmg_recs := sim.damage_city_buildings_in_radius(c_pos, 100.0, 999.0)
	check(multi_dmg_recs.size() == 2, "Cataclysm penetrates and damages all buildings in city without premature loop break")
	check(city["buildings"].is_empty(), "All buildings in city destroyed by lethal AoE blast")
	if multi_dmg_recs.size() == 1 and city["buildings"].size() > 0:
		record_finding("Major", "AoE Cataclysm Premature Termination", "Cataclysms with lethal damage break out of building damage loop after destroying only 1 building instance, shielding remaining buildings from the blast.")

	# =========================================================================
	# SECTION 3: God Powers & Cataclysms on Empty Ocean
	# =========================================================================
	print("\n--- SECTION 3: Cataclysms on Empty Ocean & World Constants ---")

	var ocean_tile_idx := -1
	for i in range(sim.TILE_COUNT):
		if sim.tiles[i]["biome_id"] == "biome_primordial_ocean" and int(sim.tiles[i]["city_id"]) == -1:
			ocean_tile_idx = i
			break
	if ocean_tile_idx == -1:
		ocean_tile_idx = 123
		sim.tiles[ocean_tile_idx]["biome_id"] = "biome_primordial_ocean"
		sim.tiles[ocean_tile_idx]["elevation"] = -0.20
		sim.tiles[ocean_tile_idx]["city_id"] = -1

	var ocean_t: Dictionary = sim.tiles[ocean_tile_idx]
	var initial_elev: float = float(ocean_t["elevation"])
	check(initial_elev < 0.0, "Ocean tile initial elevation is negative (water)")

	# Test 3.1: Meteor strike on ocean
	var res_meteor := sim.apply_god_power_to_tile(ocean_tile_idx, "power_meteor_strike")
	check(bool(res_meteor["ok"]), "Meteor strike on ocean succeeded")
	check(ocean_t["elevation"] <= -0.25, "Meteor creates deep underwater crater")
	check(ocean_t["biome_id"] == "biome_actinide_wasteland", "Impact epicenter converted to actinide wasteland")

	# Test 3.2: Gaia Bloom on ocean
	ocean_t["radiation"] = 0.9
	var res_bloom := sim.apply_god_power_to_tile(ocean_tile_idx, "power_gaia_bloom")
	check(bool(res_bloom["ok"]), "Gaia bloom on ocean succeeded")
	check(ocean_t["radiation"] == 0.0, "Gaia bloom cleansed ocean radiation to 0.0")
	check(ocean_t["biome_id"] == "biome_primordial_ocean", "Negative elevation tile restored to primordial ocean by bloom")

	# Test 3.3: Seismic Quake on ocean
	ocean_t["elevation"] = -0.10
	var res_quake := sim.apply_god_power_to_tile(ocean_tile_idx, "power_seismic_quake")
	check(bool(res_quake["ok"]), "Seismic quake on ocean succeeded")
	if float(ocean_t["elevation"]) > 0.0 and ocean_t["biome_id"] == "biome_primordial_ocean":
		record_finding("Minor", "Ocean Biome Uplift Inconsistency", "Seismic faulting can raise seabed above sea level (elevation > 0.0), leaving a dry land tile typed as biome_primordial_ocean.")

	# Test 3.4: World Constants - Negative and Extreme Values
	sim.set_world_constant("gravitational_constant", -999.0)
	check(sim.get_world_constant("gravitational_constant") == 0.1, "Negative G clamped to min_val 0.1")
	sim.set_world_constant("gravitational_constant", 99999.0)
	check(sim.get_world_constant("gravitational_constant") == 5.0, "Extreme G clamped to max_val 5.0")

	sim.set_world_constant("light_speed", -10.0)
	check(sim.get_world_constant("light_speed") == 0.2, "Negative light_speed clamped to min_val 0.2")

	sim.set_world_constant("cosmic_entropy_rate", -5.0)
	check(sim.get_world_constant("cosmic_entropy_rate") == 0.0, "Negative cosmic_entropy_rate clamped to min_val 0.0")

	sim.set_world_constant("mutation_rate_multiplier", -100.0)
	check(sim.get_world_constant("mutation_rate_multiplier") == 0.1, "Negative mutation rate clamped to min_val 0.1")

	# Test 3.5: Unknown constant set
	sim.set_world_constant("unknown_nonexistent_constant", -42.0)
	check(sim.get_world_constant("unknown_nonexistent_constant") == -42.0, "Unregistered constant accepts arbitrary values")
	record_finding("Minor", "Unclamped Unregistered Constants", "set_world_constant only clamps if an asset is registered; unknown IDs bypass clamping.")

	# Test 3.6: Dead constant verification (cosmic_entropy_rate)
	record_finding("Minor", "Unused Cosmic Entropy Constant", "cosmic_entropy_rate is exposed in UI and assets with description 'Управляет естественным износом городских построек', but is unreferenced in simulation logic.")

	# =========================================================================
	# SUMMARY
	# =========================================================================
	print("\n=== REVIEWER 2 ADVERSARIAL TEST RESULTS ===")
	print("Total assertions: ", total_assertions)
	print("Passed: ", passed_assertions)
	print("Failed: ", failed_assertions)
	print("Findings Recorded: ", findings.size())
	for f in findings:
		print(" [%s] %s: %s" % [f["severity"], f["title"], f["details"]])

	sim.free()
	quit(0 if failed_assertions == 0 else 1)
