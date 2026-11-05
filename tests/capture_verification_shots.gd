extends SceneTree

## Скрипт визуальной GPU-верификации 2D Pixel-Art версии (в стиле WorldBox v0.51.2):
## Запускает 2D-сцену, симулирует развитие цивилизаций и пиксельных человечков (Actors),
## применяет Божественные Силы (биомы, купола времени/сингулярности, кольца Сферы Дайсона)
## и сохраняет 4 скриншота в E:/Godot_Проекты/1/screenshots/ для проверки глазами.

func _init() -> void:
	var main_packed: PackedScene = load("res://scenes/main.tscn")
	var main_node: Node2D = main_packed.instantiate()
	root.add_child(main_node)

	for _i in range(4):
		await process_frame

	var sim = main_node.sim
	var renderer = main_node.renderer
	var camera = main_node.camera
	var hud = main_node.hud

	var center_pos := Vector2(960.0, 500.0)
	var west_pos := Vector2(640.0, 440.0)
	var east_pos := Vector2(1240.0, 460.0)
	var south_pos := Vector2(920.0, 690.0)

	# 1. Для Скриншота 1 сохраняем естественный изумрудный архипелаг WorldBox с деревнями, кострами, кораблями и жителями
	sim.apply_god_power_at_pos(center_pos, "power_bless_unit", 0.18)
	sim.apply_god_power_at_pos(east_pos, "power_spawn_fauna", 0.18)
	for _s in range(14):
		sim.step_simulation(0.8)
		renderer._process(0.08)

	sim.spawn_cloud(west_pos + Vector2(60.0, -30.0), "rain")
	renderer._process(0.15)
	hud.update_tile_scanner(sim.find_closest_tile_2d(center_pos), center_pos)
	renderer.set_cursor_brush_preview_2d(false, center_pos, 60.0, Color.WHITE)

	DirAccess.make_dir_recursive_absolute("E:/Godot_Проекты/1/screenshots")

	# Скриншот 1: Аутентичная 2D WorldBox Карта Мира (изумрудные леса, песчаные пляжи, деревни с черепичными крышами, костры и корабли)
	camera.set_view_mode(0)
	camera.apply_immediately()
	hud._select_tab("life")
	for _f in range(6):
		await process_frame
	var img1: Image = root.get_texture().get_image()
	img1.save_png("E:/Godot_Проекты/1/screenshots/shot_1_planet_civilizations.png")
	print("Saved shot_1_planet_civilizations.png")

	# 2. Теперь применяем космические вмешательства и кольца Сферы Дайсона для скриншотов 2..6
	sim.apply_god_power_at_pos(center_pos, "power_lens_time_accel", 0.22)
	sim.apply_god_power_at_pos(east_pos, "power_crystal_lattice", 0.20)
	sim.apply_god_power_at_pos(center_pos, "power_dyson_ring")
	sim.apply_god_power_at_pos(center_pos, "power_dyson_ring")
	sim.apply_god_power_at_pos(center_pos, "power_stellar_stabilizer")
	for _s2 in range(20):
		sim.step_simulation(1.0)
		renderer._process(0.08)

	# Скриншот 2: 2D Пиксель-Арт Звезда и вращающиеся кольца Сферы Дайсона
	hud._select_tab("cosmos")
	camera.set_view_mode(1)
	camera.apply_immediately()
	for _f in range(6):
		renderer._process(0.1)
		await process_frame
	var img2: Image = root.get_texture().get_image()
	img2.save_png("E:/Godot_Проекты/1/screenshots/shot_2_star_dyson_swarm.png")
	print("Saved shot_2_star_dyson_swarm.png")

	# Скриншот 3: 2D Тактическая карта всей звёздной системы (Звезда + Планета + Пояс астероидов + Дроны)
	camera.set_view_mode(2)
	camera.apply_immediately()
	hud._select_tab("alchemy")
	for _f in range(6):
		renderer._process(0.1)
		await process_frame
	var img3: Image = root.get_texture().get_image()
	img3.save_png("E:/Godot_Проекты/1/screenshots/shot_3_system_overview.png")
	print("Saved shot_3_system_overview.png")

	# Скриншот 4: Приближенный 2D-зум на пиксельный город + открытое окно Кодекса Бесконечной Науки
	camera.focus_on_planet_pos(center_pos, 1.85)
	camera.apply_immediately()
	hud.toggle_codex_modal()
	for _f in range(6):
		await process_frame
	var img4: Image = root.get_texture().get_image()
	img4.save_png("E:/Godot_Проекты/1/screenshots/shot_4_science_codex.png")
	print("Saved shot_4_science_codex.png")

	# Скриншот 5: Модальное окно "🌍 Мир" (Космические Эпохи, Шаблоны Карты, Слои и Сохранения)
	hud.toggle_world_modal()
	for _f in range(6):
		await process_frame
	var img5: Image = root.get_texture().get_image()
	img5.save_png("E:/Godot_Проекты/1/screenshots/shot_5_world_modal.png")
	print("Saved shot_5_world_modal.png")

	# Скриншот 6: Инспектор Полиса (Империя, Лояльность, Морской Флот, Религия, Язык, Книги и Хромосомы)
	var first_cid: int = int(sim.cities_map.keys()[0])
	sim.write_city_book(first_cid)
	hud.open_city_inspector(first_cid)
	for _f in range(6):
		await process_frame
	var img6: Image = root.get_texture().get_image()
	img6.save_png("E:/Godot_Проекты/1/screenshots/shot_6_city_supreme_inspector.png")
	print("Saved shot_6_city_supreme_inspector.png")

	# Скриншот 7: Макро-зум (3.85x) — Меха-Колосс К-Титан + 8 зданий Кардашёва + корабли/ракеты + экзотические реликвии
	hud.close_active_modal()
	var second_cid: int = int(sim.cities_map.keys()[1]) if sim.cities_map.size() > 1 else first_cid
	var vil_pos: Vector2 = sim.cities_map[second_cid]["map_pos"]
	var b_insts: Array = sim.cities_map[second_cid]["building_instances"]
	var showcase_archs := ["spire", "collider", "elevator", "shipyard", "anchor", "matrioshka"]
	var showcase_offsets := [
		Vector2(-52.0, -18.0), Vector2(-24.0, -32.0), Vector2(28.0, -28.0),
		Vector2(62.0, -14.0), Vector2(-46.0, 28.0), Vector2(72.0, 26.0)
	]
	for s_i in range(showcase_archs.size()):
		b_insts.append({
			"id": "bld_" + showcase_archs[s_i],
			"map_pos": vil_pos + showcase_offsets[s_i],
			"dir": Vector3.UP,
			"tier": 2,
			"title": showcase_archs[s_i],
			"archetype": showcase_archs[s_i],
			"is_orbital": false,
			"color": sim.cities_map[second_cid]["color"],
			"spawn_spring": 1.0,
			"hit_shake": 0.0
		})
	var exotic_types := ["piezo_spire", "cyber_node", "lava_vent", "void_monolith"]
	var exotic_offsets := [Vector2(-78.0, 6.0), Vector2(-68.0, 52.0), Vector2(88.0, 56.0), Vector2(92.0, -2.0)]
	for e_i in range(exotic_types.size()):
		sim.flora_instances.append({
			"pos": vil_pos + exotic_offsets[e_i],
			"type": exotic_types[e_i],
			"is_mineral": true,
			"sway_phase": 0.0,
			"chop_shake": 0.0,
			"spawn_spring": 1.0
		})
	var col_spawn_pos: Vector2 = vil_pos + Vector2(36.0, 68.0)
	sim.spawn_kardashev_colossus(col_spawn_pos)
	renderer._on_rocket_launched(vil_pos + Vector2(-12.0, 38.0), Color.CYAN, "Crucible")
	renderer.show_diplomacy_lines = false
	renderer._process(0.1)
	if not sim.actors.is_empty():
		sim.actors[sim.actors.size() - 1]["pos"] = col_spawn_pos
		sim.actors[sim.actors.size() - 1]["target_pos"] = col_spawn_pos + Vector2(0.0, 24.0)
	renderer._update_multimeshes(0.0)
	renderer.queue_redraw()
	camera.set_view_mode(0)
	camera.focus_on_planet_pos(vil_pos + Vector2(12.0, 26.0), 3.85)
	camera.apply_immediately()
	hud._select_tab("life")
	for _f in range(6):
		await process_frame
	var img7: Image = root.get_texture().get_image()
	img7.save_png("E:/Godot_Проекты/1/screenshots/shot_7_ktitan_colossus_live.png")
	print("Saved shot_7_ktitan_colossus_live.png")

	main_node.free()
	quit(0)
