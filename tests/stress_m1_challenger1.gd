extends SceneTree

## Empirical Correctness & Falsification Stress Suite for Milestone 1
## Authored by M1 Challenger 1 (teamwork_challenger)
## Target: Diplomacy, Culture/Ethos & Inter-Island Colonization under Extreme Pressure

const WorldSimulation = preload("res://scripts/sim/world_simulation.gd")
const SandboxAssetManager = preload("res://scripts/core/asset_manager.gd")
const SandboxAssetScript = preload("res://scripts/core/sandbox_asset.gd")

var total_assertions: int = 0
var total_checks_passed: int = 0
var total_checks_failed: int = 0

func assert_check(condition: bool, message: String) -> void:
	total_assertions += 1
	if not condition:
		push_error("STRESS ASSERTION FAILED: " + message)
		printerr("STRESS ASSERTION FAILED: " + message)
		total_checks_failed += 1
	else:
		total_checks_passed += 1

func assert_no_nan_or_inf(val: float, context: String) -> void:
	assert_check(not is_nan(val), "NaN detected in: " + context)
	assert_check(not is_inf(val), "Inf detected in: " + context)

func _init() -> void:
	print("=====================================================================")
	print("=== STARTING M1 CHALLENGER 1 EMPIRICAL STRESS & FALSIFICATION TEST ==")
	print("=====================================================================")

	var sim := WorldSimulation.new()
	root.add_child(sim)
	await process_frame

	sim.setup_world(7777)
	var initial_mem: int = int(OS.get_static_memory_usage())
	print("Initial baseline memory usage: %d bytes" % initial_mem)

	# -------------------------------------------------------------------------
	# STRESS TEST 1: Extreme City Scale (12+ cities) & Rapid Diplomacy Transitions
	# -------------------------------------------------------------------------
	print("\n--- [TEST 1/6] Extreme City Scale (12+ Cities) & Dense Diplomacy Matrix ---")
	
	var base_city_count: int = sim.cities_map.size()
	assert_check(base_city_count >= 2, "Expected at least 2 cradle cities initially")

	# Expand world to 12 cities using uplift power across the map
	var candidate_tiles: Array[int] = [
		64, 128, 256, 384, 512, 600, 720, 800, 880, 950
	]
	for t_idx in candidate_tiles:
		if sim.cities_map.size() >= 12:
			break
		sim.tiles[t_idx]["elevation"] = 0.20
		sim.tiles[t_idx]["biome_id"] = "biome_primordial_ocean"
		var sp_id := sim._spawn_subspecies_at_tile(t_idx, "humanoid")
		var c_id := sim._uplift_subspecies_and_found_city(sp_id, t_idx)
		assert_check(c_id > 0, "Uplift and found city must return valid ID")

	var city_count: int = sim.cities_map.size()
	print("Active Cities Count after scaling: %d" % city_count)
	assert_check(city_count >= 10, "Must have 10+ active cities for stress testing (got %d)" % city_count)

	var expected_pairs: int = (city_count * (city_count - 1)) / 2
	var city_ids: Array = sim.cities_map.keys()
	print("Expected bilateral diplomacy pairs: %d" % expected_pairs)

	# Ensure all pairs exist and verify symmetric pair keys
	for i in range(city_ids.size()):
		var id_a: int = int(city_ids[i])
		for j in range(i + 1, city_ids.size()):
			var id_b: int = int(city_ids[j])
			var rel_ab := sim._ensure_diplomacy_relation(id_a, id_b)
			var rel_ba := sim.get_diplomacy_relation(id_b, id_a)
			assert_check(not rel_ab.is_empty(), "Relation ab between %d and %d must exist" % [id_a, id_b])
			assert_check(rel_ab["key"] == rel_ba["key"], "Relation key must be symmetric for (%d, %d)" % [id_a, id_b])
			assert_check(int(rel_ab["city_a"]) == mini(id_a, id_b), "city_a must be smaller ID")
			assert_check(int(rel_ab["city_b"]) == maxi(id_a, id_b), "city_b must be larger ID")

	# Rapid diplomacy transitions across all pairs (Repeated Wars, Peace, Trade, Alliance)
	print("Executing 400 rapid diplomacy transitions across all pairs...")
	var transition_statuses := ["WAR", "PEACE", "TRADE", "ALLIANCE", "NEUTRAL"]
	var signal_tracker := {
		"count": 0,
		"last_old": "",
		"last_new": ""
	}

	var sig_callable := func(a_id: int, b_id: int, old_s: String, new_s: String):
		signal_tracker["count"] += 1
		signal_tracker["last_old"] = old_s
		signal_tracker["last_new"] = new_s

	sim.diplomacy_relation_changed.connect(sig_callable)

	for cycle in range(5):
		for i in range(mini(city_ids.size(), 10)):
			var id_a: int = int(city_ids[i])
			for j in range(i + 1, mini(city_ids.size(), 10)):
				var id_b: int = int(city_ids[j])
				for st in transition_statuses:
					sim.set_diplomacy_status(id_a, id_b, st)
					var cur_rel := sim.get_diplomacy_relation(id_a, id_b)
					assert_check(cur_rel.get("status") == st, "Status must match transition target: " + st)

	sim.diplomacy_relation_changed.disconnect(sig_callable)
	print("Rapid transitions passed. Signal fired %d times without crashes." % int(signal_tracker["count"]))
	assert_check(int(signal_tracker["count"]) > 100, "Signal must fire across rapid transitions (got %d)" % int(signal_tracker["count"]))

	# Check event log size limit
	assert_check(sim.event_log.size() <= 80, "Event log must be bounded to 80 entries max (got %d)" % sim.event_log.size())

	# -------------------------------------------------------------------------
	# STRESS TEST 2: Rapid & Extreme Opinion Swings (-100 to +100 & NaN Safety)
	# -------------------------------------------------------------------------
	print("\n--- [TEST 2/6] Rapid & Extreme Opinion Swings (-100 to +100) & Numeric Safety ---")

	var c_first: Dictionary = sim.cities_map[city_ids[0]]
	var c_second: Dictionary = sim.cities_map[city_ids[1]]

	# Adversarial opinion stress: test all permutations of ethos, distances, borders, treaties
	var test_ethoses := ["ethos_expansionist", "ethos_scientific", "ethos_xenophile", "ethos_militarist", "unknown_ethos", ""]
	var test_distances := [0.0, 1.0, 50.0, 200.0, 499.0, 500.0, 1500.0, 99999.0]
	var test_subspecies := [int(c_first["subspecies_id"]), 9999, -1]

	var iterations_tested: int = 0
	for eth_a in test_ethoses:
		for eth_b in test_ethoses:
			for d_val in test_distances:
				for sp_val in test_subspecies:
					c_first["ethos_id"] = eth_a
					c_second["ethos_id"] = eth_b
					c_second["subspecies_id"] = sp_val
					c_second["map_pos"] = (c_first["map_pos"] as Vector2) + Vector2(d_val, 0.0)

					for st in ["NEUTRAL", "WAR", "TRADE", "ALLIANCE"]:
						sim.set_diplomacy_status(int(c_first["id"]), int(c_second["id"]), st)
						var op: float = sim._calculate_opinion(c_first, c_second)
						assert_no_nan_or_inf(op, "Opinion calculation for d=%f, st=%s" % [d_val, st])
						assert_check(op >= -100.0 and op <= 100.0, "Opinion MUST be bounded in [-100.0, 100.0], got %f" % op)
						iterations_tested += 1

	print("Tested %d adversarial opinion parameter combinations. All within [-100, 100] with zero NaNs/Infs." % iterations_tested)

	# Verify boundary condition: Militarist war vs Xenophile yields <= -70
	c_first["ethos_id"] = "ethos_militarist"
	c_second["ethos_id"] = "ethos_xenophile"
	c_second["subspecies_id"] = 8888
	sim.set_diplomacy_status(int(c_first["id"]), int(c_second["id"]), "WAR")
	var hostile_op: float = sim._calculate_opinion(c_first, c_second)
	assert_check(hostile_op <= -70.0, "Militarist alien at war must have very hostile opinion (got %f)" % hostile_op)

	# Verify boundary condition: Mother-Daughter same ethos Alliance yields >= +80
	c_second["parent_city_id"] = int(c_first["id"])
	c_second["ethos_id"] = "ethos_xenophile"
	c_first["ethos_id"] = "ethos_xenophile"
	c_second["subspecies_id"] = int(c_first["subspecies_id"])
	sim.set_diplomacy_status(int(c_first["id"]), int(c_second["id"]), "ALLIANCE")
	var ally_op: float = sim._calculate_opinion(c_first, c_second)
	assert_check(ally_op >= 80.0, "Mother-daughter alliance must have near max opinion (got %f)" % ally_op)
	c_second["parent_city_id"] = -1 # reset

	# -------------------------------------------------------------------------
	# STRESS TEST 3: Edge Tile Colonization (Corners and Grid Periphery)
	# -------------------------------------------------------------------------
	print("\n--- [TEST 3/6] Edge Tile Colonization & Daughter Polis Architecture ---")

	var edge_test_tiles: Array[int] = [
		0,                       # Top-left corner (gx=0, gy=0)
		31,                      # Top-right corner (gx=31, gy=0)
		992,                     # Bottom-left corner (gx=0, gy=31)
		1023,                    # Bottom-right corner (gx=31, gy=31)
		15,                      # Top edge midpoint (gx=15, gy=0)
		1007,                    # Bottom edge midpoint (gx=15, gy=31)
		480,                     # Left edge midpoint (gx=0, gy=15)
		511                      # Right edge midpoint (gx=31, gy=15)
	]

	var mother_c_id: int = int(city_ids[0])
	var mother_city: Dictionary = sim.cities_map[mother_c_id]
	var m_sp_id: int = int(mother_city["subspecies_id"])
	var m_cult_id: int = int(mother_city["culture_id"])

	var founded_colonies: Array[int] = []
	for edge_tile in edge_test_tiles:
		sim.tiles[edge_tile]["city_id"] = -1
		for nbr in sim.tiles[edge_tile]["neighbors"]:
			sim.tiles[nbr]["city_id"] = -1

		var daughter_id := sim._found_daughter_city(mother_c_id, edge_tile, m_sp_id, m_cult_id)
		assert_check(daughter_id > 0, "Daughter city founded on edge tile %d must succeed" % edge_tile)
		assert_check(sim.cities_map.has(daughter_id), "Daughter city %d must be registered in cities_map" % daughter_id)

		var d_city: Dictionary = sim.cities_map[daughter_id]
		assert_check(int(d_city["parent_city_id"]) == mother_c_id, "Daughter city must reference mother")
		assert_check(d_city["ethos_id"] == mother_city["ethos_id"], "Daughter city must inherit mother ethos")
		assert_check(int(d_city["center_tile"]) == edge_tile, "Center tile must match edge tile")
		assert_check((d_city["claimed_tiles"] as Array).size() >= 1, "Must claim at least center tile on edge")

		var d_rel := sim.get_diplomacy_relation(mother_c_id, daughter_id)
		assert_check(d_rel.get("status") == "ALLIANCE", "Daughter city must have ALLIANCE with mother")

		founded_colonies.append(daughter_id)

	print("Successfully founded colonies on all 8 extreme edge tiles and corners without crash.")

	# Test 3rd Generation Colonization (Granddaughter Polis)
	var grand_mother_id: int = founded_colonies[0]
	var grand_target_tile: int = 160
	sim.tiles[grand_target_tile]["city_id"] = -1
	var grand_daughter_id := sim._found_daughter_city(grand_mother_id, grand_target_tile, m_sp_id, m_cult_id)
	var gd_city: Dictionary = sim.cities_map[grand_daughter_id]
	assert_check(int(gd_city["parent_city_id"]) == grand_mother_id, "Granddaughter must reference daughter")
	assert_check(int(gd_city["kingdom_id"]) == int(sim.cities_map[grand_mother_id]["kingdom_id"]), "Kingdom dynasty must be preserved")
	print("Granddaughter 3rd generation colony founded successfully.")

	# -------------------------------------------------------------------------
	# STRESS TEST 4: Multiple Concurrent Colonization Parties & Land Exhaustion
	# -------------------------------------------------------------------------
	print("\n--- [TEST 4/6] Multiple Concurrent Colonization Parties & Land Exhaustion ---")

	# Prepare uncolonized island tiles suitable for colonization
	# Elevation >= -0.04, city_id == -1, distance between 200 and 850 from candidate mothers
	var test_island_tiles: Array[int] = [340, 345, 350, 460, 465, 470]
	for t_idx in test_island_tiles:
		sim.tiles[t_idx]["city_id"] = -1
		sim.tiles[t_idx]["elevation"] = 0.25
		for n in sim.tiles[t_idx]["neighbors"]:
			sim.tiles[n]["city_id"] = -1

	# Ensure room in actor pool
	while sim.actors.size() > 150:
		sim.actors.pop_back()

	var exp_tracker := {"count": 0}
	var launched_listener := func(m_id: int, from_p: Vector2, to_p: Vector2):
		exp_tracker["count"] += 1
	sim.colony_expedition_launched.connect(launched_listener)

	var active_mother_ids: Array = sim.cities_map.keys().slice(0, 4)
	var colonist_actors: Array[Dictionary] = []
	for mid in active_mother_ids:
		var c_dict: Dictionary = sim.cities_map[mid]
		c_dict["population"] = 100.0
		var target_t := sim._find_best_colony_tile(c_dict)
		if target_t != -1:
			sim._launch_colonist_expedition(c_dict, target_t)
			for a in sim.actors:
				if str(a.get("role", "")) == "colonist" and int(a.get("city_id", -1)) == mid:
					if not colonist_actors.has(a):
						colonist_actors.append(a)
						break

	sim.colony_expedition_launched.disconnect(launched_listener)
	print("Launched %d concurrent colonist expeditions." % int(exp_tracker["count"]))
	assert_check(int(exp_tracker["count"]) >= 1, "Expected colonist expeditions launched (got %d)" % int(exp_tracker["count"]))

	# Step movement for colonists: simulate them reaching targets
	print("Stepping %d colonist actors toward target tiles..." % colonist_actors.size())
	for a in colonist_actors:
		var target_t_idx: int = int(a.get("home_tile", -1))
		if target_t_idx != -1 and target_t_idx < sim.TILE_COUNT:
			a["pos"] = sim.tiles[target_t_idx]["map_pos"] + Vector2(2.0, 2.0)
			a["target_pos"] = sim.tiles[target_t_idx]["map_pos"]

	var cities_before_arrival: int = sim.cities_map.size()
	sim._step_actors(0.2)
	print("Cities count after colonist arrivals: %d (was %d)" % [sim.cities_map.size(), cities_before_arrival])

	# Test Land Exhaustion Edge Case: what if no free land exists on entire map?
	print("Testing land exhaustion edge case (all tiles claimed or flooded)...")
	var saved_elevations := {}
	for i in range(sim.TILE_COUNT):
		if int(sim.tiles[i]["city_id"]) == -1:
			saved_elevations[i] = sim.tiles[i]["elevation"]
			sim.tiles[i]["elevation"] = -0.30

	var no_land_tile: int = sim._find_best_colony_tile(mother_city)
	assert_check(no_land_tile == -1, "_find_best_colony_tile must return -1 when no valid land exists")

	sim._check_and_step_colonization(1.0)
	print("Land exhaustion handled safely. Returned -1 with zero crashes.")

	# Restore elevations
	for idx in saved_elevations.keys():
		sim.tiles[idx]["elevation"] = saved_elevations[idx]

	# -------------------------------------------------------------------------
	# STRESS TEST 5: High-Density Actor Combat, Border Raids & War Exhaustion
	# -------------------------------------------------------------------------
	print("\n--- [TEST 5/6] High-Density Actor Combat & War Exhaustion Dynamics ---")

	var city_war_a_id: int = int(city_ids[0])
	var city_war_b_id: int = int(city_ids[1])
	sim.set_diplomacy_status(city_war_a_id, city_war_b_id, "WAR")
	var war_rel := sim.get_diplomacy_relation(city_war_a_id, city_war_b_id)
	assert_check(war_rel.get("status") == "WAR", "War status must be active")

	# Ensure room in actor pool for warriors
	while sim.actors.size() > 160:
		sim.actors.pop_back()

	var combat_tracker := {"dmg": 0, "raid": 0}
	var combat_listener := func(a_id: int, k_id: int, cause: String):
		combat_tracker["dmg"] += 1
	var raid_listener := func(c_id: int, b_id: String, destroyed: bool):
		combat_tracker["raid"] += 1

	sim.actor_damaged_or_killed.connect(combat_listener)
	sim.building_damaged_or_destroyed.connect(raid_listener)

	var war_pos := Vector2(400.0, 300.0)
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345
	for _w in range(15):
		var wa := sim._spawn_actor_unit(int(sim.cities_map[city_war_a_id]["subspecies_id"]), 0, city_war_a_id, "warrior")
		var wb := sim._spawn_actor_unit(int(sim.cities_map[city_war_b_id]["subspecies_id"]), 0, city_war_b_id, "warrior")
		if not wa.is_empty():
			wa["pos"] = war_pos + Vector2(rng.randf_range(-4.0, 4.0), rng.randf_range(-4.0, 4.0))
			wa["role"] = "warrior"
			wa["hp"] = 150
		if not wb.is_empty():
			wb["pos"] = war_pos + Vector2(rng.randf_range(-4.0, 4.0), rng.randf_range(-4.0, 4.0))
			wb["role"] = "warrior"
			wb["hp"] = 150

	for _step in range(30):
		sim._step_actor_combat(1.0)

	sim.actor_damaged_or_killed.disconnect(combat_listener)
	sim.building_damaged_or_destroyed.disconnect(raid_listener)

	print("Combat stress results: %d damage/kill events, %d raid events." % [
		int(combat_tracker["dmg"]), int(combat_tracker["raid"])
	])
	assert_check(int(combat_tracker["dmg"]) > 0, "Actor combat must register hits during war clash (got %d)" % int(combat_tracker["dmg"]))

	var ex_a: float = float(war_rel.get("war_exhaustion_a", 0.0))
	var ex_b: float = float(war_rel.get("war_exhaustion_b", 0.0))
	assert_no_nan_or_inf(ex_a, "war_exhaustion_a")
	assert_no_nan_or_inf(ex_b, "war_exhaustion_b")
	print("War exhaustion accumulated: A=%.2f, B=%.2f" % [ex_a, ex_b])
	assert_check(ex_a > 0.0 or ex_b > 0.0, "Combat must accumulate war exhaustion on relation")

	# Test peace transition
	sim.set_diplomacy_status(city_war_a_id, city_war_b_id, "PEACE")
	assert_check(war_rel.get("status") == "PEACE", "Must transition to PEACE")

	# Decay exhaustion in peace
	for _p in range(10):
		sim._tick_city_diplomacy(4.0)
	print("Peace exhaustion decay tested. Status: %s" % war_rel.get("status"))

	# -------------------------------------------------------------------------
	# STRESS TEST 6: Continuous Simulation Warp, Telemetry & Memory Leak Check
	# -------------------------------------------------------------------------
	print("\n--- [TEST 6/6] 120-Step Continuous Simulation Warp & Memory Leak Check ---")

	for warp_step in range(120):
		sim.step_simulation(0.5)

		if warp_step % 15 == 0:
			var rand_a: int = int(city_ids[warp_step % city_ids.size()])
			var rand_b: int = int(city_ids[(warp_step + 3) % city_ids.size()])
			if rand_a != rand_b:
				var st_choices := ["TRADE", "ALLIANCE", "WAR", "PEACE", "NEUTRAL"]
				sim.set_diplomacy_status(rand_a, rand_b, st_choices[warp_step % st_choices.size()])

	var g_metrics: Dictionary = sim.get_global_world_metrics()
	assert_check(not g_metrics.is_empty(), "Global world metrics must not be empty")
	assert_check(int(g_metrics["total_cities"]) >= 10, "Total cities metric must be >= 10")
	assert_no_nan_or_inf(float(g_metrics["matter_stock"]), "Global matter_stock")
	assert_no_nan_or_inf(float(g_metrics["energy_gw"]), "Global energy_gw")
	assert_no_nan_or_inf(float(g_metrics["compute_pflops"]), "Global compute_pflops")

	for cid in sim.cities_map.keys():
		var c_data := sim.get_detailed_city_data(int(cid))
		assert_check(not c_data.is_empty(), "Detailed city data must exist for city %d" % cid)
		assert_no_nan_or_inf(float(c_data["population"]), "City %d population" % cid)
		assert_no_nan_or_inf(float(c_data["kardashev_level"]), "City %d kardashev" % cid)
		assert_no_nan_or_inf(float(c_data["internal_cohesion"]), "City %d cohesion" % cid)

		var rels_dict: Dictionary = c_data.get("relations", {})
		for oid in rels_dict.keys():
			var r_info: Dictionary = rels_dict[oid]
			assert_no_nan_or_inf(float(r_info.get("opinion", 0.0)), "City %d to %d opinion" % [cid, oid])
			assert_no_nan_or_inf(float(r_info.get("war_exhaustion", 0.0)), "City %d to %d war_exhaustion" % [cid, oid])
			assert_no_nan_or_inf(float(r_info.get("trade_yield", 0.0)), "City %d to %d trade_yield" % [cid, oid])

	var inspected_actor_count: int = 0
	for a in sim.actors:
		var a_data := sim.get_detailed_actor_data(int(a["id"]))
		if not a_data.is_empty():
			assert_no_nan_or_inf(float(a_data.get("hp", 0)), "Actor %d hp" % int(a["id"]))
			inspected_actor_count += 1
	print("Verified detailed inspection contracts for all cities and %d actors." % inspected_actor_count)

	var final_mem: int = int(OS.get_static_memory_usage())
	var mem_delta_kb: float = float(final_mem - initial_mem) / 1024.0
	print("Memory profile: Initial=%d KB, Final=%d KB, Delta=%.2f KB" % [
		initial_mem / 1024, final_mem / 1024, mem_delta_kb
	])
	assert_check(mem_delta_kb < 30000.0, "Static memory growth exceeded 30 MB (potential leak)")

	sim.free()

	print("\n=====================================================================")
	if total_checks_failed == 0:
		print("=== ALL STRESS & FALSIFICATION TESTS PASSED! (FAILED: 0)          ===")
		print("=== Total assertions verified: %d / %d (100%%)                     ===" % [total_checks_passed, total_assertions])
		print("=====================================================================")
		quit(0)
	else:
		printerr("=== STRESS SUITE COMPLETED WITH FAILURES: %d FAILED / %d TOTAL ===" % [total_checks_failed, total_assertions])
		print("=====================================================================")
		quit(1)
