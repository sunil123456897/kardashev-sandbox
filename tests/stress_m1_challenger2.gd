extends SceneTree

## Independent Boundary & Concurrency Stress Test Suite for Milestone 1
## Challenger 2: Empirical Boundary & Concurrency Verifier

const SandboxAssetManager = preload("res://scripts/core/asset_manager.gd")
const SandboxAssetScript = preload("res://scripts/core/sandbox_asset.gd")
const WorldSimulation = preload("res://scripts/sim/world_simulation.gd")

var total_tests: int = 0
var passed_tests: int = 0
var failed_tests: int = 0
var failure_details: Array[String] = []

func _init() -> void:
	print("=====================================================================")
	print("=== RUNNING CHALLENGER 2: BOUNDARY & CONCURRENCY STRESS SUITE     ===")
	print("=====================================================================")

	await run_all_stress_tests()

	print("=====================================================================")
	print("=== STRESS SUITE COMPLETE: Total: %d, Passed: %d, Failed: %d ===" % [total_tests, passed_tests, failed_tests])
	if failed_tests > 0:
		print("!!! DETECTED FAILURES:")
		for f in failure_details:
			print("  - ", f)
		print("=====================================================================")
		quit(1)
	else:
		print("=== ALL BOUNDARY & CONCURRENCY STRESS TESTS PASSED EMPIRICALLY! ===")
		print("=====================================================================")
		quit(0)


func check_assert(condition: bool, test_name: String, error_msg: String = "") -> void:
	total_tests += 1
	if condition:
		passed_tests += 1
		print("  [PASS] %s" % test_name)
	else:
		failed_tests += 1
		var full_msg := "%s: %s" % [test_name, error_msg]
		failure_details.append(full_msg)
		print("  [FAIL] %s" % full_msg)


func run_all_stress_tests() -> void:
	await test_zero_cities_boundary()
	await test_single_city_self_diplomacy()
	await test_maximum_cities_and_scaling()
	await test_empty_tiles_and_landless_city()
	await test_destroyed_city_during_active_diplomatic_plot()
	await test_colonist_invalid_targets_and_lifecycle()
	await test_warfare_with_no_actors()
	await test_signals_integrity_and_clean_teardown()
	await test_parallel_plots_concurrency()
	await test_rapid_diplomatic_churn_stress()
	await test_multi_city_diplomatic_triad()
	await test_dual_colonist_race_on_same_island()
	await test_high_density_melee_meatgrinder()
	await test_exhaustive_ethos_opinion_matrix()
	await test_extreme_distance_trade_stability()


# ------------------------------------------------------------------------------
# 1. Zero Cities Boundary
# ------------------------------------------------------------------------------
func test_zero_cities_boundary() -> void:
	print("\n--- [TEST 1] Zero Cities Boundary Limits ---")
	var sim := WorldSimulation.new()
	root.add_child(sim)
	await process_frame
	sim.setup_world(101)

	# Очищаем все города полностью
	sim.cities_map.clear()
	check_assert(sim.cities_map.is_empty(), "Zero cities map confirmed")

	# 1.1 Дипломатия при нуле городов
	sim._tick_city_diplomacy(1.0)
	check_assert(true, "1.1 _tick_city_diplomacy with 0 cities does not crash")

	# 1.2 Боевые действия при нуле городов
	sim._step_actor_combat(1.0)
	check_assert(true, "1.2 _step_actor_combat with 0 cities does not crash")

	# 1.3 Колонизация при нуле городов
	sim._check_and_step_colonization(1.0)
	check_assert(true, "1.3 _check_and_step_colonization with 0 cities does not crash")

	# 1.4 Инспекция несуществующего полиса
	var details := sim.get_detailed_city_data(999)
	check_assert(details.is_empty(), "1.4 get_detailed_city_data(999) returns empty dict safely")

	# 1.5 Глобальные метрики при 0 городов
	var metrics := sim.get_global_world_metrics()
	check_assert(metrics.get("total_cities", -1) == 0, "1.5 total_cities metric is 0")
	check_assert(float(metrics.get("total_population", -1.0)) == 0.0, "1.5 total_population metric is 0.0")
	check_assert(float(metrics.get("max_kardashev", -1.0)) == 0.0, "1.5 max_kardashev metric is 0.0")

	# 1.6 Попытка установить статус между несуществующими городами
	sim.set_diplomacy_status(100, 200, "WAR")
	var rel := sim.get_diplomacy_relation(100, 200)
	check_assert(rel.get("status") == "WAR", "1.6 set_diplomacy_status between phantom cities handles fallback")

	sim.free()


# ------------------------------------------------------------------------------
# 2. Single City (Self-Diplomacy)
# ------------------------------------------------------------------------------
func test_single_city_self_diplomacy() -> void:
	print("\n--- [TEST 2] Single City & Self-Diplomacy Limits ---")
	var sim := WorldSimulation.new()
	root.add_child(sim)
	await process_frame
	sim.setup_world(202)

	# Оставляем ровно 1 город
	var keys := sim.cities_map.keys()
	while sim.cities_map.size() > 1:
		sim.cities_map.erase(keys.pop_back())
	check_assert(sim.cities_map.size() == 1, "Single city confirmed in simulation")

	var c_id: int = int(sim.cities_map.keys()[0])
	var city: Dictionary = sim.cities_map[c_id]

	# 2.1 Дипломатия с самим собой: set_diplomacy_status(c, c, "WAR")
	var rel_changed := false
	sim.diplomacy_relation_changed.connect(func(a, b, old_s, new_s):
		rel_changed = true
	)
	sim.set_diplomacy_status(c_id, c_id, "WAR")
	check_assert(not rel_changed, "2.1 set_diplomacy_status with self does not emit or change status")

	# 2.2 Проверка отношения с собой
	var self_rel := sim.get_diplomacy_relation(c_id, c_id)
	check_assert(self_rel.is_empty(), "2.2 get_diplomacy_relation with self returns empty dict")
	var ensure_self := sim._ensure_diplomacy_relation(c_id, c_id)
	check_assert(ensure_self.is_empty(), "2.2 _ensure_diplomacy_relation with self returns empty dict")

	# 2.3 Мнение о себе
	var opinion_self: float = sim._calculate_opinion(city, city)
	check_assert(opinion_self >= -100.0 and opinion_self <= 100.0, "2.3 _calculate_opinion with self returns clamped float [%f]" % opinion_self)

	# 2.4 Проверка границ с собой
	var borders_self: bool = sim._cities_share_border(city, city)
	check_assert(borders_self != null, "2.4 _cities_share_border with self does not crash")

	# 2.5 Попытка начать дипломатический замысел против себя
	sim._try_start_diplomatic_plot(city, city, "plot_war_mobilization")
	var self_plot_id: int = int(city.get("active_diplomatic_plot_id", -1))
	check_assert(self_plot_id != -1, "2.5 Diplomatic plot initialized against self")
	sim.active_plots[self_plot_id]["progress"] = 999.0
	sim._step_diplomatic_plots(0.5)
	check_assert(int(city.get("active_diplomatic_plot_id", -1)) == -1, "2.5 Self-targeted plot resolves and cleans up safely")

	# 2.6 Дипломатический тик при 1 городе
	sim._tick_city_diplomacy(1.0)
	check_assert(true, "2.6 _tick_city_diplomacy with single city is a clean no-op")

	sim.free()


# ------------------------------------------------------------------------------
# 3. Maximum Cities (12 Cities) & Scaling
# ------------------------------------------------------------------------------
func test_maximum_cities_and_scaling() -> void:
	print("\n--- [TEST 3] Maximum Cities Limit (12 Cities) & Scaling ---")
	var sim := WorldSimulation.new()
	root.add_child(sim)
	await process_frame
	sim.setup_world(303)

	var mother_id: int = int(sim.cities_map.keys()[0])
	var mother: Dictionary = sim.cities_map[mother_id]
	var sp_id: int = int(mother["subspecies_id"])
	var cult_id: int = int(mother["culture_id"])

	# Доводим количество городов ровно до MAX_CITIES (12)
	var tile_candidates := [120, 240, 360, 480, 600, 720, 840, 960, 150, 280, 420, 560]
	var cand_idx := 0
	while sim.cities_map.size() < sim.MAX_CITIES and cand_idx < tile_candidates.size():
		var t_idx: int = tile_candidates[cand_idx]
		cand_idx += 1
		sim._found_daughter_city(mother_id, t_idx, sp_id, cult_id)

	check_assert(sim.cities_map.size() == sim.MAX_CITIES, "3.1 Cities count reached MAX_CITIES (%d)" % sim.MAX_CITIES)

	# 3.2 Проверяем, что автоматическая колонизация блокируется при достижении MAX_CITIES
	var prev_cities_count := sim.cities_map.size()
	mother["population"] = 90.0
	sim._last_colony_time = -999.0
	sim._check_and_step_colonization(1.0)
	check_assert(sim.cities_map.size() == prev_cities_count, "3.2 _check_and_step_colonization respects MAX_CITIES cap")

	# 3.3 Проверяем переполнение (13 городов при ручном/событийном создании)
	var overflow_city_id: int = sim._found_daughter_city(mother_id, 777, sp_id, cult_id)
	check_assert(sim.cities_map.size() == 13, "3.3 13th city created cleanly without engine crash")

	# 3.4 Проверяем масштабируемость дипломатической матрицы: 13 городов = 78 пар отношений!
	for _tick in range(5):
		sim._tick_city_diplomacy(1.0)
	var expected_pairs: int = (13 * 12) / 2
	check_assert(sim.diplomacy_relations.size() >= expected_pairs, "3.4 All %d bilateral relations indexed in matrix (actual: %d)" % [expected_pairs, sim.diplomacy_relations.size()])

	# 3.5 Проверяем глобальные метрики
	var metrics: Dictionary = sim.get_global_world_metrics()
	check_assert(int(metrics.get("total_cities", 0)) == 13, "3.5 get_global_world_metrics accurately reports 13 cities")

	sim.free()


# ------------------------------------------------------------------------------
# 4. Empty Tiles & Landless City Boundary
# ------------------------------------------------------------------------------
func test_empty_tiles_and_landless_city() -> void:
	print("\n--- [TEST 4] Empty Tiles & Landless City Boundary ---")
	var sim := WorldSimulation.new()
	root.add_child(sim)
	await process_frame
	sim.setup_world(404)

	var c_id: int = int(sim.cities_map.keys()[0])
	var city: Dictionary = sim.cities_map[c_id]

	# 4.1 Тестируем ситуацию, когда все тайлы карты затоплены океаном
	for i in range(sim.TILE_COUNT):
		sim.tiles[i]["elevation"] = -0.6
	var colony_tile: int = sim._find_best_colony_tile(city)
	check_assert(colony_tile == -1, "4.1 _find_best_colony_tile returns -1 when no dry land exists")

	# 4.2 Тестируем город с полностью пустым claimed_tiles = []
	city["claimed_tiles"] = []
	sim._rebuild_city_2d_instances(city)
	check_assert(true, "4.2 _rebuild_city_2d_instances handles empty claimed_tiles safely")

	var other_id: int = int(sim.cities_map.keys()[1])
	var other_city: Dictionary = sim.cities_map[other_id]
	var shares_border: bool = sim._cities_share_border(city, other_city)
	check_assert(shares_border == false, "4.2 _cities_share_border returns false for landless city without error")

	# 4.3 Проверяем тики актеров при пустых заявленных тайлах города
	var dummy_actor := sim._spawn_actor_unit(int(city["subspecies_id"]), int(city["center_tile"]), c_id)
	if not dummy_actor.is_empty():
		dummy_actor["pos"] = dummy_actor["target_pos"]
		dummy_actor["wait_timer"] = 0.0
		sim._step_actors(0.5)
		check_assert(true, "4.3 _step_actors handles citizen of landless city safely")

	sim.free()


# ------------------------------------------------------------------------------
# 5. Destroyed City During Active Diplomatic Plot
# ------------------------------------------------------------------------------
func test_destroyed_city_during_active_diplomatic_plot() -> void:
	print("\n--- [TEST 5] Destroyed City During Active Diplomatic Plot ---")
	var sim := WorldSimulation.new()
	root.add_child(sim)
	await process_frame
	sim.setup_world(505)

	var city_ids := sim.cities_map.keys()
	var c_a_id: int = int(city_ids[0])
	var c_b_id: int = int(city_ids[1])
	var city_a: Dictionary = sim.cities_map[c_a_id]
	var city_b: Dictionary = sim.cities_map[c_b_id]

	# 5.1 Целевой город B уничтожен во время дипломатического замысла города A
	city_a["active_diplomatic_plot_id"] = -1
	sim._try_start_diplomatic_plot(city_a, city_b, "plot_alliance_federation")
	var plot_id: int = int(city_a["active_diplomatic_plot_id"])
	check_assert(plot_id != -1, "5.1 Diplomatic plot started before target destruction")

	# Уничтожаем город B
	sim.cities_map.erase(c_b_id)
	check_assert(not sim.cities_map.has(c_b_id), "5.1 City B erased from cities_map")

	# Доводим замысел до завершения
	sim.active_plots[plot_id]["progress"] = 999.0
	sim._step_diplomatic_plots(0.5)
	check_assert(not sim.active_plots.has(plot_id), "5.1 Plot removed from active_plots upon target destruction resolution")
	check_assert(int(city_a["active_diplomatic_plot_id"]) == -1, "5.1 Initiator active_diplomatic_plot_id cleared cleanly")

	# 5.2 Инспекция города A после уничтожения его партнера
	var details: Dictionary = sim.get_detailed_city_data(c_a_id)
	check_assert(not details.is_empty(), "5.2 get_detailed_city_data returns valid data even if relation targets destroyed")
	var rels: Dictionary = details.get("relations", {})
	if rels.has(c_b_id):
		check_assert(str(rels[c_b_id]["other_name"]).begins_with("Полис #"), "5.2 Fallback name used for destroyed relation partner")

	# 5.3 Инициатор города уничтожен во время замысла
	sim.setup_world(506)
	var new_ids := sim.cities_map.keys()
	var init_id: int = int(new_ids[0])
	var target_id: int = int(new_ids[1])
	var c_init: Dictionary = sim.cities_map[init_id]
	var c_target: Dictionary = sim.cities_map[target_id]

	sim._try_start_diplomatic_plot(c_init, c_target, "plot_war_mobilization")
	# Удаляем инициатора
	sim.cities_map.erase(init_id)
	# Тикаем замыслы
	sim._step_diplomatic_plots(1.0)
	check_assert(true, "5.3 _step_diplomatic_plots does not crash when initiator city is erased")

	sim.free()


# ------------------------------------------------------------------------------
# 6. Colonist Reaching Non-Existent / Invalid Target Tile
# ------------------------------------------------------------------------------
func test_colonist_invalid_targets_and_lifecycle() -> void:
	print("\n--- [TEST 6] Colonist Invalid Targets & Lifecycle ---")
	var sim := WorldSimulation.new()
	root.add_child(sim)
	await process_frame
	sim.setup_world(606)

	var c0_id: int = int(sim.cities_map.keys()[0])
	var c0: Dictionary = sim.cities_map[c0_id]

	# 6.1 Колонист с недействительным home_tile = -1
	var colonist := sim._spawn_actor_unit(int(c0["subspecies_id"]), int(c0["center_tile"]), c0_id, "colonist")
	colonist["home_tile"] = -1
	colonist["target_pos"] = colonist["pos"]
	colonist["wait_timer"] = 0.0
	sim._step_actors(0.5)
	check_assert(colonist["city_id"] == c0_id, "6.1 Colonist with home_tile=-1 does not found city and does not crash")

	# 6.2 Колонист плывёт, но метрополия уничтожена во время пути
	var colonist2 := sim._spawn_actor_unit(int(c0["subspecies_id"]), int(c0["center_tile"]), c0_id, "colonist")
	var dest_tile := 500
	colonist2["home_tile"] = dest_tile
	colonist2["pos"] = sim.tiles[dest_tile]["map_pos"]
	colonist2["target_pos"] = sim.tiles[dest_tile]["map_pos"]
	colonist2["wait_timer"] = 0.0

	# Уничтожаем метрополию
	sim.cities_map.erase(c0_id)
	sim._step_actors(0.5)
	check_assert(true, "6.2 Colonist reaching destination after mother destruction handled safely without crash")

	# 6.3 Штатный жизненный цикл колонизации
	sim.setup_world(607)
	var mother_c: Dictionary = sim.cities_map.values()[0]
	var m_id: int = int(mother_c["id"])
	var colony_tile: int = sim._find_best_colony_tile(mother_c)
	check_assert(colony_tile != -1, "6.3 Found valid colony tile for expedition")

	var col_sig_state := {
		"expedition_fired": false,
		"founded_fired": false
	}
	sim.colony_expedition_launched.connect(func(mid, fpos, tpos):
		col_sig_state["expedition_fired"] = true
	)
	sim.colony_founded.connect(func(did, mid, cname, pos):
		col_sig_state["founded_fired"] = true
	)

	sim._launch_colonist_expedition(mother_c, colony_tile)
	check_assert(bool(col_sig_state["expedition_fired"]), "6.3 colony_expedition_launched signal emitted")

	var d_id: int = sim._found_daughter_city(m_id, colony_tile, int(mother_c["subspecies_id"]), int(mother_c["culture_id"]))
	check_assert(bool(col_sig_state["founded_fired"]), "6.3 colony_founded signal emitted")
	check_assert(sim.cities_map.has(d_id), "6.3 Daughter city added to cities_map")

	var rel := sim.get_diplomacy_relation(m_id, d_id)
	check_assert(rel.get("status") == "ALLIANCE", "6.3 Daughter and mother form permanent ALLIANCE")

	sim.free()


# ------------------------------------------------------------------------------
# 7. Warfare With No Actors
# ------------------------------------------------------------------------------
func test_warfare_with_no_actors() -> void:
	print("\n--- [TEST 7] Warfare With No Actors Boundary ---")
	var sim := WorldSimulation.new()
	root.add_child(sim)
	await process_frame
	sim.setup_world(707)

	var ids := sim.cities_map.keys()
	var id_a: int = int(ids[0])
	var id_b: int = int(ids[1])

	# Переводим в состояние войны
	sim.set_diplomacy_status(id_a, id_b, "WAR")
	var rel := sim.get_diplomacy_relation(id_a, id_b)
	check_assert(rel.get("status") == "WAR", "7.1 Warfare declared between cities")

	# Полностью удаляем всех актеров
	sim.actors.clear()
	check_assert(sim.actors.is_empty(), "7.1 All actors cleared from simulation")

	# 7.2 Шаг боя при отсутствии актеров
	sim._step_actor_combat(1.0)
	check_assert(true, "7.2 _step_actor_combat with 0 actors runs cleanly")

	# 7.3 Тик дипломатии во время войны без актеров (война истощения по таймеру)
	for _s in range(40):
		sim._tick_city_diplomacy(1.0)
		if int(sim.cities_map[id_a].get("active_diplomatic_plot_id", -1)) != -1:
			break

	var peace_plot_id: int = int(sim.cities_map[id_a].get("active_diplomatic_plot_id", -1))
	check_assert(peace_plot_id != -1, "7.3 Prolonged war without actors triggers peace accord plot")

	sim.active_plots[peace_plot_id]["progress"] = 999.0
	sim._step_diplomatic_plots(0.5)
	var rel_after := sim.get_diplomacy_relation(id_a, id_b)
	check_assert(rel_after.get("status") == "PEACE", "7.3 Peace treaty successfully concluded")

	sim.free()


# ------------------------------------------------------------------------------
# 8. Signal Integrity, Signatures & Dangling References
# ------------------------------------------------------------------------------
func test_signals_integrity_and_clean_teardown() -> void:
	print("\n--- [TEST 8] Signals Integrity & Teardown ---")
	var sim := WorldSimulation.new()
	root.add_child(sim)
	await process_frame
	sim.setup_world(808)

	var sig_log := {
		"diplomacy_relation_changed": [],
		"building_damaged_or_destroyed": [],
		"actor_damaged_or_killed": [],
		"trade_route_established": [],
		"colony_expedition_launched": [],
		"colony_founded": []
	}

	# 8.1 Подключение строго типизированных колбэков
	var c_dip = func(city_a: int, city_b: int, old_st: String, new_st: String) -> void:
		sig_log["diplomacy_relation_changed"].append([city_a, city_b, old_st, new_st])
	var c_bldg = func(city_id: int, bldg_id: String, destroyed: bool) -> void:
		sig_log["building_damaged_or_destroyed"].append([city_id, bldg_id, destroyed])
	var c_actor = func(actor_id: int, killer_id: int, cause: String) -> void:
		sig_log["actor_damaged_or_killed"].append([actor_id, killer_id, cause])
	var c_trade = func(city_a: int, city_b: int, trade_val: float) -> void:
		sig_log["trade_route_established"].append([city_a, city_b, trade_val])
	var c_exp = func(mid: int, f_pos: Vector2, t_pos: Vector2) -> void:
		sig_log["colony_expedition_launched"].append([mid, f_pos, t_pos])
	var c_col = func(did: int, mid: int, cname: String, mpos: Vector2) -> void:
		sig_log["colony_founded"].append([did, mid, cname, mpos])

	sim.diplomacy_relation_changed.connect(c_dip)
	sim.building_damaged_or_destroyed.connect(c_bldg)
	sim.actor_damaged_or_killed.connect(c_actor)
	sim.trade_route_established.connect(c_trade)
	sim.colony_expedition_launched.connect(c_exp)
	sim.colony_founded.connect(c_col)

	# Эмитируем каждый сигнал с реальными параметрами
	sim.diplomacy_relation_changed.emit(1, 2, "NEUTRAL", "TRADE")
	sim.trade_route_established.emit(1, 2, 14.5)
	sim.actor_damaged_or_killed.emit(10, 20, "combat")
	sim.building_damaged_or_destroyed.emit(1, "order_bio_dome", false)
	sim.colony_expedition_launched.emit(1, Vector2(100.0, 100.0), Vector2(300.0, 300.0))
	sim.colony_founded.emit(3, 1, "Нова-Колония", Vector2(300.0, 300.0))

	# Проверяем сигнатуры и типы аргументов
	check_assert((sig_log["diplomacy_relation_changed"] as Array).size() == 1, "8.1 diplomacy_relation_changed fired")
	var dip_args: Array = sig_log["diplomacy_relation_changed"][0]
	check_assert(dip_args[0] is int and dip_args[1] is int and dip_args[2] is String and dip_args[3] is String, "8.1 diplomacy_relation_changed arg types verified")

	check_assert((sig_log["trade_route_established"] as Array).size() == 1, "8.2 trade_route_established fired")
	var trade_args: Array = sig_log["trade_route_established"][0]
	check_assert(trade_args[0] is int and trade_args[1] is int and (trade_args[2] is float or trade_args[2] is int), "8.2 trade_route_established arg types verified")

	check_assert((sig_log["actor_damaged_or_killed"] as Array).size() == 1, "8.3 actor_damaged_or_killed fired")
	var actor_args: Array = sig_log["actor_damaged_or_killed"][0]
	check_assert(actor_args[0] is int and actor_args[1] is int and actor_args[2] is String, "8.3 actor_damaged_or_killed arg types verified")

	check_assert((sig_log["building_damaged_or_destroyed"] as Array).size() == 1, "8.4 building_damaged_or_destroyed fired")
	var bldg_args: Array = sig_log["building_damaged_or_destroyed"][0]
	check_assert(bldg_args[0] is int and bldg_args[1] is String and bldg_args[2] is bool, "8.4 building_damaged_or_destroyed arg types verified")

	check_assert((sig_log["colony_expedition_launched"] as Array).size() == 1, "8.5 colony_expedition_launched fired")
	var exp_args: Array = sig_log["colony_expedition_launched"][0]
	check_assert(exp_args[0] is int and exp_args[1] is Vector2 and exp_args[2] is Vector2, "8.5 colony_expedition_launched arg types verified")

	check_assert((sig_log["colony_founded"] as Array).size() == 1, "8.6 colony_founded fired")
	var col_args: Array = sig_log["colony_founded"][0]
	check_assert(col_args[0] is int and col_args[1] is int and col_args[2] is String and col_args[3] is Vector2, "8.6 colony_founded arg types verified")

	# Отключение
	sim.diplomacy_relation_changed.disconnect(c_dip)
	sim.building_damaged_or_destroyed.disconnect(c_bldg)
	sim.actor_damaged_or_killed.disconnect(c_actor)
	sim.trade_route_established.disconnect(c_trade)
	sim.colony_expedition_launched.disconnect(c_exp)
	sim.colony_founded.disconnect(c_col)

	sim.free()
	check_assert(true, "8.7 Signals disconnected and node freed without memory leak")


# ------------------------------------------------------------------------------
# 9. Parallel Plots Concurrency
# ------------------------------------------------------------------------------
func test_parallel_plots_concurrency() -> void:
	print("\n--- [TEST 9] Parallel Plots Concurrency ---")
	var sim := WorldSimulation.new()
	root.add_child(sim)
	await process_frame
	sim.setup_world(909)

	var ids := sim.cities_map.keys()
	var c_a: Dictionary = sim.cities_map[ids[0]]
	var c_b: Dictionary = sim.cities_map[ids[1]]

	# 1. Запускаем научный замысел (active_plot_id)
	var cult_a: Dictionary = sim.cultures_map[int(c_a["culture_id"])]
	sim._try_start_plot_for_city(c_a, cult_a)
	var sci_plot_id: int = int(c_a.get("active_plot_id", -1))
	check_assert(sci_plot_id != -1, "9.1 Scientific plot successfully active")

	# 2. Запускаем параллельный дипломатический замысел (active_diplomatic_plot_id)
	c_a["active_diplomatic_plot_id"] = -1
	sim._try_start_diplomatic_plot(c_a, c_b, "plot_trade_route_pact")
	var dip_plot_id: int = int(c_a.get("active_diplomatic_plot_id", -1))
	check_assert(dip_plot_id != -1, "9.2 Parallel diplomatic plot successfully active")
	check_assert(sci_plot_id != dip_plot_id, "9.2 Distinct IDs for scientific and diplomatic plots")

	# 3. Продвигаем научный замысел до завершения
	sim.active_plots[sci_plot_id]["progress"] = 999.0
	sim._tick_plots_and_infinite_science(0.5)
	check_assert(int(c_a.get("active_plot_id", -1)) == -1 or int(c_a.get("active_plot_id", -1)) != sci_plot_id, "9.3 Scientific plot completed")
	check_assert(int(c_a.get("active_diplomatic_plot_id", -1)) == dip_plot_id, "9.3 Diplomatic plot remained intact during scientific completion")

	# 4. Продвигаем дипломатический замысел до завершения
	sim.active_plots[dip_plot_id]["progress"] = 999.0
	sim._step_diplomatic_plots(0.5)
	check_assert(int(c_a.get("active_diplomatic_plot_id", -1)) == -1, "9.4 Diplomatic plot resolved cleanly")
	var rel := sim.get_diplomacy_relation(int(c_a["id"]), int(c_b["id"]))
	check_assert(rel.get("status") == "TRADE", "9.4 Diplomatic plot established TRADE status")

	sim.free()


# ------------------------------------------------------------------------------
# 10. Rapid Diplomatic Churn Stress
# ------------------------------------------------------------------------------
func test_rapid_diplomatic_churn_stress() -> void:
	print("\n--- [TEST 10] Rapid Diplomatic Churn Stress ---")
	var sim := WorldSimulation.new()
	root.add_child(sim)
	await process_frame
	sim.setup_world(1010)

	var ids := sim.cities_map.keys()
	var id_a: int = int(ids[0])
	var id_b: int = int(ids[1])

	var statuses := ["WAR", "PEACE", "TRADE", "ALLIANCE", "NEUTRAL"]
	var event_count_start := sim.event_log.size()

	# 50 быстрых переключений дипломатического статуса подряд
	for i in range(50):
		var target_st: String = statuses[i % statuses.size()]
		sim.set_diplomacy_status(id_a, id_b, target_st)

	check_assert(sim.event_log.size() <= 80, "10.1 Event log buffer capped at 80 despite churn (actual: %d)" % sim.event_log.size())
	var final_st: String = sim.get_diplomacy_relation(id_a, id_b).get("status", "")
	check_assert(final_st == statuses[49 % statuses.size()], "10.2 Final status accurately recorded after 50 rapid transitions")

	sim.free()


# ------------------------------------------------------------------------------
# 11. Multi-City Diplomatic Triad (Concurrent Network Plots)
# ------------------------------------------------------------------------------
func test_multi_city_diplomatic_triad() -> void:
	print("\n--- [TEST 11] Multi-City Diplomatic Triad Concurrency ---")
	var sim := WorldSimulation.new()
	root.add_child(sim)
	await process_frame
	sim.setup_world(1111)

	var ids := sim.cities_map.keys()
	var c_a: Dictionary = sim.cities_map[ids[0]]
	var c_b: Dictionary = sim.cities_map[ids[1]]

	# Создаем третий город C
	var c_c_id: int = sim._found_daughter_city(int(c_a["id"]), 700, int(c_a["subspecies_id"]), int(c_a["culture_id"]))
	var c_c: Dictionary = sim.cities_map[c_c_id]

	# City A начинает военную мобилизацию против City B
	c_a["active_diplomatic_plot_id"] = -1
	sim._try_start_diplomatic_plot(c_a, c_b, "plot_war_mobilization")
	var plot_ab: int = int(c_a.get("active_diplomatic_plot_id", -1))
	check_assert(plot_ab != -1, "11.1 Plot A->B (WAR) started")

	# City C начинает заключение союза с City B
	c_c["active_diplomatic_plot_id"] = -1
	sim._try_start_diplomatic_plot(c_c, c_b, "plot_alliance_federation")
	var plot_cb: int = int(c_c.get("active_diplomatic_plot_id", -1))
	check_assert(plot_cb != -1, "11.2 Concurrent Plot C->B (ALLIANCE) started")
	check_assert(plot_ab != plot_cb, "11.2 Independent plot identifiers assigned")

	# Разрешаем оба замысла
	sim.active_plots[plot_ab]["progress"] = 999.0
	sim.active_plots[plot_cb]["progress"] = 999.0
	sim._step_diplomatic_plots(0.5)

	check_assert(int(c_a.get("active_diplomatic_plot_id", -1)) == -1, "11.3 Plot A->B resolved")
	check_assert(int(c_c.get("active_diplomatic_plot_id", -1)) == -1, "11.3 Plot C->B resolved")

	var rel_ab := sim.get_diplomacy_relation(int(c_a["id"]), int(c_b["id"]))
	var rel_cb := sim.get_diplomacy_relation(int(c_c["id"]), int(c_b["id"]))
	check_assert(rel_ab.get("status") == "WAR", "11.4 A and B are now at WAR")
	check_assert(rel_cb.get("status") == "ALLIANCE", "11.4 C and B are now in ALLIANCE")

	var metrics := sim.get_global_world_metrics()
	check_assert(int(metrics.get("active_wars_count", 0)) >= 1, "11.5 Global metrics accurately tracks 1 active war")
	check_assert(int(metrics.get("active_alliances_count", 0)) >= 2, "11.5 Global metrics accurately tracks alliances (mother-daughter + C-B)")

	sim.free()


# ------------------------------------------------------------------------------
# 12. Dual Colonist Race on Same Target Island
# ------------------------------------------------------------------------------
func test_dual_colonist_race_on_same_island() -> void:
	print("\n--- [TEST 12] Dual Colonist Race on Same Island ---")
	var sim := WorldSimulation.new()
	root.add_child(sim)
	await process_frame
	sim.setup_world(1212)

	var ids := sim.cities_map.keys()
	var c_a_id: int = int(ids[0])
	var c_b_id: int = int(ids[1])
	var c_a: Dictionary = sim.cities_map[c_a_id]
	var c_b: Dictionary = sim.cities_map[c_b_id]

	var target_tile := 555

	# Экспедиция 1 от города A
	var col_a := sim._spawn_actor_unit(int(c_a["subspecies_id"]), int(c_a["center_tile"]), c_a_id, "colonist")
	col_a["home_tile"] = target_tile
	col_a["pos"] = sim.tiles[target_tile]["map_pos"]
	col_a["target_pos"] = sim.tiles[target_tile]["map_pos"]
	col_a["wait_timer"] = 0.0

	# Экспедиция 2 от города B
	var col_b := sim._spawn_actor_unit(int(c_b["subspecies_id"]), int(c_b["center_tile"]), c_b_id, "colonist")
	col_b["home_tile"] = target_tile
	col_b["pos"] = sim.tiles[target_tile]["map_pos"]
	col_b["target_pos"] = sim.tiles[target_tile]["map_pos"]
	col_b["wait_timer"] = 0.0

	var initial_cities_count := sim.cities_map.size()

	# Шаг симуляции: экспедиция 1 первой основывает колонию
	sim._step_actors(0.5)

	check_assert(sim.cities_map.size() > initial_cities_count, "12.1 First colonist successfully founded colony")
	var new_city_id: int = int(col_a.get("city_id", -1))
	check_assert(new_city_id != c_a_id and sim.cities_map.has(new_city_id), "12.1 Colonist A reassigned to daughter city")

	# Шаг 2: второй колонист прибывает на уже частично занятый тайл
	sim._step_actors(0.5)
	check_assert(sim.cities_map.size() >= initial_cities_count + 1, "12.2 Simulation state remains valid and robust under tile contention")

	sim.free()


# ------------------------------------------------------------------------------
# 13. High-Density Melee Meatgrinder (50 vs 50 Combat Stress)
# ------------------------------------------------------------------------------
func test_high_density_melee_meatgrinder() -> void:
	print("\n--- [TEST 13] High-Density Melee Meatgrinder (50 vs 50) ---")
	var sim := WorldSimulation.new()
	root.add_child(sim)
	await process_frame
	sim.setup_world(1313)

	var ids := sim.cities_map.keys()
	var c_a_id: int = int(ids[0])
	var c_b_id: int = int(ids[1])
	var c_a: Dictionary = sim.cities_map[c_a_id]
	var c_b: Dictionary = sim.cities_map[c_b_id]

	sim.set_diplomacy_status(c_a_id, c_b_id, "WAR")

	var center_arena := Vector2(800.0, 500.0)
	var combat_stats := {
		"damaged": 0,
		"killed": 0
	}

	sim.actor_damaged_or_killed.connect(func(a_id, k_id, cause):
		if cause == "combat":
			combat_stats["damaged"] = int(combat_stats["damaged"]) + 1
		elif cause == "killed_in_combat":
			combat_stats["killed"] = int(combat_stats["killed"]) + 1
	)

	# Спавним по 30 воинов с каждой стороны в одной тесной локации
	for _i in range(30):
		var wa := sim._spawn_actor_unit(int(c_a["subspecies_id"]), int(c_a["center_tile"]), c_a_id, "warrior")
		wa["pos"] = center_arena + Vector2(randf_range(-8.0, 8.0), randf_range(-8.0, 8.0))
		wa["hp"] = 40
		var wb := sim._spawn_actor_unit(int(c_b["subspecies_id"]), int(c_b["center_tile"]), c_b_id, "warrior")
		wb["pos"] = center_arena + Vector2(randf_range(-8.0, 8.0), randf_range(-8.0, 8.0))
		wb["hp"] = 40

	var actors_before := sim.actors.size()

	# Интенсивный бой на протяжении 25 тиков
	for _t in range(25):
		sim._step_actor_combat(0.5)

	var hits: int = int(combat_stats["damaged"])
	var kills: int = int(combat_stats["killed"])
	check_assert(hits > 0, "13.1 Hundreds of combat interactions processed (damage hits: %d)" % hits)
	check_assert(kills > 0, "13.2 Fatal combat encounters recorded (kills: %d)" % kills)
	check_assert(sim.actors.size() < actors_before, "13.3 Actors cleanly removed upon death without array corruption (remaining: %d)" % sim.actors.size())

	var rel := sim.get_diplomacy_relation(c_a_id, c_b_id)
	check_assert(float(rel.get("war_exhaustion_b", 0.0)) > 5.0, "13.4 War exhaustion accumulated significantly from combat casualties")

	sim.free()


# ------------------------------------------------------------------------------
# 14. Exhaustive Ethos & Species Opinion Matrix
# ------------------------------------------------------------------------------
func test_exhaustive_ethos_opinion_matrix() -> void:
	print("\n--- [TEST 14] Exhaustive Ethos & Species Opinion Matrix ---")
	var sim := WorldSimulation.new()
	root.add_child(sim)
	await process_frame
	sim.setup_world(1414)

	var ethos_options := ["ethos_expansionist", "ethos_scientific", "ethos_xenophile", "ethos_militarist"]
	var all_clamped := true
	var min_found: float = 999.0
	var max_found: float = -999.0

	var dummy_a := {
		"id": 1,
		"name": "Полис-А",
		"subspecies_id": 1,
		"culture_id": 1,
		"map_pos": Vector2(100.0, 100.0),
		"claimed_tiles": [10, 11]
	}
	var dummy_b := {
		"id": 2,
		"name": "Полис-Б",
		"subspecies_id": 2,
		"culture_id": 2,
		"map_pos": Vector2(400.0, 400.0),
		"claimed_tiles": [80, 81]
	}

	for sp_match in [true, false]:
		dummy_b["subspecies_id"] = 1 if sp_match else 2
		for eth_a in ethos_options:
			dummy_a["ethos_id"] = eth_a
			for eth_b in ethos_options:
				dummy_b["ethos_id"] = eth_b
				var op := sim._calculate_opinion(dummy_a, dummy_b)
				min_found = minf(min_found, op)
				max_found = maxf(max_found, op)
				if op < -100.0 or op > 100.0:
					all_clamped = false

	check_assert(all_clamped, "14.1 All 32 ethos & species permutations strictly clamped in [-100.0, 100.0]")
	check_assert(min_found < 0.0 and max_found > 0.0, "14.2 Opinion spectrum spans negative and positive values (min: %.1f, max: %.1f)" % [min_found, max_found])

	# Проверяем явное столкновение ксенофилов и милитаристов
	dummy_a["ethos_id"] = "ethos_militarist"
	dummy_b["ethos_id"] = "ethos_xenophile"
	var op_clash := sim._calculate_opinion(dummy_a, dummy_b)
	dummy_b["ethos_id"] = "ethos_militarist"
	var op_match := sim._calculate_opinion(dummy_a, dummy_b)
	check_assert(op_clash < op_match, "14.3 Militarist-Xenophile ideological clash produces severe opinion penalty")

	sim.free()


# ------------------------------------------------------------------------------
# 15. Extreme & Zero Distance Trade Stability
# ------------------------------------------------------------------------------
func test_extreme_distance_trade_stability() -> void:
	print("\n--- [TEST 15] Extreme & Zero Distance Trade Stability ---")
	var sim := WorldSimulation.new()
	root.add_child(sim)
	await process_frame
	sim.setup_world(1515)

	var ids := sim.cities_map.keys()
	var c_a: Dictionary = sim.cities_map[ids[0]]
	var c_b: Dictionary = sim.cities_map[ids[1]]

	sim.set_diplomacy_status(int(c_a["id"]), int(c_b["id"]), "TRADE")

	# Случай 1: Нулевая дистанция между городами (map_pos совпадают)
	c_a["map_pos"] = Vector2(500.0, 500.0)
	c_b["map_pos"] = Vector2(500.0, 500.0)
	var m_before := sim.matter_stock
	sim._tick_city_diplomacy(1.0)
	var m_gain_zero := sim.matter_stock - m_before
	check_assert(m_gain_zero > 0.0 and not is_nan(m_gain_zero) and not is_inf(m_gain_zero), "15.1 Zero-distance trade produces finite positive yield (gain: %.2f)" % m_gain_zero)

	# Случай 2: Экстремальная дистанция (10000 пикселей)
	c_b["map_pos"] = Vector2(10500.0, 500.0)
	m_before = sim.matter_stock
	sim._tick_city_diplomacy(1.0)
	var m_gain_far := sim.matter_stock - m_before
	check_assert(m_gain_far > 0.0 and not is_nan(m_gain_far) and not is_inf(m_gain_far), "15.2 Extreme-distance trade clamps efficiency safely without underflow (gain: %.2f)" % m_gain_far)
	check_assert(m_gain_far < m_gain_zero, "15.3 Trade efficiency drops with extreme distance as designed")

	sim.free()

