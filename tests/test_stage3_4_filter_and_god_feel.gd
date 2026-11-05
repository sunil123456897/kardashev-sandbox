extends SceneTree

# ==============================================================================
# E2E & GPU STORYBOARD VERIFICATION: ЭТАП 3 И 4 (ВЕЛИКИЙ ФИЛЬТР + ОЩУЩЕНИЕ БОГА)
# Проверяет:
# 1. Затмение Звезды Сферой Дайсона: остывание незащищённых регионов планеты в крио-тундру
#    и активацию тёплых Термальных Куполов Оазисов над развитыми полисами K-I+.
# 2. Кризис «Великий Фильтр» (Восстание ИИ «Архонт-Омега»): спавн босса К-Титана,
#    заключение Коалиции Выживания (ALLIANCE) и всплывающие Map Event Toast Markers.
# 3. Прямое вселение в Меха-Колосса [WASD + Пробел]: аннигиляционный луч главного
#    калибра, выжигающий кратер и клеточный пожар.
# 4. В GPU-режиме снимает 3-кадровый сториборд screenshots/stage3_4_storyboard_3frames.png.
# ==============================================================================

var _passed: int = 0
var _failed: int = 0


func _assert(cond: bool, msg: String) -> void:
	if cond:
		_passed += 1
		print("  [PASS] " + msg)
	else:
		_failed += 1
		printerr("  [FAIL] " + msg)


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	print("==================================================================")
	print("  TEST STAGE 3 & 4: DYSON ECLIPSE, GREAT FILTER & COLOSSUS LASER  ")
	print("==================================================================")

	var is_headless: bool = DisplayServer.get_name() == "headless"
	if not is_headless:
		DisplayServer.window_set_size(Vector2i(1920, 1080))
		root.content_scale_size = Vector2i(1920, 1080)

	var main_scene: PackedScene = load("res://scenes/main.tscn")
	var main_node: Node = main_scene.instantiate()
	root.add_child(main_node)

	for _i in range(4):
		await process_frame

	var sim: Node = main_node.get("sim")
	var renderer: Node2D = main_node.get("renderer")
	var hud: CanvasLayer = main_node.get("hud")
	_assert(sim != null and renderer != null, "Sim & CosmicRenderer initialized")

	if hud != null:
		hud.visible = false

	var c_ids: Array = sim.cities_map.keys()
	_assert(c_ids.size() >= 2, "At least 2 starter cities exist on the archipelago")
	var cid_a: int = int(c_ids[0])
	var cid_b: int = int(c_ids[1])
	var city_a: Dictionary = sim.cities_map[cid_a]
	var city_b: Dictionary = sim.cities_map[cid_b]
	var pos_a: Vector2 = city_a["map_pos"]
	var pos_b: Vector2 = city_b["map_pos"]
	var mid_pos: Vector2 = (pos_a + pos_b) * 0.5

	if not is_headless:
		DirAccess.make_dir_recursive_absolute("res://screenshots")

	# ==========================================================================
	# КАДР 1: ЗАТМЕНИЕ СФЕРОЙ ДАЙСОНА И ТЕРМАЛЬНЫЕ КУПОЛА ОАЗИСОВ (ЭТАП 3)
	# ==========================================================================
	sim.advance_city_to_era(cid_a, 2)
	city_b["kardashev_level"] = 0.55
	city_b["era"] = 1
	sim._create_dyson_ring(260, city_a["color"])
	sim.dyson_stage = 3
	var frozen_cnt: int = 0
	for _step_i in range(4):
		frozen_cnt += sim.apply_dyson_eclipse_cooling_step(2.0)

	_assert(sim.dyson_planetary_cooling_active, "Stage 3: Dyson eclipse planetary cooling activated")
	_assert(sim.total_eclipse_frozen_tiles >= 20, "Stage 3: Unprotected outer tiles froze into cryo-superconductor (%d frozen)" % sim.total_eclipse_frozen_tiles)
	_assert(bool(city_a.get("thermal_dome_active", false)) and bool(city_a.get("shielded", false)), "Stage 3: Era II city activated Thermal Oasis Shield Dome")
	_assert(not bool(city_b.get("thermal_dome_active", false)), "Stage 3: Era I village lacks Thermal Oasis Shield Dome")

	var crop_1: Image = null
	if not is_headless:
		renderer._active_shockwaves.clear()
		if renderer._shockwave_lens_rect != null:
			renderer._shockwave_lens_rect.visible = false
		renderer._rebuild_pixel_map_texture()
		renderer._update_multimeshes(0.016)
		renderer.queue_redraw()
		for _f in range(5):
			await process_frame
		var img1: Image = root.get_viewport().get_texture().get_image()
		img1.save_png("res://screenshots/stage3_1_dyson_eclipse_domes.png")
		crop_1 = _crop_around(img1, pos_a, Vector2i(640, 360))

	# ==========================================================================
	# КАДР 2: ВЕЛИКИЙ ФИЛЬТР — ВОССТАНИЕ ИИ «АРХОНТ-ОМЕГА» И MAP TOAST MARKERS
	# ==========================================================================
	var boss: Dictionary = sim.trigger_great_filter_crisis(cid_a, "ai_uprising")
	_assert(not boss.is_empty() and bool(boss.get("is_rogue_boss", false)), "Stage 3: Rogue K-Titan Boss 'Archon-Omega' spawned")
	_assert(sim.total_great_filter_crises_triggered >= 1, "Stage 3: Great Filter crisis counter incremented")
	_assert(sim.get_diplomacy_status(cid_a, cid_b) == "ALLIANCE", "Stage 3: All surviving cities formed Grand Coalition (ALLIANCE)")
	_assert(sim.map_event_markers.size() >= 1 and sim.total_map_markers_spawned >= 1, "Stage 4: Map Event Toast Markers spawned on map (%d markers)" % sim.map_event_markers.size())
	var clicked_marker: Dictionary = sim.get_clicked_map_event_marker(boss["pos"] + Vector2(0.0, -26.0), 64.0)
	_assert(not clicked_marker.is_empty(), "Stage 4: Map Event Toast Marker is clickable at its world coordinates")

	var crop_2: Image = null
	if not is_headless:
		renderer._active_shockwaves.clear()
		if renderer._shockwave_lens_rect != null:
			renderer._shockwave_lens_rect.visible = false
		renderer._update_multimeshes(0.016)
		renderer.queue_redraw()
		for _f in range(5):
			await process_frame
		var img2: Image = root.get_viewport().get_texture().get_image()
		img2.save_png("res://screenshots/stage3_2_great_filter_boss.png")
		crop_2 = _crop_around(img2, boss["pos"], Vector2i(640, 360))

	# ==========================================================================
	# КАДР 3: ПРЯМОЕ ВСЕЛЕНИЕ В МЕХА-КОЛОССА И ЗАЛП ГЛАВНОГО КАЛИБРА (ЭТАП 4)
	# ==========================================================================
	var hero_colossus: Dictionary = sim.spawn_kardashev_colossus(pos_b + Vector2(-42.0, 12.0))
	_assert(sim.controlled_actor_id == int(hero_colossus["id"]), "Stage 4: Player possessed Hero Mecha-Colossus")
	var old_pos: Vector2 = hero_colossus["pos"]
	var target_strike_pos: Vector2 = pos_b + Vector2(36.0, -8.0)
	var stepped_ok: bool = sim.step_controlled_actor(Vector2(1.0, 0.0), 0.20, true, target_strike_pos)
	_assert(stepped_ok and (hero_colossus["pos"] as Vector2).distance_to(old_pos) > 5.0, "Stage 4: Possessed Mecha-Colossus moved via WASD input")
	_assert(sim.total_colossus_laser_strikes >= 1 and sim.active_colossus_beams.size() >= 1, "Stage 4: Mecha-Colossus fired Main Caliber Annihilation Laser Beam")
	_assert(sim.active_fire_count > 0 and sim.has_fine_elevation_deltas, "Stage 4: Main Caliber Laser carved scorched crater and ignited plasma fire")

	var crop_3: Image = null
	if not is_headless:
		renderer._active_shockwaves.clear()
		if renderer._shockwave_lens_rect != null:
			renderer._shockwave_lens_rect.visible = false
		renderer._rebuild_pixel_map_texture()
		renderer._update_multimeshes(0.016)
		renderer.queue_redraw()
		for _f in range(5):
			await process_frame
		var img3: Image = root.get_viewport().get_texture().get_image()
		img3.save_png("res://screenshots/stage4_3_colossus_laser_strike.png")
		crop_3 = _crop_around(img3, pos_b, Vector2i(640, 360))

	if not is_headless and crop_1 != null and crop_2 != null and crop_3 != null:
		crop_1.resize(1280, 720, Image.INTERPOLATE_NEAREST)
		crop_2.resize(1280, 720, Image.INTERPOLATE_NEAREST)
		crop_3.resize(1280, 720, Image.INTERPOLATE_NEAREST)
		var storyboard := Image.create(3840, 720, false, crop_1.get_format())
		storyboard.blit_rect(crop_1, Rect2i(0, 0, 1280, 720), Vector2i(0, 0))
		storyboard.blit_rect(crop_2, Rect2i(0, 0, 1280, 720), Vector2i(1280, 0))
		storyboard.blit_rect(crop_3, Rect2i(0, 0, 1280, 720), Vector2i(2560, 0))
		for y in range(720):
			for dx in range(-3, 4):
				storyboard.set_pixel(1280 + dx, y, Color(0.25, 0.92, 1.0))
				storyboard.set_pixel(2560 + dx, y, Color(1.0, 0.25, 0.32))
		storyboard.save_png("res://screenshots/stage3_4_storyboard_3frames.png")
		print("  [STORYBOARD SAVED] res://screenshots/stage3_4_storyboard_3frames.png (3840x720)")

	print("==================================================================")
	print("  RESULT: Passed=%d, Failed=%d" % [_passed, _failed])
	print("==================================================================")
	quit(0 if _failed == 0 else 1)


func _crop_around(img: Image, center: Vector2, sz: Vector2i) -> Image:
	var cx: int = clampi(int(center.x) - sz.x / 2, 0, img.get_width() - sz.x)
	var cy: int = clampi(int(center.y) - sz.y / 2, 0, img.get_height() - sz.y)
	return img.get_region(Rect2i(cx, cy, sz.x, sz.y))
