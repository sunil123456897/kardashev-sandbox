extends SceneTree

## Automated Verification Test for Milestone 1 (F1, F2, F3)
## Civilization Deepening, Ideology, Diplomacy & Inter-Island Colonization

const SandboxAssetManager = preload("res://scripts/core/asset_manager.gd")
const SandboxAssetScript = preload("res://scripts/core/sandbox_asset.gd")
const WorldSimulation = preload("res://scripts/sim/world_simulation.gd")

func _init() -> void:
	print("=== RUNNING MILESTONE 1 (DIPLOMACY & COLONIZATION) TEST SUITE ===")
	var am := SandboxAssetManager.new()

	# 1. Проверка реестров и дуальной индексации (Dual-Indexing Pattern)
	print("[1/6] Verifying Dual-Indexing & Asset Registry extensions...")
	assert(am.culture_trait_list.size() == 12, "Base culture_trait_list must remain 12 for test_step1 compatibility")
	assert(am.plot_list.size() == 8, "Base plot_list must remain 8 for test_step1 compatibility")
	assert(am.build_order_list.size() == 9, "Base build_order_list must remain 9 for test_step1 compatibility")

	assert(am.ethos_trait_list.size() == 4, "Expected 4 cultural ethos traits in dedicated list")
	assert(am.diplomacy_plot_list.size() == 4, "Expected 4 diplomacy plots in dedicated list")
	assert(am.expedition_order_list.size() == 1, "Expected 1 expedition order in dedicated list")

	assert(am.get_all_culture_traits().size() == 16, "Composite get_all_culture_traits() must return 16")
	assert(am.get_all_plots().size() == 12, "Composite get_all_plots() must return 12")
	assert(am.get_all_build_orders().size() == 10, "Composite get_all_build_orders() must return 10")
	assert(am.get_all_ethos_traits().size() == 4, "get_all_ethos_traits() must return 4")

	# Проверка доступности через основные словари
	assert(am.culture_traits.has("ethos_expansionist"), "ethos_expansionist must be in culture_traits map")
	assert(am.culture_traits.has("ethos_scientific"), "ethos_scientific must be in culture_traits map")
	assert(am.culture_traits.has("ethos_xenophile"), "ethos_xenophile must be in culture_traits map")
	assert(am.culture_traits.has("ethos_militarist"), "ethos_militarist must be in culture_traits map")

	assert(am.plots.has("plot_war_mobilization"), "plot_war_mobilization must be in plots map")
	assert(am.plots.has("plot_peace_accord"), "plot_peace_accord must be in plots map")
	assert(am.plots.has("plot_alliance_federation"), "plot_alliance_federation must be in plots map")
	assert(am.plots.has("plot_trade_route_pact"), "plot_trade_route_pact must be in plots map")

	assert(am.build_orders.has("order_colony_ship"), "order_colony_ship must be in build_orders map")
	var colony_bo: SandboxAssetScript.BuildOrderAsset = am.build_orders["order_colony_ship"]
	assert(colony_bo.is_colony_expedition == true, "order_colony_ship must have is_colony_expedition == true")
	print(" -> Dual-indexing assertions PASSED!")

	# 2. Инициализация симуляции и проверка внутренней структуры полисов (F1)
	print("[2/6] Verifying Polis Internal Organization & Ethos (F1)...")
	var sim := WorldSimulation.new()
	root.add_child(sim)
	await process_frame

	sim.setup_world(4242)
	assert(sim.cities_map.size() >= 2, "Expected at least 2 cradle cities after setup")

	var city_ids := sim.cities_map.keys()
	var c0: Dictionary = sim.cities_map[city_ids[0]]
	var c1: Dictionary = sim.cities_map[city_ids[1]]

	assert(c0.has("ethos_id") and c0["ethos_id"] != "", "City must have an assigned ethos_id")
	assert(c0.has("council") and not (c0["council"] as Dictionary).is_empty(), "City must have council metadata")
	assert(float(c0.get("internal_cohesion", 0.0)) > 0.5, "City must have positive internal cohesion")
	assert(c0.has("active_diplomatic_plot_id"), "City must have parallel active_diplomatic_plot_id slot")
	print(" -> Polis internal org & ethos PASSED!")

	# 3. Проверка матрицы мнений и дипломатических сигналов (F2)
	print("[3/6] Verifying Opinion Calculation & Diplomatic Status Transitions (F2)...")
	var rel := sim.get_diplomacy_relation(int(c0["id"]), int(c1["id"]))
	assert(not rel.is_empty(), "Bilateral relation between cradle cities must exist")

	var op_0_1: float = sim._calculate_opinion(c0, c1)
	assert(op_0_1 >= -100.0 and op_0_1 <= 100.0, "Opinion must be clamped in [-100, 100]")

	var test_state := {
		"rel_changed": false,
		"old_st": "",
		"new_st": "",
		"trade_established": false,
		"trade_yield": 0.0,
		"actor_damaged": false,
		"bldg_damaged": false,
		"expedition_launched": false,
		"colony_founded": false,
		"daughter_id": -1
	}

	sim.diplomacy_relation_changed.connect(func(a_id, b_id, old_st, new_st):
		test_state["rel_changed"] = true
		test_state["old_st"] = old_st
		test_state["new_st"] = new_st
	)

	sim.trade_route_established.connect(func(a_id, b_id, yield_v):
		test_state["trade_established"] = true
		test_state["trade_yield"] = yield_v
	)

	# Переход в TRADE
	sim.set_diplomacy_status(int(c0["id"]), int(c1["id"]), "TRADE")
	assert(bool(test_state["rel_changed"]) == true, "diplomacy_relation_changed signal must fire")
	assert(str(test_state["new_st"]) == "TRADE", "New status must be TRADE")
	assert(bool(test_state["trade_established"]) == true, "trade_route_established signal must fire on TRADE")

	var op_trade: float = sim._calculate_opinion(c0, c1)
	assert(op_trade > op_0_1, "TRADE status must improve opinion compared to NEUTRAL")

	# Переход в ALLIANCE
	sim.set_diplomacy_status(int(c0["id"]), int(c1["id"]), "ALLIANCE")
	var op_ally: float = sim._calculate_opinion(c0, c1)
	assert(op_ally > op_trade, "ALLIANCE status must yield higher opinion than TRADE")

	# Переход в WAR
	sim.set_diplomacy_status(int(c0["id"]), int(c1["id"]), "WAR")
	var op_war: float = sim._calculate_opinion(c0, c1)
	assert(op_war < 0.0, "WAR status must significantly degrade opinion")
	print(" -> Diplomatic relations & opinion formulas PASSED!")

	# 4. Проверка боевых действий, урона и пограничных рейдов (F2)
	print("[4/6] Verifying Actor Combat, Damage & Border Raids during War...")
	sim.actor_damaged_or_killed.connect(func(a_id, k_id, cause):
		test_state["actor_damaged"] = true
	)
	sim.building_damaged_or_destroyed.connect(func(city_id, b_id, destroyed):
		test_state["bldg_damaged"] = true
	)

	# Спавним двух противостоящих воинов в непосредственной близости
	var warrior_a := sim._spawn_actor_unit(int(c0["subspecies_id"]), int(c0["center_tile"]), int(c0["id"]), "warrior")
	var warrior_b := sim._spawn_actor_unit(int(c1["subspecies_id"]), int(c0["center_tile"]), int(c1["id"]), "warrior")
	warrior_a["pos"] = Vector2(500.0, 500.0)
	warrior_b["pos"] = Vector2(508.0, 504.0)

	sim._step_actor_combat(1.0)
	assert(bool(test_state["actor_damaged"]) == true, "actor_damaged_or_killed signal must fire when warring actors clash")

	# Проверяем набег на пограничные постройки
	warrior_a["home_tile"] = int(c1["center_tile"])
	warrior_a["hp"] = 300
	for _r in range(40):
		sim._step_actor_combat(0.5)
		if bool(test_state["bldg_damaged"]):
			break
	assert(bool(test_state["bldg_damaged"]) == true, "building_damaged_or_destroyed signal must fire on border raid")
	print(" -> Combat, damage and border raids PASSED!")

	# 5. Проверка межполисной торговли и параллельных дипломатических замыслов
	print("[5/6] Verifying Trade Yields & Parallel Diplomatic Plots...")
	sim.set_diplomacy_status(int(c0["id"]), int(c1["id"]), "TRADE")
	var matter_before: float = sim.matter_stock
	var energy_before: float = sim.energy_gw

	# Запускаем симуляцию дипломатического тика
	sim._tick_city_diplomacy(2.0)
	assert(sim.matter_stock > matter_before, "Trade route must generate matter stock")
	assert(sim.energy_gw > energy_before, "Trade route must generate energy GW")

	# Проверяем запуск дипломатического замысла без помехи научным замыслам
	c0["active_diplomatic_plot_id"] = -1
	sim._try_start_diplomatic_plot(c0, c1, "plot_alliance_federation")
	var dp_id: int = int(c0["active_diplomatic_plot_id"])
	assert(dp_id != -1, "City must start diplomatic plot")
	assert(sim.active_plots.has(dp_id), "Diplomatic plot must be registered in active_plots")
	assert(sim.active_plots[dp_id]["plot_type"] == "diplomacy", "Plot type must be 'diplomacy'")

	# Завершаем замысел альянса
	sim.active_plots[dp_id]["progress"] = 999.0
	sim._step_diplomatic_plots(0.5)
	assert(int(c0["active_diplomatic_plot_id"]) == -1, "Diplomatic plot must clear upon resolution")
	var rel_after_plot := sim.get_diplomacy_relation(int(c0["id"]), int(c1["id"]))
	assert(rel_after_plot.get("status") == "ALLIANCE", "Plot resolution must set status to ALLIANCE")
	print(" -> Trade yields and parallel diplomatic plots PASSED!")

	# 6. Проверка меж островной колонизации и инспекционных методов (F3, PROJECT.md)
	print("[6/6] Verifying Inter-Island Colonization & Inspection Contracts (F3)...")
	sim.colony_expedition_launched.connect(func(m_id, f_pos, t_pos):
		test_state["expedition_launched"] = true
	)
	sim.colony_founded.connect(func(d_id, m_id, c_name, pos):
		test_state["colony_founded"] = true
		test_state["daughter_id"] = d_id
	)

	var target_tile: int = sim._find_best_colony_tile(c0)
	assert(target_tile != -1, "CityPlaceFinder must locate suitable uncolonized coastal tile")

	sim._launch_colonist_expedition(c0, target_tile)
	assert(bool(test_state["expedition_launched"]) == true, "colony_expedition_launched signal must fire")

	# Основываем дочерний полис
	var d_id: int = sim._found_daughter_city(int(c0["id"]), target_tile, int(c0["subspecies_id"]), int(c0["culture_id"]))
	assert(bool(test_state["colony_founded"]) == true, "colony_founded signal must fire")
	assert(sim.cities_map.has(d_id), "New daughter city must exist in cities_map")

	var d_city: Dictionary = sim.cities_map[d_id]
	assert(int(d_city.get("parent_city_id", -1)) == int(c0["id"]), "Daughter city must reference mother city")
	assert(str(d_city.get("ethos_id", "")) == str(c0.get("ethos_id", "")), "Daughter city must inherit mother ethos")

	var mother_daughter_rel := sim.get_diplomacy_relation(int(c0["id"]), d_id)
	assert(mother_daughter_rel.get("status") == "ALLIANCE", "Daughter city must form permanent ALLIANCE with mother")

	# Проверяем интерфейсные методы инспекции
	var city_details: Dictionary = sim.get_detailed_city_data(int(c0["id"]))
	assert(not city_details.is_empty(), "get_detailed_city_data must return populated dict")
	assert(city_details.has("relations") and not (city_details["relations"] as Dictionary).is_empty(), "City details must include relations matrix")
	assert(city_details.has("ethos_id"), "City details must include ethos_id")
	assert(city_details.has("council"), "City details must include council")

	var actor_to_inspect: int = int(warrior_a["id"]) if not sim.get_detailed_actor_data(int(warrior_a["id"])).is_empty() else int(sim.actors[0]["id"])
	var actor_details: Dictionary = sim.get_detailed_actor_data(actor_to_inspect)
	assert(not actor_details.is_empty(), "get_detailed_actor_data must return populated dict")
	assert(actor_details.has("role") and actor_details.has("thought"), "Actor details must contain role and thought")

	var world_metrics: Dictionary = sim.get_global_world_metrics()
	assert(not world_metrics.is_empty(), "get_global_world_metrics must return populated dict")
	assert(world_metrics.has("active_alliances_count"), "Global metrics must include active_alliances_count")
	assert(world_metrics.has("total_cities") and int(world_metrics["total_cities"]) >= 3, "Global metrics total_cities must reflect new colony")
	print(" -> Colonization lifecycle and inspection contracts PASSED!")

	sim.free()
	print("=== ALL MILESTONE 1 CHECKS PASSED (FAILED: 0) ===")
	quit(0)
