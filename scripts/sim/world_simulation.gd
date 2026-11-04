class_name WorldSimulation
extends Node

## 2D-движок симуляции «Kardashev Sandbox: Crucible of Stars» в стиле WorldBox v0.51.2.
## Реализует:
## - Плоскую 2D-карту континентов и островов (GRID_W × GRID_H = 32 × 32 = 1024 макро-тайла)
## - Индивидуальных живых пиксельных существ (actors: граждане, учёные, строители, шахтёры, астронавты)
## - Клеточную физику жидкостей и катастроф (лава, остывание в базальт у воды, пиксельные кратеры)
## - Цепочку Biome -> Subspecies -> Culture -> City -> BuildOrders -> Plots -> Infinite Science Codex
## - Автономный запуск пиксельных ракет с космодромов в Рой Сферы Дайсона.

signal event_logged(entry: Dictionary)
signal telemetry_updated()
signal planet_surface_changed()
signal city_structures_changed()
signal dyson_swarm_changed()
signal field_lenses_changed()
signal god_impact_triggered(u_dir: Vector3, radius: float, color: Color, power_id: String)
signal god_impact_2d_triggered(map_pos: Vector2, radius_px: float, color: Color, power_id: String)
signal rocket_launched(from_pos: Vector2, color: Color, city_name: String)
signal supernova_cycle_triggered(new_cycle: int)
signal diplomacy_relation_changed(city_a_id: int, city_b_id: int, old_status: String, new_status: String)
signal building_damaged_or_destroyed(city_id: int, building_id: String, is_destroyed: bool)
signal actor_damaged_or_killed(actor_id: int, killer_id: int, cause: String)
signal trade_route_established(city_a_id: int, city_b_id: int, trade_value: float)
signal colony_expedition_launched(mother_city_id: int, from_pos: Vector2, target_pos: Vector2)
signal colony_founded(daughter_city_id: int, mother_city_id: int, city_name: String, map_pos: Vector2)
signal dyson_megastructure_stage_advanced(stage_index: int, stage_name: String, total_energy: float)
signal dyson_visual_state_updated(stage: int, progress: float, active_segments: int)
signal world_constant_modified(constant_id: String, new_value: float)
signal shockwave_triggered(world_pos: Vector2, radius: float, color: Color)
signal sfx_requested(sfx_id: String, world_pos: Vector2, pitch_scale: float, volume_db: float)
signal ambient_state_changed(ambient_mood: String, intensity: float)
signal dirty_rect_requested(rect: Rect2i)

const SandboxAssetScript = preload("res://scripts/core/sandbox_asset.gd")
const SandboxAssetManagerScript = preload("res://scripts/core/asset_manager.gd")

const GRID_W: int = 32
const GRID_H: int = 32
const TILE_COUNT: int = GRID_W * GRID_H # 1024 тайла (полная совместимость со всеми контрактами)
const MAP_PIXEL_W: float = 1920.0
const MAP_PIXEL_H: float = 1080.0
const CELL_W: float = MAP_PIXEL_W / float(GRID_W) # 60.0 px
const CELL_H: float = MAP_PIXEL_H / float(GRID_H) # 33.75 px
const PLANET_RADIUS: float = 10.0

# Высокодетальная сетка WorldTile (384×216 = 82 944 микро-тайла, чанки 16×16, зоны городов 8×8 как в WorldBox v0.51.2)
const FINE_W: int = 384
const FINE_H: int = 216
const FINE_COUNT: int = FINE_W * FINE_H
const CHUNK_SIZE: int = 16
const CHUNK_W: int = 24 # 384 / 16
const CHUNK_H: int = 14 # ceil(216 / 16)
const ZONE_SIZE: int = 8
const ZONE_W: int = 48 # 384 / 8
const ZONE_H: int = 27 # 216 / 8
const ZONE_COUNT: int = ZONE_W * ZONE_H # 1296 прямоугольных зон 8×8

const BASE_DEEP_OCEAN: int = 0
const BASE_CLOSE_OCEAN: int = 1
const BASE_SHALLOW_WATERS: int = 2
const BASE_SAND: int = 3
const BASE_SOIL_LOW: int = 4
const BASE_SOIL_HIGH: int = 5
const BASE_HILLS: int = 6
const BASE_MOUNTAINS: int = 7
const BASE_SUMMIT: int = 8
const BASE_ROAD: int = 9
const BASE_FIELD: int = 10
const BASE_LAVA0: int = 11
const BASE_LAVA1: int = 12
const BASE_LAVA2: int = 13

const FIXED_SUBSTEP_DT: float = 0.05
const MAX_SUBSTEPS_PER_FRAME: int = 600

var assets: SandboxAssetManagerScript

# Настройки времени и законов мира
var paused: bool = false
var sim_speed: float = 1.0
var time_speed_multiplier: float:
	get: return sim_speed
	set(v): sim_speed = maxf(0.0, v)

var _sim_time_accumulator: float = 0.0
var world_year: float = 0.0

func set_time_speed_multiplier(multiplier: float) -> void:
	sim_speed = maxf(0.0, multiplier)

func get_time_speed_multiplier() -> float:
	return sim_speed

func request_dirty_rect_update(rect: Rect2i) -> void:
	dirty_rect_requested.emit(rect)

func request_dirty_circle_update(center_pos: Vector2, radius_px: float) -> void:
	var cx: int = int(center_pos.x / 5.0)
	var cy: int = int(center_pos.y / 5.0)
	var rad_tex: int = int(ceil(radius_px / 5.0)) + 3
	var r := Rect2i(cx - rad_tex, cy - rad_tex, rad_tex * 2, rad_tex * 2)
	dirty_rect_requested.emit(r)

func request_dirty_tiles_update(tile_indices: Array) -> void:
	if tile_indices.is_empty():
		return
	var min_gx: int = GRID_W
	var min_gy: int = GRID_H
	var max_gx: int = 0
	var max_gy: int = 0
	for idx in tile_indices:
		var t_idx: int = int(idx)
		if t_idx >= 0 and t_idx < TILE_COUNT:
			var t: Dictionary = tiles[t_idx]
			var gx: int = int(t["gx"])
			var gy: int = int(t["gy"])
			min_gx = mini(min_gx, gx)
			min_gy = mini(min_gy, gy)
			max_gx = maxi(max_gx, gx)
			max_gy = maxi(max_gy, gy)
	# Если изменились 2–5 разрозненных тайлов на разных концах карты, обновляем каждый локально (350 пикселей вместо 55,000)
	if tile_indices.size() <= 5 and (max_gx - min_gx > 4 or max_gy - min_gy > 4):
		for idx in tile_indices:
			var t_idx: int = int(idx)
			if t_idx >= 0 and t_idx < TILE_COUNT:
				var t: Dictionary = tiles[t_idx]
				var gx: int = int(t["gx"])
				var gy: int = int(t["gy"])
				var lx: int = clampi(int(float(gx) / float(GRID_W) * 384.0) - 2, 0, 384)
				var ly: int = clampi(int(float(gy) / float(GRID_H) * 216.0) - 2, 0, 216)
				var lw: int = clampi(16, 1, 384 - lx)
				var lh: int = clampi(11, 1, 216 - ly)
				dirty_rect_requested.emit(Rect2i(lx, ly, lw, lh))
		return
	var px_x: int = clampi(int(float(min_gx) / float(GRID_W) * 384.0) - 2, 0, 384)
	var px_y: int = clampi(int(float(min_gy) / float(GRID_H) * 216.0) - 2, 0, 216)
	var px_w: int = clampi(int(ceil(float(max_gx - min_gx + 1) / float(GRID_W) * 384.0)) + 4, 1, 384 - px_x)
	var px_h: int = clampi(int(ceil(float(max_gy - min_gy + 1) / float(GRID_H) * 216.0)) + 4, 1, 216 - px_y)
	dirty_rect_requested.emit(Rect2i(px_x, px_y, px_w, px_h))
var chrono_cycle: int = 1
var world_seed: int = 1337
var active_world_laws: Dictionary = {} # law_id -> bool

# 3 Фундаментальных макро-ресурса (без конвейерной рутины)
var matter_stock: float = 250.0
var energy_gw: float = 120.0
var compute_pflops: float = 40.0

var matter_rate: float = 0.0
var energy_rate: float = 0.0
var compute_rate: float = 0.0

# Состояние Звезды и Сферы Дайсона
var star_name: String = "Гелиос-Прайм"
var star_spectral_class: String = "G2V Жёлтый Карлик"
var star_temp_k: float = 5780.0
var star_stability: float = 0.96
var star_luminosity_mult: float = 1.0
var star_color: Color = Color(1.0, 0.76, 0.32)

var dyson_rings: Array[Dictionary] = []
var total_dyson_sails: int = 0
var asteroid_belt_mass: float = 5000.0

# ==============================================================================
# МЕГАСТРУКТУРА СФЕРЫ ДАЙСОНА: 4 ЭТАПА СТРОИТЕЛЬСТВА (F4)
# ==============================================================================
var dyson_stage: int = 1 # 1: Swarm, 2: Ring Frame, 3: Shell Segments, 4: Matrioshka Brain
var dyson_stage_progress: float = 0.0 # 0.0 .. 1.0
var dyson_ring_frame_segments: int = 0 # 0 .. 12
var dyson_shell_active_segments: int = 0 # 0 .. 60
var dyson_matrioshka_layers: int = 0 # 0 .. 3
var dyson_construction_enabled: bool = true
var dyson_is_constructing: bool = false
var _dyson_last_emitted_progress: float = -1.0
var _dyson_last_emitted_segments: int = -1

const DYSON_STAGE_NAMES: Array[String] = [
	"",
	"Swarm Collectors",
	"Equatorial Ring Frame",
	"Dyson Shell Segments",
	"Matrioshka Brain Clusters"
]

# ==============================================================================
# ФУНДАМЕНТАЛЬНЫЕ ФИЗИЧЕСКИЕ КОНСТАНТЫ ВСЕЛЕННОЙ (F6)
# ==============================================================================
var world_constants: Dictionary = {
	"gravitational_constant": 1.0,
	"light_speed": 1.0,
	"cosmic_entropy_rate": 1.0,
	"mutation_rate_multiplier": 1.0
}


# Постоянный Кодекс Архитектора (сохраняется через Хроно-Петли Сверхновых)
var codex_theories: Array[Dictionary] = []
var unlocked_god_powers: Dictionary = {}
var codex_matter_mult: float = 1.0
var codex_energy_mult: float = 1.0
var codex_compute_mult: float = 1.0

# 2D-сетка карты (1024 макро-тайла + типизированные буферы 384×216 WorldTile + чанки 16×16 и зоны 8×8)
var tiles: Array[Dictionary] = []
var fine_elevation: PackedFloat32Array = PackedFloat32Array()
var fine_base_tile: PackedByteArray = PackedByteArray()
var fine_biome_idx: PackedByteArray = PackedByteArray()
var fine_top_variant: PackedByteArray = PackedByteArray()
var fine_road_overlay: PackedByteArray = PackedByteArray()
var zone_city_id: PackedInt32Array = PackedInt32Array()
var chunk_dirty: PackedByteArray = PackedByteArray()
var flora_instances: Array[Dictionary] = []
var total_citizen_tasks_completed: int = 0
var _biome_id_to_idx: Dictionary = {}

var _noise_elev: FastNoiseLite
var _noise_moisture: FastNoiseLite
var _noise_detail: FastNoiseLite

# Мета-объекты симуляции (в духе WorldBox)
var subspecies_map: Dictionary = {} # id -> Dictionary
var cultures_map: Dictionary = {}   # id -> Dictionary
var cities_map: Dictionary = {}     # id -> Dictionary
var kingdoms_map: Dictionary = {}   # id -> Dictionary
var active_plots: Dictionary = {}   # id -> Dictionary
var field_lenses: Array[Dictionary] = [] # [{id, lens_type, dir, map_pos, radius, radius_px, time_mult, grav_mult, remaining, max_dur, color}]

var diplomacy_relations: Dictionary = {} # "idA_idB" -> Dictionary
var _diplomacy_timer: float = 0.0
const DIPLOMACY_TICK_INTERVAL: float = 1.0

const MAX_CITIES: int = 12
const COLONY_EXPEDITION_POP_THRESHOLD: float = 45.0
const COLONY_EXPEDITION_COOLDOWN: float = 15.0
var _last_colony_time: float = -999.0

# Живые индивидуальные пиксельные существа (Actor из WorldBox)
var actors: Array[Dictionary] = []
const MAX_ACTORS: int = 220

var _next_meta_id: int = 1
var event_log: Array[Dictionary] = []

var _wb_timers: Dictionary = {}
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _ready() -> void:
	if assets == null:
		setup_world(1337)


func setup_world(seed_val: int = 1337, preserve_codex: bool = false) -> void:
	world_seed = seed_val
	_rng.seed = seed_val
	if assets == null:
		assets = SandboxAssetManagerScript.new()

	if not preserve_codex:
		chrono_cycle = 1
		codex_theories.clear()
		codex_matter_mult = 1.0
		codex_energy_mult = 1.0
		codex_compute_mult = 1.0
		unlocked_god_powers.clear()
		for gp in assets.god_power_list:
			unlocked_god_powers[gp.id] = gp.unlocked_by_default
		for wl in assets.world_law_list:
			active_world_laws[wl.id] = wl.enabled_by_default

	world_year = 0.0
	matter_stock = 280.0 * codex_matter_mult
	energy_gw = 140.0 * codex_energy_mult
	compute_pflops = 50.0 * codex_compute_mult

	subspecies_map.clear()
	cultures_map.clear()
	cities_map.clear()
	kingdoms_map.clear()
	active_plots.clear()
	field_lenses.clear()
	actors.clear()
	flora_instances.clear()
	dyson_rings.clear()
	diplomacy_relations.clear()
	_diplomacy_timer = 0.0
	_last_colony_time = -999.0
	total_dyson_sails = 0
	total_citizen_tasks_completed = 0
	dyson_stage = 1
	dyson_stage_progress = 0.0
	dyson_ring_frame_segments = 0
	dyson_shell_active_segments = 0
	dyson_matrioshka_layers = 0
	dyson_is_constructing = false
	_dyson_last_emitted_progress = -1.0
	_dyson_last_emitted_segments = -1
	world_constants = {
		"gravitational_constant": 1.0,
		"light_speed": 1.0,
		"cosmic_entropy_rate": 1.0,
		"mutation_rate_multiplier": 1.0
	}
	asteroid_belt_mass = 6000.0 * (1.0 + 0.25 * float(chrono_cycle - 1))

	_init_star_for_cycle(chrono_cycle)
	_build_2d_worldbox_grid(seed_val)

	for wb in assets.world_behaviour_list:
		_wb_timers[wb.id] = 0.0

	_log_event(
		"Космогенез Цикла #%d: архипелаг системы «%s» (%s) сгенерирован. Кликайте Кистью Бога по 2D-карте, чтобы менять биомы, сеять пиксельных существ и ставить купола физики." % [chrono_cycle, star_name, star_spectral_class],
		"cosmos",
		Color(0.35, 0.88, 1.0)
	)

	_seed_initial_cradle()

	planet_surface_changed.emit()
	city_structures_changed.emit()
	dyson_swarm_changed.emit()
	field_lenses_changed.emit()
	telemetry_updated.emit()


func _init_star_for_cycle(cycle: int) -> void:
	var star_presets := [
		{"name": "Гелиос-Прайм", "spec": "G2V Жёлтый Карлик", "temp": 5800.0, "lum": 1.0, "col": Color(1.0, 0.78, 0.32)},
		{"name": "Сириус-Алькор", "spec": "A1V Бело-Голубой Гигант", "temp": 9940.0, "lum": 1.45, "col": Color(0.55, 0.82, 1.0)},
		{"name": "Вега-Магнетар", "spec": "M-Пульсар с Релятивистским Джетом", "temp": 14500.0, "lum": 2.10, "col": Color(0.78, 0.42, 1.0)},
		{"name": "Керр-Омега", "spec": "Искусственная Квантовая Сингулярность", "temp": 22000.0, "lum": 3.20, "col": Color(1.0, 0.35, 0.72)}
	]
	var preset: Dictionary = star_presets[(cycle - 1) % star_presets.size()]
	star_name = "%s (Виток %d)" % [preset["name"], cycle]
	star_spectral_class = preset["spec"]
	star_temp_k = preset["temp"]
	star_luminosity_mult = preset["lum"]
	star_color = preset["col"]
	star_stability = 0.95


# ==============================================================================
# ГЕНЕРАЦИЯ ПЛОСКОЙ 2D-КАРТЫ ОСТРОВОВ И КОНТИНЕНТОВ В ДУХЕ WORLDBOX
# ==============================================================================
func _build_2d_worldbox_grid(seed_val: int) -> void:
	tiles.clear()
	_noise_elev = FastNoiseLite.new()
	_noise_elev.seed = seed_val
	_noise_elev.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_noise_elev.frequency = 0.042
	_noise_elev.fractal_octaves = 4

	_noise_moisture = FastNoiseLite.new()
	_noise_moisture.seed = seed_val + 7919
	_noise_moisture.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_noise_moisture.frequency = 0.055
	_noise_moisture.fractal_octaves = 3

	_noise_detail = FastNoiseLite.new()
	_noise_detail.seed = seed_val + 31337
	_noise_detail.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_noise_detail.frequency = 0.14
	_noise_detail.fractal_octaves = 2

	for gy in range(GRID_H):
		for gx in range(GRID_W):
			var idx: int = gy * GRID_W + gx
			var uv := Vector2((float(gx) + 0.5) / float(GRID_W), (float(gy) + 0.5) / float(GRID_H))
			var map_pos := Vector2(uv.x * MAP_PIXEL_W, uv.y * MAP_PIXEL_H)

			# Для обратной совместимости с 3D-векторами в тестах храним инъективное направление на единичной сфере
			var lon: float = (uv.x - 0.5) * TAU * 0.92
			var lat: float = (0.5 - uv.y) * PI * 0.88
			var dir := Vector3(cos(lat) * cos(lon), sin(lat), cos(lat) * sin(lon)).normalized()

			# Формируем архипелаг в открытом центре экрана (x: 360..1540, y: 90..890),
			# чтобы боковые панели HUD никогда не перекрывали материки и города (края карты — глубокий океан, как в WorldBox)
			var norm_cx: float = (uv.x - 0.5) / 0.31
			var norm_cy: float = (uv.y - 0.49) / 0.36
			var radial_d: float = sqrt(norm_cx * norm_cx * 0.85 + norm_cy * norm_cy)
			var island_mask: float = clampf(1.18 - pow(radial_d, 2.0), 0.0, 1.0)

			var n_e: float = _noise_elev.get_noise_2d(float(gx) * 2.5, float(gy) * 2.8)
			var n_m: float = _noise_moisture.get_noise_2d(float(gx) * 2.5, float(gy) * 2.5)
			var elev: float = clampf((n_e + 0.24) * 0.62 * island_mask - (1.0 - island_mask) * 0.34, -0.40, 0.48)

			# Температура зависит от широты (север/юг холоднее, экватор теплее)
			var lat_factor: float = 1.0 - absf(uv.y - 0.5) * 1.85
			var base_temp: float = -30.0 + lat_factor * 64.0 * star_luminosity_mult - maxf(0.0, elev) * 35.0

			var biome_id: String = "biome_barren_crust"
			if elev < -0.02:
				biome_id = "biome_primordial_ocean"
			elif base_temp < -12.0 or gy <= 3 or gy >= GRID_H - 4:
				biome_id = "biome_cryo_superconductor"
			elif n_m > 0.05:
				biome_id = "biome_primordial_ocean"
			elif n_m < -0.22 and elev > 0.08:
				biome_id = "biome_crystal_lattice"
			elif elev > 0.26:
				biome_id = "biome_actinide_wasteland"

			var flora_type: String = _pick_flora_for_biome(biome_id, elev, idx)

			var tile := {
				"index": idx,
				"gx": gx,
				"gy": gy,
				"uv": uv,
				"map_pos": map_pos,
				"dir": dir,
				"elevation": elev,
				"temperature_c": base_temp,
				"radiation": 0.04,
				"gravity_mult": 1.0,
				"time_scale_mult": 1.0,
				"biome_id": biome_id,
				"flora": flora_type,
				"city_id": -1,
				"subspecies_id": -1,
				"neighbors": PackedInt32Array()
			}
			tiles.append(tile)

	# 8-связные соседи на 2D-сетке (в точности как WorldTile.neighboursAll в WorldBox)
	for gy in range(GRID_H):
		for gx in range(GRID_W):
			var idx: int = gy * GRID_W + gx
			var nbrs := PackedInt32Array()
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					if dx == 0 and dy == 0:
						continue
					var nx: int = gx + dx
					var ny: int = gy + dy
					if nx >= 0 and nx < GRID_W and ny >= 0 and ny < GRID_H:
						nbrs.append(ny * GRID_W + nx)
			tiles[idx]["neighbors"] = nbrs

	_init_worldbox_fine_buffers()


func _init_worldbox_fine_buffers() -> void:
	_biome_id_to_idx.clear()
	for i in range(assets.biome_list.size()):
		_biome_id_to_idx[assets.biome_list[i].id] = i

	if fine_road_overlay.size() != FINE_COUNT:
		fine_road_overlay.resize(FINE_COUNT)
	fine_road_overlay.fill(0)

	if zone_city_id.size() != ZONE_COUNT:
		zone_city_id.resize(ZONE_COUNT)
	zone_city_id.fill(-1)

	if chunk_dirty.size() != CHUNK_W * CHUNK_H:
		chunk_dirty.resize(CHUNK_W * CHUNK_H)
	chunk_dirty.fill(1)


func _populate_fine_flora_and_minerals() -> void:
	flora_instances.clear()
	var fid: int = 1
	for wy in range(12, FINE_H - 12, 3):
		for wx in range(28, FINE_W - 28, 3):
			var hash_v: int = ((wx * 73856093) ^ (wy * 19349663) ^ (world_seed * 83492791)) & 0x7fffffff
			if (hash_v % 100) > 24:
				continue
			var jx: int = clampi(wx + (hash_v % 3) - 1, 8, FINE_W - 9)
			var jy: int = clampi(wy + ((hash_v >> 3) % 3) - 1, 8, FINE_H - 9)
			var uv := Vector2((float(jx) + 0.5) / float(FINE_W), (float(jy) + 0.5) / float(FINE_H))
			var sample: Dictionary = sample_pixel_terrain(uv)
			var elev: float = float(sample["elevation"])
			if elev < 0.038 or elev > 0.33:
				continue
			var b_id: String = str(sample["biome_id"])
			var t_idx: int = int(sample["tile_index"])
			var is_min: bool = (elev > 0.21) or ((hash_v % 10) < 3)
			var f_type: String = "bio_tree"
			if is_min:
				match b_id:
					"biome_crystal_lattice": f_type = "piezo_spire"
					"biome_cryo_superconductor": f_type = "cryo_crystal"
					"biome_actinide_wasteland": f_type = "actinide_ore"
					"biome_cybercore": f_type = "cyber_node"
					"biome_plasma_inferno": f_type = "lava_vent"
					"biome_singularity_swamp": f_type = "void_monolith"
					_: f_type = "basalt_rock"
			else:
				match b_id:
					"biome_primordial_ocean": f_type = "bio_tree"
					"biome_barren_crust": f_type = "savanna_tree" if (hash_v % 2 == 0) else "bio_tree"
					"biome_cryo_superconductor": f_type = "pine_tree"
					"biome_crystal_lattice": f_type = "piezo_spire"
					"biome_cybercore": f_type = "cyber_node"
					"biome_actinide_wasteland": f_type = "actinide_ore"
					"biome_plasma_inferno": f_type = "lava_vent"
					"biome_singularity_swamp": f_type = "void_monolith"
					_: f_type = "bio_tree"

			var w_pos := Vector2(uv.x * MAP_PIXEL_W, uv.y * MAP_PIXEL_H)
			flora_instances.append({
				"id": fid,
				"pos": w_pos,
				"wx": jx,
				"wy": jy,
				"tile_idx": t_idx,
				"type": f_type,
				"is_mineral": is_min,
				"hp": 4.0,
				"sway_phase": float(hash_v % 628) * 0.01,
				"chop_shake": 0.0,
				"spawn_spring": 1.0
			})
			fid += 1
			if flora_instances.size() >= 480:
				return


func _pick_flora_for_biome(biome_id: String, elev: float, seed_idx: int) -> String:
	if elev < -0.02:
		return ""
	if ((seed_idx * 1103515245 + 12345) & 0x7fffffff) % 100 > 58:
		return ""
	match biome_id:
		"biome_primordial_ocean":
			return "bio_tree"
		"biome_cryo_superconductor":
			return "cryo_crystal"
		"biome_actinide_wasteland":
			return "actinide_ore"
		"biome_crystal_lattice":
			return "piezo_spire"
		"biome_cybercore":
			return "cyber_node"
		"biome_plasma_inferno":
			return "lava_vent"
		"biome_singularity_swamp":
			return "void_monolith"
		_:
			return "basalt_rock"


func sample_pixel_terrain(px_uv: Vector2) -> Dictionary:
	## Вычисляет точный суб-тайловый рельеф и биом для каждого пикселя 2D-карты (в духе MapBox из WorldBox).
	var fx: float = clampf(px_uv.x * float(GRID_W), 0.0, float(GRID_W) - 0.001)
	var fy: float = clampf(px_uv.y * float(GRID_H), 0.0, float(GRID_H) - 0.001)
	var gx: int = int(fx)
	var gy: int = int(fy)
	var t_idx: int = gy * GRID_W + gx
	var t: Dictionary = tiles[t_idx]

	# Билинейная интерполяция высоты между соседними узлами + высокочастотный береговой шум
	var gx1: int = mini(gx + 1, GRID_W - 1)
	var gy1: int = mini(gy + 1, GRID_H - 1)
	var tx: float = fx - float(gx)
	var ty: float = fy - float(gy)

	var e00: float = float(tiles[gy * GRID_W + gx]["elevation"])
	var e10: float = float(tiles[gy * GRID_W + gx1]["elevation"])
	var e01: float = float(tiles[gy1 * GRID_W + gx]["elevation"])
	var e11: float = float(tiles[gy1 * GRID_W + gx1]["elevation"])
	var base_e: float = lerpf(lerpf(e00, e10, tx), lerpf(e01, e11, tx), ty)

	var coast_jitter: float = _noise_detail.get_noise_2d(px_uv.x * 180.0, px_uv.y * 110.0) * 0.055
	var micro_jitter: float = _noise_detail.get_noise_2d(px_uv.x * 420.0 + 70.0, px_uv.y * 260.0) * 0.022
	var final_elev: float = base_e + coast_jitter + micro_jitter

	# Сглаженный выбор биома с органической пиксельной границей
	var jx: int = clampi(int(fx + coast_jitter * 6.5), 0, GRID_W - 1)
	var jy: int = clampi(int(fy + micro_jitter * 12.0), 0, GRID_H - 1)
	var b_tile: Dictionary = tiles[jy * GRID_W + jx]

	# Smoother zone-based city_id lookup (8x8 TileZone grid synced with 32x32 macro grid)
	var zx: int = clampi(int(px_uv.x * float(ZONE_W)), 0, ZONE_W - 1)
	var zy: int = clampi(int(px_uv.y * float(ZONE_H)), 0, ZONE_H - 1)
	var z_id: int = zy * ZONE_W + zx
	var z_city: int = int(t["city_id"])
	if z_id >= 0 and z_id < zone_city_id.size() and zone_city_id[z_id] != -1:
		z_city = zone_city_id[z_id]

	return {
		"elevation": final_elev,
		"biome_id": b_tile["biome_id"],
		"city_id": z_city,
		"tile_index": t_idx,
		"zone_id": z_id
	}


func sample_elevation_fast(u: float, v: float) -> float:
	var fx: float = clampf(u * float(GRID_W), 0.0, float(GRID_W) - 0.001)
	var fy: float = clampf(v * float(GRID_H), 0.0, float(GRID_H) - 0.001)
	var gx: int = int(fx)
	var gy: int = int(fy)
	var gx1: int = mini(gx + 1, GRID_W - 1)
	var gy1: int = mini(gy + 1, GRID_H - 1)
	var tx: float = fx - float(gx)
	var ty: float = fy - float(gy)

	var e00: float = float(tiles[gy * GRID_W + gx]["elevation"])
	var e10: float = float(tiles[gy * GRID_W + gx1]["elevation"])
	var e01: float = float(tiles[gy1 * GRID_W + gx]["elevation"])
	var e11: float = float(tiles[gy1 * GRID_W + gx1]["elevation"])
	var base_e: float = lerpf(lerpf(e00, e10, tx), lerpf(e01, e11, tx), ty)

	var coast_jitter: float = _noise_detail.get_noise_2d(u * 180.0, v * 110.0) * 0.055
	var micro_jitter: float = _noise_detail.get_noise_2d(u * 420.0 + 70.0, v * 260.0) * 0.022
	return base_e + coast_jitter + micro_jitter


func classify_base_tile_tier(elev: float) -> int:
	if elev < -0.18:
		return 0 # deep_ocean
	elif elev < -0.055:
		return 1 # close_ocean
	elif elev < 0.0:
		return 2 # shallow_waters
	elif elev < 0.034:
		return 3 # sand
	elif elev < 0.135:
		return 4 # soil_low / top_low
	elif elev < 0.235:
		return 5 # soil_high / top_high
	elif elev < 0.285:
		return 6 # hills
	elif elev < 0.345:
		return 7 # mountains
	return 8 # summit


func get_base_tile_id_for_tier(tier: int, biome_id: String = "") -> String:
	if biome_id == "biome_plasma_inferno" and tier >= 3 and tier <= 5:
		return "lava1" if tier == 5 else "lava0"
	match tier:
		0: return "deep_ocean"
		1: return "close_ocean"
		2: return "shallow_waters"
		3: return "sand"
		4: return "soil_low"
		5: return "soil_high"
		6: return "hills"
		7: return "mountains"
		_: return "summit"


func sample_fine_world_tile(px: int, py: int) -> Dictionary:
	var c_px: int = clampi(px, 0, FINE_W - 1)
	var c_py: int = clampi(py, 0, FINE_H - 1)
	var uv := Vector2((float(c_px) + 0.5) / float(FINE_W), (float(c_py) + 0.5) / float(FINE_H))
	var cur: Dictionary = sample_pixel_terrain(uv)
	var elev: float = float(cur["elevation"])
	var biome_id: String = str(cur["biome_id"])
	var tier: int = classify_base_tile_tier(elev)

	# Кардинальные соседи (N, E, S, W) для 4-битного автотайлинга, береговой пены и теней высот (WorldBox Cliff Shadow)
	var v_n: float = (float(maxi(0, c_py - 1)) + 0.5) / float(FINE_H)
	var v_s: float = (float(mini(FINE_H - 1, c_py + 1)) + 0.5) / float(FINE_H)
	var u_w: float = (float(maxi(0, c_px - 1)) + 0.5) / float(FINE_W)
	var u_e: float = (float(mini(FINE_W - 1, c_px + 1)) + 0.5) / float(FINE_W)

	var tier_n: int = classify_base_tile_tier(sample_elevation_fast(uv.x, v_n))
	var tier_s: int = classify_base_tile_tier(sample_elevation_fast(uv.x, v_s))
	var tier_w: int = classify_base_tile_tier(sample_elevation_fast(u_w, uv.y))
	var tier_e: int = classify_base_tile_tier(sample_elevation_fast(u_e, uv.y))

	# 4-битная маска одинакового уровня высоты (N=1, E=2, S=4, W=8)
	var mask_4bit: int = 0
	if tier_n >= tier: mask_4bit |= 1
	if tier_e >= tier: mask_4bit |= 2
	if tier_s >= tier: mask_4bit |= 4
	if tier_w >= tier: mask_4bit |= 8

	var has_cliff_shadow: bool = (tier_n > tier and tier_n >= 3)
	var is_cliff_rim: bool = (tier >= 3 and tier_s < tier)
	var is_shoreline_foam: bool = (tier == 2 and (tier_n >= 3 or tier_s >= 3 or tier_w >= 3 or tier_e >= 3))
	var is_wet_sand: bool = (tier == 3 and (tier_n <= 2 or tier_s <= 2 or tier_w <= 2 or tier_e <= 2))

	var fine_idx: int = c_py * FINE_W + c_px
	var road_val: int = fine_road_overlay[fine_idx] if fine_idx < fine_road_overlay.size() else 0
	var has_road: bool = (road_val == 1 and tier >= 3 and tier <= 5)
	var has_field: bool = (road_val == 2 and tier >= 3 and tier <= 5)

	var base_tile_id: String = get_base_tile_id_for_tier(tier, biome_id)
	if has_road:
		base_tile_id = "road"
	elif has_field:
		base_tile_id = "field"

	var zx: int = clampi(c_px / ZONE_SIZE, 0, ZONE_W - 1)
	var zy: int = clampi(c_py / ZONE_SIZE, 0, ZONE_H - 1)
	var z_id: int = zy * ZONE_W + zx
	var c_id: int = int(cur["city_id"])

	var is_zone_border := false
	if c_id != -1 and tier >= 2:
		if (c_px % ZONE_SIZE == 0) and (zx == 0 or _get_zone_owner(zx - 1, zy) != c_id):
			is_zone_border = true
		elif (c_px % ZONE_SIZE == ZONE_SIZE - 1) and (zx == ZONE_W - 1 or _get_zone_owner(zx + 1, zy) != c_id):
			is_zone_border = true
		elif (c_py % ZONE_SIZE == 0) and (zy == 0 or _get_zone_owner(zx, zy - 1) != c_id):
			is_zone_border = true
		elif (c_py % ZONE_SIZE == ZONE_SIZE - 1) and (zy == ZONE_H - 1 or _get_zone_owner(zx, zy + 1) != c_id):
			is_zone_border = true

	var hash_decor: int = ((c_px * 374761393) ^ (c_py * 668265263)) & 0x7fffffff
	var is_decor: bool = (tier >= 4 and tier <= 5 and not has_road and not has_field and (hash_decor % 19 == 0))

	return {
		"px": c_px,
		"py": c_py,
		"elevation": elev,
		"height_tier": tier,
		"base_tile_id": base_tile_id,
		"top_biome_id": biome_id,
		"is_high_variant": (tier >= 5),
		"is_decor_pixel": is_decor,
		"autotile_mask_4bit": mask_4bit,
		"has_cliff_shadow": has_cliff_shadow,
		"is_cliff_rim": is_cliff_rim,
		"is_shoreline_foam": is_shoreline_foam,
		"is_wet_sand": is_wet_sand,
		"zone_id": z_id,
		"city_id": c_id,
		"is_zone_border": is_zone_border,
		"has_road": has_road,
		"has_field": has_field
	}


func _get_zone_owner(zx: int, zy: int) -> int:
	if zx < 0 or zx >= ZONE_W or zy < 0 or zy >= ZONE_H:
		return -1
	var z_id: int = zy * ZONE_W + zx
	if z_id >= 0 and z_id < zone_city_id.size() and zone_city_id[z_id] != -1:
		return zone_city_id[z_id]
	var gx: int = clampi(int((float(zx) + 0.5) / float(ZONE_W) * float(GRID_W)), 0, GRID_W - 1)
	var gy: int = clampi(int((float(zy) + 0.5) / float(ZONE_H) * float(GRID_H)), 0, GRID_H - 1)
	return int(tiles[gy * GRID_W + gx]["city_id"])


func _claim_zones_for_tile(city_id: int, t_idx: int) -> Array[int]:
	var claimed_z: Array[int] = []
	if t_idx < 0 or t_idx >= TILE_COUNT:
		return claimed_z
	var t: Dictionary = tiles[t_idx]
	var gx: int = int(t["gx"])
	var gy: int = int(t["gy"])
	var z_min_x: int = clampi(int(floor(float(gx) / float(GRID_W) * float(ZONE_W))), 0, ZONE_W - 1)
	var z_max_x: int = clampi(int(ceil(float(gx + 1) / float(GRID_W) * float(ZONE_W))) - 1, z_min_x, ZONE_W - 1)
	var z_min_y: int = clampi(int(floor(float(gy) / float(GRID_H) * float(ZONE_H))), 0, ZONE_H - 1)
	var z_max_y: int = clampi(int(ceil(float(gy + 1) / float(GRID_H) * float(ZONE_H))) - 1, z_min_y, ZONE_H - 1)

	for zy in range(z_min_y, z_max_y + 1):
		for zx in range(z_min_x, z_max_x + 1):
			var z_id: int = zy * ZONE_W + zx
			if z_id >= 0 and z_id < zone_city_id.size():
				zone_city_id[z_id] = city_id
				claimed_z.append(z_id)
	return claimed_z


func _carve_city_roads_and_fields(city: Dictionary) -> void:
	if fine_road_overlay.size() != FINE_COUNT:
		return
	var c_pos: Vector2 = city["map_pos"]
	var cx0: int = clampi(int(c_pos.x / MAP_PIXEL_W * float(FINE_W)), 2, FINE_W - 3)
	var cy0: int = clampi(int(c_pos.y / MAP_PIXEL_H * float(FINE_H)), 2, FINE_H - 3)

	# Центральная мощёная площадь вокруг ратуши (3x3 микро-тайла road #C1997C)
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			var r_idx: int = (cy0 + dy) * FINE_W + (cx0 + dx)
			fine_road_overlay[r_idx] = 1

	# Террасные фермерские поля (field #A8663A) рядом с центром полиса
	for fy in range(-4, -1):
		for fx in range(-4, 0):
			var f_px: int = clampi(cx0 + fx, 1, FINE_W - 2)
			var f_py: int = clampi(cy0 + fy, 1, FINE_H - 2)
			fine_road_overlay[f_py * FINE_W + f_px] = 2

	# Прокладываем дороги (road #C1997C) от каждого здания к центру города (L-образная трассировка как в WorldBox)
	var inst_list: Array = city.get("building_instances", [])
	for b_inst in inst_list:
		var b_pos: Vector2 = b_inst["map_pos"]
		var bx: int = clampi(int(b_pos.x / MAP_PIXEL_W * float(FINE_W)), 2, FINE_W - 3)
		var by: int = clampi(int(b_pos.y / MAP_PIXEL_H * float(FINE_H)), 2, FINE_H - 3)
		var cur_x: int = bx
		var cur_y: int = by
		var steps: int = 0
		while (cur_x != cx0 or cur_y != cy0) and steps < 64:
			fine_road_overlay[cur_y * FINE_W + cur_x] = 1
			if cur_x != cx0 and (steps % 2 == 0 or cur_y == cy0):
				cur_x += 1 if cx0 > cur_x else -1
			elif cur_y != cy0:
				cur_y += 1 if cy0 > cur_y else -1
			steps += 1


func count_road_tiles() -> int:
	var cnt: int = 0
	for i in range(fine_road_overlay.size()):
		if fine_road_overlay[i] == 1:
			cnt += 1
	return cnt


func count_field_tiles() -> int:
	var cnt: int = 0
	for i in range(fine_road_overlay.size()):
		if fine_road_overlay[i] == 2:
			cnt += 1
	return cnt


func _seed_initial_cradle() -> void:
	# Выбираем 3 живописных острова в центральной зоне карты (gx: 8..23, gy: 6..24) и заселяем их
	var land_candidates: Array[int] = []
	for gy in range(7, GRID_H - 7):
		for gx in range(8, GRID_W - 8):
			var idx: int = gy * GRID_W + gx
			if float(tiles[idx]["elevation"]) > 0.05:
				land_candidates.append(idx)

	if land_candidates.size() < 12:
		for dy in range(-3, 4):
			for dx in range(-4, 5):
				var c_idx: int = (15 + dy) * GRID_W + (16 + dx)
				tiles[c_idx]["elevation"] = 0.16
				tiles[c_idx]["biome_id"] = "biome_primordial_ocean"
				land_candidates.append(c_idx)

	var idx_west: int = land_candidates[0]
	var idx_east: int = land_candidates[land_candidates.size() - 1]
	var idx_mid: int = land_candidates[land_candidates.size() / 2]

	# Делаем западный остров Био-Террасой, восточный — Кристаллической Решёткой, северный — Крио-Сверхпроводником
	_paint_biome_cluster(idx_west, "biome_primordial_ocean", 0.15)
	_paint_biome_cluster(idx_east, "biome_crystal_lattice", 0.18)
	_paint_biome_cluster(idx_mid, "biome_cybercore", 0.14)

	_populate_fine_flora_and_minerals()

	var sp1_id: int = _spawn_subspecies_at_tile(idx_west, "carbon")
	_uplift_subspecies_and_found_city(sp1_id, idx_west)

	var sp2_id: int = _spawn_subspecies_at_tile(idx_east, "silicon")
	_uplift_subspecies_and_found_city(sp2_id, idx_east)

	# И дикое племя кибер-дронов в центре
	_spawn_subspecies_at_tile(idx_mid, "cyber")

	_create_dyson_ring(24, Color(0.25, 0.85, 1.0))


func _paint_biome_cluster(center_idx: int, biome_id: String, min_elev: float) -> void:
	tiles[center_idx]["biome_id"] = biome_id
	tiles[center_idx]["elevation"] = maxf(float(tiles[center_idx]["elevation"]), min_elev)
	tiles[center_idx]["flora"] = _pick_flora_for_biome(biome_id, min_elev, center_idx)
	for nbr in tiles[center_idx]["neighbors"]:
		tiles[nbr]["biome_id"] = biome_id
		tiles[nbr]["elevation"] = maxf(float(tiles[nbr]["elevation"]), min_elev * 0.85)
		tiles[nbr]["flora"] = _pick_flora_for_biome(biome_id, min_elev, nbr)


# ==============================================================================
# ГЛАВНЫЙ ЦИКЛ СИМУЛЯЦИИ (WorldBehaviour тики + движение пиксельных человечков)
# ==============================================================================
func _process(delta: float) -> void:
	if paused:
		return
	step_simulation(delta * sim_speed)


func step_simulation(dt: float) -> void:
	if dt <= 0.0:
		return

	world_year += dt * 2.5

	_sim_time_accumulator += dt
	var max_steps: int = maxi(MAX_SUBSTEPS_PER_FRAME, int(dt / FIXED_SUBSTEP_DT) + 2)
	var steps_done: int = 0
	while _sim_time_accumulator >= FIXED_SUBSTEP_DT and steps_done < max_steps:
		_substep_simulation(FIXED_SUBSTEP_DT)
		_sim_time_accumulator -= FIXED_SUBSTEP_DT
		steps_done += 1
	if _sim_time_accumulator > FIXED_SUBSTEP_DT * 2.0:
		_sim_time_accumulator = fmod(_sim_time_accumulator, FIXED_SUBSTEP_DT)


func _substep_simulation(sub_dt: float) -> void:
	_update_field_lenses(sub_dt)
	_step_actors(sub_dt)

	_diplomacy_timer += sub_dt
	while _diplomacy_timer >= DIPLOMACY_TICK_INTERVAL:
		_tick_city_diplomacy(DIPLOMACY_TICK_INTERVAL)
		_diplomacy_timer -= DIPLOMACY_TICK_INTERVAL

	for wb in assets.world_behaviour_list:
		var t_val: float = _wb_timers.get(wb.id, 0.0) + sub_dt
		while t_val >= wb.interval:
			_execute_world_behaviour(wb.id, wb.interval)
			t_val -= wb.interval
		_wb_timers[wb.id] = t_val

	_tick_building_entropy(sub_dt)


func _tick_building_entropy(dt: float) -> void:
	var sigma: float = get_world_constant("cosmic_entropy_rate")
	if sigma <= 0.0:
		return

	# Космическая диссипация: истощение пояса астероидов и рассеивание энергии
	asteroid_belt_mass = maxf(0.0, asteroid_belt_mass - 0.02 * sigma * dt)
	energy_gw = maxf(0.0, energy_gw - 0.01 * sigma * dt)

	# Коэффициенты коррозии биомов
	var biome_corrosion := {
		"biome_singularity_swamp": 2.2,
		"biome_plasma_inferno": 2.0,
		"biome_actinide_wasteland": 1.6,
		"biome_primordial_ocean": 1.0,
		"biome_barren_crust": 1.0,
		"biome_crystal_lattice": 0.7,
		"biome_cryo_superconductor": 0.6,
		"biome_cybercore": 0.5
	}

	for c_id in cities_map.keys():
		var city: Dictionary = cities_map[c_id]
		if not city.has("buildings"):
			continue
		var b_dict: Dictionary = city["buildings"]
		if b_dict.is_empty():
			continue

		if not city.has("building_durability"):
			city["building_durability"] = {}
		var dur_dict: Dictionary = city["building_durability"]

		var t_idx: int = clampi(int(city.get("center_tile", 0)), 0, TILE_COUNT - 1)
		var b_id_tile: String = tiles[t_idx].get("biome_id", "biome_barren_crust")
		var c_biome: float = float(biome_corrosion.get(b_id_tile, 1.0))

		var pop: float = float(city.get("population", 0.0))
		var kardashev: float = float(city.get("kardashev_level", 0.5))

		# Ремонт в процветающих городах при достатке населения и материи
		var can_repair: bool = (pop >= 15.0 and matter_stock >= 5.0)
		var repair_rate: float = (0.25 + 0.15 * kardashev) * dt if can_repair else 0.0

		var b_keys := b_dict.keys()
		for b_id in b_keys:
			var bo: SandboxAssetScript.BuildOrderAsset = assets.build_orders.get(b_id)
			var tier: float = float(bo.tier) if bo != null else 1.0
			var max_hp: float = 100.0 * tier
			var cur_hp: float = float(dur_dict.get(b_id, max_hp))

			var wear_rate: float = sigma * (0.15 * tier) * c_biome * dt
			var net_change: float = repair_rate - wear_rate
			var new_hp: float = cur_hp + net_change

			if new_hp <= 0.0:
				dur_dict[b_id] = 0.0
				damage_city_building(c_id, b_id, max_hp + 10.0)
			else:
				dur_dict[b_id] = minf(new_hp, max_hp)


func get_building_wear_telemetry(city_id: int) -> Dictionary:
	if not cities_map.has(city_id):
		return {}
	var city: Dictionary = cities_map[city_id]
	return {
		"city_id": city_id,
		"city_name": city.get("name", ""),
		"durability": city.get("building_durability", {}).duplicate(),
		"buildings": city.get("buildings", {}).duplicate(),
		"entropy_rate": get_world_constant("cosmic_entropy_rate")
	}


func _execute_world_behaviour(wb_id: String, interval_dt: float) -> void:
	match wb_id:
		"wb_thermodynamics_and_lenses":
			_tick_thermodynamics_and_lenses(interval_dt)
		"wb_biome_spread_and_abiogenesis":
			_tick_biome_spread_and_abiogenesis()
		"wb_subspecies_evolution":
			_tick_subspecies_evolution()
		"wb_city_build_orders":
			_tick_city_build_orders(interval_dt)
		"wb_plots_and_infinite_science":
			_tick_plots_and_infinite_science(interval_dt)
		"wb_dyson_swarm_and_star":
			_tick_dyson_swarm_and_star(interval_dt)


# ==============================================================================
# ДВИЖЕНИЕ И ЖИЗНЬ ПИКСЕЛЬНЫХ СУЩЕСТВ (ActorMove / CitizenJobs из WorldBox)
# ==============================================================================
func _spawn_actor_unit(sp_id: int, tile_idx: int, city_id: int = -1, custom_role: String = "") -> Dictionary:
	if actors.size() >= MAX_ACTORS:
		return {}
	var sp: Dictionary = subspecies_map.get(sp_id, {})
	if sp.is_empty():
		return {}

	var t: Dictionary = tiles[tile_idx]
	var center_pos: Vector2 = t["map_pos"]
	var jitter := Vector2(_rng.randf_range(-20.0, 20.0), _rng.randf_range(-12.0, 12.0))
	var start_pos: Vector2 = (center_pos + jitter).clamp(Vector2(24.0, 24.0), Vector2(MAP_PIXEL_W - 24.0, MAP_PIXEL_H - 24.0))

	var roles := ["gatherer", "builder", "scholar", "miner", "astronaut", "warrior"]
	var role: String = custom_role if custom_role != "" else roles[_rng.randi_range(0, roles.size() - 1)]

	var thoughts_by_role := {
		"gatherer": "Собирает био-образцы",
		"builder": "Возводит техно-купол",
		"scholar": "Вычисляет квантовую теорию",
		"miner": "Бурит литосферу",
		"astronaut": "Готовит пуск к Сфере Дайсона",
		"warrior": "Охраняет рубежи полиса",
		"colonist": "Плывёт основывать дочерний полис"
	}

	var job_by_role := {
		"gatherer": "woodcutter",
		"builder": "builder",
		"scholar": "road_builder",
		"miner": "miner",
		"astronaut": "builder",
		"warrior": "attacker",
		"colonist": "builder"
	}

	var unit_id: int = _next_meta_id
	_next_meta_id += 1
	var actor := {
		"id": unit_id,
		"name": "%s #%d" % [str(sp.get("name", "Юнит")).split("-")[0], unit_id % 100],
		"subspecies_id": sp_id,
		"city_id": city_id,
		"archetype": sp.get("archetype", "carbon"),
		"role": role,
		"job_id": job_by_role.get(role, "woodcutter"),
		"job_state": "IDLE",
		"job_timer": 0.0,
		"target_flora_idx": -1,
		"carrying": "",
		"tool_swing": 0.0,
		"hit_shake": 0.0,
		"thought": thoughts_by_role.get(role, "Исследует мир"),
		"pos": start_pos,
		"target_pos": start_pos,
		"home_tile": tile_idx,
		"age": _rng.randi_range(1, 45),
		"hp": 100,
		"color": sp.get("color", Color.AQUA),
		"anim_phase": _rng.randf() * TAU,
		"wait_timer": _rng.randf_range(0.15, 0.8),
		"facing_left": _rng.randf() < 0.5
	}
	actors.append(actor)
	return actor


func _step_actors(dt: float) -> void:
	for c_val in cities_map.values():
		var b_insts: Array = c_val.get("building_instances", [])
		for b_i in b_insts:
			var b_sp: float = float(b_i.get("spawn_spring", 1.0))
			if b_sp < 1.0:
				b_i["spawn_spring"] = minf(1.0, b_sp + dt * 2.0)
			var b_sh: float = float(b_i.get("hit_shake", 0.0))
			if b_sh > 0.0:
				b_i["hit_shake"] = maxf(0.0, b_sh - dt * 3.5)

	var idx: int = actors.size() - 1
	while idx >= 0:
		if idx >= actors.size():
			idx -= 1
			continue
		var a: Dictionary = actors[idx]
		a["anim_phase"] = float(a["anim_phase"]) + dt * 9.0
		var hs: float = float(a.get("hit_shake", 0.0))
		if hs > 0.0:
			a["hit_shake"] = maxf(0.0, hs - dt * 4.0)

		var wait_t: float = float(a["wait_timer"]) - dt
		if wait_t > 0.0:
			a["wait_timer"] = wait_t
			idx -= 1
			continue

		var pos: Vector2 = a["pos"]
		var target: Vector2 = a["target_pos"]
		var diff: Vector2 = target - pos
		var dist: float = diff.length()

		# Проверка колониальной экспедиции
		if str(a.get("role", "")) == "colonist":
			if dist < 12.0:
				var mother_c_id: int = int(a.get("city_id", -1))
				var target_t_idx: int = int(a.get("home_tile", -1))
				if mother_c_id != -1 and cities_map.has(mother_c_id) and target_t_idx != -1:
					var m_cult: int = int(cities_map[mother_c_id]["culture_id"])
					var daughter_id: int = _found_daughter_city(mother_c_id, target_t_idx, int(a["subspecies_id"]), m_cult)
					a["city_id"] = daughter_id
					a["role"] = "builder"
					a["job_id"] = "builder"
					a["thought"] = "Возводит техно-купол нового полиса"
				idx -= 1
				continue

		var home_idx: int = clampi(int(a["home_tile"]), 0, TILE_COUNT - 1)
		var local_time: float = clampf(float(tiles[home_idx]["time_scale_mult"]), 1.0, 6.0)
		var move_speed: float = (38.0 if str(a.get("role", "")) == "colonist" else 32.0) * sqrt(local_time)

		var c_id: int = int(a.get("city_id", -1))
		var j_state: String = str(a.get("job_state", "IDLE"))
		var j_id: String = str(a.get("job_id", "woodcutter"))

		# Цикл задач жителей из WorldBox (ActorJobLibrary: Найти -> Собрать -> Отнести в ратушу -> Построить)
		if c_id != -1 and cities_map.has(c_id) and str(a.get("role", "")) != "colonist":
			var city: Dictionary = cities_map[c_id]
			if j_state == "WORKING":
				var jt: float = float(a.get("job_timer", 0.0)) - dt * sqrt(local_time)
				a["job_timer"] = jt
				a["tool_swing"] = fmod(float(a.get("tool_swing", 0.0)) + dt * 14.0, TAU)
				var tf_idx: int = int(a.get("target_flora_idx", -1))
				if tf_idx >= 0 and tf_idx < flora_instances.size():
					flora_instances[tf_idx]["chop_shake"] = 1.0
				if jt <= 0.0:
					a["tool_swing"] = 0.0
					if j_id == "woodcutter":
						a["carrying"] = "wood"
						a["target_pos"] = city["map_pos"]
						a["job_state"] = "CARRY_TO_STORAGE"
						a["thought"] = "Несёт бревно на склад полиса"
					elif j_id == "miner":
						a["carrying"] = "minerals"
						a["target_pos"] = city["map_pos"]
						a["job_state"] = "CARRY_TO_STORAGE"
						a["thought"] = "Несёт кристаллическую руду в ратушу"
					elif j_id == "farmer" or j_id == "gatherer_bushes":
						a["carrying"] = "food"
						a["target_pos"] = city["map_pos"]
						a["job_state"] = "CARRY_TO_STORAGE"
						a["thought"] = "Несёт урожай в хранилище"
					else:
						# Строитель / Дорожник завершает участок работ
						var wx: int = clampi(int(pos.x / MAP_PIXEL_W * float(FINE_W)), 1, FINE_W - 2)
						var wy: int = clampi(int(pos.y / MAP_PIXEL_H * float(FINE_H)), 1, FINE_H - 2)
						if fine_road_overlay.size() == FINE_COUNT and sample_elevation_fast(pos.x / MAP_PIXEL_W, pos.y / MAP_PIXEL_H) >= 0.01:
							fine_road_overlay[wy * FINE_W + wx] = 1
						total_citizen_tasks_completed += 1
						a["job_state"] = "IDLE"
						a["wait_timer"] = _rng.randf_range(0.25, 0.7)
				idx -= 1
				continue

			if dist < 8.0:
				if j_state == "MOVE_TO_TARGET":
					a["job_state"] = "WORKING"
					a["job_timer"] = _rng.randf_range(0.45, 0.95)
					idx -= 1
					continue
				elif j_state == "CARRY_TO_STORAGE":
					if not city.has("storage"):
						city["storage"] = {"wood": 20, "minerals": 15, "food": 30}
					var st_dict: Dictionary = city["storage"]
					var carried: String = str(a.get("carrying", "wood"))
					if carried != "":
						st_dict[carried] = int(st_dict.get(carried, 0)) + 2
						if carried == "minerals":
							matter_stock += 1.2 * codex_matter_mult
						elif carried == "wood":
							matter_stock += 0.8 * codex_matter_mult
						elif carried == "food":
							energy_gw += 0.6 * codex_energy_mult
					a["carrying"] = ""
					a["target_flora_idx"] = -1
					a["job_state"] = "IDLE"
					a["wait_timer"] = _rng.randf_range(0.2, 0.6)
					total_citizen_tasks_completed += 1
					idx -= 1
					continue
				else:
					# Назначаем новую задачу из CitizenJobLibrary
					_assign_next_citizen_job_target(a, city)
					idx -= 1
					continue

		if dist < 4.0:
			# Дикие существа без города просто гуляют по острову
			a["wait_timer"] = _rng.randf_range(0.4, 1.4)
			var next_tile_idx: int = home_idx
			var nbrs: PackedInt32Array = tiles[home_idx]["neighbors"]
			if nbrs.size() > 0:
				var cand: int = nbrs[_rng.randi_range(0, nbrs.size() - 1)]
				if float(tiles[cand]["elevation"]) >= -0.04:
					next_tile_idx = cand

			a["home_tile"] = next_tile_idx
			var base_p: Vector2 = tiles[next_tile_idx]["map_pos"]
			a["target_pos"] = (base_p + Vector2(_rng.randf_range(-24.0, 24.0), _rng.randf_range(-14.0, 14.0))).clamp(
				Vector2(20.0, 20.0), Vector2(MAP_PIXEL_W - 20.0, MAP_PIXEL_H - 20.0)
			)
		else:
			var step_v: Vector2 = (diff / dist) * minf(dist, move_speed * dt)
			a["pos"] = pos + step_v
			if absf(step_v.x) > 0.05:
				a["facing_left"] = step_v.x < 0.0
		idx -= 1

	_step_actor_combat(dt)


func _assign_next_citizen_job_target(a: Dictionary, city: Dictionary) -> void:
	var j_id: String = str(a.get("job_id", "woodcutter"))
	var c_pos: Vector2 = city["map_pos"]
	a["carrying"] = ""
	a["target_flora_idx"] = -1

	if (j_id == "woodcutter" or j_id == "miner") and not flora_instances.is_empty():
		var want_mineral: bool = (j_id == "miner")
		var best_f_idx: int = -1
		var best_d: float = 260.0
		var tries: int = mini(8, flora_instances.size())
		var start_i: int = _rng.randi_range(0, flora_instances.size() - 1)
		for k in range(tries):
			var cand_i: int = (start_i + k * 7) % flora_instances.size()
			var fl: Dictionary = flora_instances[cand_i]
			if bool(fl.get("is_mineral", false)) != want_mineral:
				continue
			var d: float = (fl["pos"] as Vector2).distance_to(c_pos)
			if d < best_d:
				best_d = d
				best_f_idx = cand_i
		if best_f_idx != -1:
			a["target_flora_idx"] = best_f_idx
			a["target_pos"] = flora_instances[best_f_idx]["pos"]
			a["job_state"] = "MOVE_TO_TARGET"
			a["thought"] = "Идёт добывать руду" if want_mineral else "Идёт рубить лес"
			return

	var b_insts: Array = city.get("building_instances", [])
	if (j_id == "builder" or j_id == "road_builder") and not b_insts.is_empty():
		var b_target: Dictionary = b_insts[_rng.randi_range(0, b_insts.size() - 1)]
		a["target_pos"] = (b_target["map_pos"] as Vector2) + Vector2(_rng.randf_range(-10.0, 10.0), _rng.randf_range(-8.0, 8.0))
		a["job_state"] = "MOVE_TO_TARGET"
		a["thought"] = "Мостит дорогу полиса" if j_id == "road_builder" else "Строит здание в зоне полиса"
		return

	var claimed: Array = city.get("claimed_tiles", [])
	if not claimed.is_empty():
		var next_t: int = int(claimed[_rng.randi_range(0, claimed.size() - 1)])
		a["home_tile"] = next_t
		a["target_pos"] = (tiles[next_t]["map_pos"] as Vector2) + Vector2(_rng.randf_range(-18.0, 18.0), _rng.randf_range(-12.0, 12.0))
		a["job_state"] = "MOVE_TO_TARGET"
		a["thought"] = "Работает на благо полиса"


func find_closest_actor(world_pos: Vector2, max_dist: float = 42.0) -> Dictionary:
	var best_actor: Dictionary = {}
	var best_d: float = max_dist
	for a in actors:
		var d: float = (a["pos"] as Vector2).distance_to(world_pos)
		if d < best_d:
			best_d = d
			best_actor = a
	return best_actor


# ==============================================================================
# 1. ТЕРМОДИНАМИКА, КЛЕТОЧНАЯ ЛАВА И КУПОЛА-ЛИНЗЫ КОНСТАНТ
# ==============================================================================
func _update_field_lenses(dt: float) -> void:
	if field_lenses.is_empty():
		return
	var changed := false
	for i in range(field_lenses.size() - 1, -1, -1):
		var lens: Dictionary = field_lenses[i]
		lens["remaining"] = float(lens["remaining"]) - dt
		if float(lens["remaining"]) <= 0.0:
			field_lenses.remove_at(i)
			changed = true
	if changed:
		_recalc_tile_lens_modifiers()
		field_lenses_changed.emit()


func _recalc_tile_lens_modifiers() -> void:
	for i in range(TILE_COUNT):
		var t: Dictionary = tiles[i]
		var b_asset: SandboxAssetScript.BiomeAsset = assets.biomes.get(t["biome_id"])
		var time_m: float = b_asset.time_scale_mod if b_asset != null else 1.0
		var grav_m: float = b_asset.gravity_mod if b_asset != null else 1.0
		var t_pos: Vector2 = t["map_pos"]

		for lens in field_lenses:
			var l_pos: Vector2 = lens["map_pos"]
			var rad_px: float = float(lens["radius_px"])
			if t_pos.distance_to(l_pos) <= rad_px:
				time_m = maxf(time_m, float(lens["time_mult"]))
				grav_m = minf(grav_m, float(lens["grav_mult"]))
		t["time_scale_mult"] = time_m
		t["gravity_mult"] = grav_m


func _tick_thermodynamics_and_lenses(_dt: float) -> void:
	_recalc_tile_lens_modifiers()
	var surface_dirty := false
	var dirty_tiles: Array[int] = []

	for i in range(0, TILE_COUNT, 4):
		var idx: int = (i + int(world_year) % 4) % TILE_COUNT
		var t: Dictionary = tiles[idx]
		var b_id: String = t["biome_id"]
		var b_asset: SandboxAssetScript.BiomeAsset = assets.biomes.get(b_id)
		if b_asset != null:
			t["temperature_c"] = lerpf(float(t["temperature_c"]), b_asset.ideal_temp_c * star_luminosity_mult, 0.08)
			t["radiation"] = lerpf(float(t["radiation"]), b_asset.radiation_level, 0.06)

		# Клеточная физика из WorldBox (WorldBehaviourActionLava):
		# Если плазменная лава соприкасается с глубоким холодным океаном и остывает — края застывают в базальт!
		if b_id == "biome_plasma_inferno" and float(t["temperature_c"]) < 140.0:
			for nbr in t["neighbors"]:
				if float(tiles[nbr]["elevation"]) < -0.05 and tiles[nbr]["biome_id"] == "biome_primordial_ocean":
					if _rng.randf() < 0.18:
						t["biome_id"] = "biome_barren_crust"
						t["elevation"] = maxf(0.03, float(t["elevation"]))
						t["flora"] = "basalt_rock"
						surface_dirty = true
						dirty_tiles.append(idx)
						break

	if surface_dirty:
		request_dirty_tiles_update(dirty_tiles)
		planet_surface_changed.emit()


# ==============================================================================
# 2. РАСПРОСТРАНЕНИЕ БИОМОВ И САМОЗАРОЖДЕНИЕ ЖИЗНИ (WorldBox Biome + Abiogenesis)
# ==============================================================================
func _tick_biome_spread_and_abiogenesis() -> void:
	var surface_dirty := false
	var dirty_tiles: Array[int] = []
	for _attempt in range(14):
		var src_idx: int = _rng.randi_range(0, TILE_COUNT - 1)
		var src_tile: Dictionary = tiles[src_idx]
		var b_id: String = src_tile["biome_id"]
		if b_id == "biome_barren_crust" or float(src_tile["elevation"]) < -0.02:
			continue
		var b_asset: SandboxAssetScript.BiomeAsset = assets.biomes.get(b_id)
		if b_asset != null and b_asset.spread_strength >= 2:
			var nbrs: PackedInt32Array = src_tile["neighbors"]
			if nbrs.size() > 0:
				var dst_idx: int = nbrs[_rng.randi_range(0, nbrs.size() - 1)]
				if tiles[dst_idx]["biome_id"] == "biome_barren_crust" and float(tiles[dst_idx]["elevation"]) >= -0.02:
					tiles[dst_idx]["biome_id"] = b_id
					tiles[dst_idx]["flora"] = _pick_flora_for_biome(b_id, float(tiles[dst_idx]["elevation"]), dst_idx)
					surface_dirty = true
					dirty_tiles.append(dst_idx)

	if active_world_laws.get("law_spontaneous_abiogenesis", true) and subspecies_map.size() < 8:
		if _rng.randf() < 0.20:
			var r_idx: int = _rng.randi_range(0, TILE_COUNT - 1)
			var r_tile: Dictionary = tiles[r_idx]
			if int(r_tile["subspecies_id"]) == -1 and float(r_tile["elevation"]) >= -0.01:
				var arch := _archetype_for_biome(r_tile["biome_id"])
				var new_sp_id := _spawn_subspecies_at_tile(r_idx, arch)
				if new_sp_id > 0:
					surface_dirty = true
					dirty_tiles.append(r_idx)

	if surface_dirty:
		request_dirty_tiles_update(dirty_tiles)
		planet_surface_changed.emit()


func _archetype_for_biome(biome_id: String) -> String:
	match biome_id:
		"biome_crystal_lattice", "biome_cryo_superconductor":
			return "silicon"
		"biome_plasma_inferno", "biome_actinide_wasteland":
			return "plasma"
		"biome_cybercore":
			return "cyber"
		"biome_singularity_swamp":
			return "quantum"
		_:
			return "carbon"


# ==============================================================================
# 3. ДЕМОГРАФИЯ, МУТАЦИИ ВИДОВ И ВОЗВЫШЕНИЕ РАЗУМА (Subspecies -> Culture/City)
# ==============================================================================
func _spawn_subspecies_at_tile(tile_idx: int, archetype: String) -> int:
	var sp_id: int = _next_meta_id
	_next_meta_id += 1

	var t: Dictionary = tiles[tile_idx]
	# Если жизнь засеяна в глубокий океан — насыпаем живописный био-остров, чтобы пиксельным человечкам было где ходить!
	if float(t["elevation"]) < 0.04:
		t["elevation"] = 0.12
		if t["biome_id"] == "biome_barren_crust":
			t["biome_id"] = "biome_primordial_ocean"
		t["flora"] = _pick_flora_for_biome(t["biome_id"], 0.12, tile_idx)

	var b_asset: SandboxAssetScript.BiomeAsset = assets.biomes.get(t["biome_id"])

	var prefix_map := {
		"carbon": ["Био-Нави", "Терра-Зоа", "Сильва-Морфы", "Гидро-Цефалы"],
		"silicon": ["Кварц-Литы", "Пьезо-Грани", "Оптико-Кристаллы", "Силико-Разум"],
		"plasma": ["Гелио-Плазмоиды", "Магнито-Архонты", "Короно-Рождённые", "Ион-Странники"],
		"cyber": ["Автоматоны-Ноль", "Синтет-Коллектив", "Нано-Нексус", "Кибер-Рой"],
		"quantum": ["Хроно-Ткачи", "Вакуум-Эйдолоны", "Фазо-Сингуляры", "Тахион-Вид"]
	}
	var names: Array = prefix_map.get(archetype, ["Ксено-Вид"])
	var sp_name: String = "%s-%d" % [names[_rng.randi_range(0, names.size() - 1)], sp_id]

	var color_map := {
		"carbon": Color(0.22, 0.95, 0.58),
		"silicon": Color(0.82, 0.38, 1.0),
		"plasma": Color(1.0, 0.52, 0.14),
		"cyber": Color(0.12, 0.92, 1.0),
		"quantum": Color(0.68, 0.28, 1.0)
	}

	var initial_traits: Array[String] = []
	match archetype:
		"carbon":
			initial_traits.append("carbon_cellular")
		"silicon":
			initial_traits.append("silicon_crystalline")
		"plasma":
			initial_traits.append("plasma_magnetic_body")
		"cyber":
			initial_traits.append("cybernetic_assimilation")
			initial_traits.append("prefrontal_cortex")
		"quantum":
			initial_traits.append("quantum_phase_shift")

	if b_asset != null:
		for bt in b_asset.spawn_trait_subspecies:
			if not initial_traits.has(bt):
				initial_traits.append(bt)

	var is_sapient: bool = initial_traits.has("prefrontal_cortex") or initial_traits.has("cybernetic_assimilation")

	var sp_record := {
		"id": sp_id,
		"name": sp_name,
		"archetype": archetype,
		"generation": 1,
		"is_sapient": is_sapient,
		"population": 35,
		"traits": initial_traits,
		"home_tile": tile_idx,
		"biome_origin": t["biome_id"],
		"color": color_map.get(archetype, Color.AQUA)
	}
	subspecies_map[sp_id] = sp_record
	t["subspecies_id"] = sp_id

	# Спавним отряд живых пиксельных человечков этого вида на карте!
	for _u in range(8):
		_spawn_actor_unit(sp_id, tile_idx, -1)

	_log_event(
		"Зародился новый вид «%s» (%s) на острове биома «%s»." % [sp_name, archetype.to_upper(), b_asset.title if b_asset else t["biome_id"]],
		"life",
		sp_record["color"]
	)

	if is_sapient:
		_uplift_subspecies_and_found_city(sp_id, tile_idx)

	return sp_id


func _uplift_subspecies_and_found_city(sp_id: int, tile_idx: int) -> int:
	if not subspecies_map.has(sp_id):
		return -1
	var sp: Dictionary = subspecies_map[sp_id]
	sp["is_sapient"] = true
	var traits: Array = sp["traits"]
	if not traits.has("prefrontal_cortex"):
		traits.append("prefrontal_cortex")

	var t: Dictionary = tiles[tile_idx]
	if float(t["elevation"]) < 0.05:
		t["elevation"] = 0.14

	if int(t["city_id"]) != -1 and cities_map.has(int(t["city_id"])):
		var existing_city: Dictionary = cities_map[int(t["city_id"])]
		existing_city["population"] = float(existing_city["population"]) + 25.0
		existing_city["kardashev_level"] = minf(3.0, float(existing_city["kardashev_level"]) + 0.08)
		for _u in range(4):
			_spawn_actor_unit(sp_id, tile_idx, int(existing_city["id"]))
		return int(existing_city["id"])

	var cult_id: int = _next_meta_id
	_next_meta_id += 1
	var b_asset: SandboxAssetScript.BiomeAsset = assets.biomes.get(t["biome_id"])

	var layout_choices := ["rings", "honeycomb", "monolith_mesh", "fractal"]
	var chosen_layout: String = layout_choices[cult_id % layout_choices.size()]
	var c_traits: Array[String] = ["layout_" + chosen_layout]
	if b_asset != null:
		for ct in b_asset.spawn_trait_culture:
			if not c_traits.has(ct):
				c_traits.append(ct)

	var ethos_list := assets.get_all_ethos_traits()
	var assigned_ethos_id: String = "ethos_scientific"
	if not ethos_list.is_empty():
		assigned_ethos_id = ethos_list[sp_id % ethos_list.size()].id
	if not c_traits.has(assigned_ethos_id):
		c_traits.append(assigned_ethos_id)

	var culture_rec := {
		"id": cult_id,
		"name": "Орден %s" % sp["name"],
		"subspecies_id": sp_id,
		"layout": chosen_layout,
		"traits": c_traits,
		"ethos_id": assigned_ethos_id,
		"discovered_theories_count": 0,
		"science_points": 0.0,
		"color": sp["color"]
	}
	cultures_map[cult_id] = culture_rec

	var city_id: int = _next_meta_id
	_next_meta_id += 1

	var city_names := ["Нова-Аксиома", "Гелиос-Купол", "Квантум-Шпиль", "Крио-Цитадель", "Сингуляр-Град", "Орбита-Прайм", "Апейрон", "Гиперион"]
	var c_name: String = "%s-%d" % [city_names[city_id % city_names.size()], cities_map.size() + 1]

	var claimed: Array[int] = [tile_idx]
	var claimed_zones: Array[int] = []
	claimed_zones.append_array(_claim_zones_for_tile(city_id, tile_idx))
	for nbr in t["neighbors"]:
		if int(tiles[nbr]["city_id"]) == -1:
			if float(tiles[nbr]["elevation"]) < 0.02:
				tiles[nbr]["elevation"] = 0.08
			tiles[nbr]["city_id"] = city_id
			tiles[nbr]["subspecies_id"] = sp_id
			claimed.append(nbr)
			claimed_zones.append_array(_claim_zones_for_tile(city_id, nbr))
			if claimed.size() >= 5:
				break
	t["city_id"] = city_id

	var city_rec := {
		"id": city_id,
		"name": c_name,
		"subspecies_id": sp_id,
		"culture_id": cult_id,
		"center_tile": tile_idx,
		"map_pos": t["map_pos"],
		"dir": t["dir"],
		"claimed_tiles": claimed,
		"claimed_zones": claimed_zones,
		"storage": {"wood": 25, "minerals": 20, "food": 35},
		"population": 28.0,
		"kardashev_level": 0.60,
		"science_tier": 1,
		"buildings": {"order_bio_dome": 1},
		"building_instances": [],
		"orbital_drones": 2,
		"active_plot_id": -1,
		"active_diplomatic_plot_id": -1,
		"shielded": false,
		"color": sp["color"],
		"ethos_id": assigned_ethos_id,
		"kingdom_id": city_id,
		"parent_city_id": -1,
		"internal_cohesion": 0.90,
		"council": {
			"leader_name": "%s-%d" % [sp["name"], city_id],
			"title": "Архитектор Поля",
			"trait": assigned_ethos_id,
			"term_years": 0.0
		}
	}
	_rebuild_city_2d_instances(city_rec)
	cities_map[city_id] = city_rec

	for other_id in cities_map.keys():
		if other_id != city_id:
			_ensure_diplomacy_relation(city_id, other_id)

	# Привязываем существующих юнитов этого вида к городу и спавним новых горожан
	for a in actors:
		if int(a["subspecies_id"]) == sp_id and int(a["city_id"]) == -1:
			a["city_id"] = city_id
	for _u in range(6):
		_spawn_actor_unit(sp_id, tile_idx, city_id)

	_log_event(
		"Разум пробудился! Вид «%s» основал научный полис «%s» (планировка: %s)." % [sp["name"], c_name, chosen_layout],
		"uplift",
		Color(1.0, 0.92, 0.35)
	)
	request_dirty_tiles_update(claimed)
	planet_surface_changed.emit()
	city_structures_changed.emit()
	return city_id


func _tick_subspecies_evolution() -> void:
	for sp_id in subspecies_map.keys():
		var sp: Dictionary = subspecies_map[sp_id]
		var home_idx: int = int(sp["home_tile"])
		var t: Dictionary = tiles[home_idx]
		var time_mult: float = float(t["time_scale_mult"])
		var b_asset: SandboxAssetScript.BiomeAsset = assets.biomes.get(t["biome_id"])

		if active_world_laws.get("law_accelerated_evolution", true) and b_asset != null:
			var mut_chance: float = (0.12 + float(t["radiation"]) * 0.25) * minf(time_mult, 8.0) * get_world_constant("mutation_rate_multiplier")
			if _rng.randf() < mut_chance:
				for evo_trait in b_asset.evolution_trait_subspecies:
					var tr_list: Array = sp["traits"]
					if not tr_list.has(evo_trait):
						tr_list.append(evo_trait)
						sp["generation"] = int(sp["generation"]) + 1
						var tr_asset: SandboxAssetScript.SubspeciesTraitAsset = assets.subspecies_traits.get(evo_trait)
						var tr_title: String = tr_asset.title if tr_asset else evo_trait
						_log_event(
							"Эволюция вида «%s» (Поколение %d): приобретена черта «%s» под влиянием биома «%s»!" % [sp["name"], sp["generation"], tr_title, b_asset.title],
							"mutation",
							Color(0.85, 0.45, 1.0)
						)
						if tr_asset != null and tr_asset.grants_sapience and not bool(sp["is_sapient"]):
							_uplift_subspecies_and_found_city(sp_id, home_idx)
						break


# ==============================================================================
# 4. АВТО-СТРОИТЕЛЬСТВО ГОРОДОВ БЕЗ КОНВЕЙЕРОВ (BuildOrderLibrary)
# ==============================================================================
func _tick_city_build_orders(dt: float) -> void:
	var total_m_rate: float = 2.0
	var total_e_rate: float = 4.0
	var total_c_rate: float = 1.5
	var structures_changed := false

	for city_id in cities_map.keys():
		var city: Dictionary = cities_map[city_id]
		var center_tile: Dictionary = tiles[int(city["center_tile"])]
		var time_mult: float = float(center_tile["time_scale_mult"])
		var b_asset: SandboxAssetScript.BiomeAsset = assets.biomes.get(center_tile["biome_id"])
		var sp: Dictionary = subspecies_map.get(int(city["subspecies_id"]), {})
		var cult: Dictionary = cultures_map.get(int(city["culture_id"]), {})

		var pop_mult: float = 1.0
		var e_mult: float = (b_asset.energy_yield if b_asset else 1.0) * codex_energy_mult
		var c_mult: float = (b_asset.compute_yield if b_asset else 1.0) * codex_compute_mult
		var m_mult: float = (b_asset.matter_yield if b_asset else 1.0) * codex_matter_mult
		var build_speed: float = 1.0

		for tr_id in sp.get("traits", []):
			var st: SandboxAssetScript.SubspeciesTraitAsset = assets.subspecies_traits.get(tr_id)
			if st != null:
				pop_mult += (st.pop_growth_mult - 1.0) * 0.5
				e_mult += (st.energy_output_mult - 1.0) * 0.6
				c_mult += (st.compute_output_mult - 1.0) * 0.6

		for ct_id in cult.get("traits", []):
			var ct = assets.culture_traits.get(ct_id)
			if ct is SandboxAssetScript.CultureTraitAsset:
				c_mult += (ct.science_speed_mult - 1.0) * 0.7
				build_speed += (ct.build_speed_mult - 1.0) * 0.7
			elif ct is SandboxAssetScript.CulturalEthosAsset:
				c_mult += (ct.science_focus - 1.0) * 0.5
				build_speed += (ct.expansion_drive - 1.0) * 0.3

		var pop: float = float(city["population"])
		pop = minf(pop + (0.85 * pop_mult * time_mult * dt), 950.0)
		city["population"] = pop
		if not sp.is_empty():
			sp["population"] = int(pop)

		# Если в городе мало видимых человечков на карте — добавляем новых граждан
		if actors.size() < MAX_ACTORS and _rng.randf() < 0.30:
			var claimed_arr: Array = city["claimed_tiles"]
			var spawn_t: int = int(claimed_arr[_rng.randi_range(0, claimed_arr.size() - 1)])
			_spawn_actor_unit(int(city["subspecies_id"]), spawn_t, int(city["id"]))

		var b_dict: Dictionary = city["buildings"]
		var city_m: float = 1.5
		var city_e: float = 2.0
		var city_c: float = 1.2
		for order_id in b_dict.keys():
			var cnt: int = int(b_dict[order_id])
			var bo: SandboxAssetScript.BuildOrderAsset = assets.build_orders.get(order_id)
			if bo != null and cnt > 0:
				city_m += bo.matter_prod * float(cnt)
				city_e += bo.energy_prod * float(cnt)
				city_c += bo.compute_prod * float(cnt)

		city_m *= m_mult * sqrt(time_mult)
		city_e *= e_mult * sqrt(time_mult)
		city_c *= c_mult * time_mult

		total_m_rate += city_m
		total_e_rate += city_e
		total_c_rate += city_c

		var chosen_order: SandboxAssetScript.BuildOrderAsset = _select_next_build_order(city)
		if chosen_order != null:
			var cost_m: float = chosen_order.required_matter / maxf(1.0, build_speed * 0.5)
			var cost_e: float = chosen_order.required_energy / maxf(1.0, build_speed * 0.5)
			if matter_stock >= cost_m and energy_gw >= cost_e:
				matter_stock -= cost_m * 0.65
				var prev_cnt: int = int(b_dict.get(chosen_order.id, 0))
				b_dict[chosen_order.id] = prev_cnt + 1
				city["science_tier"] = maxi(int(city["science_tier"]), chosen_order.tier)
				city["kardashev_level"] = minf(3.0, float(city["kardashev_level"]) + 0.06 * float(chosen_order.tier))

				if chosen_order.spawns_orbital_drones > 0 and active_world_laws.get("law_autonomous_megastructures", true):
					city["orbital_drones"] = int(city["orbital_drones"]) + chosen_order.spawns_orbital_drones
					_add_sails_to_dyson_swarm(chosen_order.spawns_orbital_drones, city["color"])
					rocket_launched.emit(city["map_pos"], city["color"], city["name"])

				_expand_city_territory(city)
				_rebuild_city_2d_instances(city)
				structures_changed = true

				_log_event(
					"Полис «%s» возвёл «%s» (Уровень Кардашёва: %.2f)." % [city["name"], chosen_order.title, float(city["kardashev_level"])],
					"build",
					Color(0.35, 0.95, 0.78)
				)

	var dyson_e: float = get_dyson_energy_output()
	total_e_rate += dyson_e
	var dyson_c: float = get_dyson_compute_output()
	total_c_rate += dyson_c

	matter_rate = total_m_rate
	energy_rate = total_e_rate
	compute_rate = total_c_rate

	matter_stock += matter_rate * dt
	energy_gw += energy_rate * dt
	compute_pflops += compute_rate * dt

	if structures_changed:
		city_structures_changed.emit()
	telemetry_updated.emit()


func _select_next_build_order(city: Dictionary) -> SandboxAssetScript.BuildOrderAsset:
	var b_dict: Dictionary = city["buildings"]
	var pop: float = float(city["population"])
	var sci_tier: int = int(city["science_tier"])

	for bo in assets.build_order_list:
		var cur_cnt: int = int(b_dict.get(bo.id, 0))
		if cur_cnt >= bo.max_per_city:
			continue
		if pop < float(bo.required_pop) * 0.75:
			continue
		if sci_tier + 1 < bo.required_science_tier:
			continue
		var reqs_ok := true
		for req_id in bo.required_orders:
			if int(b_dict.get(req_id, 0)) <= 0:
				reqs_ok = false
				break
		if reqs_ok:
			return bo
	return null


func _expand_city_territory(city: Dictionary) -> void:
	var claimed: Array = city["claimed_tiles"]
	if claimed.size() >= 22:
		return
	for t_idx in claimed:
		var nbrs: PackedInt32Array = tiles[int(t_idx)]["neighbors"]
		for n_idx in nbrs:
			if int(tiles[n_idx]["city_id"]) == -1 and float(tiles[n_idx]["elevation"]) >= -0.04:
				var cid: int = int(city["id"])
				tiles[n_idx]["city_id"] = cid
				tiles[n_idx]["subspecies_id"] = int(city["subspecies_id"])
				claimed.append(n_idx)
				if not city.has("claimed_zones"):
					city["claimed_zones"] = []
				(city["claimed_zones"] as Array).append_array(_claim_zones_for_tile(cid, n_idx))
				request_dirty_tiles_update([n_idx])
				planet_surface_changed.emit()
				return


func _rebuild_city_2d_instances(city: Dictionary) -> void:
	var prev_instances: Array = city.get("building_instances", [])
	var prev_count: int = prev_instances.size()
	var instances: Array[Dictionary] = []
	var center_idx: int = int(city["center_tile"])
	var center_pos: Vector2 = tiles[center_idx]["map_pos"]
	var center_dir: Vector3 = tiles[center_idx]["dir"]
	var cult: Dictionary = cultures_map.get(int(city["culture_id"]), {})
	var layout: String = cult.get("layout", "rings")
	var b_dict: Dictionary = city["buildings"]
	var claimed: Array = city["claimed_tiles"]

	var slot_idx: int = 0
	for order_id in b_dict.keys():
		var cnt: int = int(b_dict[order_id])
		var bo: SandboxAssetScript.BuildOrderAsset = assets.build_orders.get(order_id)
		if bo == null:
			continue
		for _k in range(cnt):
			var offset_px := _layout_offset_2d_pixels(layout, slot_idx)
			var tile_anchor: Vector2 = center_pos
			if not claimed.is_empty():
				tile_anchor = tiles[int(claimed[slot_idx % claimed.size()])]["map_pos"]
			var pos_2d: Vector2 = (tile_anchor.lerp(center_pos, 0.35) + offset_px * 0.45).clamp(
				Vector2(28.0, 28.0), Vector2(MAP_PIXEL_W - 28.0, MAP_PIXEL_H - 28.0)
			)
			var spring_val: float = 1.0
			if slot_idx < prev_count:
				spring_val = float(prev_instances[slot_idx].get("spawn_spring", 1.0))
			elif prev_count > 0:
				spring_val = 0.08 # Новое здание «выпрыгивает» из земли с пружинящим scale.y (Game Juice из WorldBox)
			instances.append({
				"map_pos": pos_2d,
				"dir": center_dir,
				"tier": bo.tier,
				"title": bo.title,
				"archetype": bo.visual_archetype,
				"is_orbital": bo.is_orbital,
				"color": city["color"],
				"spawn_spring": spring_val,
				"hit_shake": 0.0
			})
			slot_idx += 1

	city["building_instances"] = instances
	_carve_city_roads_and_fields(city)


func _layout_offset_2d_pixels(layout: String, idx: int) -> Vector2:
	if idx == 0:
		return Vector2.ZERO
	var ring: int = 1 + int(idx / 6)
	var angle: float = float(idx % 6) * (TAU / 6.0)
	match layout:
		"honeycomb":
			angle += float(ring % 2) * (PI / 6.0)
			return Vector2(cos(angle), sin(angle)) * (26.0 * float(ring))
		"monolith_mesh":
			var gx: int = (idx % 5) - 2
			var gz: int = int(idx / 5) - 1
			return Vector2(float(gx) * 24.0, float(gz) * 20.0)
		"fractal":
			var f_ang: float = float(idx) * 2.3999632
			var f_rad: float = 18.0 * sqrt(float(idx))
			return Vector2(cos(f_ang), sin(f_ang)) * f_rad
		_:
			return Vector2(cos(angle), sin(angle)) * (25.0 * float(ring))


# ==============================================================================
# 5. НАУЧНЫЕ ЗАМЫСЛЫ (PLOTS) И ГЕНЕРАТОР БЕСКОНЕЧНОЙ НАУКИ
# ==============================================================================
func _tick_plots_and_infinite_science(dt: float) -> void:
	for city_id in cities_map.keys():
		var city: Dictionary = cities_map[city_id]
		var center_tile: Dictionary = tiles[int(city["center_tile"])]
		var time_mult: float = float(center_tile["time_scale_mult"])
		var cult: Dictionary = cultures_map.get(int(city["culture_id"]), {})

		var plot_id: int = int(city["active_plot_id"])
		if plot_id == -1 or not active_plots.has(plot_id):
			_try_start_plot_for_city(city, cult)
		else:
			var plot: Dictionary = active_plots[plot_id]
			var p_asset: SandboxAssetScript.PlotAsset = assets.plots.get(plot["asset_id"])
			if p_asset != null:
				var sci_speed: float = (1.5 + float(city["kardashev_level"]) * 3.0) * time_mult * dt * get_world_constant("light_speed")
				plot["progress"] = float(plot["progress"]) + sci_speed
				if float(plot["progress"]) >= float(plot["progress_needed"]):
					_complete_plot(city, cult, plot, p_asset)

		if active_world_laws.get("law_infinite_combinatorial_science", true) and not cult.is_empty():
			var pts: float = float(cult.get("science_points", 0.0)) + (0.8 + float(city["science_tier"]) * 0.9) * minf(time_mult, 10.0) * dt * get_world_constant("light_speed")
			var threshold: float = 85.0 + float(codex_theories.size()) * 40.0
			if pts >= threshold:
				cult["science_points"] = 0.0
				_synthesize_infinite_theory(city, cult, center_tile)
			else:
				cult["science_points"] = pts


func _try_start_plot_for_city(city: Dictionary, cult: Dictionary) -> void:
	var c_traits: Array = cult.get("traits", [])
	var k_lvl: float = float(city["kardashev_level"])

	for p_asset in assets.plot_list:
		if k_lvl + 0.25 < p_asset.min_kardashev:
			continue
		if p_asset.reward_culture_trait != "" and c_traits.has(p_asset.reward_culture_trait):
			continue
		var new_plot_id: int = _next_meta_id
		_next_meta_id += 1
		var plot_rec := {
			"id": new_plot_id,
			"asset_id": p_asset.id,
			"title": p_asset.title,
			"city_id": city["id"],
			"city_name": city["name"],
			"progress": 0.0,
			"progress_needed": p_asset.progress_needed,
			"plot_type": p_asset.plot_type
		}
		active_plots[new_plot_id] = plot_rec
		city["active_plot_id"] = new_plot_id
		_log_event(
			"Учёные полиса «%s» начали глобальный замысел: «%s»." % [city["name"], p_asset.title],
			"plot_start",
			Color(0.45, 0.85, 1.0)
		)
		return


func _complete_plot(city: Dictionary, cult: Dictionary, plot: Dictionary, p_asset: SandboxAssetScript.PlotAsset) -> void:
	active_plots.erase(int(plot["id"]))
	city["active_plot_id"] = -1

	if active_world_laws.get("law_quantum_anomaly_hazards", true) and p_asset.anomaly_risk > 0.20:
		if _rng.randf() < p_asset.anomaly_risk:
			var t_idx: int = int(city["center_tile"])
			tiles[t_idx]["biome_id"] = "biome_singularity_swamp"
			_spawn_field_lens_internal(t_idx, 0.26, "singularity", 8.0, 0.25, 60.0, Color(0.85, 0.2, 1.0))
			_log_event(
				"АНОМАЛИЯ ЭКСПЕРИМЕНТА! Опыт «%s» в полисе «%s» пробил метрику вакуума — родилась зона Квантовой Сингулярности (+300%% к науке)!" % [p_asset.title, city["name"]],
				"anomaly",
				Color(1.0, 0.35, 0.85)
			)
			request_dirty_tiles_update([t_idx])
			planet_surface_changed.emit()

	if p_asset.reward_culture_trait != "":
		var c_traits: Array = cult["traits"]
		if not c_traits.has(p_asset.reward_culture_trait):
			c_traits.append(p_asset.reward_culture_trait)

	if p_asset.reward_god_power_id != "":
		unlocked_god_powers[p_asset.reward_god_power_id] = true

	if p_asset.spawns_dyson_ring:
		_create_dyson_ring(60, city["color"])
		city["orbital_drones"] = int(city["orbital_drones"]) + 30
		rocket_launched.emit(city["map_pos"], city["color"], city["name"])

	city["kardashev_level"] = minf(3.0, float(city["kardashev_level"]) + 0.18)
	city["science_tier"] = int(city["science_tier"]) + 1

	_log_event(
		"ПРОРЫВ ЦИВИЛИЗАЦИИ! Полис «%s» завершил «%s» → открыта парадигма «%s» (Кардашёв %.2f)!" % [
			city["name"], p_asset.title, p_asset.reward_culture_trait, float(city["kardashev_level"])
		],
		"breakthrough",
		Color(1.0, 0.88, 0.25)
	)
	_synthesize_infinite_theory(city, cult, tiles[int(city["center_tile"])])


func _synthesize_infinite_theory(city: Dictionary, cult: Dictionary, tile: Dictionary) -> Dictionary:
	var tier_num: int = codex_theories.size() + 1
	var b_asset: SandboxAssetScript.BiomeAsset = assets.biomes.get(tile["biome_id"])
	var prefix_list := [
		"Нелокальная", "Когерентная", "Тороидальная", "Тахионная",
		"Сверхтекучая", "Метрическая", "Субатомная", "Голографическая",
		"Антиэнтропийная", "Гравитонно-Резонансная"
	]
	var core_list := [
		"Электродинамика Короны", "Решётка Констант", "Сингулярная Индукция",
		"Термодинамика Вакуума", "Квантовая Телепортация Массы", "Нуклеосинтез Полей",
		"Фрактальная Ноосфера", "Хроно-Симметрия", "Астроинженерия Матрёшки"
	]
	var t_name: String = "%s %s (Тир %d)" % [
		prefix_list[tier_num % prefix_list.size()],
		core_list[(tier_num * 3) % core_list.size()],
		tier_num
	]

	var bonus_types := ["energy", "compute", "matter"]
	var b_type: String = bonus_types[tier_num % bonus_types.size()]
	var b_val: float = 0.12 + float(tier_num) * 0.02

	match b_type:
		"energy":
			codex_energy_mult += b_val
		"compute":
			codex_compute_mult += b_val
		"matter":
			codex_matter_mult += b_val

	var formula_str: String = "ΔΦ_%d = %.2f · (%s ⊗ G=%.2f · T×%.0f)" % [
		tier_num,
		1.0 + b_val,
		b_asset.title if b_asset else "Космос",
		float(tile["gravity_mult"]),
		float(tile["time_scale_mult"])
	]

	var theory := {
		"id": "theory_%d" % tier_num,
		"title": t_name,
		"formula": formula_str,
		"discoverer_city": city["name"],
		"tier": tier_num,
		"bonus_type": b_type,
		"bonus_val": b_val,
		"cycle": chrono_cycle
	}
	codex_theories.append(theory)
	cult["discovered_theories_count"] = int(cult.get("discovered_theories_count", 0)) + 1

	_log_event(
		"НОВЫЙ ЗАКОН ФИЗИКИ В КОДЕКСЕ: «%s» [%s] открыт в «%s» (+%d%% к %s навсегда)!" % [
			t_name, formula_str, city["name"], int(b_val * 100.0), b_type.to_upper()
		],
		"science",
		Color(0.25, 1.0, 0.92)
	)
	return theory


# ==============================================================================
# 6. ОРБИТАЛЬНЫЙ РОЙ ДАЙСОНА И АСТРОФИЗИКА ЗВЕЗДЫ
# ==============================================================================
func _create_dyson_ring(sails: int, ring_color: Color) -> void:
	if dyson_rings.size() >= 12:
		var r_idx: int = dyson_rings.size() - 1
		dyson_rings[r_idx]["sails_count"] = int(dyson_rings[r_idx]["sails_count"]) + sails
		total_dyson_sails += sails
		dyson_swarm_changed.emit()
		return

	var idx: int = dyson_rings.size()
	var ring := {
		"index": idx,
		"radius": 5.2 + float(idx) * 1.15,
		"radius_2d": 115.0 + float(idx) * 34.0,
		"tilt_x": deg_to_rad(-35.0 + float(idx * 23 % 70)),
		"tilt_z": deg_to_rad(-25.0 + float(idx * 31 % 50)),
		"speed": 0.35 / (1.0 + float(idx) * 0.16),
		"sails_count": sails,
		"color": ring_color
	}
	dyson_rings.append(ring)
	total_dyson_sails += sails
	dyson_swarm_changed.emit()


func _add_sails_to_dyson_swarm(sails: int, col: Color) -> void:
	if dyson_rings.is_empty():
		_create_dyson_ring(sails, col)
		return
	var target_ring: Dictionary = dyson_rings[dyson_rings.size() - 1]
	if int(target_ring["sails_count"]) >= 160 and dyson_rings.size() < 10:
		_create_dyson_ring(sails, col)
	else:
		target_ring["sails_count"] = int(target_ring["sails_count"]) + sails
		total_dyson_sails += sails
		dyson_swarm_changed.emit()


func _tick_dyson_swarm_and_star(dt: float) -> void:
	if active_world_laws.get("law_stellar_instability", true):
		var load_ratio: float = clampf(get_dyson_eclipse_ratio(), 0.0, 1.0)
		star_stability = clampf(star_stability - load_ratio * 0.005 * dt, 0.15, 1.0)

	_advance_dyson_construction_step(dt)


func _advance_dyson_construction_step(dt: float) -> void:
	_step_dyson_megastructure_construction(dt)


func _step_dyson_megastructure_construction(dt: float) -> void:
	if not dyson_construction_enabled:
		dyson_is_constructing = false
		return

	match dyson_stage:
		1:
			dyson_is_constructing = false
			dyson_stage_progress = clampf(float(total_dyson_sails) / 100.0, 0.0, 1.0)
			if (total_dyson_sails >= 100 and get_max_kardashev_level() >= 1.0) or total_dyson_sails >= 150:
				_advance_dyson_stage_internal(2)

		2:
			var req_m: float = 2.0 * dt * codex_matter_mult
			var req_e: float = 25.0
			if matter_stock >= req_m and energy_gw >= req_e:
				dyson_is_constructing = true
				matter_stock -= req_m
				var spd: float = 0.025 * (1.0 + float(cities_map.size()) * 0.10)
				dyson_stage_progress = clampf(dyson_stage_progress + spd * dt, 0.0, 1.0)
				dyson_ring_frame_segments = clampi(int(dyson_stage_progress * 12.0), 0, 12)
				if dyson_stage_progress >= 1.0 or total_dyson_sails >= 350:
					_advance_dyson_stage_internal(3)
			else:
				dyson_is_constructing = false

		3:
			var req_m: float = 3.5 * dt * codex_matter_mult
			var req_e: float = 50.0
			if matter_stock >= req_m and energy_gw >= req_e:
				dyson_is_constructing = true
				matter_stock -= req_m
				var spd: float = 0.018 * (1.0 + float(cities_map.size()) * 0.08)
				dyson_stage_progress = clampf(dyson_stage_progress + spd * dt, 0.0, 1.0)
				dyson_shell_active_segments = clampi(int(dyson_stage_progress * 60.0), 0, 60)
				if dyson_stage_progress >= 1.0 or total_dyson_sails >= 650:
					_advance_dyson_stage_internal(4)
			else:
				dyson_is_constructing = false

		4:
			var req_m: float = 5.0 * dt * codex_matter_mult
			var req_e: float = 80.0
			if matter_stock >= req_m and energy_gw >= req_e:
				dyson_is_constructing = true
				matter_stock -= req_m
				var spd: float = 0.012 * (1.0 + float(cities_map.size()) * 0.05)
				dyson_stage_progress = clampf(dyson_stage_progress + spd * dt, 0.0, 1.0)
				dyson_matrioshka_layers = clampi(1 + int(dyson_stage_progress * 2.0), 1, 3)
			else:
				dyson_is_constructing = false

	var segs: int = get_dyson_active_segments()
	if absf(dyson_stage_progress - _dyson_last_emitted_progress) >= 0.02 or segs != _dyson_last_emitted_segments:
		_dyson_last_emitted_progress = dyson_stage_progress
		_dyson_last_emitted_segments = segs
		dyson_visual_state_updated.emit(dyson_stage, dyson_stage_progress, segs)


func _advance_dyson_stage_internal(next_stage: int) -> void:
	if next_stage <= dyson_stage or next_stage > 4:
		return
	dyson_stage = next_stage
	dyson_stage_progress = 0.0

	match dyson_stage:
		2:
			dyson_ring_frame_segments = 0
		3:
			dyson_ring_frame_segments = 12
			dyson_shell_active_segments = 0
		4:
			dyson_ring_frame_segments = 12
			dyson_shell_active_segments = 60
			dyson_matrioshka_layers = 1

	var s_name: String = DYSON_STAGE_NAMES[dyson_stage]
	var cur_e: float = get_dyson_energy_output()
	var cur_segs: int = get_dyson_active_segments()

	_dyson_last_emitted_progress = 0.0
	_dyson_last_emitted_segments = cur_segs

	dyson_megastructure_stage_advanced.emit(dyson_stage, s_name, cur_e)
	dyson_visual_state_updated.emit(dyson_stage, 0.0, cur_segs)

	_log_event(
		"МЕГАСТРУКТУРА: Развёрнут Этап %d («%s»)! Текущая энергоотдача: %.1f ГВт." % [
			dyson_stage, s_name, cur_e
		],
		"cosmos",
		Color(1.0, 0.85, 0.3)
	)


func get_dyson_stage() -> int:
	return dyson_stage


func get_dyson_stage_name() -> String:
	return DYSON_STAGE_NAMES[dyson_stage]


func get_dyson_stage_progress() -> float:
	return dyson_stage_progress


func get_dyson_active_segments() -> int:
	match dyson_stage:
		1:
			return total_dyson_sails
		2:
			return dyson_ring_frame_segments
		3:
			return dyson_shell_active_segments
		4:
			return dyson_matrioshka_layers
		_:
			return 0


func get_dyson_energy_output() -> float:
	var base_sail_e: float = float(total_dyson_sails) * 0.85
	var bonus: float = 0.0
	match dyson_stage:
		1:
			bonus = 0.0
		2:
			bonus = 35.0 + dyson_stage_progress * 40.0
		3:
			bonus = 75.0 + float(dyson_shell_active_segments) * 4.5
		4:
			bonus = 350.0 + float(dyson_matrioshka_layers) * 150.0
	return (base_sail_e + bonus) * star_luminosity_mult * codex_energy_mult


func get_dyson_compute_output() -> float:
	if dyson_stage < 4:
		return 0.0
	return float(dyson_matrioshka_layers) * 60.0 * codex_compute_mult


func get_dyson_matter_drain_rate() -> float:
	if not dyson_construction_enabled or dyson_stage == 1 or dyson_stage_progress >= 1.0:
		return 0.0
	match dyson_stage:
		2:
			return 2.0 * codex_matter_mult
		3:
			return 3.5 * codex_matter_mult
		4:
			return 5.0 * codex_matter_mult
		_:
			return 0.0


func advance_dyson_stage(target_stage: int = -1) -> bool:
	var next_s: int = (dyson_stage + 1) if target_stage <= 0 else target_stage
	if next_s <= dyson_stage or next_s > 4:
		return false
	_advance_dyson_stage_internal(next_s)
	return true


func advance_dyson_stage_manual(target_stage: int = -1) -> bool:
	return advance_dyson_stage(target_stage)


func add_dyson_construction_progress(delta_progress: float) -> void:
	if delta_progress <= 0.0:
		return
	if dyson_stage == 1:
		var sails_add: int = maxi(10, int(delta_progress * 80.0))
		_add_sails_to_dyson_swarm(sails_add, star_color)
		if total_dyson_sails >= 100:
			_advance_dyson_stage_internal(2)
		return

	dyson_stage_progress += delta_progress
	match dyson_stage:
		2:
			dyson_ring_frame_segments = clampi(int(dyson_stage_progress * 12.0), 0, 12)
			if dyson_stage_progress >= 1.0:
				_advance_dyson_stage_internal(3)
		3:
			dyson_shell_active_segments = clampi(int(dyson_stage_progress * 60.0), 0, 60)
			if dyson_stage_progress >= 1.0:
				_advance_dyson_stage_internal(4)
		4:
			dyson_matrioshka_layers = clampi(1 + int(dyson_stage_progress * 2.0), 1, 3)
			dyson_stage_progress = clampf(dyson_stage_progress, 0.0, 1.0)


func get_dyson_eclipse_ratio() -> float:
	match dyson_stage:
		1:
			var sail_ratio: float = clampf(float(total_dyson_sails) / 800.0, 0.0, 1.0)
			return clampf(sail_ratio * 0.25, 0.0, 0.25)
		2:
			return clampf(0.25 + dyson_stage_progress * 0.15, 0.25, 0.40)
		3:
			return clampf(0.40 + (float(dyson_shell_active_segments) / 60.0) * 0.35, 0.40, 0.75)
		4:
			return clampf(0.75 + dyson_stage_progress * 0.23, 0.75, 0.98)
		_:
			return clampf(float(total_dyson_sails) / 800.0, 0.0, 1.0)


func get_max_kardashev_level() -> float:
	var max_k: float = 0.50
	for c_id in cities_map.keys():
		max_k = maxf(max_k, float(cities_map[c_id]["kardashev_level"]))
	var dyson_k: float = 1.0 + get_dyson_eclipse_ratio() * 1.8
	if dyson_stage == 4:
		dyson_k = maxf(dyson_k, 2.50 + float(dyson_matrioshka_layers) * 0.16)
	max_k = maxf(max_k, dyson_k)
	return clampf(max_k, 0.50, 3.00)


# ==============================================================================
# ПРИМЕНЕНИЕ БОЖЕСТВЕННЫХ СИЛ НА 2D-КАРТЕ (И ОБРАТНАЯ СОВМЕСТИМОСТЬ С DIR)
# ==============================================================================
func brush_radius_to_pixels(rad_norm: float) -> float:
	return clampf(rad_norm * 480.0, 36.0, 320.0)


func apply_god_power_to_tile(tile_idx: int, power_id: String, brush_radius: float = -1.0) -> Dictionary:
	return _apply_god_power_at_tile_internal(tile_idx, power_id, brush_radius)


func apply_god_power_to_world(power_id: String, target_param: Variant = null) -> Dictionary:
	var gp: SandboxAssetScript.GodPowerAsset = assets.god_powers.get(power_id)
	if gp == null:
		return {"ok": false, "reason": "unknown_power"}
	var center_pos := Vector2(MAP_PIXEL_W * 0.5, MAP_PIXEL_H * 0.5)
	if target_param is Vector2:
		center_pos = target_param
	elif target_param is int:
		center_pos = tiles[clampi(target_param, 0, TILE_COUNT - 1)]["map_pos"]
	var brush_rad: float = gp.default_brush_radius if gp.default_brush_radius > 0.0 else 0.25
	return apply_god_power_at_pos(center_pos, power_id, brush_rad)


func apply_god_power_at_pos(world_pos: Vector2, power_id: String, brush_radius: float = -1.0) -> Dictionary:
	var best_tile: int = find_closest_tile_2d(world_pos)
	return _apply_god_power_at_tile_internal(best_tile, power_id, brush_radius)


func apply_god_power_at_dir(u_dir: Vector3, power_id: String, brush_radius: float = -1.0) -> Dictionary:
	var best_tile: int = find_closest_tile(u_dir)
	return _apply_god_power_at_tile_internal(best_tile, power_id, brush_radius)


func _apply_god_power_at_tile_internal(best_tile: int, power_id: String, brush_radius: float = -1.0) -> Dictionary:
	var gp: SandboxAssetScript.GodPowerAsset = assets.god_powers.get(power_id)
	if gp == null:
		return {"ok": false, "reason": "unknown_power"}

	var center_t: Dictionary = tiles[clampi(best_tile, 0, TILE_COUNT - 1)]
	var center_pos: Vector2 = center_t["map_pos"]
	var center_dir: Vector3 = center_t["dir"]
	var rad_norm: float = brush_radius if brush_radius > 0.0 else gp.default_brush_radius
	var rad_px: float = brush_radius_to_pixels(rad_norm)

	var affected_tiles: Array[int] = []
	for i in range(TILE_COUNT):
		var d_px: float = center_pos.distance_to(tiles[i]["map_pos"])
		if d_px <= rad_px:
			affected_tiles.append(i)
	if affected_tiles.is_empty():
		affected_tiles.append(best_tile)

	matter_stock = maxf(0.0, matter_stock + gp.matter_injection * codex_matter_mult)
	energy_gw = maxf(0.0, energy_gw + gp.energy_injection * codex_energy_mult)

	# Проверка алхимических реакций на затронутых тайлах (F6)
	var alchemical_tiles: Dictionary = {}
	for idx in affected_tiles:
		var prev_biome: String = tiles[idx]["biome_id"]
		var rx := evaluate_alchemical_reaction(power_id, prev_biome)
		if rx == null and gp.target_biome_id != "":
			rx = evaluate_alchemical_reaction(gp.target_biome_id, prev_biome)
		if rx != null:
			alchemical_tiles[idx] = true
			tiles[idx]["biome_id"] = rx.output_biome_id
			tiles[idx]["temperature_c"] = rx.temp_result_c
			tiles[idx]["elevation"] = clampf(float(tiles[idx]["elevation"]) + rx.elevation_delta, -0.38, 0.46)
			tiles[idx]["radiation"] = clampf(float(tiles[idx]["radiation"]) + rx.radiation_delta, 0.0, 1.0)
			tiles[idx]["flora"] = _pick_flora_for_biome(rx.output_biome_id, float(tiles[idx]["elevation"]), idx)
			matter_stock += rx.matter_yield * codex_matter_mult
			energy_gw += rx.energy_yield * codex_energy_mult
			shockwave_triggered.emit(tiles[idx]["map_pos"], 45.0, gp.beam_color)
			sfx_requested.emit(rx.sfx_id, tiles[idx]["map_pos"], 1.0, 1.0)
			_log_event("Алхимическая Реакция: «%s» на тайле #%d!" % [rx.reaction_name, idx], "alchemy", gp.beam_color)

	var result := {
		"ok": true,
		"power_id": power_id,
		"center_tile": best_tile,
		"affected_count": affected_tiles.size()
	}

	match gp.power_type:
		"brush_tile":
			for idx in affected_tiles:
				if alchemical_tiles.has(idx):
					continue
				var t: Dictionary = tiles[idx]
				if gp.target_biome_id != "":
					t["biome_id"] = gp.target_biome_id
				t["temperature_c"] = clampf(float(t["temperature_c"]) + gp.temp_delta_c, -240.0, 1200.0)
				# Поднимаем сушу для наземных биомов или вырываем кратер при ударе метеорита
				var new_elev: float = clampf(float(t["elevation"]) + gp.height_delta, -0.38, 0.46)
				if gp.target_biome_id != "" and gp.height_delta >= -0.02 and new_elev < 0.04:
					new_elev = 0.10
				t["elevation"] = new_elev
				t["radiation"] = clampf(float(t["radiation"]) + gp.radiation_delta, 0.0, 1.0)
				t["flora"] = _pick_flora_for_biome(t["biome_id"], new_elev, idx)
			_log_event(
				"Кисть Бога: «%s» изменила %d тайлов 2D-карты." % [gp.title, affected_tiles.size()],
				"god_alchemy",
				gp.beam_color
			)
			request_dirty_circle_update(center_pos, rad_px)
			planet_surface_changed.emit()

		"spawn_life":
			var sp_id := _spawn_subspecies_at_tile(best_tile, gp.species_archetype)
			result["subspecies_id"] = sp_id
			request_dirty_tiles_update([best_tile])
			planet_surface_changed.emit()

		"uplift_ray":
			if power_id == "power_monolith_uplift":
				var target_sp_id: int = int(tiles[best_tile]["subspecies_id"])
				if target_sp_id == -1:
					var arch := _archetype_for_biome(tiles[best_tile]["biome_id"])
					target_sp_id = _spawn_subspecies_at_tile(best_tile, arch)
				var city_id := _uplift_subspecies_and_found_city(target_sp_id, best_tile)
				result["city_id"] = city_id
			elif power_id == "power_omega_mutation":
				for idx in affected_tiles:
					var s_id: int = int(tiles[idx]["subspecies_id"])
					if s_id != -1 and subspecies_map.has(s_id):
						var sp: Dictionary = subspecies_map[s_id]
						sp["generation"] = int(sp["generation"]) + 1
						var r_trait: SandboxAssetScript.SubspeciesTraitAsset = assets.subspecies_trait_list[_rng.randi_range(0, assets.subspecies_trait_list.size() - 1)]
						if not sp["traits"].has(r_trait.id):
							sp["traits"].append(r_trait.id)
					var c_id: int = int(tiles[idx]["city_id"])
					if c_id != -1 and cities_map.has(c_id):
						var city: Dictionary = cities_map[c_id]
						var p_id: int = int(city["active_plot_id"])
						if p_id != -1 and active_plots.has(p_id):
							active_plots[p_id]["progress"] = float(active_plots[p_id]["progress_needed"])
				_tick_plots_and_infinite_science(0.1)
				_log_event("Омега-Ливень вызвал скачок мутаций у пиксельных существ и эврику в городах!", "mutation", gp.beam_color)

		"place_lens":
			if gp.target_biome_id != "":
				for idx in affected_tiles:
					tiles[idx]["biome_id"] = gp.target_biome_id
					if float(tiles[idx]["elevation"]) < 0.02:
						tiles[idx]["elevation"] = 0.08
					tiles[idx]["flora"] = _pick_flora_for_biome(gp.target_biome_id, float(tiles[idx]["elevation"]), idx)
				request_dirty_tiles_update(affected_tiles)
				planet_surface_changed.emit()
			_spawn_field_lens_internal(best_tile, rad_norm, gp.lens_type, gp.lens_time_mult, gp.lens_grav_mult, gp.lens_duration, gp.beam_color)
			_log_event(
				"Установлена 2D-Линза Физики: «%s» (Время ×%.0f, Гравитация %.2fG)." % [gp.title, gp.lens_time_mult, gp.lens_grav_mult],
				"lens",
				gp.beam_color
			)

		"cataclysm", "transmutation":
			match power_id:
				"power_meteor_strike":
					shockwave_triggered.emit(center_pos, rad_px * 1.5, gp.shockwave_color)
					sfx_requested.emit("sfx_meteor_impact", center_pos, 0.8, 4.0)
					tiles[best_tile]["elevation"] = -0.28
					tiles[best_tile]["biome_id"] = "biome_actinide_wasteland"
					for idx in affected_tiles:
						tiles[idx]["temperature_c"] = clampf(float(tiles[idx]["temperature_c"]) + gp.temp_delta_c, -240.0, 1200.0)
						tiles[idx]["elevation"] = clampf(float(tiles[idx]["elevation"]) - 0.15, -0.38, 0.46)
						tiles[idx]["radiation"] = clampf(float(tiles[idx]["radiation"]) + 0.35, 0.0, 1.0)
						tiles[idx]["flora"] = _pick_flora_for_biome(tiles[idx]["biome_id"], float(tiles[idx]["elevation"]), idx)
					damage_city_buildings_in_radius(center_pos, rad_px, gp.building_damage)
					_damage_actors_in_radius(center_pos, rad_px, gp.actor_damage, "meteor_strike")
					request_dirty_circle_update(center_pos, rad_px)
					planet_surface_changed.emit()

				"power_antimatter_lance":
					shockwave_triggered.emit(center_pos, rad_px * 0.8, gp.shockwave_color)
					sfx_requested.emit("sfx_antimatter_lance", center_pos, 1.2, 5.0)
					tiles[best_tile]["elevation"] = -0.35
					tiles[best_tile]["biome_id"] = "biome_singularity_swamp"
					tiles[best_tile]["flora"] = _pick_flora_for_biome("biome_singularity_swamp", -0.35, best_tile)
					damage_city_buildings_in_radius(center_pos, rad_px, 999.0)
					_damage_actors_in_radius(center_pos, rad_px, 500.0, "antimatter_annihilation")
					request_dirty_circle_update(center_pos, rad_px)
					planet_surface_changed.emit()

				"power_solar_flare":
					shockwave_triggered.emit(center_pos, MAP_PIXEL_W, gp.shockwave_color)
					sfx_requested.emit("sfx_solar_flare", center_pos, 0.9, 3.0)
					for c in cities_map.values():
						if c.has("active_plot_id") and int(c["active_plot_id"]) != -1:
							var p_id: int = int(c["active_plot_id"])
							if active_plots.has(p_id):
								active_plots[p_id]["progress"] = maxf(0.0, float(active_plots[p_id]["progress"]) - 25.0)
					damage_city_buildings_in_radius(center_pos, MAP_PIXEL_W * 0.5, gp.building_damage)
					_damage_actors_in_radius(center_pos, MAP_PIXEL_W * 0.5, gp.actor_damage, "solar_flare_emi")

				"power_seismic_quake":
					shockwave_triggered.emit(center_pos, rad_px * 1.8, gp.shockwave_color)
					sfx_requested.emit("sfx_seismic_quake", center_pos, 0.7, 4.0)
					for i in range(affected_tiles.size()):
						var idx: int = affected_tiles[i]
						var elev_shift: float = 0.22 if (i % 2 == 0) else -0.20
						tiles[idx]["elevation"] = clampf(float(tiles[idx]["elevation"]) + elev_shift, -0.38, 0.46)
						tiles[idx]["flora"] = _pick_flora_for_biome(tiles[idx]["biome_id"], float(tiles[idx]["elevation"]), idx)
					damage_city_buildings_in_radius(center_pos, rad_px, gp.building_damage)
					_damage_actors_in_radius(center_pos, rad_px, gp.actor_damage, "earthquake")
					request_dirty_circle_update(center_pos, rad_px)
					planet_surface_changed.emit()

				"power_cosmic_plague":
					shockwave_triggered.emit(center_pos, rad_px, gp.shockwave_color)
					sfx_requested.emit("sfx_cosmic_plague", center_pos, 1.0, 2.0)
					_damage_actors_in_radius(center_pos, rad_px, gp.actor_damage, "cosmic_plague")
					for c in cities_map.values():
						if (c["map_pos"] as Vector2).distance_to(center_pos) <= rad_px + 60.0:
							c["population"] = maxf(5.0, float(c["population"]) * 0.75)

				"power_gaia_bloom":
					shockwave_triggered.emit(center_pos, rad_px * 1.4, gp.shockwave_color)
					sfx_requested.emit("sfx_gaia_bloom", center_pos, 1.1, 2.0)
					for idx in affected_tiles:
						tiles[idx]["radiation"] = 0.0
						tiles[idx]["temperature_c"] = lerpf(float(tiles[idx]["temperature_c"]), 22.0, 0.7)
						if float(tiles[idx]["elevation"]) < 0.0:
							tiles[idx]["biome_id"] = "biome_primordial_ocean"
						tiles[idx]["flora"] = _pick_flora_for_biome(tiles[idx]["biome_id"], float(tiles[idx]["elevation"]), idx)
					_damage_actors_in_radius(center_pos, rad_px, -100.0, "heal")
					request_dirty_circle_update(center_pos, rad_px)
					planet_surface_changed.emit()

				"power_mutagenic_spore":
					shockwave_triggered.emit(center_pos, rad_px, gp.shockwave_color)
					sfx_requested.emit("sfx_mutagenic_spore", center_pos, 1.0, 2.0)
					var mut_mult: float = get_world_constant("mutation_rate_multiplier")
					for idx in affected_tiles:
						var sp_id: int = int(tiles[idx]["subspecies_id"])
						if sp_id != -1 and subspecies_map.has(sp_id) and _rng.randf() < gp.mutation_chance * mut_mult:
							var sp: Dictionary = subspecies_map[sp_id]
							var r_trait: SandboxAssetScript.SubspeciesTraitAsset = assets.subspecies_trait_list[_rng.randi_range(0, assets.subspecies_trait_list.size() - 1)]
							if not sp["traits"].has(r_trait.id):
								sp["traits"].append(r_trait.id)
					_damage_actors_in_radius(center_pos, rad_px, gp.actor_damage, "mutagenic_exposure")

				"power_matter_transmuter":
					shockwave_triggered.emit(center_pos, rad_px, Color(0.1, 0.85, 1.0))
					sfx_requested.emit("sfx_matter_transmuter", center_pos, 1.0, 2.0)
					energy_gw = maxf(0.0, energy_gw - 30.0)
					matter_stock += gp.matter_injection * codex_matter_mult
					for idx in affected_tiles:
						if tiles[idx]["biome_id"] == "biome_plasma_inferno":
							tiles[idx]["biome_id"] = "biome_barren_crust"
							tiles[idx]["temperature_c"] = 35.0
							tiles[idx]["flora"] = _pick_flora_for_biome("biome_barren_crust", float(tiles[idx]["elevation"]), idx)
					request_dirty_tiles_update(affected_tiles)
					planet_surface_changed.emit()

				"power_zero_point_well":
					shockwave_triggered.emit(center_pos, rad_px * 1.2, Color(0.4, 0.1, 1.0))
					sfx_requested.emit("sfx_zero_point_well", center_pos, 0.6, 3.5)
					energy_gw += gp.energy_injection * codex_energy_mult
					_spawn_field_lens_internal(best_tile, gp.default_brush_radius, "time_accel", 5.0, 0.5, 30.0, Color(0.4, 0.1, 1.0))

		"cosmic_action":
			if power_id == "power_dyson_ring":
				_create_dyson_ring(80, gp.beam_color)
				if not cities_map.is_empty():
					var c0: Dictionary = cities_map.values()[0]
					rocket_launched.emit(c0["map_pos"], gp.beam_color, c0["name"])
				_log_event("Начерчена новая орбита Сферы Дайсона! Запущено +80 солнечных парусов.", "cosmos", gp.beam_color)
			elif power_id == "power_harvest_asteroids":
				var mined: float = minf(asteroid_belt_mass, 450.0)
				asteroid_belt_mass = maxf(0.0, asteroid_belt_mass - mined)
				matter_stock += mined * codex_matter_mult
				_add_sails_to_dyson_swarm(35, gp.beam_color)
				_log_event("Рой переработал астероидный сектор: +%.0f Материи и +35 парусов Сферы Дайсона!" % mined, "cosmos", gp.beam_color)
			elif power_id == "power_stellar_stabilizer":
				star_stability = minf(1.0, star_stability + 0.30)
				star_luminosity_mult += 0.20
				star_temp_k += 650.0
				if not cities_map.is_empty():
					var any_city: Dictionary = cities_map.values()[0]
					var any_cult: Dictionary = cultures_map.get(int(any_city["culture_id"]), {})
					_synthesize_infinite_theory(any_city, any_cult, tiles[int(any_city["center_tile"])])
				_log_event("Звёздная Хирургия: магнитный якорь сжал корону светила (Мощность +20%%, Стабильность %d%%)!" % int(star_stability * 100.0), "cosmos", gp.beam_color)
			elif power_id == "power_chrono_supernova":
				trigger_chrono_supernova_loop()

	god_impact_triggered.emit(center_dir, rad_norm, gp.beam_color, power_id)
	god_impact_2d_triggered.emit(center_pos, rad_px, gp.beam_color, power_id)
	telemetry_updated.emit()
	return result


func _spawn_field_lens_internal(tile_idx: int, rad_norm: float, l_type: String, t_mult: float, g_mult: float, dur: float, col: Color) -> void:
	var lens_id: int = _next_meta_id
	_next_meta_id += 1
	var t: Dictionary = tiles[clampi(tile_idx, 0, TILE_COUNT - 1)]
	field_lenses.append({
		"id": lens_id,
		"lens_type": l_type,
		"dir": t["dir"],
		"map_pos": t["map_pos"],
		"radius": rad_norm,
		"radius_px": brush_radius_to_pixels(rad_norm),
		"time_mult": t_mult,
		"grav_mult": g_mult * get_world_constant("gravitational_constant"),
		"remaining": dur,
		"max_dur": dur,
		"color": col
	})
	_recalc_tile_lens_modifiers()
	field_lenses_changed.emit()


func trigger_chrono_supernova_loop() -> void:
	if not cities_map.is_empty():
		var c: Dictionary = cities_map.values()[0]
		var cult: Dictionary = cultures_map.get(int(c["culture_id"]), {})
		_synthesize_infinite_theory(c, cult, tiles[int(c["center_tile"])])

	chrono_cycle += 1
	codex_matter_mult += 0.25
	codex_energy_mult += 0.35
	codex_compute_mult += 0.50

	_log_event(
		"ХРОНО-ПЕТЛЯ СВЕРХНОВОЙ! Звезда сжата в сингулярность, все %d открытых Законов Физики переданы в Виток #%d!" % [codex_theories.size(), chrono_cycle],
		"supernova",
		Color(1.0, 0.35, 0.78)
	)
	setup_world(world_seed + chrono_cycle * 101, true)
	supernova_cycle_triggered.emit(chrono_cycle)


# ==============================================================================
# РАЗРУШЕНИЕ ЗДАНИЙ, УРОН И БОЖЕСТВЕННЫЙ АРСЕНАЛ (F5)
# ==============================================================================
func damage_city_building(city_id: int, building_id: String, damage: float) -> bool:
	if not cities_map.has(city_id):
		return false
	var city: Dictionary = cities_map[city_id]
	var b_dict: Dictionary = city["buildings"]
	if not b_dict.has(building_id) or int(b_dict[building_id]) <= 0:
		return false

	if not city.has("building_durability"):
		city["building_durability"] = {}
	var dur_dict: Dictionary = city["building_durability"]

	var bo: SandboxAssetScript.BuildOrderAsset = assets.build_orders.get(building_id)
	var max_hp: float = 100.0 * (float(bo.tier) if bo != null else 1.0)
	var cur_hp: float = float(dur_dict.get(building_id, max_hp)) - damage

	if cur_hp <= 0.0:
		var cnt: int = int(b_dict[building_id]) - 1
		if cnt <= 0:
			b_dict.erase(building_id)
			dur_dict.erase(building_id)
		else:
			b_dict[building_id] = cnt
			dur_dict[building_id] = max_hp

		city["kardashev_level"] = maxf(0.5, float(city["kardashev_level"]) - 0.05)
		city["internal_cohesion"] = maxf(0.1, float(city.get("internal_cohesion", 1.0)) - 0.08)
		_rebuild_city_2d_instances(city)
		city_structures_changed.emit()

		building_damaged_or_destroyed.emit(city_id, building_id, true)
		sfx_requested.emit("sfx_building_collapse", city["map_pos"], 0.9, 2.0)
		_log_event("Здание «%s» в полисе «%s» уничтожено!" % [bo.title if bo else building_id, city["name"]], "damage", Color(1.0, 0.25, 0.25))
		return true
	else:
		dur_dict[building_id] = cur_hp
		building_damaged_or_destroyed.emit(city_id, building_id, false)
		sfx_requested.emit("sfx_building_damage", city["map_pos"], 1.1, 0.0)
		return false


func damage_city_buildings_in_radius(world_pos: Vector2, radius_px: float, damage: float) -> Array[Dictionary]:
	var damaged_records: Array[Dictionary] = []
	var max_range: float = maxf(1.0, radius_px + 80.0)
	for c_id in cities_map.keys():
		var city: Dictionary = cities_map[c_id]
		var c_pos: Vector2 = city["map_pos"]
		var dist: float = c_pos.distance_to(world_pos)
		if dist <= max_range:
			var factor: float = clampf(1.0 - (dist / max_range), 0.1, 1.0)
			var applied_damage: float = damage * factor
			var b_dict: Dictionary = city["buildings"]
			var b_keys := b_dict.keys()
			for b_id in b_keys:
				var destroyed := damage_city_building(c_id, b_id, applied_damage)
				damaged_records.append({
					"city_id": c_id,
					"building_id": b_id,
					"is_destroyed": destroyed
				})
	return damaged_records


func _damage_actors_in_radius(pos: Vector2, radius_px: float, damage: float, cause: String) -> void:
	for i in range(actors.size() - 1, -1, -1):
		var a: Dictionary = actors[i]
		if (a["pos"] as Vector2).distance_to(pos) <= radius_px:
			if damage < 0.0:
				a["hp"] = mini(100, int(a.get("hp", 100)) - int(damage))
			else:
				var hp := maxi(0, int(a.get("hp", 100)) - int(damage))
				a["hp"] = hp
				var killed := (hp <= 0)
				actor_damaged_or_killed.emit(int(a["id"]), -1, cause if not killed else ("killed_by_" + cause))
				if killed:
					actors.remove_at(i)


# ==============================================================================
# ФУНДАМЕНТАЛЬНЫЕ ФИЗИЧЕСКИЕ КОНСТАНТЫ ВСЕЛЕННОЙ (F6)
# ==============================================================================
func get_world_constant(constant_id: String) -> float:
	return float(world_constants.get(constant_id, 1.0))


func set_world_constant(constant_id: String, value: float) -> void:
	var c_asset: SandboxAssetScript.PhysicalConstantAsset = assets.physical_constants.get(constant_id)
	var clamped_val: float = value
	if c_asset != null:
		clamped_val = clampf(value, c_asset.min_val, c_asset.max_val)
	world_constants[constant_id] = clamped_val
	world_constant_modified.emit(constant_id, clamped_val)
	_log_event("Фундаментальная Константа изменена: %s = %.2f" % [constant_id, clamped_val], "constants", Color(0.3, 0.8, 1.0))


# ==============================================================================
# МУЛЬТИ-ЭЛЕМЕНТНАЯ АЛХИМИЯ ТАЙЛОВ (F6)
# ==============================================================================
func evaluate_alchemical_reaction(arg1: Variant, arg2: Variant = "") -> SandboxAssetScript.AlchemicalReactionAsset:
	var primary := ""
	var secondary := ""
	if arg1 is int:
		var t_idx: int = clampi(arg1, 0, TILE_COUNT - 1)
		secondary = tiles[t_idx]["biome_id"]
		primary = str(arg2)
	elif arg1 is String and arg2 is int:
		var t_idx: int = clampi(arg2, 0, TILE_COUNT - 1)
		secondary = tiles[t_idx]["biome_id"]
		primary = arg1
	else:
		primary = str(arg1)
		secondary = str(arg2)

	var k1 := "%s+%s" % [primary, secondary]
	if assets.alchemical_reactions.has(k1):
		return assets.alchemical_reactions[k1]
	var k2 := "%s+%s" % [secondary, primary]
	if assets.alchemical_reactions.has(k2):
		return assets.alchemical_reactions[k2]
	return null



func find_closest_tile_2d(world_pos: Vector2) -> int:
	var gx: int = clampi(int(world_pos.x / MAP_PIXEL_W * float(GRID_W)), 0, GRID_W - 1)
	var gy: int = clampi(int(world_pos.y / MAP_PIXEL_H * float(GRID_H)), 0, GRID_H - 1)
	return gy * GRID_W + gx


func find_closest_tile(u_dir: Vector3) -> int:
	var dir := u_dir.normalized()
	var best_idx: int = 0
	var best_dot: float = -2.0
	for i in range(TILE_COUNT):
		var d: float = dir.dot(tiles[i]["dir"])
		if d > best_dot:
			best_dot = d
			best_idx = i
	return best_idx


func _log_event(text: String, category: String, col: Color) -> void:
	var entry := {
		"year": int(world_year),
		"cycle": chrono_cycle,
		"text": text,
		"category": category,
		"color": col
	}
	event_log.push_front(entry)
	if event_log.size() > 80:
		event_log.pop_back()
	event_logged.emit(entry)


# ==============================================================================
# 7. ДИПЛОМАТИЯ, ОТНОШЕНИЯ И ВНЕШНЕПОЛИТИЧЕСКИЕ ЗАМЫСЛЫ (DiplomacyManager)
# ==============================================================================
func _rel_key(id_a: int, id_b: int) -> String:
	return "%d_%d" % [mini(id_a, id_b), maxi(id_a, id_b)]


func get_diplomacy_relation(id_a: int, id_b: int) -> Dictionary:
	return diplomacy_relations.get(_rel_key(id_a, id_b), {})


func _ensure_diplomacy_relation(id_a: int, id_b: int) -> Dictionary:
	if id_a == id_b:
		return {}
	var k := _rel_key(id_a, id_b)
	if not diplomacy_relations.has(k):
		diplomacy_relations[k] = {
			"key": k,
			"city_a": mini(id_a, id_b),
			"city_b": maxi(id_a, id_b),
			"status": "NEUTRAL",
			"opinion_a_to_b": 0.0,
			"opinion_b_to_a": 0.0,
			"war_exhaustion_a": 0.0,
			"war_exhaustion_b": 0.0,
			"war_duration": 0.0,
			"trade_yield": 0.0
		}
	return diplomacy_relations[k]


func set_diplomacy_status(id_a: int, id_b: int, new_status: String) -> void:
	if id_a == id_b:
		return
	var rel := _ensure_diplomacy_relation(id_a, id_b)
	if rel.is_empty():
		return
	var old_status: String = rel.get("status", "NEUTRAL")
	if old_status == new_status:
		return
	rel["status"] = new_status
	var name_a: String = cities_map[id_a]["name"] if cities_map.has(id_a) else "Полис #%d" % id_a
	var name_b: String = cities_map[id_b]["name"] if cities_map.has(id_b) else "Полис #%d" % id_b
	if new_status == "WAR":
		rel["war_exhaustion_a"] = 0.0
		rel["war_exhaustion_b"] = 0.0
		rel["war_duration"] = 0.0
		_log_event("ВОЙНА ОБЪЯВЛЕНА: «%s» и «%s» начали боевые действия!" % [name_a, name_b], "war", Color(1.0, 0.3, 0.3))
	elif new_status == "PEACE":
		rel["war_exhaustion_a"] = maxf(15.0, float(rel.get("war_exhaustion_a", 0.0)))
		rel["war_exhaustion_b"] = maxf(15.0, float(rel.get("war_exhaustion_b", 0.0)))
		_log_event("МИР ЗАКЛЮЧЁН: между «%s» и «%s» установлен мир." % [name_a, name_b], "peace", Color(0.4, 0.9, 0.6))
	elif new_status == "NEUTRAL":
		rel["war_exhaustion_a"] = 0.0
		rel["war_exhaustion_b"] = 0.0
	elif new_status == "TRADE":
		var yield_val: float = maxf(5.0, float(rel.get("trade_yield", 5.0)))
		trade_route_established.emit(id_a, id_b, yield_val)
		_log_event("ТОРГОВЫЙ ПАКТ: «%s» и «%s» открыли торговый маршрут!" % [name_a, name_b], "trade", Color(1.0, 0.85, 0.25))
	elif new_status == "ALLIANCE":
		_log_event("ВЕЛИКИЙ СОЮЗ: «%s» и «%s» заключили оборонительный пакт!" % [name_a, name_b], "alliance", Color(0.35, 0.75, 1.0))
	diplomacy_relation_changed.emit(id_a, id_b, old_status, new_status)


func _calculate_opinion(from_city: Dictionary, to_city: Dictionary) -> float:
	var op: float = 0.0
	var sp_from: int = int(from_city["subspecies_id"])
	var sp_to: int = int(to_city["subspecies_id"])
	var cult_from: Dictionary = cultures_map.get(int(from_city["culture_id"]), {})
	var c_traits: Array = cult_from.get("traits", [])

	# 1. Родство видов (Kinship)
	if sp_from == sp_to:
		op += 25.0
	else:
		if c_traits.has("ethos_xenophile"):
			op += 25.0
		elif c_traits.has("ethos_militarist"):
			op -= 35.0
		else:
			op -= 12.0

	# 2. Культурное наследие и материнство полисов
	var c_from_id: int = int(from_city["culture_id"])
	var c_to_id: int = int(to_city["culture_id"])
	if c_from_id == c_to_id:
		op += 30.0
	elif cult_from.get("layout", "") == cultures_map.get(c_to_id, {}).get("layout", ""):
		op += 10.0

	if int(from_city.get("parent_city_id", -1)) == int(to_city["id"]) or int(to_city.get("parent_city_id", -1)) == int(from_city["id"]):
		op += 40.0

	# 3. Совпадение этосов
	var ethos_from: String = str(from_city.get("ethos_id", ""))
	var ethos_to: String = str(to_city.get("ethos_id", ""))
	if ethos_from != "" and ethos_from == ethos_to:
		op += 20.0
	elif (ethos_from == "ethos_militarist" and ethos_to == "ethos_xenophile") or (ethos_from == "ethos_xenophile" and ethos_to == "ethos_militarist"):
		op -= 40.0

	# 4. География и пограничные трения
	var dist: float = (from_city["map_pos"] as Vector2).distance_to(to_city["map_pos"] as Vector2)
	if _cities_share_border(from_city, to_city):
		op -= 25.0 if (c_traits.has("ethos_expansionist") or c_traits.has("ethos_militarist")) else 10.0
	elif dist < 500.0:
		op += 15.0 * (1.0 - dist / 500.0)

	# 5. Текущий статус отношений
	var rel := get_diplomacy_relation(int(from_city["id"]), int(to_city["id"]))
	match rel.get("status", "NEUTRAL"):
		"TRADE": op += 35.0
		"ALLIANCE": op += 60.0
		"WAR": op -= 75.0

	return clampf(op, -100.0, 100.0)


func _cities_share_border(city_a: Dictionary, city_b: Dictionary) -> bool:
	var claimed_b_set := {}
	for idx in city_b.get("claimed_tiles", []):
		claimed_b_set[int(idx)] = true
	for idx_a in city_a.get("claimed_tiles", []):
		for n in tiles[int(idx_a)]["neighbors"]:
			if claimed_b_set.has(n):
				return true
	return false


func _tick_city_diplomacy(dt: float) -> void:
	if cities_map.size() < 2:
		return
	var city_ids := cities_map.keys()
	city_ids.sort()
	for i in range(city_ids.size()):
		var id_a: int = city_ids[i]
		if not cities_map.has(id_a):
			continue
		var c_a: Dictionary = cities_map[id_a]
		for j in range(i + 1, city_ids.size()):
			var id_b: int = city_ids[j]
			if not cities_map.has(id_b):
				continue
			var c_b: Dictionary = cities_map[id_b]
			var rel := _ensure_diplomacy_relation(id_a, id_b)
			rel["opinion_a_to_b"] = _calculate_opinion(c_a, c_b)
			rel["opinion_b_to_a"] = _calculate_opinion(c_b, c_a)
			var st: String = rel.get("status", "NEUTRAL")

			if st == "WAR":
				rel["war_duration"] = float(rel.get("war_duration", 0.0)) + dt
				rel["war_exhaustion_a"] = float(rel.get("war_exhaustion_a", 0.0)) + dt * 0.9
				rel["war_exhaustion_b"] = float(rel.get("war_exhaustion_b", 0.0)) + dt * 0.9
				if maxf(float(rel["war_exhaustion_a"]), float(rel["war_exhaustion_b"])) >= 70.0 or float(rel["war_duration"]) >= 35.0:
					_try_start_diplomatic_plot(c_a, c_b, "plot_peace_accord")
			elif st == "TRADE":
				var dist: float = (c_a["map_pos"] as Vector2).distance_to(c_b["map_pos"] as Vector2)
				var eff: float = clampf(1.0 - (dist / 1500.0) * 0.35, 0.65, 1.25)
				var trade_val: float = (float(c_a["kardashev_level"]) + float(c_b["kardashev_level"])) * 3.5 * eff
				rel["trade_yield"] = trade_val
				matter_stock += trade_val * 0.45 * dt
				energy_gw += trade_val * 0.65 * dt
				var avg_op: float = (float(rel["opinion_a_to_b"]) + float(rel["opinion_b_to_a"])) * 0.5
				if avg_op >= 55.0:
					_try_start_diplomatic_plot(c_a, c_b, "plot_alliance_federation")
				elif avg_op < -20.0:
					set_diplomacy_status(id_a, id_b, "NEUTRAL")
			elif st == "ALLIANCE":
				var dist: float = (c_a["map_pos"] as Vector2).distance_to(c_b["map_pos"] as Vector2)
				var eff: float = clampf(1.0 - (dist / 1500.0) * 0.35, 0.65, 1.25)
				var trade_val: float = (float(c_a["kardashev_level"]) + float(c_b["kardashev_level"])) * 4.75 * eff
				rel["trade_yield"] = trade_val
				matter_stock += trade_val * 0.55 * dt
				energy_gw += trade_val * 0.85 * dt
				var avg_op: float = (float(rel["opinion_a_to_b"]) + float(rel["opinion_b_to_a"])) * 0.5
				if avg_op < 10.0:
					set_diplomacy_status(id_a, id_b, "TRADE")
			elif st == "PEACE":
				rel["war_exhaustion_a"] = maxf(0.0, float(rel["war_exhaustion_a"]) - dt * 2.0)
				rel["war_exhaustion_b"] = maxf(0.0, float(rel["war_exhaustion_b"]) - dt * 2.0)
				if float(rel["war_exhaustion_a"]) <= 0.0 and float(rel["war_exhaustion_b"]) <= 0.0:
					set_diplomacy_status(id_a, id_b, "NEUTRAL")
			elif st == "NEUTRAL":
				var avg_op: float = (float(rel["opinion_a_to_b"]) + float(rel["opinion_b_to_a"])) * 0.5
				if avg_op <= -30.0:
					_try_start_diplomatic_plot(c_a, c_b, "plot_war_mobilization")
				elif avg_op >= 20.0:
					_try_start_diplomatic_plot(c_a, c_b, "plot_trade_route_pact")

	_step_diplomatic_plots(dt)
	_check_and_step_colonization(dt)


func _try_start_diplomatic_plot(initiator: Dictionary, target: Dictionary, plot_type_id: String) -> void:
	if int(initiator.get("active_diplomatic_plot_id", -1)) != -1:
		return
	var titles := {
		"plot_trade_route_pact": "Заключение Торгового Пакта с «%s»",
		"plot_alliance_federation": "Пакт Взаимной Обороны с «%s»",
		"plot_war_mobilization": "Военная Мобилизация против «%s»",
		"plot_peace_accord": "Мирные Переговоры с «%s»"
	}
	var needed := {
		"plot_trade_route_pact": 25.0,
		"plot_alliance_federation": 40.0,
		"plot_war_mobilization": 30.0,
		"plot_peace_accord": 20.0
	}
	var new_id: int = _next_meta_id
	_next_meta_id += 1
	var plot_rec := {
		"id": new_id,
		"asset_id": plot_type_id,
		"title": titles.get(plot_type_id, "Дипломатический замысел с «%s»") % target["name"],
		"city_id": initiator["id"],
		"city_name": initiator["name"],
		"target_city_id": target["id"],
		"target_city_name": target["name"],
		"progress": 0.0,
		"progress_needed": needed.get(plot_type_id, 30.0),
		"plot_type": "diplomacy"
	}
	active_plots[new_id] = plot_rec
	initiator["active_diplomatic_plot_id"] = new_id
	_log_event("Замысел: «%s» начал «%s»." % [initiator["name"], plot_rec["title"]], "diplomacy", Color(0.55, 0.85, 1.0))


func _step_diplomatic_plots(dt: float) -> void:
	for city in cities_map.values():
		var p_id: int = int(city.get("active_diplomatic_plot_id", -1))
		if p_id == -1 or not active_plots.has(p_id):
			continue
		var plot: Dictionary = active_plots[p_id]
		plot["progress"] = float(plot["progress"]) + (3.0 + float(city["kardashev_level"]) * 2.5) * dt
		if float(plot["progress"]) >= float(plot["progress_needed"]):
			_resolve_diplomatic_plot(city, plot)


func _resolve_diplomatic_plot(initiator: Dictionary, plot: Dictionary) -> void:
	active_plots.erase(int(plot["id"]))
	initiator["active_diplomatic_plot_id"] = -1
	var target_id: int = int(plot["target_city_id"])
	if not cities_map.has(target_id):
		return
	match plot["asset_id"]:
		"plot_trade_route_pact", "plot_trade_treaty":
			set_diplomacy_status(int(initiator["id"]), target_id, "TRADE")
		"plot_alliance_federation", "plot_defensive_alliance":
			set_diplomacy_status(int(initiator["id"]), target_id, "ALLIANCE")
		"plot_war_mobilization", "plot_declare_war":
			set_diplomacy_status(int(initiator["id"]), target_id, "WAR")
		"plot_peace_accord", "plot_peace_treaty":
			set_diplomacy_status(int(initiator["id"]), target_id, "PEACE")


func _step_actor_combat(dt: float) -> void:
	if diplomacy_relations.is_empty() or actors.size() < 2:
		return
	var war_active := false
	for rel in diplomacy_relations.values():
		if rel.get("status") == "WAR":
			war_active = true
			break
	if not war_active:
		return

	var check_count := mini(actors.size(), 24)
	for _k in range(check_count):
		if actors.size() < 2:
			break
		var idx_a: int = _rng.randi_range(0, actors.size() - 1)
		var a: Dictionary = actors[idx_a]
		var c_a: int = int(a.get("city_id", -1))
		if c_a == -1 or not cities_map.has(c_a):
			continue

		for idx_b in range(actors.size() - 1, -1, -1):
			if idx_b == idx_a:
				continue
			var b: Dictionary = actors[idx_b]
			var c_b: int = int(b.get("city_id", -1))
			if c_b == -1 or c_a == c_b or not cities_map.has(c_b):
				continue

			var rel := get_diplomacy_relation(c_a, c_b)
			if rel.get("status") != "WAR":
				continue

			var pos_a: Vector2 = a["pos"]
			var pos_b: Vector2 = b["pos"]
			if pos_a.distance_to(pos_b) <= 22.0:
				var dmg: int = _rng.randi_range(20, 35)
				var hp_b: int = maxi(0, int(b.get("hp", 100)) - dmg)
				b["hp"] = hp_b
				var killed: bool = (hp_b <= 0)
				actor_damaged_or_killed.emit(int(b["id"]), int(a["id"]), "combat" if not killed else "killed_in_combat")
				if killed:
					actors.remove_at(idx_b)
				var victim_k := "war_exhaustion_a" if int(rel["city_a"]) == c_b else "war_exhaustion_b"
				rel[victim_k] = float(rel.get(victim_k, 0.0)) + 1.2
				break

	for a in actors:
		var c_id: int = int(a.get("city_id", -1))
		if c_id == -1 or not cities_map.has(c_id):
			continue
		var home_t: int = clampi(int(a["home_tile"]), 0, TILE_COUNT - 1)
		var tile_owner: int = int(tiles[home_t]["city_id"])
		if tile_owner != -1 and tile_owner != c_id and cities_map.has(tile_owner):
			var rel := get_diplomacy_relation(c_id, tile_owner)
			if rel.get("status") == "WAR":
				var raid_chance: float = 0.35 * dt if str(a.get("role", "")) == "warrior" else 0.12 * dt
				if _rng.randf() < raid_chance:
					building_damaged_or_destroyed.emit(tile_owner, "order_bio_dome", false)
					var raid_k := "war_exhaustion_a" if int(rel["city_a"]) == tile_owner else "war_exhaustion_b"
					rel[raid_k] = float(rel.get(raid_k, 0.0)) + 0.8
					_log_event("Рейд! Воины «%s» совершили набег на пограничный купол «%s»!" % [cities_map[c_id]["name"], cities_map[tile_owner]["name"]], "war", Color(1.0, 0.4, 0.4))


# ==============================================================================
# 8. МЕЖОСТРОВНАЯ КОЛОНИЗАЦИЯ И ДОЧЕРНИЕ ПОЛИСЫ
# ==============================================================================
func _check_and_step_colonization(dt: float) -> void:
	if cities_map.size() >= MAX_CITIES:
		return
	if world_year - _last_colony_time < COLONY_EXPEDITION_COOLDOWN:
		return
	for c_id in cities_map.keys():
		var city: Dictionary = cities_map[c_id]
		var pop: float = float(city["population"])
		var claimed_count: int = (city.get("claimed_tiles") as Array).size()
		var ethos: String = str(city.get("ethos_id", ""))
		var threshold: float = COLONY_EXPEDITION_POP_THRESHOLD
		if ethos == "ethos_expansionist":
			threshold *= 0.75
		if pop >= threshold and claimed_count >= 6:
			var target_tile: int = _find_best_colony_tile(city)
			if target_tile != -1:
				_launch_colonist_expedition(city, target_tile)
				_last_colony_time = world_year
				break


func _find_best_colony_tile(city: Dictionary) -> int:
	var best_idx: int = -1
	var best_score: float = -9999.0
	var c_pos: Vector2 = city["map_pos"]
	for i in range(TILE_COUNT):
		var t: Dictionary = tiles[i]
		if int(t["city_id"]) != -1:
			continue
		var elev: float = float(t["elevation"])
		if elev < -0.04:
			continue
		var dist: float = (t["map_pos"] as Vector2).distance_to(c_pos)
		if dist < 200.0 or dist > 850.0:
			continue
		var free_nbrs: int = 0
		for n in t["neighbors"]:
			if int(tiles[n]["city_id"]) == -1:
				free_nbrs += 1
		var score: float = elev * 20.0 + float(free_nbrs) * 5.0 - (dist / 120.0)
		if score > best_score:
			best_score = score
			best_idx = i
	return best_idx


func _launch_colonist_expedition(city: Dictionary, target_tile: int) -> void:
	var actor := _spawn_actor_unit(int(city["subspecies_id"]), int(city["center_tile"]), int(city["id"]), "colonist")
	if actor.is_empty():
		return
	city["population"] = maxf(20.0, float(city["population"]) - 12.0)
	actor["target_pos"] = tiles[target_tile]["map_pos"]
	actor["home_tile"] = target_tile
	actor["thought"] = "Плывёт основывать дочерний полис"
	colony_expedition_launched.emit(int(city["id"]), city["map_pos"], tiles[target_tile]["map_pos"])
	_log_event("Колониальная экспедиция вышла из «%s» к дальним берегам!" % city["name"], "colony", Color(0.4, 0.85, 1.0))


func _found_daughter_city(mother_city_id: int, tile_idx: int, sp_id: int, cult_id: int) -> int:
	if not cities_map.has(mother_city_id):
		return -1
	var t: Dictionary = tiles[tile_idx]
	if float(t["elevation"]) < 0.04:
		t["elevation"] = 0.12
	var new_city_id: int = _next_meta_id
	_next_meta_id += 1
	var mother: Dictionary = cities_map[mother_city_id]
	var mother_name_prefix: String = mother["name"].split("-")[0]
	var c_name: String = "Нова-%s-%d" % [mother_name_prefix, cities_map.size() + 1]
	var claimed: Array[int] = [tile_idx]
	var claimed_zones: Array[int] = []
	claimed_zones.append_array(_claim_zones_for_tile(new_city_id, tile_idx))
	for nbr in t["neighbors"]:
		if int(tiles[nbr]["city_id"]) == -1:
			tiles[nbr]["city_id"] = new_city_id
			tiles[nbr]["subspecies_id"] = sp_id
			claimed.append(nbr)
			claimed_zones.append_array(_claim_zones_for_tile(new_city_id, nbr))
			if claimed.size() >= 4:
				break
	t["city_id"] = new_city_id
	t["subspecies_id"] = sp_id

	var assigned_ethos: String = str(mother.get("ethos_id", "ethos_expansionist"))
	var city_rec := {
		"id": new_city_id,
		"name": c_name,
		"subspecies_id": sp_id,
		"culture_id": cult_id,
		"center_tile": tile_idx,
		"map_pos": t["map_pos"],
		"dir": t["dir"],
		"claimed_tiles": claimed,
		"claimed_zones": claimed_zones,
		"storage": {"wood": 20, "minerals": 15, "food": 25},
		"population": 22.0,
		"kardashev_level": maxf(0.55, float(mother["kardashev_level"]) - 0.08),
		"science_tier": int(mother.get("science_tier", 1)),
		"buildings": {"order_bio_dome": 1},
		"building_instances": [],
		"orbital_drones": 1,
		"active_plot_id": -1,
		"active_diplomatic_plot_id": -1,
		"shielded": false,
		"color": mother["color"],
		"ethos_id": assigned_ethos,
		"kingdom_id": int(mother.get("kingdom_id", mother_city_id)),
		"parent_city_id": mother_city_id,
		"internal_cohesion": 0.95,
		"council": {
			"leader_name": "Командор-%s" % c_name,
			"title": "Губернатор Дальней Колонии",
			"trait": assigned_ethos,
			"term_years": 0.0
		}
	}
	_rebuild_city_2d_instances(city_rec)
	cities_map[new_city_id] = city_rec

	for _u in range(5):
		_spawn_actor_unit(sp_id, tile_idx, new_city_id)

	for other_id in cities_map.keys():
		if other_id != new_city_id:
			_ensure_diplomacy_relation(new_city_id, other_id)
	set_diplomacy_status(mother_city_id, new_city_id, "ALLIANCE")

	colony_founded.emit(new_city_id, mother_city_id, city_rec["name"], t["map_pos"])
	_log_event("Новый полис! На дальнем острове основана колония «%s» метрополии «%s»!" % [c_name, mother["name"]], "colony", Color(0.4, 0.9, 1.0))
	request_dirty_tiles_update(claimed)
	planet_surface_changed.emit()
	city_structures_changed.emit()
	return new_city_id


# ==============================================================================
# 9. ИНСПЕКЦИЯ ДАННЫХ И ГЛОБАЛЬНЫЕ МЕТРИКИ (PROJECT.md Interface Contracts)
# ==============================================================================
func get_detailed_city_data(city_id: int) -> Dictionary:
	if not cities_map.has(city_id):
		return {}
	var c: Dictionary = cities_map[city_id]
	var sp: Dictionary = subspecies_map.get(int(c["subspecies_id"]), {})
	var cult: Dictionary = cultures_map.get(int(c["culture_id"]), {})
	var p_id: int = int(c.get("active_plot_id", -1))
	var dp_id: int = int(c.get("active_diplomatic_plot_id", -1))

	var city_rels: Dictionary = {}
	for k in diplomacy_relations.keys():
		var rel: Dictionary = diplomacy_relations[k]
		if int(rel["city_a"]) == city_id or int(rel["city_b"]) == city_id:
			var other_id: int = int(rel["city_b"]) if int(rel["city_a"]) == city_id else int(rel["city_a"])
			var other_name: String = cities_map[other_id]["name"] if cities_map.has(other_id) else "Полис #%d" % other_id
			city_rels[other_id] = {
				"other_name": other_name,
				"status": rel.get("status", "NEUTRAL"),
				"opinion": rel.get("opinion_a_to_b" if int(rel["city_a"]) == city_id else "opinion_b_to_a", 0.0),
				"war_exhaustion": rel.get("war_exhaustion_a" if int(rel["city_a"]) == city_id else "war_exhaustion_b", 0.0),
				"trade_yield": rel.get("trade_yield", 0.0)
			}

	return {
		"id": city_id,
		"name": c["name"],
		"population": c["population"],
		"kardashev_level": c["kardashev_level"],
		"science_tier": c["science_tier"],
		"subspecies_id": c["subspecies_id"],
		"subspecies_name": sp.get("name", "Неизвестный"),
		"culture_id": c["culture_id"],
		"culture_name": cult.get("name", "Неизвестная"),
		"ethos_id": c.get("ethos_id", ""),
		"council": c.get("council", {}),
		"internal_cohesion": c.get("internal_cohesion", 0.9),
		"parent_city_id": c.get("parent_city_id", -1),
		"kingdom_id": c.get("kingdom_id", city_id),
		"center_tile": c["center_tile"],
		"map_pos": c["map_pos"],
		"claimed_tiles_count": (c["claimed_tiles"] as Array).size(),
		"buildings_count": (c["building_instances"] as Array).size(),
		"buildings": c["buildings"],
		"active_plot": active_plots.get(p_id, {}),
		"active_diplomatic_plot": active_plots.get(dp_id, {}),
		"relations": city_rels,
		"color": c["color"]
	}


func get_detailed_actor_data(actor_id: int) -> Dictionary:
	for a in actors:
		if int(a["id"]) == actor_id:
			var c_id: int = int(a["city_id"])
			var sp_id: int = int(a["subspecies_id"])
			return {
				"id": actor_id,
				"name": a["name"],
				"role": a["role"],
				"thought": a["thought"],
				"hp": a["hp"],
				"age": a["age"],
				"pos": a["pos"],
				"target_pos": a["target_pos"],
				"home_tile": a["home_tile"],
				"city_id": c_id,
				"city_name": cities_map[c_id]["name"] if cities_map.has(c_id) else "Дикий",
				"subspecies_id": sp_id,
				"subspecies_name": subspecies_map[sp_id]["name"] if subspecies_map.has(sp_id) else "",
				"color": a["color"]
			}
	return {}


func get_global_world_metrics() -> Dictionary:
	var total_pop: float = 0.0
	var max_kard: float = 0.0
	for c in cities_map.values():
		total_pop += float(c.get("population", 0.0))
		max_kard = maxf(max_kard, float(c.get("kardashev_level", 0.0)))

	var wars := 0
	var trades := 0
	var alliances := 0
	for rel in diplomacy_relations.values():
		match rel.get("status"):
			"WAR": wars += 1
			"TRADE": trades += 1
			"ALLIANCE": alliances += 1

	return {
		"world_year": world_year,
		"chrono_cycle": chrono_cycle,
		"total_cities": cities_map.size(),
		"total_population": total_pop,
		"total_actors": actors.size(),
		"total_subspecies": subspecies_map.size(),
		"total_dyson_sails": total_dyson_sails,
		"codex_theories_count": codex_theories.size(),
		"max_kardashev": max_kard,
		"matter_stock": matter_stock,
		"energy_gw": energy_gw,
		"compute_pflops": compute_pflops,
		"dyson_stage": dyson_stage,
		"dyson_stage_name": get_dyson_stage_name(),
		"dyson_stage_progress": dyson_stage_progress,
		"dyson_active_segments": get_dyson_active_segments(),
		"dyson_energy_output": get_dyson_energy_output(),
		"dyson_eclipse_ratio": get_dyson_eclipse_ratio(),
		"active_wars_count": wars,
		"active_trade_routes_count": trades,
		"active_alliances_count": alliances
	}
