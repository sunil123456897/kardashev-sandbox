class_name CosmicRenderer
extends Node2D

## 2D Пиксель-Арт Рендерер «Kardashev Sandbox: Crucible of Stars» в стиле WorldBox v0.51.2.
## Полностью заменяет 3D-сферу на чёткую 2D-пиксельную графику (TEXTURE_FILTER_NEAREST):
## - Попиксельная карта островов и биомов 384×216 (масштаб 5× -> 1920×1080) с пенным прибоем,
##   песчаными пляжами, пиксельным дизерингом высот, лавовыми жилами и границами государств.
## - Процедурный пиксель-арт атлас (человечки 5 рас, деревья/кристаллы, 8 типов техно-зданий, ракеты, паруса Дайсона).
## - 3 двумерных режима обзора: 1:Карта Мира (WorldBox), 2:Сфера Дайсона (2D), 3:Звёздная Система (2D).

const WorldSimulationScript = preload("res://scripts/sim/world_simulation.gd")
const SandboxAssetScript = preload("res://scripts/core/sandbox_asset.gd")

const TEX_W: int = 384
const TEX_H: int = 216
const PIXEL_SCALE_X: float = 1920.0 / float(TEX_W) # 5.0
const PIXEL_SCALE_Y: float = 1080.0 / float(TEX_H) # 5.0

var sim: WorldSimulationScript
var view_mode: int = 0 # 0 = Карта Мира, 1 = Сфера Дайсона 2D, 2 = Звёздная Система 2D

var _map_image: Image
var _map_texture: ImageTexture
var _sprites: Dictionary = {} # name -> ImageTexture

var _planet_image: Image:
	get: return _map_image
	set(v): _map_image = v

var _planet_texture: ImageTexture:
	get: return _map_texture
	set(v): _map_texture = v

var dirty_rect_update_count: int = 0
var last_dirty_rect: Rect2i = Rect2i()
var _skip_next_full_rebuild: bool = false

var _anim_time: float = 0.0
var _active_rockets: Array[Dictionary] = []
var _particles: Array[Dictionary] = []
var _space_stars: Array[Dictionary] = []
var _belt_asteroids: Array[Dictionary] = []

# Превью кисти бога на 2D-карте
var _brush_visible: bool = false
var _brush_pos_2d: Vector2 = Vector2(960.0, 540.0)
var _brush_radius_px: float = 96.0
var _brush_color: Color = Color(0.25, 0.88, 1.0)

# Счётчики отрисованных объектов для авто-тестов и телеметрии
var rendered_building_count: int = 0
var rendered_actor_count: int = 0
var rendered_dyson_sail_count: int = 0

# Шейдерные ноды, материалы и телеметрия F8
var _dyson_aura_rect: ColorRect
var _dyson_aura_material: ShaderMaterial
var _shockwave_lens_rect: ColorRect
var _shockwave_lens_material: ShaderMaterial

var _active_shockwaves: Array[Dictionary] = []
var rendered_shockwave_count: int = 0
var rendered_dyson_segment_count: int = 0
var rendered_active_war_count: int = 0
var rendered_alliance_count: int = 0
var rendered_trade_route_count: int = 0

var dyson_stage: int = 1
var dyson_stage_progress: float = 0.0
var dyson_active_segments: int = 0

var _dyson_visual_stage: int:
	get: return dyson_stage
	set(v): dyson_stage = v
var _dyson_visual_progress: float:
	get: return dyson_stage_progress
	set(v): dyson_stage_progress = v
var _dyson_segment_count: int:
	get: return dyson_active_segments
	set(v): dyson_active_segments = v


func setup(simulation: WorldSimulationScript) -> void:
	sim = simulation
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	_build_pixel_art_sprites()
	_init_space_backdrop()
	_init_shaders()

	_map_image = Image.create(TEX_W, TEX_H, false, Image.FORMAT_RGBA8)
	_rebuild_pixel_map_texture()

	sim.planet_surface_changed.connect(_on_planet_surface_changed)
	sim.city_structures_changed.connect(_on_city_structures_changed)
	sim.dyson_swarm_changed.connect(_on_dyson_swarm_changed)
	sim.god_impact_2d_triggered.connect(_on_god_impact_2d)
	sim.rocket_launched.connect(_on_rocket_launched)
	if sim.has_signal("shockwave_triggered"):
		sim.shockwave_triggered.connect(_on_shockwave_triggered)
	if sim.has_signal("dyson_visual_state_updated"):
		sim.dyson_visual_state_updated.connect(_on_dyson_visual_state_updated)
	if sim.has_signal("dirty_rect_requested"):
		sim.dirty_rect_requested.connect(_on_dirty_rect_requested)

	_refresh_counts()
	queue_redraw()


func _init_shaders() -> void:
	var sh_aura: Shader = load("res://shaders/dyson_aura.gdshader") as Shader
	if sh_aura != null:
		_dyson_aura_material = ShaderMaterial.new()
		_dyson_aura_material.shader = sh_aura
		_dyson_aura_rect = ColorRect.new()
		_dyson_aura_rect.name = "DysonAuraRect"
		_dyson_aura_rect.position = Vector2(630.0, 175.0)
		_dyson_aura_rect.size = Vector2(640.0, 640.0)
		_dyson_aura_rect.material = _dyson_aura_material
		_dyson_aura_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_dyson_aura_rect.visible = false
		add_child(_dyson_aura_rect)

	var sh_lens: Shader = load("res://shaders/cosmic_lens.gdshader") as Shader
	if sh_lens != null:
		_shockwave_lens_material = ShaderMaterial.new()
		_shockwave_lens_material.shader = sh_lens
		_shockwave_lens_rect = ColorRect.new()
		_shockwave_lens_rect.name = "CosmicLensRect"
		_shockwave_lens_rect.position = Vector2.ZERO
		_shockwave_lens_rect.size = Vector2(1920.0, 1080.0)
		_shockwave_lens_rect.material = _shockwave_lens_material
		_shockwave_lens_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_shockwave_lens_rect.visible = false
		add_child(_shockwave_lens_rect)


func set_view_mode(mode: int) -> void:
	view_mode = mode
	if _dyson_aura_rect != null:
		_dyson_aura_rect.visible = (view_mode == 1)
	queue_redraw()


func set_cursor_brush_preview_2d(vis: bool, world_pos: Vector2, rad_px: float, col: Color) -> void:
	_brush_visible = vis
	_brush_pos_2d = world_pos
	_brush_radius_px = rad_px
	_brush_color = col


func set_cursor_brush_preview(vis: bool, u_dir: Vector3, rad_norm: float, col: Color) -> void:
	if sim == null:
		return
	var t_idx: int = sim.find_closest_tile(u_dir)
	var pos_2d: Vector2 = sim.tiles[t_idx]["map_pos"]
	set_cursor_brush_preview_2d(vis, pos_2d, sim.brush_radius_to_pixels(rad_norm), col)


func _process(delta: float) -> void:
	if sim == null:
		return
	_anim_time += delta

	# Обновляем летящие пиксельные ракеты
	for i in range(_active_rockets.size() - 1, -1, -1):
		var r: Dictionary = _active_rockets[i]
		var pos: Vector2 = r["pos"]
		var vel: Vector2 = r["vel"]
		vel.y -= 110.0 * delta
		pos += vel * delta
		r["pos"] = pos
		r["vel"] = vel
		r["life"] = float(r["life"]) - delta
		if _particles.size() < 240:
			_particles.append({
				"pos": pos + Vector2(randf_range(-3.0, 3.0), 10.0),
				"vel": Vector2(randf_range(-18.0, 18.0), randf_range(25.0, 55.0)),
				"color": Color(1.0, 0.65, 0.18, 0.95),
				"size": 4.0,
				"life": 0.35,
				"max_life": 0.35
			})
		if float(r["life"]) <= 0.0 or pos.y < 75.0:
			_active_rockets.remove_at(i)

	# Обновляем пиксельные частицы ударов и взрывов
	for i in range(_particles.size() - 1, -1, -1):
		var p: Dictionary = _particles[i]
		p["pos"] = (p["pos"] as Vector2) + (p["vel"] as Vector2) * delta
		p["life"] = float(p["life"]) - delta
		if float(p["life"]) <= 0.0:
			_particles.remove_at(i)

	# Обновляем активные ударные волны катаклизмов
	for i in range(_active_shockwaves.size() - 1, -1, -1):
		var sw: Dictionary = _active_shockwaves[i]
		sw["current_radius"] = float(sw["current_radius"]) + float(sw["speed"]) * delta
		sw["life"] = float(sw["life"]) - delta
		var p_ratio: float = 1.0 - (float(sw["life"]) / float(sw["max_life"]))
		sw["progress"] = p_ratio
		if _shockwave_lens_material != null and i == _active_shockwaves.size() - 1:
			_shockwave_lens_material.set_shader_parameter("progress", clampf(p_ratio, 0.0, 1.0))
		if float(sw["life"]) <= 0.0 or float(sw["current_radius"]) >= float(sw["max_radius"]):
			_active_shockwaves.remove_at(i)

	rendered_shockwave_count = _active_shockwaves.size()
	if _active_shockwaves.is_empty() and _shockwave_lens_rect != null:
		_shockwave_lens_rect.visible = false

	_refresh_counts()
	queue_redraw()


func _refresh_counts() -> void:
	if sim == null:
		return
	rendered_actor_count = sim.actors.size()
	var b_cnt: int = 0
	for c_id in sim.cities_map.keys():
		b_cnt += (sim.cities_map[c_id]["building_instances"] as Array).size()
	rendered_building_count = b_cnt
	rendered_dyson_sail_count = sim.total_dyson_sails

	var w_cnt: int = 0
	var a_cnt: int = 0
	var t_cnt: int = 0
	for rel in sim.diplomacy_relations.values():
		var st: String = str(rel.get("status", "NEUTRAL"))
		if st == "WAR":
			w_cnt += 1
		elif st == "ALLIANCE":
			a_cnt += 1
			t_cnt += 1
		elif st == "TRADE":
			t_cnt += 1
	rendered_active_war_count = w_cnt
	rendered_alliance_count = a_cnt
	rendered_trade_route_count = t_cnt


func _on_shockwave_triggered(world_pos: Vector2, radius: float, color: Color) -> void:
	if _active_shockwaves.size() >= 16:
		_active_shockwaves.pop_front()
	_active_shockwaves.append({
		"pos": world_pos,
		"max_radius": radius,
		"current_radius": 4.0,
		"speed": maxf(180.0, radius * 3.6),
		"color": color,
		"life": 0.75,
		"max_life": 0.75,
		"progress": 0.0,
		"thickness": maxf(3.0, radius * 0.08)
	})
	rendered_shockwave_count = _active_shockwaves.size()

	if _shockwave_lens_material != null and _shockwave_lens_rect != null:
		var screen_center := Vector2(world_pos.x / 1920.0, world_pos.y / 1080.0)
		_shockwave_lens_material.set_shader_parameter("center", screen_center)
		_shockwave_lens_material.set_shader_parameter("radius", clampf(radius / 1080.0, 0.1, 0.6))
		_shockwave_lens_material.set_shader_parameter("progress", 0.02)
		_shockwave_lens_material.set_shader_parameter("shock_color", color)
		_shockwave_lens_rect.visible = true


func _on_dyson_visual_state_updated(stage: int, progress: float, active_segs: int) -> void:
	dyson_stage = stage
	dyson_stage_progress = progress
	dyson_active_segments = active_segs
	rendered_dyson_segment_count = active_segs
	if _dyson_aura_material != null:
		_dyson_aura_material.set_shader_parameter("active_segments", active_segs)
		_dyson_aura_material.set_shader_parameter("stage_progress", progress)
	queue_redraw()


func _on_dirty_rect_requested(rect: Rect2i) -> void:
	request_dirty_rect_update(rect)
	_skip_next_full_rebuild = true


func _on_planet_surface_changed() -> void:
	if _skip_next_full_rebuild:
		_skip_next_full_rebuild = false
		return
	_rebuild_pixel_map_texture()


func _on_city_structures_changed() -> void:
	if _skip_next_full_rebuild:
		_skip_next_full_rebuild = false
		_refresh_counts()
		return
	_refresh_counts()
	queue_redraw()


func _on_dyson_swarm_changed() -> void:
	_refresh_counts()


func _on_rocket_launched(from_pos: Vector2, col: Color, _city_name: String) -> void:
	if _active_rockets.size() >= 18:
		return
	_active_rockets.append({
		"pos": from_pos + Vector2(0.0, -12.0),
		"vel": Vector2(randf_range(-12.0, 12.0), -95.0),
		"color": col,
		"life": 4.5
	})


func _on_god_impact_2d(map_pos: Vector2, radius_px: float, color: Color, _power_id: String) -> void:
	for _i in range(28):
		var ang: float = randf() * TAU
		var spd: float = randf_range(25.0, maxf(60.0, radius_px * 1.2))
		_particles.append({
			"pos": map_pos + Vector2(cos(ang), sin(ang)) * randf_range(0.0, radius_px * 0.35),
			"vel": Vector2(cos(ang), sin(ang)) * spd,
			"color": color.lightened(0.25),
			"size": 5.0 if randf() < 0.5 else 4.0,
			"life": randf_range(0.35, 0.85),
			"max_life": 0.85
		})


# ==============================================================================
# ГЕНЕРАЦИЯ ПОПИКСЕЛЬНОЙ КАРТЫ WORLDBOX (ImageTexture 384×216 NEAREST & DIRTY-RECT)
# ==============================================================================
func request_dirty_world_pos(world_pos: Vector2, radius_px: float) -> void:
	var u: float = world_pos.x / 1920.0
	var v: float = world_pos.y / 1080.0
	var cx: int = int(u * float(TEX_W))
	var cy: int = int(v * float(TEX_H))
	var rad_tex: int = int(ceil(radius_px / 5.0)) + 3
	request_dirty_rect_update(Rect2i(cx - rad_tex, cy - rad_tex, rad_tex * 2, rad_tex * 2))


func request_dirty_tile_rect(min_gx: int, min_gy: int, max_gx: int, max_gy: int) -> void:
	var px_x: int = clampi(int(float(min_gx) / float(sim.GRID_W) * float(TEX_W)) - 2, 0, TEX_W)
	var px_y: int = clampi(int(float(min_gy) / float(sim.GRID_H) * float(TEX_H)) - 2, 0, TEX_H)
	var px_w: int = clampi(int(ceil(float(max_gx - min_gx + 1) / float(sim.GRID_W) * float(TEX_W))) + 4, 1, TEX_W - px_x)
	var px_h: int = clampi(int(ceil(float(max_gy - min_gy + 1) / float(sim.GRID_H) * float(TEX_H))) + 4, 1, TEX_H - px_y)
	request_dirty_rect_update(Rect2i(px_x, px_y, px_w, px_h))


func request_dirty_rect_update(rect: Rect2i) -> void:
	if sim == null or _map_image == null:
		return

	last_dirty_rect = rect
	dirty_rect_update_count += 1

	if rect.size.x <= 0 or rect.size.y <= 0:
		return

	var min_x: int = clampi(rect.position.x, 0, TEX_W)
	var min_y: int = clampi(rect.position.y, 0, TEX_H)
	var max_x: int = clampi(rect.position.x + rect.size.x, 0, TEX_W)
	var max_y: int = clampi(rect.position.y + rect.size.y, 0, TEX_H)

	if min_x >= max_x or min_y >= max_y:
		return

	var bayer2 := [0.0, 0.5, 0.75, 0.25]
	for py in range(min_y, max_y):
		var v: float = (float(py) + 0.5) / float(TEX_H)
		for px in range(min_x, max_x):
			var u: float = (float(px) + 0.5) / float(TEX_W)
			var col: Color = _sample_and_shade_pixel(px, py, u, v, bayer2)
			_map_image.set_pixel(px, py, col)

	if _map_texture == null:
		_map_texture = ImageTexture.create_from_image(_map_image)
	else:
		_map_texture.update(_map_image)
	queue_redraw()


func _rebuild_pixel_map_texture() -> void:
	if sim == null or _map_image == null:
		return

	var bayer2 := [0.0, 0.5, 0.75, 0.25]

	for py in range(TEX_H):
		var v: float = (float(py) + 0.5) / float(TEX_H)
		for px in range(TEX_W):
			var u: float = (float(px) + 0.5) / float(TEX_W)
			var col: Color = _sample_and_shade_pixel(px, py, u, v, bayer2)
			_map_image.set_pixel(px, py, col)

	if _map_texture == null:
		_map_texture = ImageTexture.create_from_image(_map_image)
	else:
		_map_texture.update(_map_image)
	queue_redraw()


func _sample_and_shade_pixel(px: int, py: int, u: float, v: float, bayer2: Array) -> Color:
	var sample: Dictionary = sim.sample_pixel_terrain(Vector2(u, v))
	var elev: float = float(sample["elevation"])
	var biome_id: String = sample["biome_id"]
	var city_id: int = int(sample["city_id"])
	var dither: float = bayer2[(px % 2) + (py % 2) * 2] - 0.375

	var col: Color
	if elev < -0.18:
		# Глубокий абиссальный океан (как на краях карты WorldBox)
		col = Color(0.035, 0.095, 0.19)
		if ((px + py * 3) % 17) == 0:
			col = col.darkened(0.12)
	elif elev < -0.055:
		# Средний океан
		col = Color(0.055, 0.19, 0.34)
		if elev + dither * 0.03 < -0.15:
			col = Color(0.035, 0.095, 0.19)
	elif elev < 0.0:
		# Мелководная бирюзовая лагуна и пенный прибой у берега
		if elev > -0.013 and ((px + py) % 2 == 0):
			col = Color(0.68, 0.94, 0.98) # Береговая пиксельная пена
		else:
			col = Color(0.11, 0.41, 0.54)
	elif elev < 0.032:
		# Пиксельный песчаный пляж или базальтовая кромка для экстремальных биомов
		if biome_id == "biome_plasma_inferno" or biome_id == "biome_cybercore" or biome_id == "biome_singularity_swamp":
			col = Color(0.24, 0.23, 0.29)
		elif biome_id == "biome_cryo_superconductor":
			col = Color(0.68, 0.88, 0.98)
		else:
			col = Color(0.82, 0.73, 0.46) if (px + py) % 2 == 0 else Color(0.74, 0.64, 0.39)
	else:
		# Основная суша биома с пошаговой пиксельной высотой и дизерингом
		var b_asset: SandboxAssetScript.BiomeAsset = sim.assets.biomes.get(biome_id)
		var low_c: Color = b_asset.base_color_low if b_asset != null else Color(0.18, 0.22, 0.26)
		var high_c: Color = b_asset.base_color_high if b_asset != null else Color(0.32, 0.38, 0.42)
		var em_c: Color = b_asset.emissive_color if b_asset != null else Color.BLACK
		var em_str: float = b_asset.emissive_strength if b_asset != null else 0.0

		var h_norm: float = clampf((elev - 0.03) / 0.26 + dither * 0.16, 0.0, 1.0)
		# Квантуем в 4 чёткие пиксельные ступени палитры
		var h_step: float = floor(h_norm * 4.0) / 3.0
		col = low_c.lerp(high_c, h_step)

		# Пиксельный узор для специфических биомов (магистрали Кибер-Ядра, жилы лавы, кристаллы)
		if biome_id == "biome_cybercore":
			if (px % 6 == 0 and py % 3 != 0) or (py % 6 == 0 and px % 4 != 0):
				col = col.lerp(Color(0.0, 0.95, 1.0), 0.55)
		elif biome_id == "biome_plasma_inferno":
			if ((px * 5 + py * 7) % 11) < 2:
				col = Color(1.0, 0.58, 0.12)
		elif em_str > 0.2 and ((px * 13 + py * 7) % 23) == 0:
			col = col.lerp(em_c, 0.65)

		# Высокие горные хребты и заснеженные/кристаллические пики
		if elev > 0.27:
			if elev > 0.34:
				col = Color(0.88, 0.94, 1.0) if (px + py) % 2 == 0 else Color(0.72, 0.82, 0.92)
			else:
				col = Color(0.36, 0.39, 0.46) if py % 2 == 0 else Color(0.26, 0.28, 0.34)

		# Политическая подсветка территории города и пунктирная пиксельная граница (как в WorldBox)
		if city_id != -1 and sim.cities_map.has(city_id):
			var c_col: Color = sim.cities_map[city_id]["color"]
			col = col.lerp(c_col, 0.14)
			# Проверяем границу клетки города
			var gx_f: float = u * float(sim.GRID_W)
			var gy_f: float = v * float(sim.GRID_H)
			var cell_frac_x: float = gx_f - floor(gx_f)
			var cell_frac_y: float = gy_f - floor(gy_f)
			var gx_i: int = clampi(int(gx_f), 0, sim.GRID_W - 1)
			var gy_i: int = clampi(int(gy_f), 0, sim.GRID_H - 1)
			var is_border := false
			if cell_frac_x < 0.09 and gx_i > 0 and int(sim.tiles[gy_i * sim.GRID_W + (gx_i - 1)]["city_id"]) != city_id:
				is_border = true
			elif cell_frac_x > 0.91 and gx_i < sim.GRID_W - 1 and int(sim.tiles[gy_i * sim.GRID_W + (gx_i + 1)]["city_id"]) != city_id:
				is_border = true
			elif cell_frac_y < 0.13 and gy_i > 0 and int(sim.tiles[(gy_i - 1) * sim.GRID_W + gx_i]["city_id"]) != city_id:
				is_border = true
			elif cell_frac_y > 0.87 and gy_i < sim.GRID_H - 1 and int(sim.tiles[(gy_i + 1) * sim.GRID_W + gx_i]["city_id"]) != city_id:
				is_border = true
			if is_border and ((px + py) % 2 == 0):
				col = c_col.lightened(0.28)

	return col


# ==============================================================================
# ОТРИСОВКА КАДРА (3 РЕЖИМА В ЧИСТОМ 2D PIXEL-ART)
# ==============================================================================
func _draw() -> void:
	if sim == null:
		return

	match view_mode:
		0:
			_draw_mode_planet_worldbox()
		1:
			_draw_mode_star_dyson_2d()
		2:
			_draw_mode_system_overview_2d()


func _draw_mode_planet_worldbox() -> void:
	# 1. Базовая попиксельная карта 384×216, растянутая на 1920×1080 без размытия (Nearest)
	if _map_texture != null:
		draw_texture_rect(_map_texture, Rect2(0.0, 0.0, 1920.0, 1080.0), false)

	# 2. Анимированные пиксельные блики волн на воде
	var wave_shift: int = int(_anim_time * 3.0)
	for i in range(0, sim.TILE_COUNT, 3):
		var t: Dictionary = sim.tiles[i]
		if float(t["elevation"]) < -0.03:
			var mp: Vector2 = t["map_pos"]
			var wx: float = mp.x + float(((i * 17 + wave_shift) % 7) - 3) * 5.0
			var wy: float = mp.y + float(((i * 11) % 5) - 2) * 5.0
			draw_rect(Rect2(wx, wy, 10.0, 3.0), Color(0.35, 0.78, 0.95, 0.28), true)

	# 3. Отрисовка пиксельной флоры и кристаллов на суше
	for i in range(sim.TILE_COUNT):
		var t: Dictionary = sim.tiles[i]
		var fl: String = t["flora"]
		if fl == "" or float(t["elevation"]) < 0.01:
			continue
		var tex: ImageTexture = _sprites.get("flora_" + fl)
		if tex != null:
			var p: Vector2 = t["map_pos"] + Vector2(-14.0, -8.0)
			draw_rect(Rect2(p.x - 7.0, p.y + 6.0, 14.0, 4.0), Color(0.0, 0.0, 0.0, 0.35), true)
			draw_texture_rect(tex, Rect2(p.x - 10.0, p.y - 12.0, 20.0, 20.0), false)

	# 4. Отрисовка зданий городов (BuildOrder instances) и лучей орбитальных лифтов
	for c_id in sim.cities_map.keys():
		var city: Dictionary = sim.cities_map[c_id]
		var c_col: Color = city["color"]
		var inst_list: Array = city["building_instances"]
		for b_inst in inst_list:
			var b_pos: Vector2 = b_inst["map_pos"]
			var arch: String = b_inst["archetype"]
			var tex: ImageTexture = _sprites.get("bld_" + arch, _sprites.get("bld_dome"))

			# Если это орбитальный лифт или гравитационный якорь — рисуем пиксельный лазерный луч вверх в космос!
			if arch == "elevator" or arch == "anchor":
				draw_rect(Rect2(b_pos.x - 2.0, 92.0, 4.0, maxf(0.0, b_pos.y - 92.0)), Color(c_col.r, c_col.g, c_col.b, 0.32), true)
				draw_rect(Rect2(b_pos.x - 1.0, 92.0, 2.0, maxf(0.0, b_pos.y - 92.0)), Color(0.85, 0.98, 1.0, 0.65), true)

			# Тень под зданием + сам пиксель-арт спрайт здания
			draw_rect(Rect2(b_pos.x - 12.0, b_pos.y + 8.0, 24.0, 6.0), Color(0.0, 0.0, 0.0, 0.45), true)
			if tex != null:
				var tint: Color = Color.WHITE.lerp(c_col.lightened(0.35), 0.35)
				draw_texture_rect(tex, Rect2(b_pos.x - 13.0, b_pos.y - 16.0, 26.0, 26.0), false, tint)

	# 5. Отрисовка живых пиксельных человечков (Actors) на континентах
	var frame_idx: int = int(_anim_time * 5.0) % 2
	for a in sim.actors:
		var a_pos: Vector2 = a["pos"]
		var arch: String = a["archetype"]
		var u_frame: int = (frame_idx + int(a["id"])) % 2
		var tex: ImageTexture = _sprites.get("actor_%s_%d" % [arch, u_frame], _sprites.get("actor_carbon_0"))
		var bob_y: float = -absf(sin(float(a["anim_phase"]))) * 2.5

		# Пиксельная тень под ногами
		draw_rect(Rect2(a_pos.x - 5.0, a_pos.y + 5.0, 10.0, 3.0), Color(0.0, 0.0, 0.0, 0.45), true)
		if tex != null:
			var w_sign: float = -16.0 if bool(a.get("facing_left", false)) else 16.0
			draw_texture_rect(tex, Rect2(a_pos.x - w_sign * 0.5, a_pos.y - 10.0 + bob_y, w_sign, 16.0), false)

		# Маленький пиксельный значок профессии над учёными и астронавтами
		var role: String = a.get("role", "")
		if role == "scholar":
			draw_rect(Rect2(a_pos.x - 2.0, a_pos.y - 14.0 + bob_y, 4.0, 4.0), Color(0.25, 0.95, 1.0), true)
		elif role == "astronaut":
			draw_rect(Rect2(a_pos.x - 2.0, a_pos.y - 14.0 + bob_y, 4.0, 4.0), Color(1.0, 0.85, 0.25), true)

	# 6. Пиксельные купола-линзы констант (Время ×25, Гравитация 0.1G, Сингулярность)
	var font: Font = ThemeDB.fallback_font
	for lens in sim.field_lenses:
		var l_pos: Vector2 = lens["map_pos"]
		var l_rad: float = float(lens["radius_px"])
		var l_col: Color = lens["color"]
		_draw_pixel_lens_dome(l_pos, l_rad, l_col, str(lens["lens_type"]), float(lens["time_mult"]), float(lens["grav_mult"]), font)

	# 7. Таблички-баннеры городов прямо на карте (как в WorldBox)
	for c_id in sim.cities_map.keys():
		var city: Dictionary = sim.cities_map[c_id]
		var c_pos: Vector2 = city["map_pos"]
		var c_col: Color = city["color"]
		var label_txt: String = "★ %s [%d] K-%.2f" % [city["name"], int(city["population"]), float(city["kardashev_level"])]
		var banner_rect := Rect2(c_pos.x - 92.0, c_pos.y - 34.0, 184.0, 18.0)
		draw_rect(banner_rect, Color(0.04, 0.06, 0.11, 0.88), true)
		draw_rect(banner_rect, c_col, false, 1.5)
		if font != null:
			draw_string(font, Vector2(banner_rect.position.x + 6.0, banner_rect.position.y + 13.0), label_txt, HORIZONTAL_ALIGNMENT_CENTER, 172.0, 11, c_col.lightened(0.35))

	# 7.1. Дипломатические индикаторы цивилизаций (Войны, Союзы, Торговля)
	rendered_active_war_count = 0
	rendered_alliance_count = 0
	rendered_trade_route_count = 0

	for rel in sim.diplomacy_relations.values():
		var id_a: int = int(rel.get("city_a", -1))
		var id_b: int = int(rel.get("city_b", -1))
		if not sim.cities_map.has(id_a) or not sim.cities_map.has(id_b):
			continue
		var city_a: Dictionary = sim.cities_map[id_a]
		var city_b: Dictionary = sim.cities_map[id_b]
		var pos_a: Vector2 = city_a["map_pos"]
		var pos_b: Vector2 = city_b["map_pos"]
		var mid_p := (pos_a + pos_b) * 0.5
		var status: String = str(rel.get("status", "NEUTRAL"))

		match status:
			"WAR":
				rendered_active_war_count += 1
				draw_line(pos_a, pos_b, Color(0.95, 0.22, 0.22, 0.5), 2.5)
				var clash_t: float = 0.5 + sin(_anim_time * 8.0 + float(id_a + id_b)) * 0.2
				var clash_p: Vector2 = pos_a.lerp(pos_b, clash_t)
				draw_rect(Rect2(clash_p.x - 4.0, clash_p.y - 4.0, 8.0, 8.0), Color(1.0, 0.45, 0.15), true)
				var pulse_red: float = 0.5 + 0.5 * sin(_anim_time * 6.0)
				draw_rect(Rect2(pos_a.x - 42.0, pos_a.y - 54.0, 84.0, 16.0), Color(0.35 * pulse_red + 0.1, 0.02, 0.04, 0.9), true)
				draw_rect(Rect2(pos_b.x - 42.0, pos_b.y - 54.0, 84.0, 16.0), Color(0.35 * pulse_red + 0.1, 0.02, 0.04, 0.9), true)
				if font != null:
					draw_string(font, Vector2(pos_a.x - 38.0, pos_a.y - 42.0), "⚔ ВОЙНА ⚔", HORIZONTAL_ALIGNMENT_CENTER, 76.0, 10, Color(1.0, 0.35, 0.35))
					draw_string(font, Vector2(pos_b.x - 38.0, pos_b.y - 42.0), "⚔ ВОЙНА ⚔", HORIZONTAL_ALIGNMENT_CENTER, 76.0, 10, Color(1.0, 0.35, 0.35))
			"ALLIANCE":
				rendered_alliance_count += 1
				draw_line(pos_a, pos_b, Color(0.25, 0.78, 1.0, 0.35), 4.0)
				draw_line(pos_a, pos_b, Color(0.85, 0.98, 1.0, 0.85), 1.5)
				draw_rect(Rect2(mid_p.x - 36.0, mid_p.y - 9.0, 72.0, 18.0), Color(0.04, 0.08, 0.18, 0.9), true)
				draw_rect(Rect2(mid_p.x - 36.0, mid_p.y - 9.0, 72.0, 18.0), Color(0.35, 0.85, 1.0), false, 1.0)
				if font != null:
					draw_string(font, Vector2(mid_p.x - 34.0, mid_p.y + 4.0), "🛡 СОЮЗ 🛡", HORIZONTAL_ALIGNMENT_CENTER, 68.0, 10, Color(0.75, 0.95, 1.0))
				# Союзники также обмениваются торговым флотом
				rendered_trade_route_count += 1
				draw_dashed_line(pos_a, pos_b, Color(1.0, 0.82, 0.25, 0.75), 2.0, 9.0)
				var car_t_al: float = fmod(_anim_time * 0.25 + float(id_a * 7 + id_b * 13) * 0.1, 1.0)
				var car_p_al: Vector2 = pos_a.lerp(pos_b, car_t_al)
				draw_rect(Rect2(car_p_al.x - 3.0, car_p_al.y - 3.0, 6.0, 6.0), Color(1.0, 0.95, 0.45), true)
			"TRADE":
				rendered_trade_route_count += 1
				draw_dashed_line(pos_a, pos_b, Color(1.0, 0.82, 0.25, 0.75), 2.0, 9.0)
				var car_t: float = fmod(_anim_time * 0.25 + float(id_a * 7 + id_b * 13) * 0.1, 1.0)
				var car_p: Vector2 = pos_a.lerp(pos_b, car_t)
				draw_rect(Rect2(car_p.x - 3.0, car_p.y - 3.0, 6.0, 6.0), Color(1.0, 0.95, 0.45), true)
				var t_val: float = float(rel.get("trade_yield", 0.0))
				if t_val > 0.0 and font != null:
					draw_string(font, Vector2(mid_p.x - 35.0, mid_p.y - 6.0), "⚖ +%.1f ГВт" % t_val, HORIZONTAL_ALIGNMENT_CENTER, 70.0, 10, Color(1.0, 0.92, 0.45))

	# 7.2. Активные 2D ударные волны катаклизмов
	for sw in _active_shockwaves:
		var sw_p: Vector2 = sw["pos"]
		var sw_r: float = float(sw["current_radius"])
		var sw_c: Color = sw["color"]
		var sw_ratio: float = float(sw["life"]) / maxf(0.01, float(sw["max_life"]))
		var sw_th: float = float(sw["thickness"]) * sw_ratio
		sw_c.a = sw_ratio
		_draw_pixel_circle_outline(sw_p, sw_r, sw_c.lightened(0.2), maxf(2.0, sw_th))
		if sw_r > 12.0:
			_draw_pixel_circle_outline(sw_p, sw_r * 0.76, sw_c, maxf(1.5, sw_th * 0.6))
		if sw_ratio > 0.75:
			_draw_pixel_filled_circle(sw_p, sw_r * 0.45, Color(sw_c.r, sw_c.g, sw_c.b, 0.45 * sw_ratio))

	# 8. Взлетающие пиксельные ракеты и частицы взрывов
	var rocket_tex: ImageTexture = _sprites.get("rocket_ship")
	for r in _active_rockets:
		var rp: Vector2 = r["pos"]
		if rocket_tex != null:
			draw_texture_rect(rocket_tex, Rect2(rp.x - 9.0, rp.y - 12.0, 18.0, 24.0), false)

	for p in _particles:
		var ratio: float = clampf(float(p["life"]) / maxf(0.01, float(p["max_life"])), 0.0, 1.0)
		var pc: Color = p["color"]
		pc.a = ratio
		var sz: float = float(p["size"])
		var pp: Vector2 = p["pos"]
		draw_rect(Rect2(pp.x - sz * 0.5, pp.y - sz * 0.5, sz, sz), pc, true)

	# 9. Верхняя орбитальная полоса космоса над картой («Орбита Звезды и Роя Дайсона»)
	_draw_top_orbital_strip(font)

	# 10. Пиксельный прицел Кисти Бога
	if _brush_visible:
		_draw_pixel_circle_outline(_brush_pos_2d, _brush_radius_px, _brush_color, 3.0)
		draw_rect(Rect2(_brush_pos_2d.x - 6.0, _brush_pos_2d.y - 1.0, 12.0, 2.0), _brush_color, true)
		draw_rect(Rect2(_brush_pos_2d.x - 1.0, _brush_pos_2d.y - 6.0, 2.0, 12.0), _brush_color, true)


func _draw_top_orbital_strip(font: Font) -> void:
	# Компактное окно орбиты прямо над архипелагом (x: 375..1525, y: 74..106), куда долетают ракеты с космодромов
	var strip_rect := Rect2(375.0, 74.0, 1150.0, 32.0)
	draw_rect(strip_rect, Color(0.02, 0.03, 0.07, 0.88), true)
	draw_rect(strip_rect, Color(0.22, 0.52, 0.78, 0.75), false, 1.0)

	# Мини-звезда и вращающиеся паруса справа на орбитальной полосе (не перекрывают текст слева)
	var star_p := Vector2(1345.0, 90.0)
	draw_circle(star_p, 11.0, sim.star_color.darkened(0.15))
	draw_circle(star_p, 8.0, sim.star_color.lightened(0.25))

	var sail_tex: ImageTexture = _sprites.get("dyson_sail")
	var vis_sails: int = mini(sim.total_dyson_sails, 40)
	for i in range(vis_sails):
		var phase: float = _anim_time * 1.4 + float(i) * (TAU / maxf(1.0, float(vis_sails)))
		var sx: float = star_p.x + cos(phase) * (28.0 + float(i % 5) * 26.0)
		var sy: float = star_p.y + sin(phase * 2.0) * 8.0
		if sail_tex != null:
			draw_texture_rect(sail_tex, Rect2(sx - 5.0, sy - 5.0, 10.0, 10.0), false)

	if font != null:
		draw_string(
			font,
			Vector2(388.0, 94.0),
			"ОРБИТА СИСТЕМЫ: Парусов Дайсона: %d (Покрытие: %.0f%%) — Нажмите [2:Сфера 2D] или [3:Система 2D]" % [
				sim.total_dyson_sails, sim.get_dyson_eclipse_ratio() * 100.0
			],
			HORIZONTAL_ALIGNMENT_LEFT,
			780.0,
			11,
			Color(0.78, 0.92, 1.0)
		)


func _draw_mode_star_dyson_2d() -> void:
	# Полный 2D Пиксель-Арт обзор Звезды и колец Сферы Дайсона
	draw_rect(Rect2(0.0, 0.0, 1920.0, 1080.0), Color(0.015, 0.02, 0.045), true)
	_draw_pixel_starfield()

	var center := Vector2(950.0, 495.0)
	var font: Font = ThemeDB.fallback_font

	# Затенение центральной звезды при постройке сегментов Сферы Дайсона
	var eclipse_ratio: float = sim.get_dyson_eclipse_ratio()
	var star_base_col: Color = sim.star_color.darkened(eclipse_ratio * 0.55)

	# Пиксельная корона и кипящая звезда в центре
	var pulse: float = sin(_anim_time * 3.0) * 6.0
	_draw_pixel_filled_circle(center, 118.0 + pulse, Color(star_base_col.r, star_base_col.g * 0.6, 0.1, 0.18))
	_draw_pixel_filled_circle(center, 96.0 + pulse * 0.5, star_base_col.darkened(0.2))
	_draw_pixel_filled_circle(center, 78.0, star_base_col)
	_draw_pixel_filled_circle(center, 52.0, star_base_col.lightened(0.42 * (1.0 - eclipse_ratio * 0.5)))

	# Пиксельные протуберанцы вокруг звезды
	for i in range(12):
		var ang: float = float(i) * (TAU / 12.0) + _anim_time * 0.35
		var pr: float = 92.0 + sin(_anim_time * 4.0 + float(i)) * 12.0
		var fp := center + Vector2(cos(ang), sin(ang)) * pr
		draw_rect(Rect2(fp.x - 5.0, fp.y - 5.0, 10.0, 10.0), star_base_col.lightened(0.2), true)

	# Отрисовка стадий мегаструктуры Сферы Дайсона (Этапы 1..4)
	rendered_dyson_segment_count = dyson_active_segments

	# 1. Этап 1: Рой Дайсона (Swarm Collectors)
	var sail_tex: ImageTexture = _sprites.get("dyson_sail")
	for r_idx in range(sim.dyson_rings.size()):
		var ring: Dictionary = sim.dyson_rings[r_idx]
		var rx: float = 155.0 + float(r_idx) * 38.0
		var ry: float = rx * (0.58 + float(r_idx % 3) * 0.12)
		var r_col: Color = ring["color"]
		var sails_cnt: int = mini(int(ring["sails_count"]), 90)
		var spd: float = float(ring.get("speed", 0.3))

		_draw_pixel_ellipse_outline(center, rx, ry, Color(r_col.r, r_col.g, r_col.b, 0.32))

		for s in range(sails_cnt):
			var a: float = float(s) * (TAU / maxf(1.0, float(sails_cnt))) + _anim_time * spd * (1.0 if r_idx % 2 == 0 else -1.0)
			var sp := center + Vector2(cos(a) * rx, sin(a) * ry)
			if s % 8 == 0:
				draw_line(sp, center + (sp - center).normalized() * 88.0, Color(r_col.r, r_col.g, r_col.b, 0.25), 2.0)
			if sail_tex != null:
				draw_texture_rect(sail_tex, Rect2(sp.x - 7.0, sp.y - 7.0, 14.0, 14.0), false, Color.WHITE.lerp(r_col, 0.45))

	# 2. Этап 2: Экваториальный Каркас Кольца (Equatorial Ring Frame — 12 ферм)
	if dyson_stage >= 2:
		var frame_rx: float = 230.0
		var frame_ry: float = 135.0
		_draw_pixel_ellipse_outline(center, frame_rx, frame_ry, Color(0.35, 0.85, 1.0, 0.55), 2.0)
		_draw_pixel_ellipse_outline(center, frame_rx + 16.0, frame_ry + 10.0, Color(0.2, 0.65, 0.95, 0.4), 1.5)
		for seg_i in range(12):
			var seg_a0: float = float(seg_i) * (TAU / 12.0)
			var seg_a1: float = float(seg_i + 1) * (TAU / 12.0)
			var p0 := center + Vector2(cos(seg_a0) * frame_rx, sin(seg_a0) * frame_ry)
			var p1 := center + Vector2(cos(seg_a1) * frame_rx, sin(seg_a1) * frame_ry)
			var q0 := center + Vector2(cos(seg_a0) * (frame_rx + 16.0), sin(seg_a0) * (frame_ry + 10.0))
			var q1 := center + Vector2(cos(seg_a1) * (frame_rx + 16.0), sin(seg_a1) * (frame_ry + 10.0))

			if dyson_stage > 2 or seg_i < dyson_active_segments:
				# Завершённый сегмент: массивные золотисто-циановые фермы с распорками
				draw_line(p0, p1, Color(0.25, 0.90, 1.0, 0.95), 3.0)
				draw_line(q0, q1, Color(0.95, 0.82, 0.35, 0.85), 2.0)
				draw_line(p0, q1, Color(0.35, 0.75, 1.0, 0.65), 1.5)
			elif dyson_stage == 2 and seg_i == dyson_active_segments:
				# Активно строящийся сегмент: искры сварки и плазма
				draw_line(p0, p1, Color(0.25, 0.90, 1.0, 0.45), 2.0)
				var spark_p: Vector2 = p0.lerp(p1, dyson_stage_progress)
				var spark_col := Color(1.0, 0.95, 0.55, 0.9) if sin(_anim_time * 12.0) > 0.0 else Color(0.35, 0.95, 1.0)
				draw_circle(spark_p, 5.0, spark_col)
			else:
				# Чертежи будущих ферм: полупрозрачный пунктир
				draw_line(p0, p1, Color(0.35, 0.65, 0.95, 0.20), 1.0)

	# 3. Этап 3: Сегменты Геодезической Оболочки (Dyson Shell — до 60 щитов)
	if dyson_stage >= 3:
		var shell_r: float = 168.0
		var max_shell_segs: int = 60
		var active_shell_count: int = max_shell_segs if dyson_stage > 3 else mini(dyson_active_segments, max_shell_segs)
		for sh_i in range(active_shell_count):
			var sh_ang: float = float(sh_i) * (TAU / float(max_shell_segs))
			var sh_p := center + Vector2(cos(sh_ang) * shell_r, sin(sh_ang) * (shell_r * 0.72))
			var plate_rect := Rect2(sh_p.x - 9.0, sh_p.y - 7.0, 18.0, 14.0)
			draw_rect(plate_rect, Color(0.08, 0.12, 0.22, 0.85), true)
			draw_rect(plate_rect, Color(0.25, 0.85, 1.0, 0.75), false, 1.2)
			if sh_i % 3 == 0:
				draw_rect(Rect2(sh_p.x - 3.0, sh_p.y - 3.0, 6.0, 6.0), Color(1.0, 0.65, 0.18, 0.8), true)

	# 4. Этап 4: Вычислительные Сферы Матрёшки (Matrioshka Brain — 3 слоя)
	if dyson_stage >= 4:
		var mb_radii := [190.0, 255.0, 320.0]
		var mb_colors := [Color(1.0, 0.72, 0.25, 0.6), Color(0.25, 0.92, 1.0, 0.6), Color(0.85, 0.35, 1.0, 0.6)]
		for layer_i in range(3):
			var lr: float = mb_radii[layer_i]
			var lc: Color = mb_colors[layer_i]
			_draw_pixel_circle_outline(center, lr, lc, 2.0)
			var packet_count := 8 + layer_i * 4
			for p_i in range(packet_count):
				var p_ang: float = float(p_i) * (TAU / float(packet_count)) + _anim_time * (0.8 - float(layer_i) * 0.2)
				var pkt_pos := center + Vector2(cos(p_ang) * lr, sin(p_ang) * lr)
				draw_rect(Rect2(pkt_pos.x - 3.0, pkt_pos.y - 3.0, 6.0, 6.0), lc.lightened(0.4), true)

	# Отрисовка ударных волн, если происходят в звёздном обзоре
	for sw in _active_shockwaves:
		var sw_p: Vector2 = sw["pos"]
		var sw_r: float = float(sw["current_radius"])
		var sw_c: Color = sw["color"]
		var sw_ratio: float = float(sw["life"]) / maxf(0.01, float(sw["max_life"]))
		var sw_th: float = float(sw["thickness"]) * sw_ratio
		sw_c.a = sw_ratio
		_draw_pixel_circle_outline(sw_p, sw_r, sw_c.lightened(0.2), maxf(2.0, sw_th))

	if font != null:
		var stage_name: String = sim.get_dyson_stage_name() if sim.has_method("get_dyson_stage_name") else "Этап %d" % dyson_stage
		draw_string(
			font,
			Vector2(390.0, 115.0),
			"2D АСТРОИНЖЕНЕРИЯ: %s — Этап %d: %s | Сегментов: %d/60 | Затмение: %.0f%% | Парусов: %d" % [
				sim.star_name, dyson_stage, stage_name, dyson_active_segments, eclipse_ratio * 100.0, sim.total_dyson_sails
			],
			HORIZONTAL_ALIGNMENT_CENTER,
			1120.0,
			15,
			Color(1.0, 0.88, 0.42)
		)


func _draw_mode_system_overview_2d() -> void:
	# 2D Тактическая карта всей Звёздной Системы: Звезда + Рой + Планета + Пояс Астероидов + Дроны
	draw_rect(Rect2(0.0, 0.0, 1920.0, 1080.0), Color(0.012, 0.018, 0.038), true)
	_draw_pixel_starfield()

	var center := Vector2(950.0, 500.0)
	var font: Font = ThemeDB.fallback_font

	# 1. Орбита планеты и Пояса Астероидов
	_draw_pixel_ellipse_outline(center, 250.0, 155.0, Color(0.25, 0.65, 0.95, 0.38))
	_draw_pixel_ellipse_outline(center, 430.0, 275.0, Color(0.65, 0.55, 0.42, 0.30))

	# 2. Центральная звезда и мини-кольца Сферы Дайсона
	_draw_pixel_filled_circle(center, 46.0, sim.star_color.darkened(0.15))
	_draw_pixel_filled_circle(center, 34.0, sim.star_color.lightened(0.25))

	var sail_tex: ImageTexture = _sprites.get("dyson_sail")
	for r_idx in range(sim.dyson_rings.size()):
		var ring: Dictionary = sim.dyson_rings[r_idx]
		var rr: float = 64.0 + float(r_idx) * 16.0
		var r_col: Color = ring["color"]
		var cnt: int = mini(int(ring["sails_count"]), 36)
		for s in range(cnt):
			var a: float = float(s) * (TAU / maxf(1.0, float(cnt))) + _anim_time * 0.5
			var sp := center + Vector2(cos(a) * rr, sin(a) * rr * 0.68)
			if sail_tex != null:
				draw_texture_rect(sail_tex, Rect2(sp.x - 5.0, sp.y - 5.0, 10.0, 10.0), false, r_col)

	# 3. Планета цивилизаций на своей 2D-орбите
	var p_ang: float = _anim_time * 0.22 + 0.4
	var planet_pos := center + Vector2(cos(p_ang) * 250.0, sin(p_ang) * 155.0)
	_draw_pixel_filled_circle(planet_pos, 26.0, Color(0.08, 0.32, 0.52))
	_draw_pixel_filled_circle(planet_pos + Vector2(-5.0, -3.0), 12.0, Color(0.18, 0.68, 0.48))
	_draw_pixel_filled_circle(planet_pos + Vector2(7.0, 5.0), 9.0, Color(0.72, 0.32, 0.92))
	_draw_pixel_circle_outline(planet_pos, 30.0, Color(0.35, 0.88, 1.0, 0.75), 2.0)
	if font != null:
		draw_string(font, planet_pos + Vector2(-55.0, 44.0), "Планета (%d полисов)" % sim.cities_map.size(), HORIZONTAL_ALIGNMENT_LEFT, 140.0, 12, Color(0.45, 0.95, 1.0))

	# 4. Пиксельный Пояс Астероидов и добывающие корабли-дроны
	var ast_tex: ImageTexture = _sprites.get("asteroid_chunk")
	for ast in _belt_asteroids:
		var a_ang: float = float(ast["angle"]) + _anim_time * float(ast["speed"])
		var ax: float = center.x + cos(a_ang) * float(ast["rx"])
		var ay: float = center.y + sin(a_ang) * float(ast["ry"])
		if ast_tex != null:
			var sz: float = float(ast["size"])
			draw_texture_rect(ast_tex, Rect2(ax - sz * 0.5, ay - sz * 0.5, sz, sz), false)

	# 5. Автономные флотилии дронов, курсирующие между Планетой, Поясом Астероидов и Сферой Дайсона
	var rocket_tex: ImageTexture = _sprites.get("rocket_ship")
	var fleet_count: int = clampi(sim.cities_map.size() * 6 + int(sim.total_dyson_sails / 25), 8, 36)
	for f in range(fleet_count):
		var t_cycle: float = fmod(_anim_time * 0.45 + float(f) * 0.37, 1.0)
		var target_ast_ang: float = float(f) * (TAU / float(fleet_count)) + _anim_time * 0.05
		var ast_pos := center + Vector2(cos(target_ast_ang) * 430.0, sin(target_ast_ang) * 275.0)
		var drone_pos: Vector2 = planet_pos.lerp(ast_pos, sin(t_cycle * PI))
		if t_cycle > 0.42 and t_cycle < 0.58:
			# Пиксельный лазер бурения астероида
			draw_line(drone_pos, ast_pos, Color(0.25, 1.0, 0.75, 0.85), 2.0)
		if rocket_tex != null:
			draw_texture_rect(rocket_tex, Rect2(drone_pos.x - 7.0, drone_pos.y - 7.0, 14.0, 14.0), false)

	if font != null:
		draw_string(
			font,
			Vector2(490.0, 110.0),
			"2D КАРТА СИСТЕМЫ: Масса Пояса Астероидов: %.0f ед. | Автономных флотилий Роя: %d" % [
				sim.asteroid_belt_mass, fleet_count
			],
			HORIZONTAL_ALIGNMENT_CENTER,
			920.0,
			15,
			Color(0.55, 0.92, 1.0)
		)


# ==============================================================================
# ПИКСЕЛЬНЫЕ ГЕОМЕТРИЧЕСКИЕ ПРИМИТИВЫ И ШТАМПЫ СПРАЙТОВ
# ==============================================================================
func _draw_pixel_lens_dome(center: Vector2, rad: float, col: Color, l_type: String, t_mult: float, g_mult: float, font: Font) -> void:
	# Полупрозрачный пиксельный купол со сканирующими полосами
	var step_px: float = 6.0
	var r_steps: int = int(rad / step_px)
	for sy in range(-r_steps, r_steps + 1):
		var dy: float = float(sy) * step_px
		var chord: float = sqrt(maxf(0.0, rad * rad - dy * dy))
		if chord > 2.0 and ( abs(sy) % 2 == int(_anim_time * 4.0) % 2 ):
			draw_rect(Rect2(center.x - chord, center.y + dy, chord * 2.0, 3.0), Color(col.r, col.g, col.b, 0.14), true)

	_draw_pixel_circle_outline(center, rad, Color(col.r, col.g, col.b, 0.92), 4.0)
	_draw_pixel_circle_outline(center, rad - 6.0, Color(1.0, 1.0, 1.0, 0.45), 2.0)

	if font != null:
		var tag_txt: String = "ЛИНЗА ×%.0f ВРЕМЯ" % t_mult
		if l_type == "zero_grav":
			tag_txt = "ЛИНЗА %.2fG ГРАВИТАЦИЯ" % g_mult
		elif l_type == "singularity":
			tag_txt = "⚛ КВАНТОВАЯ СИНГУЛЯРНОСТЬ (×%.0f)" % t_mult
		elif l_type == "shield_dome":
			tag_txt = "🛡 ТЕРМО-КУПОЛ ЗАЩИТЫ"
		draw_string(font, center + Vector2(-72.0, -rad - 8.0), tag_txt, HORIZONTAL_ALIGNMENT_CENTER, 144.0, 11, col.lightened(0.35))


func _draw_pixel_circle_outline(center: Vector2, rad: float, col: Color, px_size: float = 4.0) -> void:
	var steps: int = maxi(24, int(rad * 0.65))
	for i in range(steps):
		var a: float = float(i) * (TAU / float(steps))
		var x: float = snappedf(center.x + cos(a) * rad, px_size)
		var y: float = snappedf(center.y + sin(a) * rad, px_size)
		draw_rect(Rect2(x - px_size * 0.5, y - px_size * 0.5, px_size, px_size), col, true)


func _draw_pixel_filled_circle(center: Vector2, rad: float, col: Color, px_step: float = 6.0) -> void:
	var r_steps: int = int(rad / px_step)
	for sy in range(-r_steps, r_steps + 1):
		var dy: float = float(sy) * px_step
		var chord: float = snappedf(sqrt(maxf(0.0, rad * rad - dy * dy)), px_step)
		if chord > 0.0:
			draw_rect(Rect2(center.x - chord, center.y + dy - px_step * 0.5, chord * 2.0, px_step), col, true)


func _draw_pixel_ellipse_outline(center: Vector2, rx: float, ry: float, col: Color, px_size: float = 4.0) -> void:
	var steps: int = 64
	var half_px: float = px_size * 0.5
	for i in range(0, steps, 2):
		var a: float = float(i) * (TAU / float(steps))
		var p := Vector2(snappedf(center.x + cos(a) * rx, px_size), snappedf(center.y + sin(a) * ry, px_size))
		draw_rect(Rect2(p.x - half_px, p.y - half_px, px_size, px_size), col, true)


func _draw_pixel_starfield() -> void:
	for st in _space_stars:
		var pos: Vector2 = st["pos"]
		var sz: float = float(st["size"])
		var col: Color = st["color"]
		draw_rect(Rect2(pos.x, pos.y, sz, sz), col, true)


func _init_space_backdrop() -> void:
	_space_stars.clear()
	_belt_asteroids.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = 9001
	for _i in range(220):
		var c_pick := Color(0.75, 0.88, 1.0, rng.randf_range(0.35, 0.95))
		if rng.randf() < 0.25:
			c_pick = Color(1.0, 0.82, 0.55, rng.randf_range(0.45, 0.95))
		_space_stars.append({
			"pos": Vector2(rng.randf_range(20.0, 1900.0), rng.randf_range(20.0, 1060.0)),
			"size": 4.0 if rng.randf() < 0.35 else 2.0,
			"color": c_pick
		})

	for i in range(140):
		_belt_asteroids.append({
			"angle": float(i) * (TAU / 140.0) + rng.randf_range(-0.04, 0.04),
			"rx": rng.randf_range(405.0, 460.0),
			"ry": rng.randf_range(255.0, 295.0),
			"speed": rng.randf_range(0.04, 0.09),
			"size": rng.randf_range(10.0, 16.0)
		})


# ==============================================================================
# ГЕНЕРАТОР ЧЁТКИХ ПИКСЕЛЬ-АРТ СПРАЙТОВ (ASCII МАТРИЦЫ С ТЁМНЫМ КОНТУРОМ)
# ==============================================================================
func _make_sprite_from_grid(rows: Array[String], palette: Dictionary) -> ImageTexture:
	var h: int = rows.size()
	var w: int = rows[0].length()
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y in range(h):
		var line: String = rows[y]
		for x in range(w):
			var ch: String = line.substr(x, 1)
			if ch != "." and palette.has(ch):
				img.set_pixel(x, y, palette[ch])
	return ImageTexture.create_from_image(img)


func _build_pixel_art_sprites() -> void:
	_sprites.clear()
	var k_out := Color(0.04, 0.06, 0.10, 1.0) # Чёрно-синий пиксельный контур

	# --- 1. ПИКСЕЛЬНЫЕ ЧЕЛОВЕЧКИ И СУЩЕСТВА (5 рас × 2 кадра анимации шага) ---
	var actor_variants := [
		{"id": "carbon", "c1": Color(0.22, 0.95, 0.58), "c2": Color(0.85, 1.0, 0.92)},
		{"id": "silicon", "c1": Color(0.84, 0.38, 1.0), "c2": Color(1.0, 0.78, 1.0)},
		{"id": "plasma", "c1": Color(1.0, 0.52, 0.14), "c2": Color(1.0, 0.95, 0.35)},
		{"id": "cyber", "c1": Color(0.12, 0.92, 1.0), "c2": Color(1.0, 0.88, 0.25)},
		{"id": "quantum", "c1": Color(0.65, 0.30, 1.0), "c2": Color(0.35, 1.0, 0.95)}
	]
	for av in actor_variants:
		var pal := {"#": k_out, "1": av["c1"], "2": av["c2"]}
		_sprites["actor_%s_0" % av["id"]] = _make_sprite_from_grid([
			"...####...",
			"..#1221#..",
			"..#1221#..",
			"...####...",
			"..#1111#..",
			".#112211#.",
			".#111111#.",
			"..#1##1#..",
			"..#1..1#..",
			"..##..##.."
		], pal)
		_sprites["actor_%s_1" % av["id"]] = _make_sprite_from_grid([
			"...####...",
			"..#1221#..",
			"..#1221#..",
			"...####...",
			".#111111#.",
			"..#1221#..",
			"..#1111#..",
			".#1#..#1#.",
			".##....##.",
			".........."
		], pal)

	# --- 2. ПИКСЕЛЬНАЯ ФЛОРА И РЕСУРСЫ БИОМОВ ---
	_sprites["flora_bio_tree"] = _make_sprite_from_grid([
		"...####...",
		".##1221##.",
		"#12211221#",
		"#12111121#",
		".#111111#.",
		"..##33##..",
		"...#33#...",
		"...#33#...",
		"..##33##..",
		".........."
	], {"#": k_out, "1": Color(0.12, 0.75, 0.52), "2": Color(0.35, 1.0, 0.78), "3": Color(0.45, 0.32, 0.22)})

	_sprites["flora_cryo_crystal"] = _make_sprite_from_grid([
		"....##....",
		"...#21#...",
		".###21###.",
		"#21221121#",
		"#11221111#",
		".#122111#.",
		"..#1111#..",
		"..######..",
		"..........",
		".........."
	], {"#": k_out, "1": Color(0.28, 0.75, 0.98), "2": Color(0.82, 0.96, 1.0)})

	_sprites["flora_actinide_ore"] = _make_sprite_from_grid([
		"....##....",
		"..##22##..",
		".#122221#.",
		"#11211211#",
		"#12211221#",
		"#11122111#",
		".########.",
		"..........",
		"..........",
		".........."
	], {"#": k_out, "1": Color(0.32, 0.45, 0.22), "2": Color(0.58, 1.0, 0.18)})

	_sprites["flora_piezo_spire"] = _make_sprite_from_grid([
		"....##....",
		"...#22#...",
		"..#1221#..",
		"..#1221#..",
		".#112211#.",
		".#111111#.",
		"..#1111#..",
		"..######..",
		"..........",
		".........."
	], {"#": k_out, "1": Color(0.68, 0.25, 0.92), "2": Color(0.95, 0.65, 1.0)})

	_sprites["flora_cyber_node"] = _make_sprite_from_grid([
		"...####...",
		"..#2222#..",
		"..######..",
		"...#11#...",
		".###11###.",
		"#12211221#",
		"#11111111#",
		".########.",
		"..........",
		".........."
	], {"#": k_out, "1": Color(0.22, 0.38, 0.48), "2": Color(0.0, 0.95, 1.0)})

	_sprites["flora_lava_vent"] = _make_sprite_from_grid([
		"...####...",
		"..#2222#..",
		".#122221#.",
		"#11122111#",
		"#11111111#",
		"##########",
		"..........",
		"..........",
		"..........",
		".........."
	], {"#": k_out, "1": Color(0.32, 0.16, 0.14), "2": Color(1.0, 0.55, 0.12)})

	_sprites["flora_void_monolith"] = _make_sprite_from_grid([
		"...####...",
		"..#2112#..",
		"..#1221#..",
		"..#1221#..",
		"..#1111#..",
		"..#2112#..",
		"...####...",
		"..........",
		"..........",
		".........."
	], {"#": k_out, "1": Color(0.22, 0.08, 0.42), "2": Color(0.85, 0.35, 1.0)})

	_sprites["flora_basalt_rock"] = _make_sprite_from_grid([
		"..........",
		"..........",
		"...####...",
		".##1221##.",
		"#11122111#",
		"#11111111#",
		".########.",
		"..........",
		"..........",
		".........."
	], {"#": k_out, "1": Color(0.34, 0.36, 0.42), "2": Color(0.52, 0.55, 0.62)})

	# --- 3. ПИКСЕЛЬНЫЕ ЗДАНИЯ ГОРОДОВ (12×12 с яркими окнами и куполами) ---
	var b_pal := {
		"#": k_out,
		"1": Color(0.58, 0.68, 0.82),
		"2": Color(0.88, 0.95, 1.0),
		"3": Color(0.22, 0.95, 1.0),
		"4": Color(1.0, 0.82, 0.25)
	}
	_sprites["bld_dome"] = _make_sprite_from_grid([
		"....####....",
		"..##2222##..",
		".#22333322#.",
		"#2332222332#",
		"#1223333221#",
		"#1112222111#",
		"#1144114411#",
		"#1144114411#",
		"############",
		"............",
		"............",
		"............"
	], b_pal)

	_sprites["bld_extractor"] = _make_sprite_from_grid([
		"....####....",
		"...#4444#...",
		"..#113311#..",
		"..#113311#..",
		".##111111##.",
		"#1411331141#",
		"#1411331141#",
		"#1111111111#",
		"############",
		"....#11#....",
		".....##.....",
		"............"
	], b_pal)

	_sprites["bld_spire"] = _make_sprite_from_grid([
		".....##.....",
		"....#33#....",
		"....#33#....",
		"...#2332#...",
		"...#1221#...",
		"..#113311#..",
		"..#113311#..",
		".#11233211#.",
		".#11122111#.",
		"#1144114411#",
		"############",
		"............"
	], b_pal)

	_sprites["bld_collider"] = _make_sprite_from_grid([
		"..########..",
		".#12222221#.",
		"#1233333321#",
		"#233####332#",
		"#23#....#32#",
		"#23#....#32#",
		"#233####332#",
		"#1233333321#",
		".#12222221#.",
		"..########..",
		"............",
		"............"
	], b_pal)

	_sprites["bld_elevator"] = _make_sprite_from_grid([
		".....##.....",
		"....#33#....",
		"....#22#....",
		"....#33#....",
		"...##22##...",
		"..#123321#..",
		"..#123321#..",
		".#11233211#.",
		"#1144334411#",
		"############",
		"............",
		"............"
	], b_pal)

	_sprites["bld_shipyard"] = _make_sprite_from_grid([
		".....##.....",
		"....#22#....",
		"...#2332#...",
		"...#2222#...",
		".###1441###.",
		"#1412222141#",
		"#1411111141#",
		"#1114444111#",
		"############",
		"............",
		"............",
		"............"
	], b_pal)

	_sprites["bld_anchor"] = _make_sprite_from_grid([
		"..##....##..",
		".#33#..#33#.",
		".#23####32#.",
		"..#123321#..",
		"..#134431#..",
		".#11344311#.",
		"#1122332211#",
		"#1111111111#",
		"############",
		"............",
		"............",
		"............"
	], b_pal)

	_sprites["bld_matrioshka"] = _make_sprite_from_grid([
		"....####....",
		"..##4444##..",
		".#44333344#.",
		"#4332442334#",
		"#4324334234#",
		"#4324334234#",
		"#4332442334#",
		".#44333344#.",
		"..##4444##..",
		"....####....",
		"............",
		"............"
	], b_pal)

	# --- 4. КОСМИЧЕСКИЕ ОБЪЕКТЫ (Ракета, Парус Дайсона, Астероид) ---
	_sprites["rocket_ship"] = _make_sprite_from_grid([
		"....##....",
		"...#22#...",
		"..#1221#..",
		"..#1331#..",
		"..#1221#..",
		".#412214#.",
		"#44111144#",
		"#4.#44#.4#",
		"...#44#...",
		".........."
	], {"#": k_out, "1": Color(0.75, 0.82, 0.92), "2": Color(0.96, 0.98, 1.0), "3": Color(0.2, 0.92, 1.0), "4": Color(1.0, 0.55, 0.15)})

	_sprites["dyson_sail"] = _make_sprite_from_grid([
		"....##....",
		"...#44#...",
		"..#4334#..",
		".#432234#.",
		"#43222234#",
		".#432234#.",
		"..#4334#..",
		"...#44#...",
		"....##....",
		".........."
	], {"#": k_out, "2": Color(0.85, 0.98, 1.0), "3": Color(0.25, 0.88, 1.0), "4": Color(1.0, 0.82, 0.25)})

	_sprites["asteroid_chunk"] = _make_sprite_from_grid([
		"...####...",
		".##1221##.",
		"#11221211#",
		"#12111121#",
		"#11121111#",
		".#111111#.",
		"..######..",
		".........."
	], {"#": k_out, "1": Color(0.38, 0.34, 0.32), "2": Color(0.58, 0.52, 0.46)})
