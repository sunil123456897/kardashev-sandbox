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
var rendered_flora_count: int = 0
var rendered_dyson_sail_count: int = 0

# Переключатели слоёв карты (WorldBox Map Layer Toggles)
var show_city_banners: bool = true
var show_diplomacy_lines: bool = true
var show_army_banners: bool = true

# Слои GPU-инстансинга в стиле WorldBox (MultiMeshInstance2D + worldbox_multimesh.gdshader)
var _map_bg_rect: TextureRect
var _mm_flora: MultiMeshInstance2D
var _mm_buildings: MultiMeshInstance2D
var _mm_actors: MultiMeshInstance2D
var _mm_flora_material: ShaderMaterial
var _mm_buildings_material: ShaderMaterial
var _mm_actors_material: ShaderMaterial
var _atlas_flora_tex: ImageTexture
var _atlas_building_tex: ImageTexture
var _atlas_actor_tex: ImageTexture
var _flora_type_to_col: Dictionary = {}
var _building_arch_to_col: Dictionary = {}
var _actor_key_to_col: Dictionary = {}

# Палитра базовых тайлов WorldBox v0.51.2 (из декомпилированного TileLibrary)
const WB_DEEP_OCEAN := Color(0.200, 0.439, 0.800)      # #3370CC
const WB_ABYSS_OCEAN := Color(0.161, 0.353, 0.651)     # #295AA6
const WB_CLOSE_OCEAN := Color(0.251, 0.518, 0.886)     # #4084E2
const WB_SHALLOW_WATERS := Color(0.333, 0.682, 0.941)  # #55AEF0
const WB_SHORE_FOAM := Color(0.604, 0.973, 1.000)      # #9AF8FF
const WB_SAND := Color(0.969, 0.910, 0.596)            # #F7E898
const WB_SAND_WET := Color(0.847, 0.753, 0.549)        # #D8C08C
const WB_SOIL_LOW := Color(0.886, 0.576, 0.294)        # #E2934B
const WB_SOIL_HIGH := Color(0.714, 0.435, 0.227)       # #B66F3A
const WB_HILLS := Color(0.357, 0.369, 0.361)           # #5B5E5C
const WB_HILLS_EDGE := Color(0.427, 0.439, 0.431)      # #6D706E
const WB_MOUNTAINS := Color(0.255, 0.271, 0.271)       # #414545
const WB_SUMMIT := Color(0.200, 0.200, 0.200)          # #333333
const WB_SUMMIT_SNOW := Color(0.886, 0.929, 0.969)     # #E2EDF7
const WB_ROAD := Color(0.757, 0.600, 0.486)            # #C1997C
const WB_ROAD_EDGE := Color(0.678, 0.525, 0.420)       # #AD866B
const WB_FIELD := Color(0.659, 0.400, 0.227)           # #A8663A
const WB_FIELD_FURROW := Color(0.557, 0.325, 0.173)    # #8E532C

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
	_init_multimesh_layers()
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
	_update_multimeshes(0.0)
	queue_redraw()


func _create_2d_quad_mesh(w: float, h: float) -> ArrayMesh:
	var hw: float = w * 0.5
	var hh: float = h * 0.5
	var verts := PackedVector2Array([
		Vector2(-hw, -hh),
		Vector2(hw, -hh),
		Vector2(hw, hh),
		Vector2(-hw, -hh),
		Vector2(hw, hh),
		Vector2(-hw, hh)
	])
	var uvs := PackedVector2Array([
		Vector2(0.0, 0.0),
		Vector2(1.0, 0.0),
		Vector2(1.0, 1.0),
		Vector2(0.0, 0.0),
		Vector2(1.0, 1.0),
		Vector2(0.0, 1.0)
	])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


func _init_multimesh_layers() -> void:
	# 0. Полноэкранный пиксельный фон карты (show_behind_parent = true, рисуется первым)
	if _map_bg_rect == null:
		_map_bg_rect = TextureRect.new()
		_map_bg_rect.name = "WorldBoxMapBgRect"
		_map_bg_rect.position = Vector2.ZERO
		_map_bg_rect.size = Vector2(1920.0, 1080.0)
		_map_bg_rect.stretch_mode = TextureRect.STRETCH_SCALE
		_map_bg_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_map_bg_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_map_bg_rect.show_behind_parent = true
		add_child(_map_bg_rect)

	var wb_shader: Shader = load("res://shaders/worldbox_multimesh.gdshader") as Shader

	# 1. MultiMeshInstance2D для Флоры и Рудных Залежей (~480 объектов)
	if _mm_flora == null:
		_mm_flora = MultiMeshInstance2D.new()
		_mm_flora.name = "MultiMeshFlora"
		_mm_flora.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_mm_flora.show_behind_parent = true
		_mm_flora.texture = _atlas_flora_tex
		var mm_f := MultiMesh.new()
		mm_f.transform_format = MultiMesh.TRANSFORM_2D
		mm_f.use_colors = true
		mm_f.use_custom_data = true
		mm_f.mesh = _create_2d_quad_mesh(20.0, 20.0)
		mm_f.instance_count = 0
		_mm_flora.multimesh = mm_f
		if wb_shader != null:
			_mm_flora_material = ShaderMaterial.new()
			_mm_flora_material.shader = wb_shader
			_mm_flora_material.set_shader_parameter("atlas_cols", 10.0)
			_mm_flora_material.set_shader_parameter("sway_strength", 2.1)
			_mm_flora.material = _mm_flora_material
		add_child(_mm_flora)

	# 2. MultiMeshInstance2D для Зданий Полисов (пружинящий scale.y при постройке)
	if _mm_buildings == null:
		_mm_buildings = MultiMeshInstance2D.new()
		_mm_buildings.name = "MultiMeshBuildings"
		_mm_buildings.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_mm_buildings.show_behind_parent = true
		_mm_buildings.texture = _atlas_building_tex
		var mm_b := MultiMesh.new()
		mm_b.transform_format = MultiMesh.TRANSFORM_2D
		mm_b.use_colors = true
		mm_b.use_custom_data = true
		mm_b.mesh = _create_2d_quad_mesh(26.0, 26.0)
		mm_b.instance_count = 0
		_mm_buildings.multimesh = mm_b
		if wb_shader != null:
			_mm_buildings_material = ShaderMaterial.new()
			_mm_buildings_material.shader = wb_shader
			_mm_buildings_material.set_shader_parameter("atlas_cols", 8.0)
			_mm_buildings_material.set_shader_parameter("sway_strength", 0.0)
			_mm_buildings.material = _mm_buildings_material
		add_child(_mm_buildings)

	# 3. MultiMeshInstance2D для Жителей (2 кадра шага, покачивание, вспышка удара)
	if _mm_actors == null:
		_mm_actors = MultiMeshInstance2D.new()
		_mm_actors.name = "MultiMeshActors"
		_mm_actors.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_mm_actors.show_behind_parent = true
		_mm_actors.texture = _atlas_actor_tex
		var mm_a := MultiMesh.new()
		mm_a.transform_format = MultiMesh.TRANSFORM_2D
		mm_a.use_colors = true
		mm_a.use_custom_data = true
		mm_a.mesh = _create_2d_quad_mesh(16.0, 16.0)
		mm_a.instance_count = 0
		_mm_actors.multimesh = mm_a
		if wb_shader != null:
			_mm_actors_material = ShaderMaterial.new()
			_mm_actors_material.shader = wb_shader
			_mm_actors_material.set_shader_parameter("atlas_cols", 10.0)
			_mm_actors_material.set_shader_parameter("sway_strength", 0.0)
			_mm_actors.material = _mm_actors_material
		add_child(_mm_actors)


func _sync_multimesh_visibility() -> void:
	var vis: bool = (view_mode == 0)
	if _map_bg_rect != null:
		_map_bg_rect.visible = vis
	if _mm_flora != null:
		_mm_flora.visible = vis
	if _mm_buildings != null:
		_mm_buildings.visible = vis
	if _mm_actors != null:
		_mm_actors.visible = vis


func _update_multimeshes(_delta: float) -> void:
	if sim == null:
		return
	_sync_multimesh_visibility()

	# 1. Флора и минеральные жилы
	if _mm_flora != null and _mm_flora.multimesh != null:
		var mm_f: MultiMesh = _mm_flora.multimesh
		var f_list: Array = sim.flora_instances
		var f_cnt: int = f_list.size()
		if mm_f.instance_count != f_cnt:
			mm_f.instance_count = f_cnt
		for i in range(f_cnt):
			var fl: Dictionary = f_list[i]
			var f_pos: Vector2 = fl["pos"]
			var f_type: String = str(fl.get("type", "bio_tree"))
			var col_idx: float = float(_flora_type_to_col.get(f_type, 0))
			var is_min: bool = bool(fl.get("is_mineral", false))
			var sway_ph: float = 0.0 if is_min else maxf(0.05, float(fl.get("sway_phase", 0.5)))
			var chop_sh: float = clampf(float(fl.get("chop_shake", 0.0)), 0.0, 1.0)
			var sp_spr: float = clampf(float(fl.get("spawn_spring", 1.0)), 0.05, 1.0)
			if _delta > 0.0:
				if chop_sh > 0.0:
					chop_sh = maxf(0.0, chop_sh - _delta * 3.5)
					fl["chop_shake"] = chop_sh
				if sp_spr < 1.0:
					sp_spr = minf(1.0, sp_spr + _delta * 2.2)
					fl["spawn_spring"] = sp_spr

			mm_f.set_instance_transform_2d(i, Transform2D(0.0, f_pos + Vector2(0.0, -4.0)))
			mm_f.set_instance_color(i, Color.WHITE)
			mm_f.set_instance_custom_data(i, Color(sway_ph, chop_sh, sp_spr, col_idx))

			# Если рубят дерево или дробят кристалл — спавним пиксельные щепки с гравитацией
			if chop_sh > 0.88 and _particles.size() < 220 and ((i + int(_anim_time * 60.0)) % 5 == 0):
				var chip_col := Color(0.35, 0.92, 0.88) if is_min else Color(0.28, 0.78, 0.36)
				_particles.append({
					"pos": f_pos + Vector2(randf_range(-4.0, 4.0), -6.0),
					"vel": Vector2(randf_range(-38.0, 38.0), randf_range(-65.0, -25.0)),
					"gravity": 260.0,
					"ground_y": f_pos.y + randf_range(-2.0, 5.0),
					"color": chip_col,
					"size": 3.0,
					"life": 0.42,
					"max_life": 0.42
				})

	# 2. Здания городов
	if _mm_buildings != null and _mm_buildings.multimesh != null:
		var mm_b: MultiMesh = _mm_buildings.multimesh
		var total_b: int = 0
		for c_id in sim.cities_map.keys():
			total_b += (sim.cities_map[c_id]["building_instances"] as Array).size()
		if mm_b.instance_count != total_b:
			mm_b.instance_count = total_b
		var b_idx: int = 0
		for c_id in sim.cities_map.keys():
			var city: Dictionary = sim.cities_map[c_id]
			var c_col: Color = city["color"]
			var tint: Color = Color.WHITE.lerp(c_col.lightened(0.35), 0.35)
			var inst_list: Array = city["building_instances"]
			for b_inst in inst_list:
				var b_pos: Vector2 = b_inst["map_pos"]
				var arch: String = str(b_inst.get("archetype", "dome"))
				var col_idx: float = float(_building_arch_to_col.get(arch, 0))
				var sp_spr: float = clampf(float(b_inst.get("spawn_spring", 1.0)), 0.05, 1.0)
				var hit_sh: float = clampf(float(b_inst.get("hit_shake", 0.0)), 0.0, 1.0)
				mm_b.set_instance_transform_2d(b_idx, Transform2D(0.0, b_pos + Vector2(0.0, -3.0)))
				mm_b.set_instance_color(b_idx, tint)
				mm_b.set_instance_custom_data(b_idx, Color(0.0, hit_sh, sp_spr, col_idx))
				b_idx += 1

	# 3. Живые человечки и существа (Actors)
	if _mm_actors != null and _mm_actors.multimesh != null:
		var mm_a: MultiMesh = _mm_actors.multimesh
		var a_cnt: int = sim.actors.size()
		if mm_a.instance_count != a_cnt:
			mm_a.instance_count = a_cnt
		var frame_tick: int = int(_anim_time * 5.0) % 2
		for i in range(a_cnt):
			var a: Dictionary = sim.actors[i]
			var a_pos: Vector2 = a["pos"]
			var arch: String = str(a.get("archetype", "carbon"))
			var u_frame: int = (frame_tick + int(a.get("id", i))) % 2
			var col_idx: float = float(_actor_key_to_col.get("%s_%d" % [arch, u_frame], 0))
			var flip_x: float = -1.0 if bool(a.get("facing_left", false)) else 1.0
			var ptrs: Array = a.get("personal_traits", [])
			var scale_m: float = 1.38 if ptrs.has("trait_giant") else (1.15 if str(a.get("role", "")) == "general" else 1.0)
			var xf := Transform2D(Vector2(flip_x * scale_m, 0.0), Vector2(0.0, scale_m), a_pos + Vector2(0.0, -2.0))
			var walk_ph: float = -maxf(0.02, float(a.get("anim_phase", 0.5)))
			var hit_fl: float = 0.85 if str(a.get("job_state", "")) == "WORKING" and sin(float(a.get("tool_swing", 0.0))) > 0.7 else 0.0
			var inst_col: Color = Color.WHITE.lerp(a.get("color", Color.WHITE), 0.35) if str(a.get("role", "")) == "fauna" else Color.WHITE
			mm_a.set_instance_transform_2d(i, xf)
			mm_a.set_instance_color(i, inst_col)
			mm_a.set_instance_custom_data(i, Color(walk_ph, hit_fl * 0.35, 1.0, col_idx))


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
	_sync_multimesh_visibility()
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
				"gravity": -30.0,
				"color": Color(1.0, 0.65, 0.18, 0.95),
				"size": 4.0,
				"life": 0.35,
				"max_life": 0.35
			})
		if float(r["life"]) <= 0.0 or pos.y < 75.0:
			_active_rockets.remove_at(i)

	# Обновляем физические пиксельные частицы с гравитацией и отскоком от земли (WorldBox Pixel Debris)
	for i in range(_particles.size() - 1, -1, -1):
		var p: Dictionary = _particles[i]
		var vel: Vector2 = p["vel"]
		var grav: float = float(p.get("gravity", 240.0))
		vel.y += grav * delta
		var pos: Vector2 = (p["pos"] as Vector2) + vel * delta
		if p.has("ground_y"):
			var gy: float = float(p["ground_y"])
			if pos.y >= gy and vel.y > 0.0:
				pos.y = gy
				vel.y = -vel.y * 0.36
				vel.x *= 0.62
		p["pos"] = pos
		p["vel"] = vel
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
	_update_multimeshes(delta)
	queue_redraw()


func _refresh_counts() -> void:
	if sim == null:
		return
	rendered_actor_count = sim.actors.size()
	rendered_flora_count = sim.flora_instances.size()
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
	_refresh_counts()
	_update_multimeshes(0.0)
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
		var spd: float = randf_range(28.0, maxf(65.0, radius_px * 1.25))
		var offset := Vector2(cos(ang), sin(ang)) * randf_range(0.0, radius_px * 0.35)
		_particles.append({
			"pos": map_pos + offset,
			"vel": Vector2(cos(ang) * spd, sin(ang) * spd * 0.55 - randf_range(40.0, 95.0)),
			"gravity": 260.0,
			"ground_y": map_pos.y + offset.y + randf_range(4.0, 18.0),
			"color": color.lightened(0.25),
			"size": 5.0 if randf() < 0.5 else 4.0,
			"life": randf_range(0.45, 0.95),
			"max_life": 0.95
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
	if _map_bg_rect != null:
		_map_bg_rect.texture = _map_texture
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
	if _map_bg_rect != null:
		_map_bg_rect.texture = _map_texture
	queue_redraw()


func _sample_and_shade_pixel(px: int, py: int, u: float, v: float, bayer2: Array) -> Color:
	var gw: int = sim.GRID_W
	var gh: int = sim.GRID_H
	var fx: float = clampf(u * float(gw), 0.0, float(gw) - 0.001)
	var fy: float = clampf(v * float(gh), 0.0, float(gh) - 0.001)
	var gx: int = int(fx)
	var gy: int = int(fy)
	var gx1: int = mini(gx + 1, gw - 1)
	var gy1: int = mini(gy + 1, gh - 1)
	var tx: float = fx - float(gx)
	var ty: float = fy - float(gy)

	var t00: Dictionary = sim.tiles[gy * gw + gx]
	var e00: float = float(t00["elevation"])
	var e10: float = float(sim.tiles[gy * gw + gx1]["elevation"])
	var e01: float = float(sim.tiles[gy1 * gw + gx]["elevation"])
	var e11: float = float(sim.tiles[gy1 * gw + gx1]["elevation"])
	var base_e: float = lerpf(lerpf(e00, e10, tx), lerpf(e01, e11, tx), ty)

	var coast_jitter: float = sim._noise_detail.get_noise_2d(u * 180.0, v * 110.0) * 0.055
	var micro_jitter: float = sim._noise_detail.get_noise_2d(u * 420.0 + 70.0, v * 260.0) * 0.022
	var fine_idx: int = py * TEX_W + px
	var fine_delta: float = 0.0
	if sim.has_fine_elevation_deltas and fine_idx >= 0 and fine_idx < sim.fine_elevation_delta.size():
		fine_delta = sim.fine_elevation_delta[fine_idx]
	var elev: float = clampf(base_e + coast_jitter + micro_jitter + fine_delta, -0.38, 0.48)
	var dither: float = bayer2[(px % 2) + (py % 2) * 2] - 0.375
	var tier: int = sim.classify_base_tile_tier(elev)

	if tier == 0:
		# Глубокий океан (WorldBox TileLibrary.deep_ocean #3370CC)
		if elev + dither * 0.025 < -0.25 or ((px + py * 3) % 19) == 0:
			return WB_ABYSS_OCEAN
		return WB_DEEP_OCEAN
	elif tier == 1:
		# Прибрежный океан (WorldBox TileLibrary.close_ocean #4084E2)
		if elev + dither * 0.025 < -0.165:
			return WB_DEEP_OCEAN
		return WB_CLOSE_OCEAN

	var jx: int = clampi(int(fx + coast_jitter * 6.5), 0, gw - 1)
	var jy: int = clampi(int(fy + micro_jitter * 12.0), 0, gh - 1)
	var biome_id: String = sim.tiles[jy * gw + jx]["biome_id"]

	var zx: int = clampi(px / sim.ZONE_SIZE, 0, sim.ZONE_W - 1)
	var zy: int = clampi(py / sim.ZONE_SIZE, 0, sim.ZONE_H - 1)
	var z_id: int = zy * sim.ZONE_W + zx
	var city_id: int = int(t00["city_id"])
	if z_id >= 0 and z_id < sim.zone_city_id.size() and sim.zone_city_id[z_id] != -1:
		city_id = sim.zone_city_id[z_id]

	# Северный сосед (py - 1) для 2.5D теней уступов и береговой пены в стиле WorldBox
	var py_n: int = maxi(0, py - 1)
	var v_north: float = (float(py_n) + 0.5) / float(TEX_H)
	var ty_n: float = maxf(0.0, ty - 0.148148)
	var base_e_n: float = lerpf(lerpf(e00, e10, tx), lerpf(e01, e11, tx), ty_n)
	var fine_delta_n: float = 0.0
	var fine_idx_n: int = py_n * TEX_W + px
	if sim.has_fine_elevation_deltas and fine_idx_n >= 0 and fine_idx_n < sim.fine_elevation_delta.size():
		fine_delta_n = sim.fine_elevation_delta[fine_idx_n]
	var elev_n: float = clampf(base_e_n + sim._noise_detail.get_noise_2d(u * 180.0, v_north * 110.0) * 0.055 + micro_jitter + fine_delta_n, -0.38, 0.48)
	var tier_n: int = sim.classify_base_tile_tier(elev_n)

	var col: Color
	if tier == 2:
		# Мелководная лагуна (WorldBox TileLibrary.shallow_waters #55AEF0) или лёд в Эпоху Крио-Сна
		if sim.current_age_id == "age_of_ice":
			col = Color(0.76, 0.93, 0.99) if ((px + py) % 2 == 0) else Color(0.62, 0.85, 0.96)
		elif (elev > -0.014 or tier_n >= 3) and ((px + py) % 2 == 0):
			col = WB_SHORE_FOAM
		else:
			col = WB_SHALLOW_WATERS
	elif tier == 3:
		# Песчаный пляж (WorldBox TileLibrary.sand #F7E898 / мокрый песок #D8C08C)
		if biome_id == "biome_plasma_inferno" or biome_id == "biome_cybercore" or biome_id == "biome_singularity_swamp":
			col = Color(0.28, 0.27, 0.33) if (px + py) % 2 == 0 else Color(0.22, 0.21, 0.26)
		elif biome_id == "biome_cryo_superconductor":
			col = Color(0.75, 0.88, 0.96) if (px + py) % 2 == 0 else Color(0.65, 0.80, 0.90)
		else:
			var is_wet: bool = (elev < 0.015) or (tier_n <= 2) or ((px + py) % 3 == 0 and elev < 0.024)
			col = WB_SAND_WET if is_wet else WB_SAND
	elif tier == 4 or tier == 5:
		# Основная суша: проверяем дороги (#C1997C) и фермерские поля (#A8663A) поверх почвы
		var road_val: int = sim.fine_road_overlay[fine_idx] if fine_idx < sim.fine_road_overlay.size() else 0
		if road_val == 1:
			col = WB_ROAD if ((px + py) % 3 != 0) else WB_ROAD_EDGE
		elif road_val == 2:
			col = WB_FIELD if (py % 2 == 0) else WB_FIELD_FURROW
		else:
			var b_asset: SandboxAssetScript.BiomeAsset = sim.assets.biomes.get(biome_id)
			var low_c: Color = b_asset.base_color_low if b_asset != null else WB_SOIL_LOW
			var high_c: Color = b_asset.base_color_high if b_asset != null else WB_SOIL_HIGH
			var dec_c: Color = b_asset.decor_color if b_asset != null else low_c.lightened(0.12)
			var em_c: Color = b_asset.emissive_color if b_asset != null else Color.BLACK
			var em_str: float = b_asset.emissive_strength if b_asset != null else 0.0

			# Чёткое разделение на _low и _high слой биома с пиксельным дизерингом на границе (WorldBox TopTileLibrary)
			var use_high: bool = (elev + dither * 0.028) >= 0.135
			col = high_c if use_high else low_c

			# Микро-декор травинок и цветов биома
			var hash_decor: int = ((px * 374761393) ^ (py * 668265263)) & 0x7fffffff
			if (hash_decor % 19) == 0:
				col = dec_c

			if biome_id == "biome_cybercore":
				if (px % 6 == 0 and py % 3 != 0) or (py % 6 == 0 and px % 4 != 0):
					col = col.lerp(Color(0.41, 0.92, 0.87), 0.55)
			elif biome_id == "biome_plasma_inferno":
				if ((px * 5 + py * 7) % 11) < 2:
					col = Color(1.0, 0.42, 0.03)
			elif em_str > 0.2 and ((px * 13 + py * 7) % 23) == 0:
				col = col.lerp(em_c, 0.55)
	elif tier == 6:
		# Скалистые предгорья (WorldBox TileLibrary.hills #5B5E5C) без шахматной сетки
		var h_noise: int = ((px * 374761393) ^ (py * 668265263)) & 0x7fffffff
		col = WB_HILLS_EDGE if (h_noise % 11 == 0) else WB_HILLS
	elif tier == 7:
		# Высокие горы (WorldBox TileLibrary.mountains #414545)
		var m_noise: int = ((px * 2654435761) ^ (py * 1597334677)) & 0x7fffffff
		col = WB_HILLS if (m_noise % 13 == 0) else WB_MOUNTAINS
	else:
		# Горные пики и ледники (WorldBox TileLibrary.summit #333333 + сплошная снежная шапка на вершине)
		if elev + dither * 0.015 >= 0.345:
			col = WB_SUMMIT_SNOW
		else:
			col = WB_SUMMIT

	# 2.5D микро-тень высоты под каждым уступом рельефа и светлая кромка (WorldBox Cliff Drop-Shadow)
	if tier >= 2:
		if tier_n > tier and tier_n >= 3:
			col = col.darkened(0.26)
		elif tier > tier_n and tier >= 3:
			col = col.lightened(0.14)

	# Чёткие квадратные зоны городов 8×8 тайлов с яркими внешними границами государств (WorldBox TileZone)
	if city_id != -1 and sim.cities_map.has(city_id) and tier >= 2:
		var c_col: Color = sim.cities_map[city_id]["color"]
		col = col.lerp(c_col, 0.14)

		var lx: int = px % sim.ZONE_SIZE
		var ly: int = py % sim.ZONE_SIZE
		var is_border := false
		if lx == 0 and (zx == 0 or sim._get_zone_owner(zx - 1, zy) != city_id):
			is_border = true
		elif lx == sim.ZONE_SIZE - 1 and (zx == sim.ZONE_W - 1 or sim._get_zone_owner(zx + 1, zy) != city_id):
			is_border = true
		elif ly == 0 and (zy == 0 or sim._get_zone_owner(zx, zy - 1) != city_id):
			is_border = true
		elif ly == sim.ZONE_SIZE - 1 and (zy == sim.ZONE_H - 1 or sim._get_zone_owner(zx, zy + 1) != city_id):
			is_border = true

		if is_border:
			col = c_col.lightened(0.32) if ((px + py) % 2 == 0) else c_col.darkened(0.15)

	# Отрисовка клеточного пожара (WorldBox FireLayer) поверх тайла
	if fine_idx >= 0 and fine_idx < sim.fine_fire_time.size() and sim.fine_fire_time[fine_idx] > 0.0:
		var fire_col := Color(1.0, 0.88, 0.22) if ((px + py) % 2 == 0) else Color(1.0, 0.36, 0.06)
		col = col.lerp(fire_col, 0.82)

	return col


func compute_non_overlapping_city_banner_rects() -> Dictionary:
	var result: Dictionary = {}
	if sim == null or sim.cities_map.is_empty():
		return result

	var ids := sim.cities_map.keys()
	ids.sort()
	var banner_w: float = 176.0
	var banner_h: float = 19.0
	var safe_min := Vector2(268.0, 114.0)
	var safe_max := Vector2(1652.0 - banner_w, 920.0 - banner_h)

	for cid in ids:
		var c: Dictionary = sim.cities_map[cid]
		var c_pos: Vector2 = c["map_pos"]
		var bx: float = clampf(c_pos.x - banner_w * 0.5, safe_min.x, safe_max.x)
		var by: float = clampf(c_pos.y - 36.0, safe_min.y, safe_max.y)
		result[cid] = Rect2(bx, by, banner_w, banner_h)

	# Итеративное разведение пересекающихся табличек полисов, чтобы они никогда не налезали друг на друга
	for _iter in range(16):
		var moved := false
		for i in range(ids.size()):
			var id_a: int = ids[i]
			var ra: Rect2 = result[id_a]
			for j in range(i + 1, ids.size()):
				var id_b: int = ids[j]
				var rb: Rect2 = result[id_b]
				if ra.grow(3.0).intersects(rb.grow(3.0)):
					moved = true
					var ca := ra.get_center()
					var cb := rb.get_center()
					var dy: float = cb.y - ca.y
					var dx: float = cb.x - ca.x
					var push_y: float = (banner_h + 6.0 - absf(dy)) * 0.55
					if push_y > 0.0:
						var sign_y: float = 1.0 if (dy > 0.0 or (is_zero_approx(dy) and id_b > id_a)) else -1.0
						ra.position.y = clampf(ra.position.y - sign_y * push_y, safe_min.y, safe_max.y)
						rb.position.y = clampf(rb.position.y + sign_y * push_y, safe_min.y, safe_max.y)
					if ra.grow(2.0).intersects(rb.grow(2.0)):
						var sign_x: float = 1.0 if (dx >= 0.0) else -1.0
						ra.position.x = clampf(ra.position.x - sign_x * 18.0, safe_min.x, safe_max.x)
						rb.position.x = clampf(rb.position.x + sign_x * 18.0, safe_min.x, safe_max.x)
					result[id_a] = ra
					result[id_b] = rb
		if not moved:
			break

	return result


# ==============================================================================
# ОТРИСОВКА КАДРА (3 РЕЖИМА В ЧИСТОМ 2D PIXEL-ART)
# ==============================================================================
func _draw() -> void:
	if sim == null:
		return
	_sync_multimesh_visibility()

	match view_mode:
		0:
			_draw_mode_planet_worldbox()
		1:
			_draw_mode_star_dyson_2d()
		2:
			_draw_mode_system_overview_2d()


func _draw_mode_planet_worldbox() -> void:
	# 1. Базовая попиксельная карта 384×216 рисуется через _map_bg_rect (или напрямую, если нода ещё не создана)
	if _map_bg_rect == null and _map_texture != null:
		draw_texture_rect(_map_texture, Rect2(0.0, 0.0, 1920.0, 1080.0), false)

	# 2. Анимированные пиксельные блики волн на воде
	var wave_shift: int = int(_anim_time * 3.0)
	for i in range(0, sim.TILE_COUNT, 3):
		var t: Dictionary = sim.tiles[i]
		if float(t["elevation"]) < -0.03:
			var mp: Vector2 = t["map_pos"]
			var wx: float = mp.x + float(((i * 17 + wave_shift) % 7) - 3) * 5.0
			var wy: float = mp.y + float(((i * 11) % 5) - 2) * 5.0
			draw_rect(Rect2(wx, wy, 10.0, 3.0), Color(0.72, 0.94, 1.0, 0.28), true)

	# 3. Флора и минералы рендерятся батчем через _mm_flora (MultiMeshInstance2D + worldbox_multimesh.gdshader)
	# 4. Отрисовка лучей орбитальных лифтов и гравитационных якорей поверх зданий (_mm_buildings)
	for c_id in sim.cities_map.keys():
		var city: Dictionary = sim.cities_map[c_id]
		var c_col: Color = city["color"]
		var inst_list: Array = city["building_instances"]
		for b_inst in inst_list:
			var b_pos: Vector2 = b_inst["map_pos"]
			var arch: String = b_inst["archetype"]
			if arch == "elevator" or arch == "anchor":
				draw_rect(Rect2(b_pos.x - 2.0, 92.0, 4.0, maxf(0.0, b_pos.y - 92.0)), Color(c_col.r, c_col.g, c_col.b, 0.32), true)
				draw_rect(Rect2(b_pos.x - 1.0, 92.0, 2.0, maxf(0.0, b_pos.y - 92.0)), Color(0.85, 0.98, 1.0, 0.65), true)

	# 5. Инструменты в руках, переносимые ресурсы (бревна, руда, урожай) и значки профессий над жителями (_mm_actors)
	for a in sim.actors:
		var a_pos: Vector2 = a["pos"]
		var bob_y: float = -absf(sin(float(a["anim_phase"]))) * 2.4
		var dir_x: float = -1.0 if bool(a.get("facing_left", false)) else 1.0
		var j_state: String = str(a.get("job_state", ""))
		var carried: String = str(a.get("carrying", ""))

		# Отображение ресурса в руках при доставке на склад полиса (CARRY_TO_STORAGE)
		if carried == "wood":
			draw_rect(Rect2(a_pos.x + dir_x * 4.0 - 3.0, a_pos.y - 5.0 + bob_y, 7.0, 4.0), Color(0.55, 0.34, 0.16), true)
			draw_rect(Rect2(a_pos.x + dir_x * 4.0 - 2.0, a_pos.y - 4.0 + bob_y, 5.0, 2.0), Color(0.76, 0.52, 0.28), true)
		elif carried == "minerals":
			draw_rect(Rect2(a_pos.x + dir_x * 4.0 - 3.0, a_pos.y - 6.0 + bob_y, 6.0, 5.0), Color(0.25, 0.95, 0.88), true)
		elif carried == "food":
			draw_rect(Rect2(a_pos.x + dir_x * 4.0 - 3.0, a_pos.y - 5.0 + bob_y, 6.0, 4.0), Color(0.98, 0.84, 0.22), true)
		elif j_state == "WORKING":
			# Взмах топора / кирки / молотка при рубке дерева, добыче руды или постройке
			var swing_y: float = sin(float(a.get("tool_swing", 0.0))) * 4.0
			draw_rect(Rect2(a_pos.x + dir_x * 6.0 - 2.0, a_pos.y - 6.0 + bob_y + swing_y, 4.0, 5.0), Color(0.88, 0.92, 0.98), true)
		else:
			# Отрисовка выкованного оружия в руках воинов и генералов (WorldBox ItemRenderer)
			var w_id: String = str(a.get("weapon_id", ""))
			if w_id != "":
				var w_col := Color(0.25, 0.95, 1.0)
				if w_id == "eq_plasma_lance":
					w_col = Color(1.0, 0.78, 0.22)
				elif w_id == "eq_tachyon_hammer":
					w_col = Color(0.95, 0.35, 1.0)
				elif w_id == "eq_void_rifle":
					w_col = Color(0.55, 0.45, 1.0)
				draw_rect(Rect2(a_pos.x + dir_x * 5.0 - 1.0, a_pos.y - 8.0 + bob_y, 2.5, 7.0), w_col, true)

		# Маленький пиксельный значок профессии над учёными, астронавтами, генералами и избранными
		var role: String = a.get("role", "")
		if role == "scholar":
			draw_rect(Rect2(a_pos.x - 2.0, a_pos.y - 14.0 + bob_y, 4.0, 4.0), Color(0.25, 0.95, 1.0), true)
		elif role == "astronaut":
			draw_rect(Rect2(a_pos.x - 2.0, a_pos.y - 14.0 + bob_y, 4.0, 4.0), Color(1.0, 0.85, 0.25), true)
		elif role == "general" and show_army_banners:
			var gen_cid: int = int(a.get("city_id", -1))
			var flag_col: Color = sim.cities_map[gen_cid]["color"] if sim.cities_map.has(gen_cid) else a.get("color", Color.GOLD)
			draw_rect(Rect2(a_pos.x - 1.0, a_pos.y - 24.0 + bob_y, 2.0, 14.0), Color(0.85, 0.82, 0.72), true)
			draw_rect(Rect2(a_pos.x + 1.0, a_pos.y - 24.0 + bob_y, 13.0, 8.0), flag_col.darkened(0.15), true)
			draw_rect(Rect2(a_pos.x + 1.0, a_pos.y - 24.0 + bob_y, 13.0, 8.0), Color(1.0, 0.88, 0.32), false, 1.0)
			draw_rect(Rect2(a_pos.x + 5.0, a_pos.y - 22.0 + bob_y, 4.0, 4.0), Color(1.0, 0.92, 0.35), true)

		if bool(a.get("is_favorite", false)):
			draw_rect(Rect2(a_pos.x - 3.0, a_pos.y - 19.0 + bob_y, 6.0, 6.0), Color(1.0, 0.88, 0.18), true)
			draw_rect(Rect2(a_pos.x - 1.5, a_pos.y - 17.5 + bob_y, 3.0, 3.0), Color(1.0, 0.98, 0.75), true)

	# 6. Пиксельные купола-линзы констант (Время ×25, Гравитация 0.1G, Сингулярность)
	var font: Font = ThemeDB.fallback_font
	for l_idx in range(sim.field_lenses.size()):
		var lens: Dictionary = sim.field_lenses[l_idx]
		var l_pos: Vector2 = lens["map_pos"]
		var l_rad: float = float(lens["radius_px"])
		var l_col: Color = lens["color"]
		_draw_pixel_lens_dome(l_pos, l_rad, l_col, str(lens["lens_type"]), float(lens["time_mult"]), float(lens["grav_mult"]), font, l_idx)

	# 7. Дипломатические индикаторы цивилизаций (Войны, Союзы, Торговля)
	rendered_active_war_count = 0
	rendered_alliance_count = 0
	rendered_trade_route_count = 0
	var cities_in_war: Dictionary = {}

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
				cities_in_war[id_a] = true
				cities_in_war[id_b] = true
				if show_diplomacy_lines:
					draw_line(pos_a, pos_b, Color(0.95, 0.22, 0.22, 0.52), 2.0)
					var clash_t: float = 0.5 + sin(_anim_time * 8.0 + float(id_a + id_b)) * 0.2
					var clash_p: Vector2 = pos_a.lerp(pos_b, clash_t)
					draw_rect(Rect2(clash_p.x - 4.0, clash_p.y - 4.0, 8.0, 8.0), Color(1.0, 0.45, 0.15), true)
			"ALLIANCE":
				rendered_alliance_count += 1
				rendered_trade_route_count += 1
				if show_diplomacy_lines:
					draw_line(pos_a, pos_b, Color(0.25, 0.78, 1.0, 0.32), 3.0)
					draw_dashed_line(pos_a, pos_b, Color(1.0, 0.82, 0.25, 0.72), 1.8, 9.0)
					var car_t_al: float = fmod(_anim_time * 0.25 + float(id_a * 7 + id_b * 13) * 0.1, 1.0)
					var car_p_al: Vector2 = pos_a.lerp(pos_b, car_t_al)
					draw_rect(Rect2(car_p_al.x - 3.0, car_p_al.y - 3.0, 6.0, 6.0), Color(1.0, 0.95, 0.45), true)
					draw_rect(Rect2(mid_p.x - 24.0, mid_p.y - 8.0, 48.0, 15.0), Color(0.04, 0.08, 0.18, 0.86), true)
					draw_rect(Rect2(mid_p.x - 24.0, mid_p.y - 8.0, 48.0, 15.0), Color(0.35, 0.85, 1.0, 0.8), false, 1.0)
					if font != null:
						draw_string(font, Vector2(mid_p.x - 22.0, mid_p.y + 3.0), "🛡 СОЮЗ", HORIZONTAL_ALIGNMENT_CENTER, 44.0, 9, Color(0.75, 0.95, 1.0))
			"TRADE":
				rendered_trade_route_count += 1
				if show_diplomacy_lines:
					draw_dashed_line(pos_a, pos_b, Color(1.0, 0.82, 0.25, 0.72), 1.8, 9.0)
					var car_t: float = fmod(_anim_time * 0.25 + float(id_a * 7 + id_b * 13) * 0.1, 1.0)
					var car_p: Vector2 = pos_a.lerp(pos_b, car_t)
					draw_rect(Rect2(car_p.x - 3.0, car_p.y - 3.0, 6.0, 6.0), Color(1.0, 0.95, 0.45), true)

	# 7.1. Неперекрывающиеся таблички-баннеры городов со значком войны ⚔ (WorldBox City Banner Layout)
	if show_city_banners:
		var banner_rects: Dictionary = compute_non_overlapping_city_banner_rects()
		for c_id in sim.cities_map.keys():
			var city: Dictionary = sim.cities_map[c_id]
			var c_pos: Vector2 = city["map_pos"]
			var c_col: Color = city["color"]
			var banner_rect: Rect2 = banner_rects.get(c_id, Rect2(c_pos.x - 88.0, c_pos.y - 36.0, 176.0, 19.0))
			var b_center: Vector2 = banner_rect.get_center()
			if b_center.distance_to(c_pos + Vector2(0.0, -26.0)) > 18.0:
				draw_line(Vector2(b_center.x, banner_rect.end.y), c_pos, Color(c_col.r, c_col.g, c_col.b, 0.55), 1.2)
			draw_rect(banner_rect, Color(0.04, 0.06, 0.11, 0.88), true)
			var border_col: Color = Color(1.0, 0.32, 0.32) if cities_in_war.has(c_id) else c_col
			draw_rect(banner_rect, border_col, false, 1.5)
			if font != null:
				var war_prefix: String = "⚔ " if cities_in_war.has(c_id) else "★ "
				var label_txt: String = "%s%s [%d] K-%.2f" % [war_prefix, city["name"], int(city["population"]), float(city["kardashev_level"])]
				draw_string(font, Vector2(banner_rect.position.x + 5.0, banner_rect.position.y + 13.5), label_txt, HORIZONTAL_ALIGNMENT_CENTER, banner_rect.size.x - 10.0, 11, c_col.lightened(0.35))

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
func _draw_pixel_lens_dome(center: Vector2, rad: float, col: Color, l_type: String, t_mult: float, g_mult: float, font: Font, lens_idx: int = 0) -> void:
	# Чистое полупрозрачное энергетическое кольцо без глухой штриховки, чтобы здания и ландшафт внутри читались идеально
	draw_circle(center, rad * 0.96, Color(col.r, col.g, col.b, 0.055))
	_draw_pixel_circle_outline(center, rad, Color(col.r, col.g, col.b, 0.78), 3.0)
	_draw_pixel_circle_outline(center, rad - 6.0, Color(1.0, 1.0, 1.0, 0.32), 2.0)

	# 4 вращающихся фазовых маркера по периметру купола
	for k in range(4):
		var ang: float = _anim_time * 0.8 + float(k) * (PI * 0.5)
		var mp := center + Vector2(cos(ang), sin(ang)) * rad
		draw_rect(Rect2(mp.x - 3.0, mp.y - 3.0, 6.0, 6.0), col.lightened(0.4), true)

	if font != null and show_diplomacy_lines:
		var tag_txt: String = "ЛИНЗА ×%.0f ВРЕМЯ" % t_mult
		if l_type == "zero_grav":
			tag_txt = "ЛИНЗА %.2fG ГРАВИТАЦИЯ" % g_mult
		elif l_type == "singularity":
			tag_txt = "⚛ СИНГУЛЯРНОСТЬ ×%.0f" % t_mult
		elif l_type == "shield_dome":
			tag_txt = "🛡 ТЕРМО-КУПОЛ"
		var pill_y: float = maxf(114.0, center.y + rad + 6.0 + float(lens_idx % 2) * 17.0)
		var pill_rect := Rect2(center.x - 70.0, pill_y, 140.0, 15.0)
		draw_rect(pill_rect, Color(0.03, 0.05, 0.09, 0.78), true)
		draw_rect(pill_rect, Color(col.r, col.g, col.b, 0.65), false, 1.0)
		draw_string(font, Vector2(pill_rect.position.x + 4.0, pill_rect.position.y + 11.5), tag_txt, HORIZONTAL_ALIGNMENT_CENTER, 132.0, 10, col.lightened(0.35))


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


func _pack_horizontal_atlas(sprite_keys: Array[String], cell_w: int, cell_h: int) -> ImageTexture:
	var cols: int = maxi(1, sprite_keys.size())
	var atlas_img := Image.create(cell_w * cols, cell_h, false, Image.FORMAT_RGBA8)
	atlas_img.fill(Color(0, 0, 0, 0))
	for i in range(cols):
		var tex: ImageTexture = _sprites.get(sprite_keys[i])
		if tex != null:
			var src_img: Image = tex.get_image()
			if src_img != null:
				atlas_img.blit_rect(src_img, Rect2i(0, 0, mini(cell_w, src_img.get_width()), mini(cell_h, src_img.get_height())), Vector2i(i * cell_w, 0))
	return ImageTexture.create_from_image(atlas_img)


func _build_pixel_art_sprites() -> void:
	_sprites.clear()
	_flora_type_to_col.clear()
	_building_arch_to_col.clear()
	_actor_key_to_col.clear()

	var k_out := Color(0.04, 0.06, 0.10, 1.0) # Чёрно-синий пиксельный контур
	var k_shd := Color(0.0, 0.0, 0.0, 0.42)   # Мягкая пиксельная тень под ногами/основанием

	# --- 1. ПИКСЕЛЬНЫЕ ЧЕЛОВЕЧКИ И СУЩЕСТВА (5 рас × 2 кадра анимации шага) ---
	var actor_variants := [
		{"id": "carbon", "c1": Color(0.22, 0.95, 0.58), "c2": Color(0.85, 1.0, 0.92)},
		{"id": "silicon", "c1": Color(0.84, 0.38, 1.0), "c2": Color(1.0, 0.78, 1.0)},
		{"id": "plasma", "c1": Color(1.0, 0.52, 0.14), "c2": Color(1.0, 0.95, 0.35)},
		{"id": "cyber", "c1": Color(0.12, 0.92, 1.0), "c2": Color(1.0, 0.88, 0.25)},
		{"id": "quantum", "c1": Color(0.65, 0.30, 1.0), "c2": Color(0.35, 1.0, 0.95)}
	]
	var actor_atlas_keys: Array[String] = []
	for av in actor_variants:
		var pal := {"#": k_out, "1": av["c1"], "2": av["c2"], "s": k_shd}
		var k0: String = "actor_%s_0" % av["id"]
		var k1: String = "actor_%s_1" % av["id"]
		_sprites[k0] = _make_sprite_from_grid([
			"...####...",
			"..#1221#..",
			"..#1221#..",
			"...####...",
			"..#1111#..",
			".#112211#.",
			".#111111#.",
			"..#1##1#..",
			"..#1..1#..",
			".ss##..##s"
		], pal)
		_sprites[k1] = _make_sprite_from_grid([
			"...####...",
			"..#1221#..",
			"..#1221#..",
			"...####...",
			".#111111#.",
			"..#1221#..",
			"..#1111#..",
			".#1#..#1#.",
			".##....##.",
			".ssssssss."
		], pal)
		_actor_key_to_col["%s_0" % av["id"]] = actor_atlas_keys.size()
		actor_atlas_keys.append(k0)
		_actor_key_to_col["%s_1" % av["id"]] = actor_atlas_keys.size()
		actor_atlas_keys.append(k1)
	_atlas_actor_tex = _pack_horizontal_atlas(actor_atlas_keys, 10, 10)

	# --- 2. ПИКСЕЛЬНАЯ ФЛОРА И РЕСУРСЫ БИОМОВ (10 типов) ---
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
		".ssssssss."
	], {"#": k_out, "1": Color(0.22, 0.72, 0.30), "2": Color(0.55, 0.92, 0.38), "3": Color(0.48, 0.32, 0.20), "s": k_shd})

	_sprites["flora_savanna_tree"] = _make_sprite_from_grid([
		".########.",
		"#12222221#",
		"#11122111#",
		".###33###.",
		"....#3#...",
		"...#33#...",
		"...#3#....",
		"...#33#...",
		"..##33##..",
		".ssssssss."
	], {"#": k_out, "1": Color(0.52, 0.68, 0.22), "2": Color(0.78, 0.88, 0.32), "3": Color(0.46, 0.30, 0.18), "s": k_shd})

	_sprites["flora_pine_tree"] = _make_sprite_from_grid([
		"....##....",
		"...#22#...",
		"..#1221#..",
		".#211112#.",
		"..#1221#..",
		".#211112#.",
		"#11111111#",
		"...#33#...",
		"..##33##..",
		".ssssssss."
	], {"#": k_out, "1": Color(0.18, 0.52, 0.45), "2": Color(0.78, 0.94, 0.98), "3": Color(0.42, 0.28, 0.18), "s": k_shd})

	_sprites["flora_cryo_crystal"] = _make_sprite_from_grid([
		"....##....",
		"...#21#...",
		".###21###.",
		"#21221121#",
		"#11221111#",
		".#122111#.",
		"..#1111#..",
		"..######..",
		".ssssssss.",
		".........."
	], {"#": k_out, "1": Color(0.28, 0.75, 0.98), "2": Color(0.82, 0.96, 1.0), "s": k_shd})

	_sprites["flora_actinide_ore"] = _make_sprite_from_grid([
		"....##....",
		"..##22##..",
		".#122221#.",
		"#11211211#",
		"#12211221#",
		"#11122111#",
		".########.",
		".ssssssss.",
		"..........",
		".........."
	], {"#": k_out, "1": Color(0.32, 0.45, 0.22), "2": Color(0.58, 1.0, 0.18), "s": k_shd})

	_sprites["flora_piezo_spire"] = _make_sprite_from_grid([
		"....##....",
		"...#22#...",
		"..#1221#..",
		"..#1221#..",
		".#112211#.",
		".#111111#.",
		"..#1111#..",
		"..######..",
		".ssssssss.",
		".........."
	], {"#": k_out, "1": Color(0.68, 0.25, 0.92), "2": Color(0.95, 0.65, 1.0), "s": k_shd})

	_sprites["flora_cyber_node"] = _make_sprite_from_grid([
		"...####...",
		"..#2222#..",
		"..######..",
		"...#11#...",
		".###11###.",
		"#12211221#",
		"#11111111#",
		".########.",
		".ssssssss.",
		".........."
	], {"#": k_out, "1": Color(0.22, 0.38, 0.48), "2": Color(0.0, 0.95, 1.0), "s": k_shd})

	_sprites["flora_lava_vent"] = _make_sprite_from_grid([
		"...####...",
		"..#2222#..",
		".#122221#.",
		"#11122111#",
		"#11111111#",
		"##########",
		".ssssssss.",
		"..........",
		"..........",
		".........."
	], {"#": k_out, "1": Color(0.32, 0.16, 0.14), "2": Color(1.0, 0.55, 0.12), "s": k_shd})

	_sprites["flora_void_monolith"] = _make_sprite_from_grid([
		"...####...",
		"..#2112#..",
		"..#1221#..",
		"..#1221#..",
		"..#1111#..",
		"..#2112#..",
		"...####...",
		"..ssssss..",
		"..........",
		".........."
	], {"#": k_out, "1": Color(0.22, 0.08, 0.42), "2": Color(0.85, 0.35, 1.0), "s": k_shd})

	_sprites["flora_basalt_rock"] = _make_sprite_from_grid([
		"..........",
		"..........",
		"...####...",
		".##1221##.",
		"#11122111#",
		"#11111111#",
		".########.",
		".ssssssss.",
		"..........",
		".........."
	], {"#": k_out, "1": Color(0.34, 0.36, 0.42), "2": Color(0.52, 0.55, 0.62), "s": k_shd})

	var flora_types_order: Array[String] = [
		"bio_tree", "savanna_tree", "pine_tree", "cryo_crystal", "actinide_ore",
		"piezo_spire", "cyber_node", "lava_vent", "void_monolith", "basalt_rock"
	]
	var flora_atlas_keys: Array[String] = []
	for i in range(flora_types_order.size()):
		var ft: String = flora_types_order[i]
		_flora_type_to_col[ft] = i
		flora_atlas_keys.append("flora_" + ft)
	_atlas_flora_tex = _pack_horizontal_atlas(flora_atlas_keys, 10, 10)

	# --- 3. ПИКСЕЛЬНЫЕ ЗДАНИЯ ГОРОДОВ (12×12 с яркими окнами, куполами и тенью) ---
	var b_pal := {
		"#": k_out,
		"1": Color(0.58, 0.68, 0.82),
		"2": Color(0.88, 0.95, 1.0),
		"3": Color(0.22, 0.95, 1.0),
		"4": Color(1.0, 0.82, 0.25),
		"s": k_shd
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
		".ssssssssss.",
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
		".sss#11#sss.",
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
		".ssssssssss."
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
		".ssssssssss.",
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
		".ssssssssss.",
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
		".ssssssssss.",
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
		".ssssssssss.",
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
		"..ssssssss..",
		"............"
	], b_pal)

	var bld_archs_order: Array[String] = [
		"dome", "extractor", "spire", "collider",
		"elevator", "shipyard", "anchor", "matrioshka"
	]
	var bld_atlas_keys: Array[String] = []
	for i in range(bld_archs_order.size()):
		var ba: String = bld_archs_order[i]
		_building_arch_to_col[ba] = i
		bld_atlas_keys.append("bld_" + ba)
	_atlas_building_tex = _pack_horizontal_atlas(bld_atlas_keys, 12, 12)

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
