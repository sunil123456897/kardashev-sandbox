class_name SandboxOrbitCamera
extends Camera2D

## 2D-камера песочницы в стиле WorldBox v0.51.2.
## Поддерживает:
## - Перемещение (WASD / Стрелки / Зажатая ПКМ или СКМ)
## - Плавный пиксельный зум колесом мыши (от обзора всего архипелага 1.0× до макро-зума 4.0× на отдельных человечков)
## - 3 режима обзора (1: 2D Карта Мира, 2: 2D Сфера Дайсона, 3: 2D Звёздная Система).

signal view_mode_changed(mode: int)

enum ViewMode {
	MODE_PLANET = 0,
	MODE_STAR_DYSON = 1,
	MODE_SYSTEM_OVERVIEW = 2
}

var view_mode: int = ViewMode.MODE_PLANET
var target_pos: Vector2 = Vector2(960.0, 540.0)
var target_zoom: float = 1.0

const MIN_ZOOM: float = 0.85
const MAX_ZOOM: float = 4.20
const PAN_SPEED: float = 520.0


func _ready() -> void:
	position = Vector2(960.0, 540.0)
	target_pos = position
	zoom = Vector2(1.0, 1.0)
	target_zoom = 1.0


func set_view_mode(mode: int) -> void:
	view_mode = mode
	target_pos = Vector2(960.0, 540.0)
	target_zoom = 1.0
	view_mode_changed.emit(view_mode)


func apply_immediately() -> void:
	position = target_pos
	zoom = Vector2(target_zoom, target_zoom)


func step_camera(delta: float) -> void:
	if delta <= 0.0:
		return

	# Клавиатурное панорамирование WASD / Стрелки в режиме карты планеты
	if view_mode == ViewMode.MODE_PLANET:
		var move_dir := Vector2.ZERO
		if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
			move_dir.y -= 1.0
		if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
			move_dir.y += 1.0
		if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
			move_dir.x -= 1.0
		if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
			move_dir.x += 1.0
		if move_dir.length_squared() > 0.01:
			target_pos += move_dir.normalized() * (PAN_SPEED / maxf(0.8, target_zoom)) * delta
			_clamp_target_pos()

	var lerp_w: float = clampf(delta * 10.0, 0.0, 1.0)
	position = position.lerp(target_pos, lerp_w)
	if not is_finite(position.x) or not is_finite(position.y):
		position = target_pos
	var z_val: float = lerpf(zoom.x, target_zoom, lerp_w)
	if not is_finite(z_val):
		z_val = target_zoom
	zoom = Vector2(z_val, z_val)


func orbit_drag(relative_px: Vector2) -> void:
	if not is_finite(relative_px.x) or not is_finite(relative_px.y):
		return
	target_pos -= relative_px / maxf(0.5, zoom.x)
	_clamp_target_pos()


func zoom_step(factor: float) -> void:
	if not is_finite(factor) or factor <= 0.0:
		return
	# В 3D factor < 1 означал приближение дистанции; в Camera2D больший zoom = крупнее пиксели
	var inv_factor: float = 1.0 / maxf(0.1, factor)
	target_zoom = clampf(target_zoom * inv_factor, MIN_ZOOM, MAX_ZOOM)
	_clamp_target_pos()


func focus_on_planet_pos(world_pos: Vector2, desired_zoom: float = 2.0) -> void:
	if not is_finite(world_pos.x) or not is_finite(world_pos.y):
		world_pos = Vector2(960.0, 540.0)
	if not is_finite(desired_zoom):
		desired_zoom = 2.0
	view_mode = ViewMode.MODE_PLANET
	target_pos = world_pos
	target_zoom = clampf(desired_zoom, MIN_ZOOM, MAX_ZOOM)
	_clamp_target_pos()
	view_mode_changed.emit(view_mode)


func pan_to(coords: Vector2, desired_zoom: float = 2.0) -> void:
	focus_on_planet_pos(coords, desired_zoom)


func focus_on_planet_dir(dir: Vector3, _dist: float = 20.0) -> void:
	# Обратная совместимость: переводим 3D-направление тайла в 2D-координаты карты
	var d := dir.normalized()
	var lon: float = atan2(d.z, d.x)
	var lat: float = asin(clampf(d.y, -1.0, 1.0))
	var uv_x: float = clampf(0.5 + lon / (TAU * 0.92), 0.1, 0.9)
	var uv_y: float = clampf(0.5 - lat / (PI * 0.88), 0.1, 0.9)
	focus_on_planet_pos(Vector2(uv_x * 1920.0, uv_y * 1080.0), 1.85)


func screen_to_world(screen_pos: Vector2) -> Vector2:
	var vp_size := Vector2(1920.0, 1080.0)
	if get_viewport() != null:
		vp_size = get_viewport().get_visible_rect().size
	return position + (screen_pos - vp_size * 0.5) / maxf(0.1, zoom.x)


func _clamp_target_pos() -> void:
	if not is_finite(target_pos.x) or not is_finite(target_pos.y):
		target_pos = Vector2(960.0, 540.0)
	if not is_finite(target_zoom):
		target_zoom = 2.0
	var half_w: float = 960.0 / maxf(1.0, target_zoom)
	var half_h: float = 540.0 / maxf(1.0, target_zoom)
	var min_x: float = minf(960.0, half_w * 0.75)
	var max_x: float = maxf(960.0, 1920.0 - half_w * 0.75)
	var min_y: float = minf(540.0, half_h * 0.75)
	var max_y: float = maxf(540.0, 1080.0 - half_h * 0.75)
	target_pos.x = clampf(target_pos.x, min_x, max_x)
	target_pos.y = clampf(target_pos.y, min_y, max_y)
	if not is_finite(target_pos.x):
		target_pos.x = 960.0
	if not is_finite(target_pos.y):
		target_pos.y = 540.0
