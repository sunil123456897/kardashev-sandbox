extends SceneTree

## Полный интеграционный и стресс-тест 2D Pixel-Art версии «Kardashev Sandbox: Crucible of Stars».
## Проверяет:
## 1. Загрузку и инстанцирование главной 2D-сцены res://scenes/main.tscn (Node2D + WorldSimulation + CosmicRenderer + Camera2D + GodHUD).
## 2. Все 20 Божественных Сил в 4 категориях на 2D-сетке карты (32×32 тайла, текстура 384×216).
## 3. Движение живых пиксельных человечков (Actors), авто-строительство зданий (BuildOrders), замыслы (Plots) и генератор бесконечной науки (Codex).
## 4. Отрисовку всех 3 двумерных режимов (Карта Мира, Сфера Дайсона 2D, Звёздная Система 2D) и UI.

func _init() -> void:
	print("=== RUNNING FULL 2D SANDBOX INTEGRATION SUITE ===")
	var main_packed: PackedScene = load("res://scenes/main.tscn")
	assert(main_packed != null, "Failed to load res://scenes/main.tscn")

	var main_node: Node2D = main_packed.instantiate()
	root.add_child(main_node)

	await process_frame

	var sim = main_node.sim
	var renderer = main_node.renderer
	var camera = main_node.camera
	var hud = main_node.hud

	assert(sim != null, "WorldSimulation missing")
	assert(renderer != null, "CosmicRenderer missing")
	assert(camera != null, "SandboxOrbitCamera missing")
	assert(hud != null, "GodHUD missing")

	# 1. Проверим применение всех 20 Божественных Сил на 2D-карте
	var idx_step: int = 0
	for gp in sim.assets.god_power_list:
		if gp.id == "power_chrono_supernova":
			continue
		var tile_idx: int = (idx_step * 43 + 300) % sim.TILE_COUNT
		var pos_2d: Vector2 = sim.tiles[tile_idx]["map_pos"]
		var res: Dictionary = sim.apply_god_power_at_pos(pos_2d, gp.id, 0.24)
		assert(bool(res.get("ok", false)), "God power failed: " + gp.id)
		idx_step += 1

	# 2. Проверим симуляцию на протяжении 30 игровых секунд (20 шагов по 1.5 с)
	for _step in range(20):
		sim.step_simulation(1.5)
		renderer._process(0.05)
		camera.step_camera(0.05)

	renderer._refresh_counts()

	print("Verified Cities: ", sim.cities_map.size())
	print("Verified Subspecies: ", sim.subspecies_map.size())
	print("Verified Living 2D Actors: ", renderer.rendered_actor_count)
	print("Verified 2D City Buildings: ", renderer.rendered_building_count)
	print("Verified Codex Theories: ", sim.codex_theories.size())
	print("Verified Dyson Sails: ", renderer.rendered_dyson_sail_count)

	assert(sim.cities_map.size() >= 3, "Expected at least 3 cities")
	assert(sim.codex_theories.size() >= 2, "Expected at least 2 discovered theories in Codex")
	assert(renderer.rendered_actor_count >= 20, "Expected at least 20 living 2D pixel actors")
	assert(renderer.rendered_building_count >= 5, "Expected 2D city building instances")
	assert(renderer.rendered_dyson_sail_count >= 50, "Expected 2D Dyson swarm sail instances")

	# 3. Проверим переключение всех 3 режимов 2D-камеры и вкладок HUD
	for vm in [0, 1, 2, 0]:
		camera.set_view_mode(vm)
		assert(renderer.view_mode == vm, "Renderer view mode switch failed")

	for tab_id in ["alchemy", "life", "lenses", "cosmos"]:
		hud._select_tab(tab_id)
		assert(hud.selected_tab == tab_id, "Tab switch failed: " + tab_id)

	hud.toggle_codex_modal()
	assert(hud._modal_codex.visible, "Codex modal should be visible")
	hud.toggle_laws_modal()
	assert(hud._modal_laws.visible, "Laws modal should be visible")
	hud.toggle_laws_modal()

	# 4. Проверим Хроно-Петлю Сверхновой
	var theories_before: int = sim.codex_theories.size()
	sim.apply_god_power_at_pos(Vector2(960, 540), "power_chrono_supernova")
	assert(sim.chrono_cycle == 2, "Expected chrono_cycle == 2")
	assert(sim.codex_theories.size() > theories_before, "Codex theories should increase on supernova")

	await process_frame
	main_node.free()
	print("=== FULL 2D SANDBOX INTEGRATION SUITE: 100% PASSED! ===")
	quit(0)
