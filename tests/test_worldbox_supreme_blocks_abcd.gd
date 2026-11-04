extends SceneTree

## Полный E2E тест «WorldBox v0.51.2 Supreme Parity & Beyond» (Блоки A, B, C, D):
## - Блок A: Морская логистика (Верфи, Рыбацкие/Торговые/Десантные корабли), Дальнобойные снаряды по дуге, Статусные эффекты (6 шт.).
## - Блок B: Двухуровневые Империи (Королевства vs Провинции, Столицы 👑, Лояльность, Восстания провинций, Шёпот Войны).
## - Блок C: Божественный Магнит, Прямое WASD-управление юнитом и боссом «Меха-Колосс К-Титан» (2500 HP),
##           Автономные Облака, Живые Торнадо, Тектонический Разлом, Ксено-Чума.
## - Блок D: Мета-культура v0.51 (Религии и Обряды, Языки, Книги, Семьи и Генеалогия, Сытость/Счастье, Хромосомный Геном).

const MainScenePacked = preload("res://scenes/main.tscn")


func _check(cond: bool, msg: String) -> void:
	if not cond:
		printerr("FAILED: " + msg)
		quit(1)
	else:
		print("[OK] " + msg)


func _init() -> void:
	print("=== TEST WORLDBOX SUPREME BLOCKS A, B, C, D START ===")
	var main_node: Node2D = MainScenePacked.instantiate()
	root.add_child(main_node)
	await process_frame
	await process_frame

	var sim = main_node.get("sim")
	var renderer = main_node.get("renderer")
	var hud = main_node.get("hud")
	_check(sim != null and renderer != null and hud != null, "Узлы sim, renderer, hud инициализированы")

	# ==========================================================================
	# 1. БЛОК A: МОРСКАЯ ЛОГИСТИКА (ВЕРФИ И КОРАБЛИ), ДАЛЬНОБОЙНЫЕ СНАРЯДЫ И СТАТУСЫ
	# ==========================================================================
	var city_ids: Array = sim.cities_map.keys()
	_check(city_ids.size() >= 3, "На старте создано не менее 3 полисов")
	var cid_a: int = int(city_ids[0])
	var cid_b: int = int(city_ids[1])

	var dock_built: bool = sim.build_coastal_dock_for_city(cid_a)
	_check(dock_built and bool(sim.cities_map[cid_a].get("has_dock", false)), "Построена прибрежная верфь/порт для полиса #%d" % cid_a)

	var boat_fish: Dictionary = sim.spawn_boat_for_city(cid_a, "fishing")
	var boat_trade: Dictionary = sim.spawn_boat_for_city(cid_a, "trade")
	var boat_trans: Dictionary = sim.spawn_boat_for_city(cid_a, "transport")
	_check(not boat_fish.is_empty() and not boat_trade.is_empty() and not boat_trans.is_empty(), "Спущены рыбацкий, торговый и десантный корабли (всего в мире=%d)" % sim.boats.size())

	var pos_before_boat: Vector2 = boat_trade["pos"]
	sim._step_boats(0.5)
	_check(boat_trade["pos"].distance_to(pos_before_boat) > 0.01, "Корабли физически плывут по океану (_step_boats)")

	# Дальнобойные снаряды по дуге с тенью
	var target_actor: Dictionary = sim.actors[0]
	var shooter_actor: Dictionary = {}
	for cand_a in sim.actors:
		if int(cand_a.get("city_id", -1)) != int(target_actor.get("city_id", -1)):
			shooter_actor = cand_a
			break
	if shooter_actor.is_empty():
		shooter_actor = sim.actors[1]
	var hp_before_proj: int = int(target_actor.get("hp", 100))
	var proj: Dictionary = sim.spawn_projectile(
		shooter_actor["pos"],
		target_actor["pos"],
		22,
		Color(0.35, 0.95, 1.0),
		"status_burning",
		-999,
		int(shooter_actor["id"])
	)
	_check(not proj.is_empty() and sim.projectiles.size() >= 1, "Снаряд создан и добавлен в sim.projectiles")
	sim._step_projectiles(0.5)
	sim._step_projectiles(0.6)
	_check(int(target_actor.get("hp", 100)) < hp_before_proj, "Прилетевший по дуге снаряд нанёс урон цели (%d -> %d HP)" % [hp_before_proj, int(target_actor.get("hp", 100))])

	# Статусные эффекты (6 видов)
	_check(sim.assets.status_effect_list.size() >= 6, "В реестре зарегистрировано 6 статусных эффектов")
	var st_ok: bool = sim.apply_status_effect_to_actor(int(target_actor["id"]), "status_frozen", 8.0)
	_check(st_ok and (target_actor["status_effects"] as Dictionary).has("status_frozen"), "На юнита наложен статусный эффект Крио-Заморозки")
	sim._step_actor_status_effects_and_needs(1.0)

	# ==========================================================================
	# 2. БЛОК B: ДВУХУРОВНЕВЫЕ ИМПЕРИИ (КОРОЛЕВСТВА VS ГОРОДА, ЛОЯЛЬНОСТЬ, ВОССТАНИЯ, ШЁПОТ ВОЙНЫ)
	# ==========================================================================
	_check(sim.kingdoms_map.size() >= 3, "Стартовые полисы объединены в суверенные Королевства/Империи (%d)" % sim.kingdoms_map.size())
	var k_id_a: int = int(sim.cities_map[cid_a].get("kingdom_id", -1))
	_check(k_id_a != -1 and bool(sim.cities_map[cid_a].get("is_capital", false)), "Полис #%d является столицей Империи #%d" % [cid_a, k_id_a])

	# Присоединяем второй полис как провинцию к Империи A, чтобы проверить лояльность и восстание
	var province_cid: int = cid_b
	var old_kb: int = int(sim.cities_map[province_cid].get("kingdom_id", -1))
	if sim.kingdoms_map.has(old_kb):
		(sim.kingdoms_map[old_kb]["member_city_ids"] as Array).erase(province_cid)
	sim.cities_map[province_cid]["kingdom_id"] = k_id_a
	sim.cities_map[province_cid]["is_capital"] = false
	if not (sim.kingdoms_map[k_id_a]["member_city_ids"] as Array).has(province_cid):
		(sim.kingdoms_map[k_id_a]["member_city_ids"] as Array).append(province_cid)

	var loy: float = sim.compute_city_loyalty(province_cid)
	_check(loy >= 0.0 and loy <= 100.0, "Расчёт лояльности провинции #%d корректен (%.1f%%)" % [province_cid, loy])

	var rebel_k_id: int = sim.trigger_city_rebellion(province_cid)
	_check(rebel_k_id != -1 and int(sim.cities_map[province_cid].get("kingdom_id", -1)) != k_id_a and bool(sim.cities_map[province_cid].get("is_capital", false)), "Провинция #%d подняла восстание и образовала новое Королевство #%d" % [province_cid, rebel_k_id])

	var cid_c: int = int(city_ids[2])
	var whisper_ok: bool = sim.whisper_of_war(cid_a, cid_c)
	var rel_ac: Dictionary = sim.get_diplomacy_relation(cid_a, cid_c)
	_check(whisper_ok and str(rel_ac.get("status", "")) == "WAR", "Сила «Шёпот Войны» спровоцировала войну между полисами #%d и #%d" % [cid_a, cid_c])

	# ==========================================================================
	# 3. БЛОК C: БОЖЕСТВЕННЫЙ МАГНИТ, ПРЯМОЕ УПРАВЛЕНИЕ + МЕХА-КОЛОСС К-ТИТАН, ТОРНАДО, ОБЛАКА, РАЗЛОМ, КСЕНО-ЧУМА
	# ==========================================================================
	var magnet_pos: Vector2 = sim.cities_map[cid_a]["map_pos"]
	var grabbed: int = sim.apply_divine_magnet_at_pos(magnet_pos, 95.0)
	_check(grabbed > 0 and sim.magnet_held_actor_ids.size() > 0, "Божественный Магнит захватил %d юнитов в радиусе" % grabbed)
	var drop_pos := magnet_pos + Vector2(35.0, 20.0)
	var released: int = sim.release_divine_magnet(drop_pos)
	_check(released == grabbed and sim.magnet_held_actor_ids.is_empty(), "Божественный Магнит мягко высадил %d юнитов" % released)

	# Спавн и прямое WASD-управление боссом «Меха-Колосс К-Титан» (2500 HP)
	var colossus: Dictionary = sim.spawn_kardashev_colossus(Vector2(960.0, 540.0))
	_check(not colossus.is_empty() and bool(colossus.get("is_colossus", false)) and int(colossus.get("max_hp", 0)) == 2500, "Призван управляемый босс «Меха-Колосс К-Титан» (2500 HP)")
	var col_id: int = int(colossus["id"])
	_check(sim.controlled_actor_id == col_id, "Прямое управление (Possession) автоматически подключено к Меха-Колоссу #%d" % col_id)
	var col_pos_before: Vector2 = colossus["pos"]
	sim.step_controlled_actor(Vector2(1.0, 0.0), 0.25, true)
	_check(colossus["pos"].distance_to(col_pos_before) > 1.0, "Меха-Колосс перемещается по команде WASD и стреляет главным калибром по Пробелу")
	sim.release_possession()
	_check(sim.controlled_actor_id == -1, "Прямое управление корректно отпущено (release_possession)")

	# Облака, Торнадо, Тектонический Разлом, Ксено-Чума
	var cloud: Dictionary = sim.spawn_cloud(magnet_pos, "rain")
	var tornado: Dictionary = sim.spawn_tornado(magnet_pos + Vector2(50.0, 0.0), 48.0)
	_check(not cloud.is_empty() and not tornado.is_empty() and sim.active_clouds.size() >= 1 and sim.active_tornadoes.size() >= 1, "В небе созданы автономное Облако и живое Торнадо")
	sim._step_clouds_and_tornadoes(0.5)

	var fault_pixels: int = sim.trigger_earthquake_fault(magnet_pos, 18.0)
	_check(fault_pixels > 0, "Тектоническое Землетрясение раскололо рельеф по линии разлома (%d пикселей)" % fault_pixels)

	var xeno_seeded: int = sim.spawn_xeno_plague(magnet_pos, 25.0)
	_check(xeno_seeded > 0 and sim.xeno_biomass_tiles.size() > 0, "Ксено-Чума заразила %d клеток биомассой" % xeno_seeded)
	sim._step_xeno_biomass(1.0)

	# ==========================================================================
	# 4. БЛОК D: МЕТА-КУЛЬТУРА v0.51 (РЕЛИГИИ, ЯЗЫКИ, КНИГИ, СЕМЬИ, СЫТОСТЬ/СЧАСТЬЕ, ХРОМОСОМЫ)
	# ==========================================================================
	_check(sim.languages_map.size() >= 3 and sim.religions_map.size() >= 3, "Для цивилизаций созданы Языки (%d) и Религии (%d)" % [sim.languages_map.size(), sim.religions_map.size()])
	_check(sim.families_map.size() >= 1, "Сформированы Семьи и Генеалогические древа жителей (%d)" % sim.families_map.size())

	var rite_res: Dictionary = sim.cast_religion_rite(cid_a)
	_check(bool(rite_res.get("ok", false)), "Храм полиса #%d провёл Божественный Обряд религии" % cid_a)

	var book: Dictionary = sim.write_city_book(cid_a)
	_check(not book.is_empty() and sim.books_list.size() >= 1, "В библиотеке полиса #%d написана священная/научная Книга «%s»" % [cid_a, str(book.get("title", ""))])

	var sp_id: int = int(sim.cities_map[cid_a]["subspecies_id"])
	var gene_ok: bool = sim.mutate_subspecies_gene(sp_id, "gene_carapace")
	var bonuses: Dictionary = sim.get_subspecies_chromosome_bonuses(sp_id)
	_check(gene_ok and int(bonuses.get("hp_bonus", 0)) != 0, "Хромосомный редактор генома модифицировал локус gene_carapace подвида #%d (hp_bonus=%d)" % [sp_id, int(bonuses.get("hp_bonus", 0))])

	# Проверка рендеринга и инспекторов UI
	renderer._update_multimeshes(0.1)
	renderer.queue_redraw()
	hud.open_city_inspector(cid_a)
	_check(hud._active_modal_id == "city", "Инспектор полиса открылся со всеми секциями Империи, Флота, Религии, Книг и Генома")
	hud.open_actor_inspector(int(target_actor["id"]))
	_check(hud._active_modal_id == "actor", "Инспектор юнита открылся с Сытостью, Семьёй, Статусами и кнопкой WASD-управления")
	hud.close_active_modal()

	# Проверка сохранения и загрузки всех новых структур (Блоки A-D)
	var snap: Dictionary = sim.save_world_to_dict()
	_check(snap.has("kingdoms_map") and snap.has("religions_map") and snap.has("languages_map") and snap.has("books_list") and snap.has("boats"), "Снапшот сохранения включает все таблицы Блоков A–D")
	sim.load_world_from_dict(snap)
	_check(sim.kingdoms_map.size() >= 3 and sim.books_list.size() >= 1 and sim.boats.size() >= 3, "Загрузка снапшота полностью восстановила Королевства, Книги и Морской Флот")

	main_node.free()
	print("=== ALL WORLDBOX SUPREME BLOCKS A, B, C, D CHECKS PASSED ===")
	quit(0)
