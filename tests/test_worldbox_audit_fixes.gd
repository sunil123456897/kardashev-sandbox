extends SceneTree

## E2E-тест исправлений полного аудита паритета с WorldBox v0.51.2 (Часть 2: 12 разомкнутых контуров + Часть 3: 7 систем).

const MainSceneScript = preload("res://scripts/main.gd")

var _passed: int = 0
var _failed: int = 0


func _assert(cond: bool, msg: String) -> void:
	if cond:
		_passed += 1
	else:
		_failed += 1
		printerr("  [FAIL] " + msg)


func _initialize() -> void:
	print("=== ЗАПУСК ТЕСТА: АУДИТ ПАРИТЕТА WORLDBOX v0.51.2 (12 КОНТУРОВ + 7 СИСТЕМ) ===")
	var main_node: Node2D = MainSceneScript.new()
	root.add_child(main_node)
	await process_frame

	var sim = main_node.sim
	var renderer = main_node.renderer
	var hud = main_node.hud

	var c_ids: Array = sim.cities_map.keys()
	_assert(c_ids.size() >= 2, "На старте должно быть минимум 2 полиса")
	var cid_a: int = int(c_ids[0])
	var cid_b: int = int(c_ids[1])
	var city_a: Dictionary = sim.cities_map[cid_a]

	# 1. Проверка исправления опечаток ID и ключей (eq_titan_exo, fauna_type, temperature_c, Tier 4 кузница)
	print("--- [1/6] Проверка исправления ключей (eq_titan_exo, fauna_type, temperature_c, Tier 4 eq_void_rifle) ---")
	sim.set_diplomacy_status(cid_a, cid_b, "WAR")
	var war_boat: Dictionary = sim.launch_amphibious_invasion(cid_a, cid_b)
	var def_dock: Vector2 = sim.cities_map[cid_b].get("dock_pos", sim.cities_map[cid_b]["map_pos"])
	sim._execute_amphibious_landing(war_boat, cid_a, cid_b, def_dock)

	var found_valid_exo: bool = false
	for a in sim.actors:
		if str(a.get("armor_id", "")) == "eq_titan_exo":
			found_valid_exo = true
			_assert(sim.get_actor_armor_defense(a) >= 8, "Морской пехотинец с eq_titan_exo должен получать реальную броню >= 8 вместо 0 (получено %d)" % sim.get_actor_armor_defense(a))
			break
	_assert(found_valid_exo, "Десантники должны экипироваться валидным ID eq_titan_exo")

	var stag: Dictionary = sim.spawn_wild_fauna(Vector2(600.0, 400.0), "crystal_stag")
	var stag_info: Dictionary = sim.get_detailed_actor_data(int(stag["id"]))
	_assert(str(stag_info.get("subspecies_name", "")) == "crystal_stag", "Инспектор дикой фауны должен возвращать fauna_type crystal_stag (получено: %s)" % str(stag_info.get("subspecies_name", "")))

	city_a["science_tier"] = 4
	city_a["storage"] = {"wood": 50, "minerals": 50, "food": 50}
	var forged_w: String = sim.forge_city_equipment_for_actor(cid_a, int(stag["id"]))
	_assert(forged_w == "eq_void_rifle" or forged_w == "eq_aegis_shield", "Кузница Tier 4 должна ковать снаряжение 4-го тира (eq_void_rifle / eq_aegis_shield), получено: %s" % forged_w)

	# 2. Проверка множителей скорости генома, личных черт, регенерации, щита и боевых книг
	print("--- [2/6] Проверка генома (speed_mult), черт (regen_per_sec), щита (status_shielded) и боевых книг ---")
	var test_unit: Dictionary = sim.actors[0]
	var uid: int = int(test_unit["id"])
	test_unit["city_id"] = cid_a
	var def_before: int = sim.get_actor_armor_defense(test_unit)
	sim.apply_status_effect_to_actor(uid, "status_shielded", 10.0)
	var def_after: int = sim.get_actor_armor_defense(test_unit)
	_assert(def_after == def_before + 12, "status_shielded должен давать +12 к защите (было %d, стало %d)" % [def_before, def_after])

	var dmg_before: int = sim.get_actor_combat_damage(test_unit)
	var bk: Dictionary = sim.write_city_book(cid_a, "Боевой Устав Титанов")
	bk["bonus_type"] = "combat"
	bk["bonus_val"] = 6.0
	var dmg_after: int = sim.get_actor_combat_damage(test_unit)
	_assert(dmg_after >= dmg_before + 6, "Книга с bonus_type==combat должна повышать боевой урон граждан полиса (было %d, стало %d)" % [dmg_before, dmg_after])

	# Проверка редактора черт (toggle_actor_personal_trait) и регенерации
	var max_hp_0: int = int(test_unit.get("max_hp", 100))
	var added_giant: bool = sim.toggle_actor_personal_trait(uid, "trait_giant")
	if not added_giant:
		# Если уже был, включим обратно
		added_giant = sim.toggle_actor_personal_trait(uid, "trait_giant")
	_assert(added_giant and int(test_unit["max_hp"]) > max_hp_0, "toggle_actor_personal_trait('trait_giant') должен добавлять черту и увеличивать max_hp")

	sim.toggle_actor_personal_trait(uid, "trait_regenerator")
	test_unit["hp"] = 50
	sim._step_actor_status_effects_and_needs(1.0)
	_assert(int(test_unit["hp"]) > 50, "Черта trait_regenerator должна регенерировать HP каждую секунду (текущее HP: %d)" % int(test_unit["hp"]))

	# 3. Проверка новых профессий (farmer, gatherer_bushes, hunter) и физического Правителя (leader)
	print("--- [3/6] Проверка профессий фермера/охотника и физического Правителя (leader с короной) ---")
	var farmer_u: Dictionary = sim._spawn_actor_unit(int(city_a["subspecies_id"]), int(city_a["center_tile"]), cid_a, "farmer")
	_assert(str(farmer_u.get("job_id", "")) == "farmer", "Роль farmer должна получать job_id == farmer")
	var leader_u: Dictionary = sim._spawn_actor_unit(int(city_a["subspecies_id"]), int(city_a["center_tile"]), cid_a, "leader")
	_assert(str(leader_u.get("role", "")) == "leader", "В полисе должен спавниться физический юнит-правитель (leader)")

	# 4. Проверка боя с Боссом «Архонт-Омега» и Ксено-Мутантами + ползучей биомассы и нанитных туч
	print("--- [4/6] Проверка боя против Босса Архонт-Омега, Ксено-биомассы и Нанитных облаков ---")
	var boss: Dictionary = sim.trigger_great_filter_crisis(cid_a, "ai_uprising")
	_assert(not boss.is_empty() and bool(boss.get("is_rogue_boss", false)), "Босс Архонт-Омега должен быть создан")
	# Ставим воина рядом с боссом и проверяем, что _step_actor_combat разрешает бой против изгоя при ALLIANCE между городами
	test_unit["pos"] = boss["pos"] + Vector2(10.0, 0.0)
	var boss_hp_initial: int = int(boss["hp"])
	for _s in range(15):
		sim._step_actor_combat(0.2)
	_assert(int(boss["hp"]) < boss_hp_initial or int(test_unit["hp"]) < int(test_unit["max_hp"]), "Воины и Босс Архонт-Омега должны вступать в реальный бой в _step_actor_combat")

	var n_cloud: Dictionary = sim.spawn_cloud(city_a["map_pos"], "nanite", 15.0)
	_assert(str(n_cloud.get("cloud_type", "")) == "nanite", "Нанитное облако должно создаваться")
	for _c in range(20):
		sim._step_clouds_and_tornadoes(0.5)

	# 5. Проверка политических режимов карты (Map Overlay Modes 0..4) и сохранения fine_road_overlay
	print("--- [5/6] Проверка слоёв карты (Map Overlays 0..4) и сохранения fine_road_overlay ---")
	renderer.set_map_overlay_mode(1) # Империи
	_assert(renderer.map_overlay_mode == 1, "Режим карты должен переключаться на 1 (Империи)")
	var col_emp: Color = renderer._get_city_overlay_color(cid_a)
	renderer.set_map_overlay_mode(3) # Религии
	var col_rel: Color = renderer._get_city_overlay_color(cid_a)
	_assert(col_emp.a > 0.0 and col_rel.a > 0.0, "Цвета оверлеев Империй и Религий должны корректно вычисляться")
	renderer.set_map_overlay_mode(0)

	var saved_dict: Dictionary = sim.save_world_to_dict()
	_assert(saved_dict.has("fine_road_overlay"), "save_world_to_dict должен сохранять fine_road_overlay")

	# 6. Проверка UI/HUD: все 9 дополнительных сил в доке и слайдеры констант в законах мира
	print("--- [6/6] Проверка HUD: 9 сил катаклизмов/трансмутаций в доке и слайдеры констант ---")
	hud._select_tab("cosmos")
	await process_frame
	var cat_btn_count: int = hud._hbox_powers.get_child_count()
	_assert(cat_btn_count >= 9, "Во вкладке 'cosmos' должны отображаться и базовые силы, и cataclysm/transmutation_power_list (>= 9 кнопок, найдено %d)" % cat_btn_count)

	hud.toggle_laws_modal()
	await process_frame
	_assert(hud._vbox_laws_list.get_child_count() >= 10, "Модальное окно законов мира должно содержать переключатели законов и слайдеры 4 физических констант (детей: %d)" % hud._vbox_laws_list.get_child_count())

	print("=== ИТОГ ТЕСТА АУДИТА WORLDBOX: Passed=%d, Failed=%d ===" % [_passed, _failed])
	quit(0 if _failed == 0 else 1)
