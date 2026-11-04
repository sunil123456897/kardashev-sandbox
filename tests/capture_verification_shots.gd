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

	# 1. Нанесём яркие божественные вмешательства на континенты в центральной зоне 2D-карты
	var center_pos := Vector2(960.0, 500.0)
	var west_pos := Vector2(640.0, 440.0)
	var east_pos := Vector2(1240.0, 460.0)
	var south_pos := Vector2(920.0, 690.0)

	sim.apply_god_power_at_pos(center_pos, "power_cyber_nanites", 0.24)
	sim.apply_god_power_at_pos(center_pos, "power_seed_cyber", 0.18)
	sim.apply_god_power_at_pos(center_pos, "power_lens_time_accel", 0.24)

	sim.apply_god_power_at_pos(west_pos, "power_actinide_meteor", 0.22)
	sim.apply_god_power_at_pos(west_pos, "power_seed_plasma", 0.18)
	sim.apply_god_power_at_pos(west_pos, "power_monolith_uplift", 0.18)

	sim.apply_god_power_at_pos(east_pos, "power_crystal_lattice", 0.24)
	sim.apply_god_power_at_pos(east_pos, "power_lens_zero_grav", 0.22)

	sim.apply_god_power_at_pos(south_pos, "power_solar_plasma", 0.20)
	sim.apply_god_power_at_pos(south_pos, "power_lens_singularity", 0.20)
	sim.apply_god_power_at_pos(center_pos, "power_bless_unit", 0.22)
	sim.apply_god_power_at_pos(east_pos, "power_spawn_fauna", 0.18)

	# Добавим несколько колец Сферы Дайсона
	sim.apply_god_power_at_pos(center_pos, "power_dyson_ring")
	sim.apply_god_power_at_pos(center_pos, "power_dyson_ring")
	sim.apply_god_power_at_pos(center_pos, "power_stellar_stabilizer")

	# Прокрутим 35 шагов симуляции, чтобы города выросли, человечки побежали по островам и запустили ракеты
	for _s in range(35):
		sim.step_simulation(1.0)
		renderer._process(0.08)

	# Запустим пару ракет прямо перед кадром для сочного следа
	sim.rocket_launched.emit(center_pos, Color(0.25, 0.95, 1.0), "Нова-Аксиома")
	sim.rocket_launched.emit(west_pos, Color(1.0, 0.65, 0.2), "Гелиос-Купол")
	renderer._process(0.15)

	hud.update_tile_scanner(sim.find_closest_tile_2d(center_pos), center_pos)
	renderer.set_cursor_brush_preview_2d(true, center_pos, 105.0, Color(0.2, 0.95, 1.0))

	DirAccess.make_dir_recursive_absolute("E:/Godot_Проекты/1/screenshots")

	# Скриншот 1: 2D WorldBox Карта Мира (архипелаг, биомы, пиксельные человечки, здания, ракеты и линзы физики)
	camera.set_view_mode(0)
	camera.apply_immediately()
	hud._select_tab("lenses")
	for _f in range(6):
		await process_frame
	var img1: Image = root.get_texture().get_image()
	img1.save_png("E:/Godot_Проекты/1/screenshots/shot_1_planet_civilizations.png")
	print("Saved shot_1_planet_civilizations.png")

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

	main_node.free()
	quit(0)
