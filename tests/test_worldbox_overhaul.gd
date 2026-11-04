extends SceneTree

## Автоматический тест-сьют апгрейда «WorldBox v0.51.2 Overhaul» (Блоки 1, 2, 3):
## 1. WorldBox Terrain 384×216 (TileLibrary + TopTileLibrary DLL палитры, 4-bit пена, 2.5D тени уступов).
## 2. MultiMeshInstance2D (_mm_flora, _mm_buildings, _mm_actors) + worldbox_multimesh.gdshader + физические частицы с гравитацией.
## 3. Квадратные зоны городов 8×8 (TileZone), дороги (#C1997C), поля (#A8663A) и цикл работ жителей (CitizenJobLibrary).

const WorldSimulationScript = preload("res://scripts/sim/world_simulation.gd")
const CosmicRendererScript = preload("res://scripts/render/cosmic_renderer.gd")

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
	print("=== RUNNING WORLDBOX v0.51.2 OVERHAUL VERIFICATION SUITE (BLOCKS 1, 2, 3) ===")
	print("================================================================================")

	var sim := WorldSimulationScript.new()
	sim.name = "WorldSimWBTest"
	root.add_child(sim)
	sim.setup_world(4242)

	var renderer := CosmicRendererScript.new()
	renderer.name = "CosmicRendererWBTest"
	root.add_child(renderer)
	renderer.setup(sim)

	# --------------------------------------------------------------------------
	# БЛОК 1: WORLDBOX TERRAIN 384×216, ПАЛИТРЫ DLL, АВТОТАЙЛИНГ И ТЕНИ ВЫСОТ
	# --------------------------------------------------------------------------
	print("\n[BLOCK 1] Verifying WorldBox v0.51.2 TileLibrary & TopTileLibrary Terrain...")
	_assert(sim.FINE_W == 384 and sim.FINE_H == 216, "Fine WorldTile grid must be 384x216")
	_assert(sim.FINE_COUNT == 82944, "FINE_COUNT must be 82,944 fine tiles")
	_assert(sim.CHUNK_SIZE == 16, "MapChunk size must be 16x16 fine tiles")

	var required_base_tiles := [
		"deep_ocean", "close_ocean", "shallow_waters", "sand",
		"soil_low", "soil_high", "hills", "mountains", "summit",
		"road", "field", "wall_order", "lava0", "lava1"
	]
	for bt_id in required_base_tiles:
		_assert(sim.assets.base_tiles.has(bt_id), "TileLibrary must register base tile: " + bt_id)

	_assert(sim.assets.base_tiles["deep_ocean"].color.is_equal_approx(Color.html("#3370CC")), "deep_ocean must match #3370CC")
	_assert(sim.assets.base_tiles["shallow_waters"].color.is_equal_approx(Color.html("#55AEF0")), "shallow_waters must match #55AEF0")
	_assert(sim.assets.base_tiles["sand"].color.is_equal_approx(Color.html("#F7E898")), "sand must match #F7E898")
	_assert(sim.assets.base_tiles["road"].color.is_equal_approx(Color.html("#C1997C")), "road must match #C1997C")
	_assert(sim.assets.base_tiles["field"].color.is_equal_approx(Color.html("#A8663A")), "field must match #A8663A")

	var grass_biome = sim.assets.biomes.get("biome_primordial_ocean")
	_assert(grass_biome != null, "biome_primordial_ocean must exist")
	_assert(grass_biome.base_color_low.is_equal_approx(Color.html("#7EAF46")), "grass_low must match #7EAF46")
	_assert(grass_biome.base_color_high.is_equal_approx(Color.html("#5F833C")), "grass_high must match #5F833C")

	var cliff_shadow_count: int = 0
	var shoreline_foam_count: int = 0
	var wet_sand_count: int = 0
	var zone_border_count: int = 0
	for py in range(16, sim.FINE_H - 16, 4):
		for px in range(24, sim.FINE_W - 24, 4):
			var ft: Dictionary = sim.sample_fine_world_tile(px, py)
			if bool(ft["has_cliff_shadow"]):
				cliff_shadow_count += 1
			if bool(ft["is_shoreline_foam"]):
				shoreline_foam_count += 1
			if bool(ft["is_wet_sand"]):
				wet_sand_count += 1
			if bool(ft["is_zone_border"]):
				zone_border_count += 1

	print("   Sampled terrain features -> cliff_shadows=%d, shoreline_foam=%d, wet_sand=%d, zone_borders=%d" % [
		cliff_shadow_count, shoreline_foam_count, wet_sand_count, zone_border_count
	])
	_assert(cliff_shadow_count > 10, "Terrain must produce 2.5D cliff drop-shadows on elevation steps")
	_assert(shoreline_foam_count > 5, "Terrain must produce 4-bit shoreline foam around islands")
	_assert(wet_sand_count > 5, "Terrain must produce wet sand transitions along beaches")
	_assert(zone_border_count > 5, "Terrain must produce 8x8 TileZone kingdom borders")
	print(" -> BLOCK 1 PASSED!")

	# --------------------------------------------------------------------------
	# БЛОК 2: MULTIMESHINSTANCE2D, ШЕЙДЕРЫ ПРУЖИНЫ/ВЕТРА И ФИЗИЧЕСКИЕ ЧАСТИЦЫ
	# --------------------------------------------------------------------------
	print("\n[BLOCK 2] Verifying MultiMeshInstance2D Layers, Shader & Gravity Debris...")
	_assert(renderer._mm_flora != null and renderer._mm_flora.multimesh != null, "_mm_flora MultiMeshInstance2D must be initialized")
	_assert(renderer._mm_buildings != null and renderer._mm_buildings.multimesh != null, "_mm_buildings MultiMeshInstance2D must be initialized")
	_assert(renderer._mm_actors != null and renderer._mm_actors.multimesh != null, "_mm_actors MultiMeshInstance2D must be initialized")
	_assert(renderer._mm_flora.material is ShaderMaterial, "_mm_flora must use worldbox_multimesh.gdshader")
	_assert(renderer._mm_buildings.material is ShaderMaterial, "_mm_buildings must use worldbox_multimesh.gdshader")
	_assert(renderer._mm_actors.material is ShaderMaterial, "_mm_actors must use worldbox_multimesh.gdshader")

	_assert(renderer._atlas_flora_tex != null and renderer._atlas_flora_tex.get_width() == 100, "Flora strip atlas must be 100x10 (10 sprites)")
	_assert(renderer._atlas_building_tex != null and renderer._atlas_building_tex.get_width() == 96, "Building strip atlas must be 96x12 (8 sprites)")
	_assert(renderer._atlas_actor_tex != null and renderer._atlas_actor_tex.get_width() == 100, "Actor strip atlas must be 100x10 (10 sprites)")

	_assert(renderer._mm_flora.multimesh.instance_count == sim.flora_instances.size(), "_mm_flora instance_count must match flora_instances.size()")
	_assert(renderer._mm_flora.multimesh.instance_count >= 120, "World must have >= 120 fine-grid flora & mineral instances")
	_assert(renderer._mm_buildings.multimesh.instance_count >= 2, "_mm_buildings must have >= 2 initial founding city hubs")
	_assert(renderer._mm_actors.multimesh.instance_count == sim.actors.size(), "_mm_actors instance_count must match sim.actors.size()")

	# Проверяем физику частиц с гравитацией и отскоком от ground_y
	renderer._particles.clear()
	renderer._on_god_impact_2d(Vector2(960.0, 540.0), 80.0, Color.ORANGE, "power_antimatter")
	_assert(renderer._particles.size() == 28, "God impact must spawn 28 physical pixel debris particles")
	var p0_vel_y_before: float = (renderer._particles[0]["vel"] as Vector2).y
	renderer._process(0.05)
	var p0_vel_y_after: float = (renderer._particles[0]["vel"] as Vector2).y
	_assert(p0_vel_y_after > p0_vel_y_before, "Gravity must accelerate debris particles downward (vel.y increased)")
	print(" -> BLOCK 2 PASSED!")

	# --------------------------------------------------------------------------
	# БЛОК 3: ЗОНЫ 8×8 (TILEZONE), ДОРОГИ, ПОЛЯ И РАБОТЫ ЖИТЕЛЕЙ (ACTORJOBLIBRARY)
	# --------------------------------------------------------------------------
	print("\n[BLOCK 3] Verifying 8x8 City Zones, Roads, Farm Fields & Citizen Job Loop...")
	_assert(sim.ZONE_SIZE == 8 and sim.ZONE_W == 48 and sim.ZONE_H == 27, "TileZone grid must be 48x27 zones of 8x8 fine tiles")
	_assert(sim.zone_city_id.size() == 1296, "zone_city_id must track all 1,296 TileZones")

	var total_claimed_zones: int = 0
	for c_id in sim.cities_map.keys():
		var city: Dictionary = sim.cities_map[c_id]
		var cz: Array = city.get("claimed_zones", [])
		total_claimed_zones += cz.size()
		_assert(city.has("storage"), "City must have resource storage dictionary (wood, minerals, food)")

	_assert(total_claimed_zones >= 16, "Cities must claim 8x8 TileZone blocks (got %d)" % total_claimed_zones)

	var road_tiles_cnt: int = sim.count_road_tiles()
	var field_tiles_cnt: int = sim.count_field_tiles()
	print("   Initial city infrastructure -> claimed_zones=%d, road_tiles=%d, field_tiles=%d" % [
		total_claimed_zones, road_tiles_cnt, field_tiles_cnt
	])
	_assert(road_tiles_cnt >= 10, "Cities must carve cobblestone/dirt roads (#C1997C) between buildings")
	_assert(field_tiles_cnt >= 6, "Cities must carve agricultural farm fields (#A8663A) around hubs")

	# Симулируем 12 секунд жизни мира, чтобы жители сходили к деревьям/шахтам, срубили ресурсы и принесли на склад
	for _step in range(24):
		sim.step_simulation(0.5)
		renderer._process(0.05)

	print("   After 12s simulation -> total_citizen_tasks_completed=%d, road_tiles=%d, buildings=%d" % [
		sim.total_citizen_tasks_completed, sim.count_road_tiles(), renderer.rendered_building_count
	])
	_assert(sim.total_citizen_tasks_completed >= 5, "Citizens must complete physical ActorJobLibrary tasks (woodcutter/miner/builder/farmer)")

	print("\n================================================================================")
	if _failed == 0:
		print("=== ALL WORLDBOX v0.51.2 OVERHAUL CHECKS PASSED! (Passed: %d, Failed: 0) ===" % _passed)
		print("================================================================================")
		quit(0)
	else:
		printerr("=== WORLDBOX OVERHAUL SUITE FAILED! (Passed: %d, Failed: %d) ===" % [_passed, _failed])
		quit(1)
