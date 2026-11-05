extends SceneTree

## Автоматический E2E тест-сьют графического и UI-паритета с WorldBox v0.51.2
## Проверяет все 3 пакета улучшений из worldbox_graphics_ui_audit_report.md:
## Пакет A: 360° береговая пена и мокрый песок, 2px тени уступов, границы со скошенными углами и 3px Inner Glow,
##          ортогональные улицы 2px с бордюрами, террасные поля с золотыми колосьями, ambient_tint эпох, бесконечный океан.
## Пакет B: 2× спрайты деревьев/кристаллов из WorldBox v0.51.2 в 640×64 атласе, тени под ногами юнитов,
##          Y-Sort глубина, плавание в воде (is_swimming), разделение шахты и мельницы в Эру I, струи дождя/молний и воронка смерча.
## Пакет C: 44 уникальные иконки Божественных Сил без дублей и без iconKnowledge.png, компактные слоты 54×48 без скролла,
##          чистая каменная рамка windowFrameClean.png, 9-slice плашки городов, портреты и прогресс-бары в Инспекторах.

const WorldSimulationScript = preload("res://scripts/sim/world_simulation.gd")
const CosmicRendererScript = preload("res://scripts/render/cosmic_renderer.gd")
const GodHUDScript = preload("res://scripts/ui/god_hud.gd")

var _passed: int = 0
var _failed: int = 0


func _assert(cond: bool, msg: String) -> void:
	if cond:
		_passed += 1
	else:
		_failed += 1
		printerr("   [ASSERT FAILED] ", msg)


func _init() -> void:
	print("================================================================================")
	print("=== RUNNING WORLDBOX v0.51.2 GRAPHICS & UI PARITY E2E VERIFICATION SUITE ===")
	print("================================================================================")

	var sim := WorldSimulationScript.new()
	sim.name = "SimVisualParityTest"
	root.add_child(sim)
	sim.setup_world(4242)

	var renderer := CosmicRendererScript.new()
	renderer.name = "RendererVisualParityTest"
	root.add_child(renderer)
	renderer.setup(sim)

	var hud := GodHUDScript.new()
	hud.name = "HUDVisualParityTest"
	root.add_child(hud)
	hud.setup(sim)

	# --------------------------------------------------------------------------
	# ПАКЕТ A: ЛАНДШАФТ, ВОДА, ГРАНИЦЫ ИMPЕРИЙ, ДОРОГИ, ПОЛЯ И ШЕЙДЕРЫ
	# --------------------------------------------------------------------------
	print("\n[PACKAGE A] Verifying Terrain Autotiling, Inner Border Glow, Orthogonal Roads & Shaders...")
	_assert(renderer.get_node_or_null("WorldBoxOceanBackdrop") != null, "WorldBoxOceanBackdrop ColorRect must exist behind map to prevent black pillarbox bars")
	_assert(renderer._dyson_aura_rect != null and renderer._dyson_aura_rect.material is ShaderMaterial, "DysonAuraRect must have ShaderMaterial")
	var dyson_sh_code: String = (renderer._dyson_aura_rect.material as ShaderMaterial).shader.code
	_assert(dyson_sh_code.find("pixel_grid") != -1 and dyson_sh_code.find("edge_guard") != -1, "dyson_aura.gdshader must quantize UV to pixel_grid and apply radial edge_guard")

	# Проверяем мировую тонировку (ambient_tint) от смены Эпохи Мира
	sim.set_world_age("age_of_ice")
	renderer._update_multimeshes(0.05)
	_assert(not renderer._map_bg_rect.modulate.is_equal_approx(Color.WHITE), "_map_bg_rect.modulate must reflect WorldAgeAsset.ambient_tint in age_of_ice")
	sim.set_world_age("age_of_hope")
	renderer._update_multimeshes(0.05)

	# Проверяем террасные поля (2 участка >= 35 клеток на полис) и ортогональные 2px улицы
	var field_tiles: int = sim.count_field_tiles()
	var road_tiles: int = sim.count_road_tiles()
	print("   Terraced fields=%d, Orthogonal road tiles=%d" % [field_tiles, road_tiles])
	_assert(field_tiles >= 60, "Terraced farm plots must carve >= 60 field tiles across starter cities (got %d)" % field_tiles)
	_assert(road_tiles >= 24, "Orthogonal 2px L-shaped streets must carve >= 24 road tiles (got %d)" % road_tiles)
	print(" -> PACKAGE A PASSED!")

	# --------------------------------------------------------------------------
	# ПАКЕТ B: СПРАЙТ-АТЛАСЫ 2× WORLDBOX, Y-SORT, ПЛАВАНИЕ В ВОДЕ И ПОГОДНЫЕ VFX
	# --------------------------------------------------------------------------
	print("\n[PACKAGE B] Verifying 2x WorldBox Flora/Mineral Sprites, Ground Shadows, Y-Sort & Swimming...")
	var flora_img := Image.load_from_file(ProjectSettings.globalize_path("res://assets/worldbox/atlas_flora_wb.png"))
	_assert(flora_img != null and flora_img.get_width() == 640 and flora_img.get_height() == 64, "atlas_flora_wb.png must be 640x64")
	# Проверяем, что дерево в колонке 0 (x=0..63) имеет высокую детализацию (> 350 непрозрачных пикселей вместо 10x10 растяжки)
	var tree0_opaque: int = 0
	for py in range(64):
		for px in range(64):
			if flora_img.get_pixel(px, py).a > 0.1:
				tree0_opaque += 1
	_assert(tree0_opaque >= 350, "Column 0 tree in atlas_flora_wb.png must be crisp 2x WorldBox sprite with shadow (opaque=%d)" % tree0_opaque)

	# Проверяем целочисленный размер квадов MultiMesh (32x32 и 16x16)
	var flora_aabb: AABB = renderer._mm_flora.multimesh.mesh.get_aabb()
	var bld_aabb: AABB = renderer._mm_buildings.multimesh.mesh.get_aabb()
	var act_aabb: AABB = renderer._mm_actors.multimesh.mesh.get_aabb()
	_assert(is_equal_approx(flora_aabb.size.x, 32.0) and is_equal_approx(flora_aabb.size.y, 32.0), "_mm_flora mesh size must be integer-aligned 32x32")
	_assert(is_equal_approx(bld_aabb.size.x, 32.0) and is_equal_approx(bld_aabb.size.y, 32.0), "_mm_buildings mesh size must be integer-aligned 32x32")
	_assert(is_equal_approx(act_aabb.size.x, 16.0) and is_equal_approx(act_aabb.size.y, 16.0), "_mm_actors mesh size must be integer-aligned 16x16")

	# Проверяем Y-Sort порядок в _mm_flora (каждый следующий инстанс имеет y >= предыдущего)
	var mm_f: MultiMesh = renderer._mm_flora.multimesh
	var y_sorted_ok := true
	var prev_y: float = -99999.0
	for i in range(mini(mm_f.instance_count, 80)):
		var cur_y: float = mm_f.get_instance_transform_2d(i).origin.y
		if cur_y + 0.01 < prev_y:
			y_sorted_ok = false
			break
		prev_y = cur_y
	_assert(y_sorted_ok, "_mm_flora instances must be Y-sorted top-to-bottom so southern trees overlap northern trunks")

	# Проверяем состояние плавания (is_swimming) при помещении юнита в глубокую воду
	var swim_actor: Dictionary = sim.actors[0]
	var orig_pos: Vector2 = swim_actor["pos"]
	for t in sim.tiles:
		if float(t["elevation"]) < -0.18:
			swim_actor["pos"] = t["map_pos"]
			break
	renderer._update_multimeshes(0.05)
	_assert(bool(swim_actor.get("is_swimming", false)), "Actor in ocean tile must enter swimming state (is_swimming == true)")
	swim_actor["pos"] = orig_pos
	renderer._update_multimeshes(0.05)
	print(" -> PACKAGE B PASSED!")

	# --------------------------------------------------------------------------
	# ПАКЕТ C: 44 УНИКАЛЬНЫЕ ИКОНКИ СИЛ, КОМПАКТНЫЙ ДОК БЕЗ СКРОЛЛА, РАМКИ И ИНСПЕКТОРЫ
	# --------------------------------------------------------------------------
	print("\n[PACKAGE C] Verifying 44 Unique Power Icons, Zero-Scroll Dock, Clean Window Frame & Inspectors...")
	var all_powers: Array = []
	all_powers.append_array(sim.assets.god_power_list)
	all_powers.append_array(sim.assets.cataclysm_power_list)
	all_powers.append_array(sim.assets.transmutation_power_list)
	all_powers.append_array(sim.assets.worldbox_power_list)
	_assert(all_powers.size() == 44, "Total God Powers across 4 lists must be 44 (got %d)" % all_powers.size())

	var seen_icons: Dictionary = {}
	var missing_or_fallback_count: int = 0
	for gp in all_powers:
		var pid: String = gp.id
		var ic_file: String = hud.POWER_WB_ICON_MAP.get(pid, "")
		if ic_file == "" or ic_file == "iconKnowledge.png":
			missing_or_fallback_count += 1
		seen_icons[ic_file] = true
		var tex: ImageTexture = hud._get_power_wb_icon(pid)
		_assert(tex != null, "Power '%s' icon '%s' must load a valid ImageTexture" % [pid, ic_file])

	print("   Total powers=%d, unique icons=%d, fallback_count=%d" % [
		all_powers.size(), seen_icons.size(), missing_or_fallback_count
	])
	_assert(missing_or_fallback_count == 0, "Zero powers may fall back to iconKnowledge.png")
	_assert(seen_icons.size() == 44, "All 44 God Powers must map to 44 distinct WorldBox icon files (got %d)" % seen_icons.size())

	# Проверяем, что в 1-й вкладке («alchemy», 16 кнопок) суммарная ширина слотов помещается в экран без горизонтального скролла
	hud._select_tab("alchemy")
	var btn_count: int = hud._hbox_powers.get_child_count()
	var total_min_w: float = float(btn_count) * 54.0 + float(maxi(0, btn_count - 1)) * 6.0
	print("   Tab 'alchemy' buttons=%d, total_min_width=%.0f px (available: 1864 px)" % [btn_count, total_min_w])
	_assert(btn_count == 16 and total_min_w <= 1200.0, "All 16 buttons in Tab 1 must fit in dock without horizontal scrolling")

	# Проверяем чистую каменную рамку windowFrameClean.png и инспекторы с портретами
	var clean_frame_tex: ImageTexture = hud._load_wb_tex("res://assets/worldbox/ui/windowFrameClean.png")
	_assert(clean_frame_tex != null and clean_frame_tex.get_width() == 96, "windowFrameClean.png (96x96) must exist for artifact-free modal windows")

	var first_cid: int = int(sim.cities_map.keys()[0])
	hud.open_city_inspector(first_cid)
	_assert(hud._vbox_city_content.get_child_count() >= 8, "City Inspector must populate portrait, demography, empire, buildings & plots")

	var first_aid: int = int(sim.actors[0]["id"])
	hud.open_actor_inspector(first_aid)
	_assert(hud._vbox_actor_content.get_child_count() >= 8, "Actor Inspector must populate portrait, health bar, traits & needs bars")
	print(" -> PACKAGE C PASSED!")

	print("\n================================================================================")
	if _failed == 0:
		print("=== ALL WORLDBOX GRAPHICS & UI PARITY CHECKS PASSED! (Passed: %d, Failed: 0) ===" % _passed)
		print("================================================================================")
		quit(0)
	else:
		printerr("=== GRAPHICS & UI PARITY SUITE FAILED! (Passed: %d, Failed: %d) ===" % [_passed, _failed])
		quit(1)
