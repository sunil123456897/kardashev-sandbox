extends SceneTree

## E2E Тест полной паритетности с WorldBox v0.51.2 (Этапы 1..4):
## 1. Чистые слои карты, отсутствие наложений баннеров полисов (compute_non_overlapping_city_banner_rects),
##    попиксельный терраформинг 384×216 (power_raise_land, power_lower_water, power_vortex_sand) и клеточный огонь (FireLayer).
## 2. Регулярные армии с Генералами, захват зон 8×8 в войне (capture_enemy_zone_at_pos), кузница снаряжения,
##    личные черты (PersonalTraitAsset), избранные юниты (★) и дикая фауна.
## 3. Космические Эпохи (5 World Ages), 4 шаблона генератора мира и полное сохранение/загрузка (Save/Load).

const MainScenePacked = preload("res://scenes/main.tscn")

var _failed: int = 0


func _check(cond: bool, msg: String) -> void:
	if not cond:
		push_error("[FAIL] " + msg)
		_failed += 1
	else:
		print("[OK] " + msg)


func _init() -> void:
	print("=== TEST WORLDBOX COMPLETE PARITY (STAGES 1..4) START ===")
	var main_node: Node = MainScenePacked.instantiate()
	root.add_child(main_node)
	await process_frame
	await process_frame

	var sim = main_node.sim
	var renderer = main_node.renderer
	var hud = main_node.hud

	_check(sim != null and renderer != null and hud != null, "Узлы sim, renderer, hud инициализированы")

	# --------------------------------------------------------------------------
	# ЭТАП 1: Неперекрывающиеся баннеры, слои карты, 384×216 терраформинг и огонь
	# --------------------------------------------------------------------------
	_check("show_city_banners" in renderer and "show_diplomacy_lines" in renderer and "show_army_banners" in renderer, "В CosmicRenderer есть флаги слоёв карты")

	# Основываем дополнительный полис рядом с существующим, чтобы проверить разведение баннеров
	var c0_id: int = sim.cities_map.keys()[0]
	var c0_tile: int = int(sim.cities_map[c0_id]["center_tile"])
	var nbr_tiles: PackedInt32Array = sim.tiles[c0_tile]["neighbors"]
	if not nbr_tiles.is_empty():
		var near_tile: int = nbr_tiles[0]
		var sp_new: int = sim._spawn_subspecies_at_tile(near_tile, "silicon")
		sim._uplift_subspecies_and_found_city(sp_new, near_tile)

	var banner_rects: Dictionary = renderer.compute_non_overlapping_city_banner_rects()
	_check(banner_rects.size() == sim.cities_map.size(), "compute_non_overlapping_city_banner_rects вернул прямоугольники для всех %d полисов" % banner_rects.size())

	var overlap_found := false
	var b_ids: Array = banner_rects.keys()
	for i in range(b_ids.size()):
		var ra: Rect2 = banner_rects[b_ids[i]]
		for j in range(i + 1, b_ids.size()):
			var rb: Rect2 = banner_rects[b_ids[j]]
			if ra.intersects(rb):
				overlap_found = true
	_check(not overlap_found, "Ни один баннер полиса не перекрывается с другим (0 пересечений)")

	# Попиксельный терраформинг 384×216: подъём суши и углубление океана
	var test_pos := Vector2(960.0, 540.0)
	var elev_before: float = sim.sample_elevation_fast(test_pos.x / 1920.0, test_pos.y / 1080.0)
	var res_raise: Dictionary = sim.apply_god_power_at_pos(test_pos, "power_raise_land", 0.16)
	var elev_after_raise: float = sim.sample_elevation_fast(test_pos.x / 1920.0, test_pos.y / 1080.0)
	_check(bool(res_raise.get("ok", false)) and int(res_raise.get("modified_fine_pixels", 0)) > 10 and elev_after_raise > elev_before,
		"Кисть power_raise_land подняла микро-рельеф 384×216 (elev %.3f -> %.3f, px=%d)" % [elev_before, elev_after_raise, int(res_raise.get("modified_fine_pixels", 0))])

	var res_lower: Dictionary = sim.apply_god_power_at_pos(test_pos, "power_lower_water", 0.16)
	var elev_after_lower: float = sim.sample_elevation_fast(test_pos.x / 1920.0, test_pos.y / 1080.0)
	_check(bool(res_lower.get("ok", false)) and elev_after_lower < elev_after_raise,
		"Кисть power_lower_water углубила рельеф (elev %.3f -> %.3f)" % [elev_after_raise, elev_after_lower])

	# Клеточный огонь (FireLayer) и тушение Живым Ливнем
	var land_pos: Vector2 = sim.cities_map[c0_id]["map_pos"]
	var res_fire: Dictionary = sim.apply_god_power_at_pos(land_pos, "power_fire_spark", 0.18)
	_check(int(res_fire.get("ignited_fires", 0)) > 0 and sim.active_fire_count > 0,
		"Пиро-Вспышка зажгла клеточный пожар на суше (active_fire_count=%d)" % sim.active_fire_count)
	sim._step_cellular_fire(0.25)
	var res_rain: Dictionary = sim.apply_god_power_at_pos(land_pos, "power_living_rain", 0.25)
	_check(int(res_rain.get("extinguished_fires", 0)) > 0,
		"Живой Ливень потушил клеточные очаги пожара (extinguished=%d)" % int(res_rain.get("extinguished_fires", 0)))

	# --------------------------------------------------------------------------
	# ЭТАП 2: Генералы армий, кузница снаряжения, захват зон 8×8, черты и фауна
	# --------------------------------------------------------------------------
	_check(sim.assets.personal_trait_list.size() == 7 and sim.assets.equipment_list.size() == 7,
		"В реестре зарегистрированы 7 личных черт и 7 видов снаряжения кузницы")

	var general_count: int = 0
	for a in sim.actors:
		if str(a.get("role", "")) == "general":
			general_count += 1
	_check(general_count >= 1, "В полисах назначены Генералы регулярных армий (general_count=%d)" % general_count)

	# Проверяем ковку оружия и брони в кузнице полиса
	var city0: Dictionary = sim.cities_map[c0_id]
	city0["storage"]["minerals"] = 20
	city0["storage"]["wood"] = 10
	var forged_w: String = sim.forge_city_equipment_for_actor(c0_id, int(city0.get("general_actor_id", -1)))
	var forged_a: String = sim.forge_city_equipment_for_actor(c0_id, int(city0.get("general_actor_id", -1)))
	_check(forged_w != "" and forged_a != "" and sim.total_items_forged >= 2,
		"Кузница полиса выковала оружие (%s) и броню (%s) для Генерала" % [forged_w, forged_a])

	# Проверяем захват 8×8 зон в войне между двумя полисами
	var all_c_ids: Array = sim.cities_map.keys()
	var ca_id: int = int(all_c_ids[0])
	var cb_id: int = int(all_c_ids[1])
	sim.set_diplomacy_status(ca_id, cb_id, "WAR")
	var cb_pos: Vector2 = sim.cities_map[cb_id]["map_pos"]
	var zones_before: int = int(sim.total_zones_captured_in_war)
	var cap_ok: bool = sim.capture_enemy_zone_at_pos(ca_id, cb_id, cb_pos)
	_check(cap_ok and sim.total_zones_captured_in_war > zones_before,
		"Армия полиса #%d захватила пограничную зону 8×8 у полиса #%d в войне (zones_captured=%d)" % [ca_id, cb_id, sim.total_zones_captured_in_war])

	# Проверяем благословение, избранного юнита (★) и дикую фауну
	var any_actor_id: int = int(sim.actors[0]["id"])
	var fav_on: bool = sim.toggle_actor_favorite(any_actor_id)
	var a_detail: Dictionary = sim.get_detailed_actor_data(any_actor_id)
	_check(fav_on and bool(a_detail.get("is_favorite", false)) and a_detail.has("personal_traits") and a_detail.has("combat_damage"),
		"Юнит #%d помечен как ★ Избранный, инспектор возвращает черты, урон и броню" % any_actor_id)

	var res_bless: Dictionary = sim.apply_god_power_at_pos(sim.actors[0]["pos"], "power_bless_unit", 0.22)
	_check(int(res_bless.get("blessed_count", 0)) >= 1, "Сила power_bless_unit благословила юнитов в радиусе")

	var res_fauna: Dictionary = sim.apply_god_power_at_pos(land_pos, "power_spawn_fauna", 0.18)
	_check(int(res_fauna.get("spawned_fauna", 0)) == 3, "Сила power_spawn_fauna выпустила 3 диких существ в экосистему")

	# --------------------------------------------------------------------------
	# ЭТАП 3: Космические Эпохи, Генератор Шаблонов Мира и Сохранение/Загрузка
	# --------------------------------------------------------------------------
	_check(sim.assets.world_age_list.size() == 5, "Зарегистрировано 5 Космических Эпох (WorldAgeAsset)")
	var age_ok: bool = sim.set_world_age("age_of_ice")
	_check(age_ok and sim.current_age_id == "age_of_ice", "Установлена Эпоха Крио-Сна (age_of_ice)")
	sim.set_world_age("age_of_wonders")
	_check(sim.current_age_id == "age_of_wonders", "Установлена Эпоха Сингулярности (age_of_wonders)")

	# Проверяем сохранение и загрузку слота #1
	var saved_year: float = sim.world_year
	var saved_cities: int = sim.cities_map.size()
	var save_ok: bool = sim.save_world_to_slot(1)
	_check(save_ok, "Мир успешно сохранён в user://saves/slot_1.save")

	# Генерируем новый мир по шаблону «Кольцевой Атолл»
	sim.generate_world_with_template(77777, "ring_atoll", 0.0)
	_check(sim.map_template_id == "ring_atoll" and sim.world_seed == 77777, "Генератор мира создал карту по шаблону ring_atoll")

	# Загружаем обратно сохранённый мир из слота #1
	var load_ok: bool = sim.load_world_from_slot(1)
	_check(load_ok and is_equal_approx(sim.world_year, saved_year) and sim.cities_map.size() == saved_cities and sim.current_age_id == "age_of_wonders",
		"Загрузка из слота #1 полностью восстановила состояние мира (городов=%d, эпоха=%s)" % [sim.cities_map.size(), sim.current_age_id])

	# Проверяем модальное окно «🌍 Мир» в GodHUD
	hud.open_modal("world")
	await process_frame
	_check(hud._modal_world != null and hud._modal_world.visible, "Модальное окно «🌍 Мир» открывается в GodHUD")
	hud.close_active_modal()
	_check(not hud._modal_world.visible, "Модальное окно «🌍 Мир» корректно закрывается")

	main_node.queue_free()
	await process_frame

	if _failed > 0:
		push_error("TEST WORLDBOX COMPLETE PARITY FAILED: %d errors" % _failed)
		quit(1)
	else:
		print("=== ALL WORLDBOX COMPLETE PARITY CHECKS PASSED ===")
		quit(0)
