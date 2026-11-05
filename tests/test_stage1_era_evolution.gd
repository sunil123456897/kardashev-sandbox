extends SceneTree

# ==============================================================================
# ЭТАП 1: 3-УРОВНЕВЫЙ ТЕСТ ВИЗУАЛЬНОЙ ЭВОЛЮЦИИ ЭПОХ (WORLDBOX -> K-I -> K-II..III)
# Проверяет:
#   1. 12-колоночный атлас зданий (768x64: 0..3 Эра I, 4..7 Эра II, 8..11 Эра III)
#   2. Эволюцию дорог (грунтовая мостовая #C1997C -> квантовая магистраль fine_road_overlay == 4)
#   3. Эволюцию морского флота (деревянный парусник Эры I -> 8-направленный ковчег Эры II+)
#   4. Покадровый GPU-сториборд одного и того же полиса в Эре I, Эре II и Эре III
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
	print("  RUNNING STAGE 1 SUITE: VISUAL ERA EVOLUTION (I -> II -> III)")
	print("==================================================================")
	_run_suite()


func _crop_city_view(full_img: Image, center: Vector2, crop_w: int = 640, crop_h: int = 440) -> Image:
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

	# 1. Проверка 12-колоночного атласа зданий
	var wb_bld_img := Image.new()
	var err_img := wb_bld_img.load(ProjectSettings.globalize_path("res://assets/worldbox/atlas_buildings_wb.png"))
	_check(err_img == OK and wb_bld_img.get_width() == 768 and wb_bld_img.get_height() == 64,
		"Multi-Era Building Atlas is 768x64 (12 columns of 64x64)")
	var sh_cols: float = float(renderer._mm_buildings_material.get_shader_parameter("atlas_cols"))
	_check(is_equal_approx(sh_cols, 12.0), "MultiMeshBuildings shader uses atlas_cols == 12.0 (got %.1f)" % sh_cols)

	var c_ids: Array = sim.cities_map.keys()
	_check(c_ids.size() >= 2, "At least 2 starter cities exist")
	var cid: int = int(c_ids[0])
	var city: Dictionary = sim.cities_map[cid]
	var c_pos: Vector2 = city["map_pos"]

	# Скрываем боковые панели, чтобы сделать чистый сториборд карты
	if hud != null and hud.get("_panels_visible"):
		hud.toggle_side_panels()
	renderer.set_view_mode(0)

	# -------------------------------------------------------------------------
	# КАДР 1: ЭРА I — ДОИНДУСТРИАЛЬНАЯ КОЛЫБЕЛЬ WORLDBOX (K = 0.50)
	# -------------------------------------------------------------------------
	sim.advance_city_to_era(cid, 1)
	sim.step_simulation(0.5)
	for b_inst in city["building_instances"]:
		b_inst["spawn_spring"] = 1.0
	renderer._process(0.95)
	renderer._update_multimeshes(0.2)
	renderer.queue_redraw()
	await process_frame
	await process_frame

	_check(sim.get_city_era(cid) == 1, "City #%d starts in Era I (K=%.2f)" % [cid, float(city["kardashev_level"])])
	_check(sim.count_road_tiles() >= 9, "Era I city has cobblestone/dirt roads (%d tiles)" % sim.count_road_tiles())
	_check(sim.count_cyber_road_tiles() == 0, "Era I city has 0 cyber-conduit highways initially")

	# Проверяем, что MultiMesh зданий для полиса в Эре I использует колонки 0..3 (деревня WorldBox)
	var mm_b: MultiMesh = renderer._mm_buildings.multimesh
	var era1_cols_valid := true
	var era1_b_count: int = (city["building_instances"] as Array).size()
	for i in range(mini(era1_b_count, mm_b.instance_count)):
		var c_data: Color = mm_b.get_instance_custom_data(i)
		if c_data.a < 0.0 or c_data.a > 3.5:
			era1_cols_valid = false
	_check(era1_cols_valid and era1_b_count >= 4, "Era I city buildings use WorldBox village atlas columns 0..3 (%d instances)" % era1_b_count)

	var is_gpu: bool = (DisplayServer.get_name() != "headless")
	var crop_era1: Image = null
	var crop_era2: Image = null
	var crop_era3: Image = null
	var abs_dir: String = ProjectSettings.globalize_path("res://screenshots")
	DirAccess.make_dir_recursive_absolute(abs_dir)

	if is_gpu:
		await RenderingServer.frame_post_draw
		var img1: Image = root.get_viewport().get_texture().get_image()
		crop_era1 = _crop_city_view(img1, c_pos)
		crop_era1.save_png(abs_dir.path_join("stage1_era1_village.png"))
		print("  -> Saved GPU frame 1 (Era I Village): screenshots/stage1_era1_village.png")

	# -------------------------------------------------------------------------
	# КАДР 2: ЭРА II — ПЛАНЕТАРНЫЙ СИНТЕЗ K-I (K = 0.90, купола + квантовые дороги + баржи)
	# -------------------------------------------------------------------------
	sim.advance_city_to_era(cid, 2)
	for b_inst in city["building_instances"]:
		b_inst["spawn_spring"] = 1.0
	renderer._process(0.95)
	renderer._update_multimeshes(0.2)
	renderer.queue_redraw()
	await process_frame
	await process_frame

	_check(sim.get_city_era(cid) == 2, "City #%d transitioned to Era II (K=%.2f)" % [cid, float(city["kardashev_level"])])
	var cyber_roads_era2: int = sim.count_cyber_road_tiles()
	_check(cyber_roads_era2 >= 9, "Era II city paved glowing Cyber-Conduit Highways (%d tiles)" % cyber_roads_era2)

	var center_px: int = clampi(int(c_pos.x / sim.MAP_PIXEL_W * float(sim.FINE_W)), 2, sim.FINE_W - 3)
	var center_py: int = clampi(int(c_pos.y / sim.MAP_PIXEL_H * float(sim.FINE_H)), 2, sim.FINE_H - 3)
	var sample_center: Dictionary = sim.sample_fine_world_tile(center_px, center_py)
	_check(bool(sample_center.get("has_cyber_road", false)), "sample_fine_world_tile reports has_cyber_road == true on Era II plaza")

	var era2_has_kardashev_cols := false
	var era2_b_count: int = (city["building_instances"] as Array).size()
	for i in range(mini(era2_b_count, mm_b.instance_count)):
		var c_data2: Color = mm_b.get_instance_custom_data(i)
		if c_data2.a >= 4.0 and c_data2.a <= 7.5:
			era2_has_kardashev_cols = true
	_check(era2_has_kardashev_cols, "Era II city buildings switched to Kardashev Planetary columns 4..7")

	var boat_upgraded := false
	for b in sim.boats:
		if int(b.get("city_id", -1)) == cid and int(b.get("era", 1)) >= 2:
			boat_upgraded = true
	_check(boat_upgraded, "City naval fleet upgraded from wooden ship to Era II hover-barge")

	if is_gpu:
		await RenderingServer.frame_post_draw
		var img2: Image = root.get_viewport().get_texture().get_image()
		crop_era2 = _crop_city_view(img2, c_pos)
		crop_era2.save_png(abs_dir.path_join("stage1_era2_domes.png"))
		print("  -> Saved GPU frame 2 (Era II Planetary Domes): screenshots/stage1_era2_domes.png")

	# -------------------------------------------------------------------------
	# КАДР 3: ЭРА III — ЗВЁЗДНАЯ ИНЖЕНЕРИЯ K-II..III (K = 1.38, лифт + якорь + матрёшка)
	# -------------------------------------------------------------------------
	var sails_before: int = sim.total_dyson_sails
	sim.advance_city_to_era(cid, 3)
	for b_inst in city["building_instances"]:
		b_inst["spawn_spring"] = 1.0
	renderer._process(0.95)
	renderer._update_multimeshes(0.2)
	renderer.queue_redraw()
	await process_frame
	await process_frame

	_check(sim.get_city_era(cid) == 3, "City #%d transitioned to Era III (K=%.2f)" % [cid, float(city["kardashev_level"])])
	_check(sim.total_dyson_sails > sails_before, "Era III transition launched Dyson Swarm sails (%d -> %d)" % [sails_before, sim.total_dyson_sails])

	var era3_has_stellar_cols := false
	var era3_b_count: int = (city["building_instances"] as Array).size()
	for i in range(mini(era3_b_count, mm_b.instance_count)):
		var c_data3: Color = mm_b.get_instance_custom_data(i)
		if c_data3.a >= 8.0 and c_data3.a <= 11.5:
			era3_has_stellar_cols = true
	_check(era3_has_stellar_cols, "Era III city buildings include Stellar Megastructure columns 8..11")

	if is_gpu:
		await RenderingServer.frame_post_draw
		var img3: Image = root.get_viewport().get_texture().get_image()
		crop_era3 = _crop_city_view(img3, c_pos)
		crop_era3.save_png(abs_dir.path_join("stage1_era3_stellar.png"))
		print("  -> Saved GPU frame 3 (Era III Stellar Megastructures): screenshots/stage1_era3_stellar.png")

		if crop_era1 != null and crop_era2 != null and crop_era3 != null:
			var cw: int = crop_era1.get_width()
			var ch: int = crop_era1.get_height()
			var strip := Image.create(cw * 3 + 16, ch, false, crop_era1.get_format())
			strip.fill(Color(0.04, 0.06, 0.10, 1.0))
			strip.blit_rect(crop_era1, Rect2i(0, 0, cw, ch), Vector2i(0, 0))
			strip.blit_rect(crop_era2, Rect2i(0, 0, cw, ch), Vector2i(cw + 8, 0))
			strip.blit_rect(crop_era3, Rect2i(0, 0, cw, ch), Vector2i(cw * 2 + 16, 0))
			strip.save_png(abs_dir.path_join("stage1_storyboard_3eras.png"))
			print("  -> Saved 3-Era Comparison Storyboard: screenshots/stage1_storyboard_3eras.png")

	print("------------------------------------------------------------------")
	print("  STAGE 1 VERIFICATION SUMMARY: Passed=%d, Failed=%d" % [_passed, _failed])
	print("==================================================================")
	quit(0 if _failed == 0 else 1)
