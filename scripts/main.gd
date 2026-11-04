extends Node2D

## Главный 2D-контроллер сцены «Kardashev Sandbox: Crucible of Stars» (в стиле WorldBox v0.51.2).
## Связывает WorldSimulation (2D-сетка + живые юниты Actors), CosmicRenderer (2D Pixel-Art),
## SandboxOrbitCamera (Camera2D) и GodHUD, обрабатывая рисование Кистью Бога по 2D-карте
## и перетаскивание живых пиксельных существ мышкой.

const WorldSimulationScript = preload("res://scripts/sim/world_simulation.gd")
const CosmicRendererScript = preload("res://scripts/render/cosmic_renderer.gd")
const SandboxOrbitCameraScript = preload("res://scripts/render/orbit_camera.gd")
const GodHUDScript = preload("res://scripts/ui/god_hud.gd")
const SandboxAssetScript = preload("res://scripts/core/sandbox_asset.gd")
const AudioSubsystemScript = preload("res://scripts/audio/audio_subsystem.gd")

var sim: WorldSimulationScript
var renderer: CosmicRendererScript
var camera: SandboxOrbitCameraScript
var hud: GodHUDScript
var audio: AudioSubsystemScript

var _is_pan_dragging: bool = false
var _is_painting_power: bool = false
var _paint_cooldown: float = 0.0
var _hovered_world_pos: Vector2 = Vector2(960.0, 540.0)
var _dragged_actor: Dictionary = {}


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	sim = WorldSimulationScript.new()
	sim.name = "WorldSimulation"
	add_child(sim)
	sim.setup_world(1337)

	renderer = CosmicRendererScript.new()
	renderer.name = "CosmicRenderer"
	add_child(renderer)
	renderer.setup(sim)

	camera = SandboxOrbitCameraScript.new()
	camera.name = "SandboxOrbitCamera"
	add_child(camera)
	if camera.is_inside_tree():
		camera.make_current()
	camera.view_mode_changed.connect(func(m: int) -> void: renderer.set_view_mode(m))

	hud = GodHUDScript.new()
	hud.name = "GodHUD"
	hud.camera = camera
	add_child(hud)
	hud.setup(sim)

	audio = AudioSubsystemScript.new()
	audio.name = "AudioSubsystem"
	add_child(audio)
	audio.setup(sim)

	hud.view_mode_requested.connect(_on_view_mode_requested)
	hud.focus_city_requested.connect(_on_focus_city_requested)
	hud.power_selected.connect(_on_power_selected)
	hud.camera_pan_requested.connect(func(coords: Vector2) -> void: camera.pan_to(coords))

	# Сразу обновим сканер центрального сектора
	hud.update_tile_scanner(sim.find_closest_tile_2d(Vector2(960.0, 540.0)), Vector2(960.0, 540.0))


func _process(delta: float) -> void:
	camera.step_camera(delta)

	if sim != null and sim.controlled_actor_id != -1:
		var move_dir := Vector2.ZERO
		if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
			move_dir.y -= 1.0
		if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
			move_dir.y += 1.0
		if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
			move_dir.x -= 1.0
		if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
			move_dir.x += 1.0
		var is_firing: bool = Input.is_key_pressed(KEY_SPACE)
		sim.step_controlled_actor(move_dir, delta, is_firing)

	if _is_painting_power and camera.view_mode == SandboxOrbitCameraScript.ViewMode.MODE_PLANET and hud.selected_power_id != "":
		if hud.selected_power_id == "power_divine_magnet":
			sim.apply_divine_magnet_at_pos(_hovered_world_pos, hud.current_brush_radius)
		else:
			_paint_cooldown -= delta
			if _paint_cooldown <= 0.0:
				var gp: SandboxAssetScript.GodPowerAsset = sim.assets.god_powers.get(hud.selected_power_id)
				if gp != null and gp.allow_hold_drag and gp.power_type == "brush_tile":
					sim.apply_god_power_at_pos(_hovered_world_pos, hud.selected_power_id, hud.current_brush_radius)
					_paint_cooldown = 0.12


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var ke: InputEventKey = event
		match ke.keycode:
			KEY_1:
				camera.set_view_mode(SandboxOrbitCameraScript.ViewMode.MODE_PLANET)
			KEY_2:
				camera.set_view_mode(SandboxOrbitCameraScript.ViewMode.MODE_STAR_DYSON)
			KEY_3:
				camera.set_view_mode(SandboxOrbitCameraScript.ViewMode.MODE_SYSTEM_OVERVIEW)
			KEY_SPACE:
				if sim.controlled_actor_id == -1:
					sim.paused = not sim.paused
					hud._refresh_telemetry_and_lists()
			KEY_TAB:
				hud.toggle_side_panels()
				if audio != null:
					audio.play_ui_sfx("ui_click")
			KEY_T:
				hud.toggle_codex_modal()
				if audio != null:
					audio.play_ui_sfx("ui_click")
			KEY_L:
				hud.toggle_laws_modal()
				if audio != null:
					audio.play_ui_sfx("ui_click")
			KEY_F9:
				hud.toggle_analytics_modal()
				if audio != null:
					audio.play_ui_sfx("ui_click")
			KEY_ESCAPE:
				if sim.controlled_actor_id != -1:
					sim.release_possession()
				elif hud._active_modal_id != "":
					hud.close_active_modal()
				else:
					hud._select_power("")
				if audio != null:
					audio.play_ui_sfx("ui_click")

	elif event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			camera.zoom_step(0.86)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			camera.zoom_step(1.16)
		elif mb.button_index == MOUSE_BUTTON_RIGHT or mb.button_index == MOUSE_BUTTON_MIDDLE:
			_is_pan_dragging = mb.pressed
		elif mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_hovered_world_pos = camera.screen_to_world(mb.position)
				if camera.view_mode == SandboxOrbitCameraScript.ViewMode.MODE_PLANET:
					if hud.selected_power_id != "":
						_is_painting_power = true
						_paint_cooldown = 0.15
						sim.apply_god_power_at_pos(_hovered_world_pos, hud.selected_power_id, hud.current_brush_radius)
					else:
						# В режиме Наблюдения проверяем, есть ли под курсором живой юнит для захвата Магнитом
						var actor: Dictionary = sim.find_closest_actor(_hovered_world_pos, 36.0)
						if not actor.is_empty():
							_dragged_actor = actor
							_dragged_actor["thought"] = "Переносится рукой Бога!"
						else:
							_is_pan_dragging = true
				else:
					_is_pan_dragging = true
			else:
				if not sim.magnet_held_actor_ids.is_empty():
					sim.release_divine_magnet(_hovered_world_pos)
				if not _dragged_actor.is_empty():
					var drop_tile: int = sim.find_closest_tile_2d(_hovered_world_pos)
					_dragged_actor["home_tile"] = drop_tile
					_dragged_actor["target_pos"] = _hovered_world_pos
					_dragged_actor["thought"] = "Осматривает новый остров"
					_dragged_actor = {}
				_is_painting_power = false
				_is_pan_dragging = false

	elif event is InputEventMouseMotion:
		var mm: InputEventMouseMotion = event
		if _is_pan_dragging:
			camera.orbit_drag(mm.relative)

		_hovered_world_pos = camera.screen_to_world(mm.position)
		if not _dragged_actor.is_empty():
			_dragged_actor["pos"] = _hovered_world_pos
			_dragged_actor["target_pos"] = _hovered_world_pos

		var t_idx: int = sim.find_closest_tile_2d(_hovered_world_pos)
		hud.update_tile_scanner(t_idx, _hovered_world_pos)

		var gp: SandboxAssetScript.GodPowerAsset = sim.assets.god_powers.get(hud.selected_power_id)
		if camera.view_mode == SandboxOrbitCameraScript.ViewMode.MODE_PLANET and gp != null and gp.power_type != "cosmic_action":
			var rad_px: float = sim.brush_radius_to_pixels(hud.current_brush_radius)
			renderer.set_cursor_brush_preview_2d(true, _hovered_world_pos, rad_px, gp.beam_color)
		else:
			renderer.set_cursor_brush_preview_2d(false, _hovered_world_pos, 60.0, Color.WHITE)


func _on_view_mode_requested(mode: int) -> void:
	camera.set_view_mode(mode)


func _on_focus_city_requested(city_dir: Vector3) -> void:
	camera.focus_on_planet_dir(city_dir, 1.85)


func _on_power_selected(power_id: String) -> void:
	if audio != null:
		audio.play_ui_sfx("ui_click")
	if power_id == "":
		renderer.set_cursor_brush_preview_2d(false, _hovered_world_pos, 60.0, Color.WHITE)
		return
	var gp: SandboxAssetScript.GodPowerAsset = sim.assets.god_powers.get(power_id)
	if gp != null and gp.power_type == "cosmic_action":
		if power_id == "power_dyson_ring" or power_id == "power_stellar_stabilizer":
			camera.set_view_mode(SandboxOrbitCameraScript.ViewMode.MODE_STAR_DYSON)
		elif power_id == "power_harvest_asteroids":
			camera.set_view_mode(SandboxOrbitCameraScript.ViewMode.MODE_SYSTEM_OVERVIEW)
		sim.apply_god_power_at_pos(Vector2(960.0, 540.0), power_id, hud.current_brush_radius)
