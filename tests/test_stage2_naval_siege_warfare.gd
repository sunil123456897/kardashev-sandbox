extends SceneTree

# ==============================================================================
# ЭТАП 2: 3-УРОВНЕВЫЙ ТЕСТ ЖИВЫХ ВОЙН, МОРСКИХ ДЕСАНТОВ И ОСАД
# Проверяет:
#   1. Автоматический спуск десантного корабля-ковчега (transport) при объявлении войны
#   2. Корабельный обстрел вражеского берега по параболической дуге при подходе к острову
#   3. Физическую высадку штурмового легиона (4 морпеха + генерал) на вражеский пляж
#   4. Осаду полиса: тряску и дым горящих зданий, клеточные пожары, захват зоны 8x8 и индикатор «ШТУРМ %»
#   5. GPU-раскадровку морского вторжения из 3 кадров (Отплытие -> Обстрел в проливе -> Десант и пожар осады)
# ==============================================================================

var _passed: int = 0
var _failed: int = 0


func _check(cond: bool, msg: String) -> void:
	if cond:
		_passed += 1
		print("  [PASS] " + msg)
	else:
		_failed += 1
		printerr("  [FAIL] " + msg)


func _initialize() -> void:
	print("==================================================================")
	print("  RUNNING STAGE 2 SUITE: NAVAL AMPHIBIOUS INVASIONS & LIVE SIEGES")
	print("==================================================================")
	_run_suite()


func _crop_view(full_img: Image, center: Vector2, crop_w: int = 640, crop_h: int = 440) -> Image:
	var rx: int = clampi(int(center.x) - crop_w / 2, 0, maxi(0, full_img.get_width() - crop_w))
	var ry: int = clampi(int(center.y) - crop_h / 2, 0, maxi(0, full_img.get_height() - crop_h))
	return full_img.get_region(Rect2i(rx, ry, crop_w, crop_h))


func _run_suite() -> void:
	var main_packed: PackedScene = load("res://scenes/main.tscn")
	var main_node: Node = main_packed.instantiate()
	root.add_child(main_node)

	await process_frame
	await process_frame

	var sim = main_node.get("sim")
	var renderer = main_node.get("renderer")
	var hud = main_node.get("hud")
	_check(sim != null and renderer != null, "Main scene initialized with sim and renderer")

	if hud != null and hud.get("_panels_visible"):
		hud.toggle_side_panels()
	renderer.set_view_mode(0)

	var c_ids: Array = sim.cities_map.keys()
	_check(c_ids.size() >= 2, "At least 2 cities exist for naval war test")
	var id_a: int = int(c_ids[0])
	var id_b: int = int(c_ids[1])
	var city_a: Dictionary = sim.cities_map[id_a]
	var city_b: Dictionary = sim.cities_map[id_b]

	# Переводим атакующий полис во II Эру, чтобы десант шёл на квантовых ковчегах
	sim.advance_city_to_era(id_a, 2)
	renderer._process(0.95)

	# -------------------------------------------------------------------------
	# КАДР 1: ОБЪЯВЛЕНИЕ ВОЙНЫ И ОТПЛЫТИЕ ШТУРМОВОГО ФЛОТА ИЗ ПОРТА
	# -------------------------------------------------------------------------
	sim.set_diplomacy_status(id_a, id_b, "WAR")
	var war_boat: Dictionary = {}
	for b in sim.boats:
		if int(b.get("city_id", -1)) == id_a and str(b.get("boat_type", "")) == "transport":
			war_boat = b
			break

	_check(not war_boat.is_empty(), "Declaring WAR automatically launches an amphibious transport barge")
	_check(int(war_boat.get("passenger_count", 0)) == 4, "Transport barge carries 4 assault marines (got %d)" % int(war_boat.get("passenger_count", 0)))

	# Сдвигаем корабль чуть от пирса в пролив для наглядного кадра отплытия
	var dock_a: Vector2 = war_boat["pos"]
	var target_b: Vector2 = war_boat["target_pos"]
	war_boat["pos"] = dock_a.lerp(target_b, 0.22)
	renderer._process(0.1)
	renderer.queue_redraw()
	await process_frame
	await process_frame

	var is_gpu: bool = (DisplayServer.get_name() != "headless")
	var abs_dir: String = ProjectSettings.globalize_path("res://screenshots")
	DirAccess.make_dir_recursive_absolute(abs_dir)
	var crop_1: Image = null
	var crop_2: Image = null
	var crop_3: Image = null

	if is_gpu:
		await RenderingServer.frame_post_draw
		var img1: Image = root.get_viewport().get_texture().get_image()
		crop_1 = _crop_view(img1, war_boat["pos"])
		crop_1.save_png(abs_dir.path_join("stage2_1_fleet_embark.png"))
		print("  -> Saved GPU frame 1 (Fleet Embarkation): screenshots/stage2_1_fleet_embark.png")

	# -------------------------------------------------------------------------
	# КАДР 2: ПОДХОД К БЕРЕГУ ВРАГА И КОРАБЕЛЬНЫЙ АРТОБСТРЕЛ С МОРЯ
	# -------------------------------------------------------------------------
	var proj_before: int = sim.total_projectiles_fired
	var dir_ab: Vector2 = (target_b - dock_a).normalized()
	war_boat["pos"] = target_b - dir_ab * 92.0
	war_boat["target_pos"] = target_b
	war_boat["state"] = "SAILING_OUT"
	for _s in range(3):
		war_boat["pos"] = target_b - dir_ab * (85.0 - float(_s) * 12.0)
		war_boat["target_pos"] = target_b
		war_boat["state"] = "SAILING_OUT"
		sim._step_boats(0.18)
		sim._step_projectiles(0.06)
	if renderer._shockwave_lens_rect != null:
		renderer._shockwave_lens_rect.visible = false
	renderer._process(0.05)
	renderer.queue_redraw()
	await process_frame
	await process_frame

	_check(sim.total_projectiles_fired > proj_before,
		"War-barge fires naval bombardment projectiles when approaching enemy coast (%d -> %d)" % [proj_before, sim.total_projectiles_fired])

	if is_gpu:
		await RenderingServer.frame_post_draw
		var img2: Image = root.get_viewport().get_texture().get_image()
		crop_2 = _crop_view(img2, target_b)
		crop_2.save_png(abs_dir.path_join("stage2_2_naval_bombardment.png"))
		print("  -> Saved GPU frame 2 (Naval Bombardment): screenshots/stage2_2_naval_bombardment.png")

	# -------------------------------------------------------------------------
	# КАДР 3: ВЫСАДКА МОРСКОГО ДЕСАНТА, ПОЖАР УКРЕПЛЕНИЙ И ШТУРМ ЗОНЫ
	# -------------------------------------------------------------------------
	var landings_before: int = sim.total_amphibious_landings
	var zones_before: int = sim.total_zones_captured_in_war
	war_boat["pos"] = target_b - dir_ab * 10.0
	war_boat["target_pos"] = target_b
	war_boat["state"] = "SAILING_OUT"
	sim._step_boats(0.25)
	sim._step_actor_combat(0.5)
	# Сбрасываем ослепляющую вспышку линзы, оставляя кольцо ударной волны, дым, пламя и плашку «ШТУРМ %»
	if renderer._shockwave_lens_rect != null:
		renderer._shockwave_lens_rect.visible = false
	renderer._update_multimeshes(0.1)
	renderer.queue_redraw()
	await process_frame
	await process_frame

	_check(sim.total_amphibious_landings > landings_before,
		"Amphibious landing executed on enemy beachhead (total=%d)" % sim.total_amphibious_landings)
	_check(sim.total_zones_captured_in_war > zones_before,
		"Enemy coastal zone captured during landing (%d -> %d)" % [zones_before, sim.total_zones_captured_in_war])
	_check(sim.total_siege_fires_ignited > 0 and sim.active_fire_count > 0,
		"Siege ignited cellular fires on enemy coast (fires=%d)" % sim.active_fire_count)
	_check(sim.active_sieges.size() >= 1,
		"Active siege registered for besieged city (active_sieges=%d)" % sim.active_sieges.size())

	var has_shaking_building := false
	for b_inst in city_b["building_instances"]:
		if float(b_inst.get("hit_shake", 0.0)) > 0.1:
			has_shaking_building = true
	_check(has_shaking_building, "Besieged enemy buildings physically shake and emit smoke/sparks")

	if is_gpu:
		await RenderingServer.frame_post_draw
		var img3: Image = root.get_viewport().get_texture().get_image()
		crop_3 = _crop_view(img3, city_b["map_pos"])
		crop_3.save_png(abs_dir.path_join("stage2_3_landing_and_siege.png"))
		print("  -> Saved GPU frame 3 (Amphibious Landing & Burning Siege): screenshots/stage2_3_landing_and_siege.png")

		if crop_1 != null and crop_2 != null and crop_3 != null:
			var cw: int = crop_1.get_width()
			var ch: int = crop_1.get_height()
			var strip := Image.create(cw * 3 + 16, ch, false, crop_1.get_format())
			strip.fill(Color(0.04, 0.06, 0.10, 1.0))
			strip.blit_rect(crop_1, Rect2i(0, 0, cw, ch), Vector2i(0, 0))
			strip.blit_rect(crop_2, Rect2i(0, 0, cw, ch), Vector2i(cw + 8, 0))
			strip.blit_rect(crop_3, Rect2i(0, 0, cw, ch), Vector2i(cw * 2 + 16, 0))
			strip.save_png(abs_dir.path_join("stage2_storyboard_3frames.png"))
			print("  -> Saved Stage 2 Naval Invasion Storyboard: screenshots/stage2_storyboard_3frames.png")

	print("------------------------------------------------------------------")
	print("  STAGE 2 VERIFICATION SUMMARY: Passed=%d, Failed=%d" % [_passed, _failed])
	print("==================================================================")
	quit(0 if _failed == 0 else 1)
