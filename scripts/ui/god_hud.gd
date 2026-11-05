class_name GodHUD
extends CanvasLayer

## Интерфейс Песочницы Бога «Kardashev Sandbox: Crucible of Stars»
## Вдохновлён док-панелью WorldBox v0.51.2 и телеметрией космических стратегий.
## Оставляет центральные >60% экрана полностью открытыми для 3D-сцены планеты и Сферы Дайсона.

signal power_selected(power_id: String)
signal brush_size_changed(radius: float)
signal view_mode_requested(mode: int)
signal focus_city_requested(city_dir: Vector3)
signal camera_pan_requested(coords: Vector2)

const WorldSimulationScript = preload("res://scripts/sim/world_simulation.gd")
const SandboxAssetScript = preload("res://scripts/core/sandbox_asset.gd")

var sim: WorldSimulationScript
var camera: Node = null # Ссылка на SandboxOrbitCamera для навигации click-to-pan
var selected_tab: String = "alchemy"
var selected_power_id: String = "power_cryo_comet"
var current_brush_radius: float = 0.22

# Узлы верхней панели
var _lbl_system_title: Label
var _lbl_resources: Label
var _lbl_star_dyson: Label
var _btn_pause: Button
var _btn_speed_1: Button
var _btn_speed_5: Button
var _btn_speed_25: Button

# Узлы левого инспектора и сканера тайла
var _vbox_cities: VBoxContainer
var _lbl_tile_scanner: RichTextLabel

# Узлы правого лога событий
var _rtl_event_log: RichTextLabel
var current_event_filter: String = "all"
var _filter_buttons: Dictionary = {}

# Узлы нижнего дока Божественных Сил
var _tab_buttons: Dictionary = {}
var _hbox_powers: HBoxContainer
var _lbl_power_desc: Label
var _brush_buttons: Array[Button] = []

# Единый менеджер модальных окон F9
var _modals: Dictionary = {}
var _active_modal_id: String = ""

var _modal_nodes: Dictionary:
	get: return _modals

var _event_filter_category: String:
	get: return current_event_filter

var _event_log_items: Array:
	get: return sim.event_log if sim != null else []

var _modal_codex: PanelContainer
var _rtl_codex_list: RichTextLabel

var _modal_laws: PanelContainer
var _vbox_laws_list: VBoxContainer

var _modal_city: PanelContainer
var _vbox_city_content: VBoxContainer

var _modal_actor: PanelContainer
var _vbox_actor_content: VBoxContainer

var _modal_culture: PanelContainer
var _vbox_culture_content: VBoxContainer

var _modal_analytics: PanelContainer
var _vbox_analytics_content: VBoxContainer

var _modal_world: PanelContainer
var _vbox_world_content: VBoxContainer
var _left_panel: PanelContainer
var _right_panel: PanelContainer
var side_panels_visible: bool = false
var renderer: Node = null
var _modal_backdrop: ColorRect = null
var _cam_mode_buttons: Dictionary = {}
var _btn_observe: Button = null
var current_view_mode: int = 0
var _wb_ui_cache: Dictionary = {}


func _load_wb_tex(res_path: String) -> ImageTexture:
	if _wb_ui_cache.has(res_path):
		return _wb_ui_cache[res_path]
	var abs_p: String = ProjectSettings.globalize_path(res_path)
	if FileAccess.file_exists(abs_p):
		var img := Image.load_from_file(abs_p)
		if img != null and not img.is_empty():
			var tex := ImageTexture.create_from_image(img)
			_wb_ui_cache[res_path] = tex
			return tex
	return null


func _get_power_wb_icon(pid: String) -> ImageTexture:
	var icon_file := "iconSpark.png"
	if pid.find("comet") != -1 or pid.find("rain") != -1:
		icon_file = "iconRain.png"
	elif pid.find("volcano") != -1 or pid.find("earthquake") != -1:
		icon_file = "iconEarthquake.png"
	elif pid.find("raise") != -1:
		icon_file = "iconShovelPlus.png"
	elif pid.find("lower") != -1:
		icon_file = "iconShovelMinus.png"
	elif pid.find("vortex") != -1 or pid.find("tornado") != -1:
		icon_file = "iconTornado.png"
	elif pid.find("monolith") != -1:
		icon_file = "iconMonolith.png"
	elif pid.find("storm") != -1 or pid.find("lightning") != -1:
		icon_file = "iconLightning.png"
	elif pid.find("spores") != -1 or pid.find("biomass") != -1:
		icon_file = "iconBiomass.png"
	elif pid.find("cyber") != -1:
		icon_file = "iconCybercore.png"
	elif pid.find("meteor") != -1:
		icon_file = "iconMeteorite.png"
	elif pid.find("savanna") != -1:
		icon_file = "iconSeedSavanna.png"
	elif pid.find("enchanted") != -1:
		icon_file = "iconSeedEnchanted.png"
	elif pid.find("corrupted") != -1:
		icon_file = "iconSeedCorrupted.png"
	elif pid.find("infernal") != -1:
		icon_file = "iconSeedInfernal.png"
	elif pid.find("crystal") != -1:
		icon_file = "iconSeedCrystal.png"
	elif pid.find("bloom") != -1 or pid.find("grass") != -1:
		icon_file = "iconSeedGrass.png"
	elif pid.find("stone") != -1:
		icon_file = "iconStone.png"
	elif pid.find("gold") != -1 and pid.find("age") == -1:
		icon_file = "iconGold.png"
	elif pid.find("gems") != -1:
		icon_file = "iconResGems.png"
	elif pid.find("abiogenesis") != -1 or pid.find("human") != -1:
		icon_file = "iconHumans.png"
	elif pid.find("mutagen") != -1 or pid.find("plague") != -1:
		icon_file = "iconPlague.png"
	elif pid.find("uplift") != -1 or pid.find("inspiration") != -1 or pid.find("eureka") != -1:
		icon_file = "iconInspiration.png"
	elif pid.find("golden_age") != -1 or pid.find("blessing") != -1:
		icon_file = "iconBlessing.png"
	elif pid.find("coffee") != -1:
		icon_file = "iconCoffee.png"
	elif pid.find("powerup") != -1:
		icon_file = "iconPowerup.png"
	elif pid.find("schism") != -1 or pid.find("war") != -1:
		icon_file = "iconWhisperOfWar.png"
	elif pid.find("colossus") != -1 or pid.find("crabzilla") != -1:
		icon_file = "iconCrabzilla.png"
	elif pid.find("dragon") != -1:
		icon_file = "iconDragon.png"
	elif pid.find("ufo") != -1:
		icon_file = "iconUfo.png"
	elif pid.find("alien") != -1:
		icon_file = "iconAlien.png"
	elif pid.find("time") != -1 or pid.find("chrono") != -1:
		icon_file = "iconClockXSonic.png"
	elif pid.find("grav") != -1 or pid.find("magnet") != -1:
		icon_file = "iconMagnet.png"
	elif pid.find("shield") != -1 or pid.find("entropy") != -1:
		icon_file = "iconShield.png"
	elif pid.find("quantum") != -1:
		icon_file = "iconAgeWonders.png"
	elif pid.find("solar") != -1 or pid.find("sails") != -1:
		icon_file = "iconAgeSun.png"
	elif pid.find("stellar") != -1 or pid.find("stabilizer") != -1:
		icon_file = "iconAgeHope.png"
	elif pid.find("antimatter") != -1 or pid.find("tsar") != -1:
		icon_file = "iconAntimatterBomb.png"
	elif pid.find("atomic") != -1:
		icon_file = "iconAtomicBomb.png"
	elif pid.find("supernova") != -1 or pid.find("heat_ray") != -1:
		icon_file = "iconHeatRay.png"
	elif pid.find("napalm") != -1 or pid.find("fire") != -1:
		icon_file = "iconFire.png"
	elif pid.find("acid") != -1:
		icon_file = "iconAcid.png"
	else:
		icon_file = "iconKnowledge.png"
	return _load_wb_tex("res://assets/worldbox/icons/" + icon_file)


func setup(simulation: WorldSimulationScript) -> void:
	sim = simulation
	_build_ui_tree()

	sim.telemetry_updated.connect(_refresh_telemetry_and_lists)
	sim.event_logged.connect(_on_event_logged)
	sim.supernova_cycle_triggered.connect(_on_supernova_cycle)

	_select_tab("alchemy")
	_select_power("power_cryo_comet")
	_refresh_telemetry_and_lists()
	_rebuild_event_log()


func toggle_side_panels() -> void:
	side_panels_visible = not side_panels_visible
	if _left_panel != null:
		_left_panel.visible = side_panels_visible
	if _right_panel != null:
		_right_panel.visible = side_panels_visible
	_update_cam_mode_button_styles()


func _process(_delta: float) -> void:
	var rend := _get_cosmic_renderer()
	if rend != null and rend.get("view_mode") != null:
		var vm: int = int(rend.get("view_mode"))
		if vm != current_view_mode:
			current_view_mode = vm
			_update_cam_mode_button_styles()


func _make_panel_style(bg_col: Color, border_col: Color, corner_r: int = 8) -> StyleBox:
	var win_tex: ImageTexture = _load_wb_tex("res://assets/worldbox/ui/windowBigNoTitle.png") if corner_r >= 10 else _load_wb_tex("res://assets/worldbox/ui/windowInnerSliced.png")
	if win_tex != null:
		var sbt := StyleBoxTexture.new()
		sbt.texture = win_tex
		var m_margin: float = 16.0 if corner_r >= 10 else 8.0
		sbt.texture_margin_left = m_margin
		sbt.texture_margin_right = m_margin
		sbt.texture_margin_top = m_margin
		sbt.texture_margin_bottom = m_margin
		sbt.content_margin_left = 14.0
		sbt.content_margin_right = 14.0
		sbt.content_margin_top = 10.0
		sbt.content_margin_bottom = 10.0
		# Сохраняем тёплый каменный оттенок рамки WorldBox с лёгким тонированием от border_col
		var stone_tint := Color(0.88, 0.90, 0.94, clampf(bg_col.a + 0.06, 0.88, 0.99)).lerp(border_col.lightened(0.25), 0.18)
		stone_tint.a = clampf(bg_col.a + 0.06, 0.88, 0.99)
		sbt.modulate_color = stone_tint
		return sbt

	var sb := StyleBoxFlat.new()
	sb.bg_color = bg_col
	sb.border_color = border_col
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(corner_r)
	sb.shadow_color = Color(0.0, 0.0, 0.0, 0.52)
	sb.shadow_size = 12
	sb.shadow_offset = Vector2(0.0, 4.0)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 9
	sb.content_margin_bottom = 9
	return sb


func _make_btn_style(bg_col: Color, border_col: Color, is_selected: bool = false) -> StyleBox:
	var btn_tex: ImageTexture = _load_wb_tex("res://assets/worldbox/ui/buttonSelected.png" if is_selected else "res://assets/worldbox/ui/button.png")
	if btn_tex != null:
		var sbt := StyleBoxTexture.new()
		sbt.texture = btn_tex
		sbt.texture_margin_left = 6.0
		sbt.texture_margin_right = 6.0
		sbt.texture_margin_top = 6.0
		sbt.texture_margin_bottom = 6.0
		sbt.content_margin_left = 9.0
		sbt.content_margin_right = 9.0
		sbt.content_margin_top = 4.0
		sbt.content_margin_bottom = 4.0
		var tint := Color(0.82, 0.86, 0.92, 0.96).lerp(border_col.lightened(0.20), 0.32 if is_selected else 0.18)
		sbt.modulate_color = tint
		return sbt

	var sb := StyleBoxFlat.new()
	sb.bg_color = bg_col
	sb.border_color = border_col
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(6)
	sb.shadow_color = Color(0.0, 0.0, 0.0, 0.28)
	sb.shadow_size = 3
	sb.shadow_offset = Vector2(0.0, 1.0)
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 5
	sb.content_margin_bottom = 5
	return sb


func _apply_btn_theme(btn: Button, bg_col: Color, border_col: Color, text_col: Color = Color(0.92, 0.96, 1.0)) -> void:
	var is_sel: bool = (border_col.a >= 0.96 or bg_col.r + bg_col.g + bg_col.b > 0.55)
	btn.add_theme_stylebox_override("normal", _make_btn_style(bg_col, border_col, is_sel))
	btn.add_theme_stylebox_override("hover", _make_btn_style(bg_col.lightened(0.14), border_col.lightened(0.25), true))
	btn.add_theme_stylebox_override("pressed", _make_btn_style(bg_col.darkened(0.12), border_col.lightened(0.35), true))
	btn.add_theme_stylebox_override("focus", _make_btn_style(bg_col.lightened(0.06), border_col.lightened(0.28), is_sel))
	btn.add_theme_color_override("font_color", text_col)
	btn.add_theme_color_override("font_hover_color", text_col.lightened(0.18))
	btn.add_theme_color_override("font_pressed_color", Color.WHITE)
	btn.add_theme_color_override("font_focus_color", text_col.lightened(0.12))
	btn.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.85))
	btn.add_theme_constant_override("outline_size", 2)


func _style_close_btn(btn: Button) -> void:
	btn.add_theme_font_size_override("font_size", 12)
	var close_ic: ImageTexture = _load_wb_tex("res://assets/worldbox/ui/iconClose.png")
	if close_ic != null:
		btn.icon = close_ic
	_apply_btn_theme(
		btn,
		Color(0.28, 0.08, 0.12, 0.96),
		Color(0.95, 0.36, 0.42, 0.92),
		Color(1.0, 0.90, 0.90)
	)


func _style_progress_bar(bar: ProgressBar, fill_col: Color, bg_col: Color = Color(0.04, 0.07, 0.13, 0.95)) -> void:
	bar.custom_minimum_size.y = maxf(bar.custom_minimum_size.y, 20.0)
	var sb_bg := StyleBoxFlat.new()
	sb_bg.bg_color = bg_col
	sb_bg.border_color = Color(fill_col.r * 0.45, fill_col.g * 0.45, fill_col.b * 0.45, 0.65)
	sb_bg.set_border_width_all(1)
	sb_bg.set_corner_radius_all(5)

	var sb_fill := StyleBoxFlat.new()
	sb_fill.bg_color = Color(fill_col.r * 0.58, fill_col.g * 0.58, fill_col.b * 0.58, 0.92)
	sb_fill.border_color = fill_col.lightened(0.25)
	sb_fill.set_border_width_all(1)
	sb_fill.set_corner_radius_all(5)

	bar.add_theme_stylebox_override("background", sb_bg)
	bar.add_theme_stylebox_override("fill", sb_fill)
	bar.add_theme_font_size_override("font_size", 11)
	bar.add_theme_color_override("font_color", Color(0.96, 0.99, 1.0))
	bar.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.85))
	bar.add_theme_constant_override("outline_size", 3)


func _style_check_button(cb: CheckButton, accent_col: Color = Color(0.35, 0.88, 1.0)) -> void:
	cb.add_theme_font_size_override("font_size", 13)
	var bg := Color(0.06, 0.10, 0.18, 0.88)
	var brd := Color(accent_col.r, accent_col.g, accent_col.b, 0.45)
	_apply_btn_theme(cb, bg, brd, Color(0.90, 0.95, 1.0))


func _build_ui_tree() -> void:
	var root := Control.new()
	root.name = "HUDRoot"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	var panel_bg := Color(0.04, 0.06, 0.10, 0.86)
	var panel_border := Color(0.18, 0.42, 0.65, 0.70)

	# ==========================================================================
	# 1. ВЕРХНЯЯ ПАНЕЛЬ ТЕЛЕМЕТРИИ
	# ==========================================================================
	var top_panel := PanelContainer.new()
	top_panel.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top_panel.offset_left = 14
	top_panel.offset_right = -14
	top_panel.offset_top = 10
	top_panel.offset_bottom = 68
	top_panel.add_theme_stylebox_override("panel", _make_panel_style(panel_bg, panel_border))
	root.add_child(top_panel)

	var top_hbox := HBoxContainer.new()
	top_hbox.add_theme_constant_override("separation", 5)
	top_panel.add_child(top_hbox)

	_lbl_system_title = Label.new()
	_lbl_system_title.add_theme_font_size_override("font_size", 12)
	_lbl_system_title.add_theme_color_override("font_color", Color(0.92, 0.96, 1.0))
	top_hbox.add_child(_lbl_system_title)

	var sep1 := VSeparator.new()
	top_hbox.add_child(sep1)

	_lbl_resources = Label.new()
	_lbl_resources.add_theme_font_size_override("font_size", 12)
	_lbl_resources.add_theme_color_override("font_color", Color(0.45, 0.95, 0.85))
	_lbl_resources.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_hbox.add_child(_lbl_resources)

	_lbl_star_dyson = Label.new()
	_lbl_star_dyson.add_theme_font_size_override("font_size", 12)
	_lbl_star_dyson.add_theme_color_override("font_color", Color(1.0, 0.84, 0.38))
	top_hbox.add_child(_lbl_star_dyson)

	var sep2 := VSeparator.new()
	top_hbox.add_child(sep2)

	# Кнопки ракурса камеры
	var cam_box := HBoxContainer.new()
	cam_box.add_theme_constant_override("separation", 3)
	top_hbox.add_child(cam_box)

	var cam_modes := [
		{"title": "1:Карта", "mode": 0},
		{"title": "2:Сфера", "mode": 1},
		{"title": "3:Система", "mode": 2}
	]
	for cm in cam_modes:
		var b := Button.new()
		b.text = cm["title"]
		b.add_theme_font_size_override("font_size", 11)
		_apply_btn_theme(b, Color(0.08, 0.14, 0.24, 0.92), Color(0.25, 0.55, 0.85, 0.82))
		var m_val: int = cm["mode"]
		b.pressed.connect(func() -> void:
			current_view_mode = m_val
			_update_cam_mode_button_styles()
			view_mode_requested.emit(m_val)
		)
		cam_box.add_child(b)
		_cam_mode_buttons[m_val] = b

	# Кнопки скорости симуляции
	var spd_box := HBoxContainer.new()
	spd_box.add_theme_constant_override("separation", 3)
	top_hbox.add_child(spd_box)

	_btn_pause = _create_top_action_btn("⏸", func() -> void: _set_sim_speed(0.0), "iconPause.png")
	_btn_speed_1 = _create_top_action_btn("1×", func() -> void: _set_sim_speed(1.0), "iconClockX1.png")
	_btn_speed_5 = _create_top_action_btn("5×", func() -> void: _set_sim_speed(5.0), "iconClockX5.png")
	_btn_speed_25 = _create_top_action_btn("25×", func() -> void: _set_sim_speed(25.0), "iconClockXSonic.png")
	spd_box.add_child(_btn_pause)
	spd_box.add_child(_btn_speed_1)
	spd_box.add_child(_btn_speed_5)
	spd_box.add_child(_btn_speed_25)

	# Кнопки Списков/Хроники, Кодекса, Законов Мира, Мира/Сохранений и Глобальной Аналитики
	var btn_panels := _create_top_action_btn("📋Tab", func() -> void: toggle_side_panels(), "iconWorldLog.png")
	var btn_world := _create_top_action_btn("🌍Мир", func() -> void: toggle_world_modal(), "iconWorldInfo.png")
	var btn_codex := _create_top_action_btn("📜Кодекс", func() -> void: toggle_codex_modal(), "iconKnowledge.png")
	var btn_laws := _create_top_action_btn("⚖Законы", func() -> void: toggle_laws_modal(), "iconWorldLaws.png")
	var btn_analytics := _create_top_action_btn("📊F9", func() -> void: toggle_analytics_modal(), "iconStatistics.png")
	top_hbox.add_child(btn_panels)
	top_hbox.add_child(btn_world)
	top_hbox.add_child(btn_codex)
	top_hbox.add_child(btn_laws)
	top_hbox.add_child(btn_analytics)

	# ==========================================================================
	# 2. ЛЕВАЯ ПАНЕЛЬ: ИНСПЕКТОР ПОЛИСОВ, ВИДОВ И СКАНЕР КУРСОРА (скрываемая по Tab)
	# ==========================================================================
	var left_panel := PanelContainer.new()
	_left_panel = left_panel
	left_panel.visible = side_panels_visible
	left_panel.anchor_left = 0.0
	left_panel.anchor_top = 0.0
	left_panel.anchor_bottom = 1.0
	left_panel.offset_left = 14
	left_panel.offset_right = 355
	left_panel.offset_top = 78
	left_panel.offset_bottom = -175
	left_panel.add_theme_stylebox_override("panel", _make_panel_style(panel_bg, panel_border))
	root.add_child(left_panel)

	var left_vbox := VBoxContainer.new()
	left_vbox.add_theme_constant_override("separation", 8)
	left_panel.add_child(left_vbox)

	var lbl_civ_header := Label.new()
	lbl_civ_header.text = "НАУЧНЫЕ ПОЛИСЫ И ЦИВИЛИЗАЦИИ"
	lbl_civ_header.add_theme_font_size_override("font_size", 13)
	lbl_civ_header.add_theme_color_override("font_color", Color(0.55, 0.85, 1.0))
	left_vbox.add_child(lbl_civ_header)

	var scroll_cities := ScrollContainer.new()
	scroll_cities.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left_vbox.add_child(scroll_cities)

	_vbox_cities = VBoxContainer.new()
	_vbox_cities.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_vbox_cities.add_theme_constant_override("separation", 6)
	scroll_cities.add_child(_vbox_cities)

	left_vbox.add_child(HSeparator.new())

	var lbl_scan_header := Label.new()
	lbl_scan_header.text = "СКАНЕР СЕКТОРА ПОД КУРСОРОМ"
	lbl_scan_header.add_theme_font_size_override("font_size", 12)
	lbl_scan_header.add_theme_color_override("font_color", Color(0.55, 0.85, 1.0))
	left_vbox.add_child(lbl_scan_header)

	_lbl_tile_scanner = RichTextLabel.new()
	_lbl_tile_scanner.bbcode_enabled = true
	_lbl_tile_scanner.fit_content = true
	_lbl_tile_scanner.custom_minimum_size = Vector2(0, 105)
	_lbl_tile_scanner.add_theme_font_size_override("normal_font_size", 12)
	_lbl_tile_scanner.meta_clicked.connect(_on_event_log_meta_clicked)
	left_vbox.add_child(_lbl_tile_scanner)

	# ==========================================================================
	# 3. ПРАВАЯ ПАНЕЛЬ: ЖУРНАЛ ОТКРОВЕНИЙ И ИСТОРИИ МИРА (скрываемая по Tab)
	# ==========================================================================
	var right_panel := PanelContainer.new()
	_right_panel = right_panel
	right_panel.visible = side_panels_visible
	right_panel.anchor_left = 1.0
	right_panel.anchor_right = 1.0
	right_panel.anchor_top = 0.0
	right_panel.anchor_bottom = 1.0
	right_panel.offset_left = -385
	right_panel.offset_right = -14
	right_panel.offset_top = 78
	right_panel.offset_bottom = -175
	right_panel.add_theme_stylebox_override("panel", _make_panel_style(panel_bg, panel_border))
	root.add_child(right_panel)

	var right_vbox := VBoxContainer.new()
	right_vbox.add_theme_constant_override("separation", 6)
	right_panel.add_child(right_vbox)

	var lbl_log_header := Label.new()
	lbl_log_header.text = "ХРОНИКА ЭВОЛЮЦИИ И НАУЧНЫХ ОТКРЫТИЙ"
	lbl_log_header.add_theme_font_size_override("font_size", 13)
	lbl_log_header.add_theme_color_override("font_color", Color(0.55, 0.85, 1.0))
	right_vbox.add_child(lbl_log_header)

	# Фильтры категорий журнала
	var filter_scroll := ScrollContainer.new()
	filter_scroll.custom_minimum_size = Vector2(0, 32)
	filter_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	filter_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right_vbox.add_child(filter_scroll)

	var filter_hbox := HBoxContainer.new()
	filter_hbox.add_theme_constant_override("separation", 3)
	filter_scroll.add_child(filter_hbox)

	var categories := [
		{"id": "all", "label": "ВСЕ"},
		{"id": "diplomacy", "label": "ДИПЛОМАТИЯ"},
		{"id": "war", "label": "ВОЙНЫ"},
		{"id": "megastructures", "label": "СФЕРА/КОСМОС"},
		{"id": "alchemy", "label": "АЛХИМИЯ"},
		{"id": "god_powers", "label": "СИЛЫ БОГА"},
		{"id": "science", "label": "НАУКА"}
	]
	for cat in categories:
		var c_id: String = cat["id"]
		var btn := Button.new()
		btn.text = cat["label"]
		btn.add_theme_font_size_override("font_size", 9)
		_apply_btn_theme(btn, Color(0.08, 0.14, 0.22, 0.9), Color(0.25, 0.55, 0.85, 0.7))
		btn.pressed.connect(func() -> void: set_event_filter(c_id))
		filter_hbox.add_child(btn)
		_filter_buttons[c_id] = btn

	_rtl_event_log = RichTextLabel.new()
	_rtl_event_log.bbcode_enabled = true
	_rtl_event_log.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_rtl_event_log.scroll_following = false
	_rtl_event_log.add_theme_font_size_override("normal_font_size", 12)
	_rtl_event_log.meta_clicked.connect(_on_event_log_meta_clicked)
	right_vbox.add_child(_rtl_event_log)

	# ==========================================================================
	# 4. НИЖНЯЯ ДОК-ПАНЕЛЬ БОЖЕСТВЕННЫХ СИЛ (В СТИЛЕ WORLDBOX)
	# ==========================================================================
	var bottom_panel := PanelContainer.new()
	bottom_panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bottom_panel.offset_left = 14
	bottom_panel.offset_right = -14
	bottom_panel.offset_top = -162
	bottom_panel.offset_bottom = -10
	bottom_panel.add_theme_stylebox_override("panel", _make_panel_style(Color(0.03, 0.05, 0.09, 0.92), Color(0.25, 0.58, 0.88, 0.85)))
	root.add_child(bottom_panel)

	var bottom_vbox := VBoxContainer.new()
	bottom_vbox.add_theme_constant_override("separation", 8)
	bottom_panel.add_child(bottom_vbox)

	# Строка вкладок и размеров кисти
	var tabs_row := HBoxContainer.new()
	tabs_row.add_theme_constant_override("separation", 10)
	bottom_vbox.add_child(tabs_row)

	var tab_defs := [
		{"id": "alchemy", "title": "1. АЛХИМИЯ И БИОМЫ", "icon": "icon_tab_drawings.png"},
		{"id": "life", "title": "2. ЖИЗНЬ И ВОЗВЫШЕНИЕ", "icon": "icon_tab_creatures.png"},
		{"id": "lenses", "title": "3. ЛИНЗЫ КОНСТАНТ", "icon": "icon_tab_noosphere.png"},
		{"id": "cosmos", "title": "4. КОСМОС И СФЕРА ДАЙСОНА", "icon": "icon_tab_other.png"}
	]
	for td in tab_defs:
		var tb := Button.new()
		tb.text = td["title"]
		tb.add_theme_font_size_override("font_size", 12)
		var tab_ic: ImageTexture = _load_wb_tex("res://assets/worldbox/icons/" + str(td["icon"]))
		if tab_ic != null:
			tb.icon = tab_ic
		var tid: String = td["id"]
		tb.pressed.connect(func() -> void: _select_tab(tid))
		tabs_row.add_child(tb)
		_tab_buttons[tid] = tb

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tabs_row.add_child(spacer)

	var lbl_brush := Label.new()
	lbl_brush.text = "Кисть:"
	lbl_brush.add_theme_font_size_override("font_size", 13)
	lbl_brush.add_theme_color_override("font_color", Color(0.75, 0.88, 1.0))
	tabs_row.add_child(lbl_brush)

	var brush_defs := [
		{"title": "Точечная", "rad": 0.12, "icon": "brush_circ_1.png"},
		{"title": "Средняя", "rad": 0.22, "icon": "brush_circ_5.png"},
		{"title": "Макро-Зона", "rad": 0.36, "icon": "brush_circ_15.png"}
	]
	for bd in brush_defs:
		var bb := Button.new()
		bb.text = bd["title"]
		bb.add_theme_font_size_override("font_size", 11)
		var br_ic: ImageTexture = _load_wb_tex("res://assets/worldbox/icons/" + str(bd["icon"]))
		if br_ic != null:
			bb.icon = br_ic
			bb.expand_icon = true
			bb.custom_minimum_size = Vector2(92, 30)
		var r_val: float = bd["rad"]
		bb.pressed.connect(func() -> void:
			current_brush_radius = r_val
			brush_size_changed.emit(r_val)
			_update_brush_button_styles()
		)
		tabs_row.add_child(bb)
		_brush_buttons.append(bb)

	var btn_observe := Button.new()
	_btn_observe = btn_observe
	btn_observe.text = "Наблюдение (Инспектор)"
	btn_observe.add_theme_font_size_override("font_size", 11)
	var obs_ic: ImageTexture = _load_wb_tex("res://assets/worldbox/icons/iconBrowse.png")
	if obs_ic != null:
		btn_observe.icon = obs_ic
	_apply_btn_theme(btn_observe, Color(0.08, 0.14, 0.24, 0.92), Color(0.32, 0.68, 0.95, 0.80))
	btn_observe.pressed.connect(func() -> void: _select_power(""))
	tabs_row.add_child(btn_observe)

	# Строка кнопок самих Божественных Сил
	var powers_scroll := ScrollContainer.new()
	powers_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	powers_scroll.custom_minimum_size = Vector2(0, 52)
	bottom_vbox.add_child(powers_scroll)

	_hbox_powers = HBoxContainer.new()
	_hbox_powers.add_theme_constant_override("separation", 6)
	powers_scroll.add_child(_hbox_powers)

	# Строка описания выбранной Божественной Силы
	_lbl_power_desc = Label.new()
	_lbl_power_desc.add_theme_font_size_override("font_size", 13)
	_lbl_power_desc.add_theme_color_override("font_color", Color(0.75, 0.90, 1.0))
	bottom_vbox.add_child(_lbl_power_desc)

	# ==========================================================================
	# 5. МОДАЛЬНЫЕ ОКНА (КОДЕКС БЕСКОНЕЧНОЙ НАУКИ И ЗАКОНЫ МИРА)
	# ==========================================================================
	_build_modals(root)
	_update_brush_button_styles()
	_update_cam_mode_button_styles()
	_update_speed_button_styles()


func _create_top_action_btn(txt: String, cb: Callable, icon_file: String = "") -> Button:
	var b := Button.new()
	b.text = txt
	b.add_theme_font_size_override("font_size", 11)
	if icon_file != "":
		var ic: ImageTexture = _load_wb_tex("res://assets/worldbox/icons/" + icon_file)
		if ic != null:
			b.icon = ic
			b.expand_icon = true
			b.custom_minimum_size.y = 28
	_apply_btn_theme(b, Color(0.10, 0.16, 0.26, 0.95), Color(0.28, 0.62, 0.92, 0.85))
	b.pressed.connect(cb)
	return b


func _build_modals(root: Control) -> void:
	# Полупрозрачное виньетирование фона под активным модальным окном
	_modal_backdrop = ColorRect.new()
	_modal_backdrop.name = "ModalBackdrop"
	_modal_backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	_modal_backdrop.color = Color(0.01, 0.02, 0.05, 0.52)
	_modal_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_modal_backdrop.visible = false
	root.add_child(_modal_backdrop)

	# 1. Модальное окно Кодекса Науки
	_modal_codex = PanelContainer.new()
	_modal_codex.name = "ModalCodex"
	_modal_codex.visible = false
	_modal_codex.anchor_left = 0.22
	_modal_codex.anchor_right = 0.78
	_modal_codex.anchor_top = 0.12
	_modal_codex.anchor_bottom = 0.76
	_modal_codex.add_theme_stylebox_override("panel", _make_panel_style(Color(0.03, 0.05, 0.11, 0.96), Color(0.30, 0.82, 1.0, 0.95), 10))
	root.add_child(_modal_codex)
	register_modal("codex", _modal_codex)

	var codex_vbox := VBoxContainer.new()
	codex_vbox.add_theme_constant_override("separation", 10)
	_modal_codex.add_child(codex_vbox)

	var c_head := HBoxContainer.new()
	codex_vbox.add_child(c_head)
	var lbl_c := Label.new()
	lbl_c.text = "📜 КОДЕКС АРХИТЕКТОРА: ОТКРЫТЫЕ ФУНДАМЕНТАЛЬНЫЕ ЗАКОНЫ И ТЕОРИИ"
	lbl_c.add_theme_font_size_override("font_size", 16)
	lbl_c.add_theme_color_override("font_color", Color(0.35, 0.95, 1.0))
	lbl_c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c_head.add_child(lbl_c)

	var btn_close_c := Button.new()
	btn_close_c.text = "Закрыть [X]"
	_style_close_btn(btn_close_c)
	btn_close_c.pressed.connect(func() -> void: close_active_modal())
	c_head.add_child(btn_close_c)

	_rtl_codex_list = RichTextLabel.new()
	_rtl_codex_list.bbcode_enabled = true
	_rtl_codex_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_rtl_codex_list.add_theme_font_size_override("normal_font_size", 13)
	codex_vbox.add_child(_rtl_codex_list)

	# 2. Модальное окно Законов Мира (WorldLaws)
	_modal_laws = PanelContainer.new()
	_modal_laws.name = "ModalLaws"
	_modal_laws.visible = false
	_modal_laws.anchor_left = 0.26
	_modal_laws.anchor_right = 0.74
	_modal_laws.anchor_top = 0.15
	_modal_laws.anchor_bottom = 0.72
	_modal_laws.add_theme_stylebox_override("panel", _make_panel_style(Color(0.03, 0.05, 0.11, 0.96), Color(1.0, 0.78, 0.28, 0.95), 10))
	root.add_child(_modal_laws)
	register_modal("laws", _modal_laws)

	var laws_vbox := VBoxContainer.new()
	laws_vbox.add_theme_constant_override("separation", 10)
	_modal_laws.add_child(laws_vbox)

	var l_head := HBoxContainer.new()
	laws_vbox.add_child(l_head)
	var lbl_l := Label.new()
	lbl_l.text = "⚖ ЗАКОНЫ МИРОЗДАНИЯ (WORLD LAWS — АРХИТЕКТУРА WORLDBOX)"
	lbl_l.add_theme_font_size_override("font_size", 16)
	lbl_l.add_theme_color_override("font_color", Color(1.0, 0.85, 0.35))
	lbl_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l_head.add_child(lbl_l)

	var btn_close_l := Button.new()
	btn_close_l.text = "Закрыть [X]"
	_style_close_btn(btn_close_l)
	btn_close_l.pressed.connect(func() -> void: close_active_modal())
	l_head.add_child(btn_close_l)

	var laws_scroll := ScrollContainer.new()
	laws_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	laws_vbox.add_child(laws_scroll)

	_vbox_laws_list = VBoxContainer.new()
	_vbox_laws_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_vbox_laws_list.add_theme_constant_override("separation", 8)
	laws_scroll.add_child(_vbox_laws_list)

	# 3. Модальное окно Инспектора Полиса (Polis Inspector F9)
	_modal_city = PanelContainer.new()
	_modal_city.name = "ModalCity"
	_modal_city.visible = false
	_modal_city.anchor_left = 0.18
	_modal_city.anchor_right = 0.82
	_modal_city.anchor_top = 0.08
	_modal_city.anchor_bottom = 0.88
	_modal_city.add_theme_stylebox_override("panel", _make_panel_style(Color(0.03, 0.06, 0.12, 0.97), Color(0.35, 0.85, 1.0, 0.95), 10))
	root.add_child(_modal_city)
	register_modal("city", _modal_city)

	var city_root_vb := VBoxContainer.new()
	city_root_vb.add_theme_constant_override("separation", 8)
	_modal_city.add_child(city_root_vb)

	var city_header := HBoxContainer.new()
	city_root_vb.add_child(city_header)
	var city_title := Label.new()
	city_title.text = "🏛 ИНСПЕКТОР НАУЧНОГО ПОЛИСА"
	city_title.add_theme_font_size_override("font_size", 15)
	city_title.add_theme_color_override("font_color", Color(0.4, 0.9, 1.0))
	city_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	city_header.add_child(city_title)
	var btn_close_city := Button.new()
	btn_close_city.text = "Закрыть [X]"
	_style_close_btn(btn_close_city)
	btn_close_city.pressed.connect(func() -> void: close_active_modal())
	city_header.add_child(btn_close_city)

	var city_scroll := ScrollContainer.new()
	city_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	city_root_vb.add_child(city_scroll)

	_vbox_city_content = VBoxContainer.new()
	_vbox_city_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_vbox_city_content.add_theme_constant_override("separation", 10)
	city_scroll.add_child(_vbox_city_content)

	# 4. Модальное окно Инспектора Актера (Actor Inspector F9)
	_modal_actor = PanelContainer.new()
	_modal_actor.name = "ModalActor"
	_modal_actor.visible = false
	_modal_actor.anchor_left = 0.28
	_modal_actor.anchor_right = 0.72
	_modal_actor.anchor_top = 0.15
	_modal_actor.anchor_bottom = 0.78
	_modal_actor.add_theme_stylebox_override("panel", _make_panel_style(Color(0.04, 0.06, 0.12, 0.97), Color(1.0, 0.85, 0.35, 0.95), 10))
	root.add_child(_modal_actor)
	register_modal("actor", _modal_actor)

	var actor_root_vb := VBoxContainer.new()
	actor_root_vb.add_theme_constant_override("separation", 8)
	_modal_actor.add_child(actor_root_vb)

	var actor_header := HBoxContainer.new()
	actor_root_vb.add_child(actor_header)
	var actor_title := Label.new()
	actor_title.text = "👤 ИНСПЕКТОР СУЩЕСТВА (2D ACTOR)"
	actor_title.add_theme_font_size_override("font_size", 15)
	actor_title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.35))
	actor_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actor_header.add_child(actor_title)
	var btn_close_actor := Button.new()
	btn_close_actor.text = "Закрыть [X]"
	_style_close_btn(btn_close_actor)
	btn_close_actor.pressed.connect(func() -> void: close_active_modal())
	actor_header.add_child(btn_close_actor)

	var actor_scroll := ScrollContainer.new()
	actor_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	actor_root_vb.add_child(actor_scroll)

	_vbox_actor_content = VBoxContainer.new()
	_vbox_actor_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_vbox_actor_content.add_theme_constant_override("separation", 10)
	actor_scroll.add_child(_vbox_actor_content)

	# 5. Модальное окно Инспектора Культуры (Culture Inspector F9)
	_modal_culture = PanelContainer.new()
	_modal_culture.name = "ModalCulture"
	_modal_culture.visible = false
	_modal_culture.anchor_left = 0.22
	_modal_culture.anchor_right = 0.78
	_modal_culture.anchor_top = 0.12
	_modal_culture.anchor_bottom = 0.82
	_modal_culture.add_theme_stylebox_override("panel", _make_panel_style(Color(0.04, 0.06, 0.12, 0.97), Color(0.4, 0.95, 0.65, 0.95), 10))
	root.add_child(_modal_culture)
	register_modal("culture", _modal_culture)

	var cult_root_vb := VBoxContainer.new()
	cult_root_vb.add_theme_constant_override("separation", 8)
	_modal_culture.add_child(cult_root_vb)

	var cult_header := HBoxContainer.new()
	cult_root_vb.add_child(cult_header)
	var cult_title := Label.new()
	cult_title.text = "🏛 ИНСПЕКТОР КУЛЬТУРЫ И ИДЕОЛОГИИ"
	cult_title.add_theme_font_size_override("font_size", 15)
	cult_title.add_theme_color_override("font_color", Color(0.4, 0.95, 0.65))
	cult_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cult_header.add_child(cult_title)
	var btn_close_cult := Button.new()
	btn_close_cult.text = "Закрыть [X]"
	_style_close_btn(btn_close_cult)
	btn_close_cult.pressed.connect(func() -> void: close_active_modal())
	cult_header.add_child(btn_close_cult)

	var cult_scroll := ScrollContainer.new()
	cult_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cult_root_vb.add_child(cult_scroll)

	_vbox_culture_content = VBoxContainer.new()
	_vbox_culture_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_vbox_culture_content.add_theme_constant_override("separation", 10)
	cult_scroll.add_child(_vbox_culture_content)

	# 6. Модальное окно Глобальной Аналитики Мира (Analytics Panel F9)
	_modal_analytics = PanelContainer.new()
	_modal_analytics.name = "ModalAnalytics"
	_modal_analytics.visible = false
	_modal_analytics.anchor_left = 0.12
	_modal_analytics.anchor_right = 0.88
	_modal_analytics.anchor_top = 0.08
	_modal_analytics.anchor_bottom = 0.90
	_modal_analytics.add_theme_stylebox_override("panel", _make_panel_style(Color(0.02, 0.04, 0.09, 0.98), Color(0.25, 0.75, 1.0, 0.95), 12))
	root.add_child(_modal_analytics)
	register_modal("analytics", _modal_analytics)

	var ana_root_vb := VBoxContainer.new()
	ana_root_vb.add_theme_constant_override("separation", 8)
	_modal_analytics.add_child(ana_root_vb)

	var ana_header := HBoxContainer.new()
	ana_root_vb.add_child(ana_header)
	var ana_title := Label.new()
	ana_title.text = "📊 КАРДАШЁВСКАЯ ТЕЛЕМЕТРИЯ И АНАЛИТИКА МИРА"
	ana_title.add_theme_font_size_override("font_size", 16)
	ana_title.add_theme_color_override("font_color", Color(0.35, 0.95, 1.0))
	ana_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ana_header.add_child(ana_title)
	var btn_close_ana := Button.new()
	btn_close_ana.text = "Закрыть [X]"
	_style_close_btn(btn_close_ana)
	btn_close_ana.pressed.connect(func() -> void: close_active_modal())
	ana_header.add_child(btn_close_ana)

	var ana_scroll := ScrollContainer.new()
	ana_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	ana_root_vb.add_child(ana_scroll)

	_vbox_analytics_content = VBoxContainer.new()
	_vbox_analytics_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_vbox_analytics_content.add_theme_constant_override("separation", 10)
	ana_scroll.add_child(_vbox_analytics_content)

	# 7. Модальное окно Управления Миром, Эпохами, Слоями и Сохранениями (World & Ages Modal)
	_modal_world = PanelContainer.new()
	_modal_world.name = "ModalWorld"
	_modal_world.visible = false
	_modal_world.anchor_left = 0.16
	_modal_world.anchor_right = 0.84
	_modal_world.anchor_top = 0.09
	_modal_world.anchor_bottom = 0.87
	_modal_world.add_theme_stylebox_override("panel", _make_panel_style(Color(0.03, 0.05, 0.11, 0.97), Color(0.35, 0.95, 0.72, 0.95), 10))
	root.add_child(_modal_world)
	register_modal("world", _modal_world)

	var world_root_vb := VBoxContainer.new()
	world_root_vb.add_theme_constant_override("separation", 8)
	_modal_world.add_child(world_root_vb)

	var world_header := HBoxContainer.new()
	world_root_vb.add_child(world_header)
	var world_title := Label.new()
	world_title.text = "🌍 ГЕНЕРАТОР МИРА, КОСМИЧЕСКИЕ ЭПОХИ, СЛОИ И СОХРАНЕНИЯ"
	world_title.add_theme_font_size_override("font_size", 15)
	world_title.add_theme_color_override("font_color", Color(0.4, 0.95, 0.75))
	world_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	world_header.add_child(world_title)
	var btn_close_world := Button.new()
	btn_close_world.text = "Закрыть [X]"
	_style_close_btn(btn_close_world)
	btn_close_world.pressed.connect(func() -> void: close_active_modal())
	world_header.add_child(btn_close_world)

	var world_scroll := ScrollContainer.new()
	world_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	world_root_vb.add_child(world_scroll)

	_vbox_world_content = VBoxContainer.new()
	_vbox_world_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_vbox_world_content.add_theme_constant_override("separation", 10)
	world_scroll.add_child(_vbox_world_content)


func register_modal(id: String, panel: PanelContainer) -> void:
	_modals[id] = panel
	panel.visible = false


func open_modal(id: String, target_param: Variant = null) -> void:
	for mid in _modals.keys():
		var p: PanelContainer = _modals[mid]
		if p != null:
			p.visible = (mid == id)
	_active_modal_id = id if _modals.has(id) else ""
	if _modal_backdrop != null:
		_modal_backdrop.visible = (_active_modal_id != "")
	if not _modals.has(id):
		return
	match id:
		"city":
			_populate_city_inspector(int(target_param) if target_param != null else -1)
		"actor":
			_populate_actor_inspector(int(target_param) if target_param != null else -1)
		"culture":
			_populate_culture_inspector(int(target_param) if target_param != null else -1)
		"analytics":
			_populate_analytics_panel()
		"codex":
			_refresh_codex_modal()
		"laws":
			_refresh_laws_modal()
		"world":
			_populate_world_modal()


func close_active_modal() -> void:
	if _active_modal_id != "" and _modals.has(_active_modal_id):
		var p: PanelContainer = _modals[_active_modal_id]
		if p != null:
			p.visible = false
	_active_modal_id = ""
	if _modal_backdrop != null:
		_modal_backdrop.visible = false


func toggle_modal(id: String, target_param: Variant = null) -> void:
	if _active_modal_id == id:
		close_active_modal()
	else:
		open_modal(id, target_param)


func open_city_inspector(city_id: int) -> void:
	open_modal("city", city_id)


func open_actor_inspector(actor_id: int) -> void:
	open_modal("actor", actor_id)


func open_culture_inspector(culture_id: int) -> void:
	open_modal("culture", culture_id)


func toggle_analytics_modal() -> void:
	toggle_modal("analytics")


func toggle_codex_modal() -> void:
	toggle_modal("codex")


func toggle_laws_modal() -> void:
	toggle_modal("laws")


func toggle_world_modal() -> void:
	toggle_modal("world")


func _get_cosmic_renderer() -> Node:
	if renderer != null and is_instance_valid(renderer):
		return renderer
	if get_parent() != null:
		renderer = get_parent().find_child("CosmicRenderer", true, false)
	return renderer


func _populate_world_modal() -> void:
	if _vbox_world_content == null or sim == null:
		return
	for ch in _vbox_world_content.get_children():
		ch.queue_free()

	# 1. Космические Эпохи (World Ages)
	var age_sec := Label.new()
	var cur_age := sim.get_current_world_age_asset()
	age_sec.text = "1. КОСМИЧЕСКИЕ ЭПОХИ МИРА (Текущая: %s)" % (cur_age.title if cur_age != null else sim.current_age_id)
	age_sec.add_theme_font_size_override("font_size", 13)
	age_sec.add_theme_color_override("font_color", Color(1.0, 0.85, 0.35))
	_vbox_world_content.add_child(age_sec)

	var age_hb := HFlowContainer.new()
	age_hb.add_theme_constant_override("h_separation", 8)
	age_hb.add_theme_constant_override("v_separation", 8)
	_vbox_world_content.add_child(age_hb)
	for wa in sim.assets.world_age_list:
		var ab := Button.new()
		var aid: String = wa.id
		var is_cur_age: bool = (aid == sim.current_age_id)
		ab.text = ("★ " if is_cur_age else "") + wa.title
		ab.add_theme_font_size_override("font_size", 12)
		var age_ic_map := {
			"age_hope": "iconAgeHope.png",
			"age_sun": "iconAgeSun.png",
			"age_ice": "iconAgeIce.png",
			"age_dark": "iconAgeChaos.png",
			"age_wonders": "iconAgeWonders.png"
		}
		var age_ic_name: String = age_ic_map.get(aid, "iconAges.png")
		var age_ic: ImageTexture = _load_wb_tex("res://assets/worldbox/icons/" + age_ic_name)
		if age_ic != null:
			ab.icon = age_ic
		var a_col: Color = wa.tint_color if wa.get("tint_color") != null else Color(1.0, 0.84, 0.38)
		var bg := Color(a_col.r * 0.28, a_col.g * 0.28, a_col.b * 0.18, 0.96) if is_cur_age else Color(0.08, 0.13, 0.22, 0.92)
		var brd := Color(1.0, 0.86, 0.38, 1.0) if is_cur_age else Color(0.28, 0.54, 0.78, 0.75)
		var fcol := Color(1.0, 0.95, 0.72) if is_cur_age else Color(0.88, 0.94, 1.0)
		_apply_btn_theme(ab, bg, brd, fcol)
		ab.pressed.connect(func() -> void:
			sim.set_world_age(aid)
			_populate_world_modal()
		)
		age_hb.add_child(ab)

	_vbox_world_content.add_child(HSeparator.new())

	# 2. Генератор Шаблонов Мира (New World Templates)
	var gen_sec := Label.new()
	gen_sec.text = "2. ГЕНЕРАТОР НОВОГО МИРА (Шаблон: %s | Seed: %d)" % [sim.map_template_id, sim.world_seed]
	gen_sec.add_theme_font_size_override("font_size", 13)
	gen_sec.add_theme_color_override("font_color", Color(0.4, 0.9, 1.0))
	_vbox_world_content.add_child(gen_sec)

	var gen_hb := HFlowContainer.new()
	gen_hb.add_theme_constant_override("h_separation", 8)
	gen_hb.add_theme_constant_override("v_separation", 8)
	_vbox_world_content.add_child(gen_hb)
	var tpls := [
		{"id": "archipelago", "title": "🏝 Архипелаг"},
		{"id": "pangaea", "title": "🌍 Суперконтинент Пангея"},
		{"id": "ring_atoll", "title": "⭕ Кольцевой Атолл"},
		{"id": "shattered_isles", "title": "🌊 Осколки Островов"}
	]
	for tp in tpls:
		var gb := Button.new()
		var tid: String = tp["id"]
		var is_cur_tpl: bool = (tid == sim.map_template_id)
		gb.text = ("✓ " if is_cur_tpl else "") + str(tp["title"])
		gb.add_theme_font_size_override("font_size", 12)
		var bg := Color(0.10, 0.30, 0.42, 0.96) if is_cur_tpl else Color(0.07, 0.13, 0.22, 0.92)
		var brd := Color(0.38, 0.95, 0.78, 1.0) if is_cur_tpl else Color(0.25, 0.56, 0.82, 0.75)
		_apply_btn_theme(gb, bg, brd, Color(0.92, 0.98, 1.0))
		gb.pressed.connect(func() -> void:
			sim.generate_world_with_template(sim.world_seed + 137, tid, 0.0)
			_populate_world_modal()
		)
		gen_hb.add_child(gb)

	_vbox_world_content.add_child(HSeparator.new())

	# 3. Переключатели Слоёв Карты (Map Overlays)
	var layer_sec := Label.new()
	layer_sec.text = "3. СЛОИ ОТОБРАЖЕНИЯ КАРТЫ (WORLDBOX OVERLAYS)"
	layer_sec.add_theme_font_size_override("font_size", 13)
	layer_sec.add_theme_color_override("font_color", Color(0.45, 0.95, 0.72))
	_vbox_world_content.add_child(layer_sec)

	var rend := _get_cosmic_renderer()
	var cb_banners := CheckButton.new()
	cb_banners.text = "Показывать таблички-баннеры полисов (без наложений)"
	cb_banners.button_pressed = bool(rend.get("show_city_banners")) if rend != null else true
	_style_check_button(cb_banners, Color(0.38, 0.92, 0.72))
	cb_banners.toggled.connect(func(v: bool) -> void:
		var r := _get_cosmic_renderer()
		if r != null:
			r.set("show_city_banners", v)
			r.queue_redraw()
	)
	_vbox_world_content.add_child(cb_banners)

	var cb_dip := CheckButton.new()
	cb_dip.text = "Показывать линии дипломатии, войн и торговых караванов"
	cb_dip.button_pressed = bool(rend.get("show_diplomacy_lines")) if rend != null else true
	_style_check_button(cb_dip, Color(0.38, 0.92, 0.72))
	cb_dip.toggled.connect(func(v: bool) -> void:
		var r := _get_cosmic_renderer()
		if r != null:
			r.set("show_diplomacy_lines", v)
			r.queue_redraw()
	)
	_vbox_world_content.add_child(cb_dip)

	var cb_armies := CheckButton.new()
	cb_armies.text = "Показывать боевые знамёна генералов армий"
	cb_armies.button_pressed = bool(rend.get("show_army_banners")) if rend != null else true
	_style_check_button(cb_armies, Color(0.38, 0.92, 0.72))
	cb_armies.toggled.connect(func(v: bool) -> void:
		var r := _get_cosmic_renderer()
		if r != null:
			r.set("show_army_banners", v)
			r.queue_redraw()
	)
	_vbox_world_content.add_child(cb_armies)

	_vbox_world_content.add_child(HSeparator.new())

	# 4. Слоты Сохранения и Загрузки Мира (Save / Load Slots)
	var save_sec := Label.new()
	save_sec.text = "4. СОХРАНЕНИЕ И ЗАГРУЗКА МИРА (user://saves/)"
	save_sec.add_theme_font_size_override("font_size", 13)
	save_sec.add_theme_color_override("font_color", Color(0.95, 0.78, 1.0))
	_vbox_world_content.add_child(save_sec)

	for slot_i in range(1, 4):
		var s_hb := HBoxContainer.new()
		s_hb.add_theme_constant_override("separation", 10)
		_vbox_world_content.add_child(s_hb)
		var s_lbl := Label.new()
		s_lbl.text = "Слот сохранения #%d:" % slot_i
		s_lbl.custom_minimum_size = Vector2(180, 0)
		s_lbl.add_theme_color_override("font_color", Color(0.86, 0.92, 1.0))
		s_hb.add_child(s_lbl)

		var btn_save := Button.new()
		btn_save.text = "💾 Сохранить в Слот #%d" % slot_i
		btn_save.add_theme_font_size_override("font_size", 12)
		_apply_btn_theme(btn_save, Color(0.08, 0.22, 0.18, 0.94), Color(0.32, 0.88, 0.64, 0.85), Color(0.88, 1.0, 0.94))
		var s_idx: int = slot_i
		btn_save.pressed.connect(func() -> void:
			sim.save_world_to_slot(s_idx)
			_populate_world_modal()
		)
		s_hb.add_child(btn_save)

		var btn_load := Button.new()
		btn_load.text = "📂 Загрузить Слот #%d" % slot_i
		btn_load.add_theme_font_size_override("font_size", 12)
		_apply_btn_theme(btn_load, Color(0.10, 0.16, 0.28, 0.94), Color(0.42, 0.72, 1.0, 0.85), Color(0.90, 0.95, 1.0))
		btn_load.pressed.connect(func() -> void:
			sim.load_world_from_slot(s_idx)
			_populate_world_modal()
		)
		s_hb.add_child(btn_load)


func set_event_filter(filter_cat: String) -> void:
	current_event_filter = filter_cat
	for c_id in _filter_buttons.keys():
		var btn: Button = _filter_buttons[c_id]
		if c_id == filter_cat:
			_apply_btn_theme(btn, Color(0.18, 0.42, 0.72, 0.96), Color(0.42, 0.90, 1.0, 1.0), Color(0.98, 1.0, 1.0))
		else:
			_apply_btn_theme(btn, Color(0.08, 0.14, 0.22, 0.90), Color(0.25, 0.55, 0.85, 0.70), Color(0.80, 0.90, 0.98))
	_rebuild_event_log()


func select_event_log_category(filter_cat: String) -> void:
	set_event_filter(filter_cat)


func get_filtered_event_entries() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if sim == null:
		return result
	for e in sim.event_log:
		if _is_entry_in_category(e, current_event_filter):
			result.append(e)
	return result


func _on_event_log_meta_clicked(meta: Variant) -> void:
	var meta_str: String = str(meta)
	if meta_str.begins_with("pan:"):
		var coords_str: String = meta_str.substr(4)
		var parts := coords_str.split(",")
		if parts.size() == 2:
			var target_coord := Vector2(parts[0].to_float(), parts[1].to_float())
			if is_finite(target_coord.x) and is_finite(target_coord.y):
				camera_pan_requested.emit(target_coord)
				if camera != null and camera.has_method("pan_to"):
					camera.pan_to(target_coord)
	elif meta_str.begins_with("city:"):
		var cid: int = meta_str.substr(5).to_int()
		open_city_inspector(cid)
	elif meta_str.begins_with("actor:"):
		var aid: int = meta_str.substr(6).to_int()
		open_actor_inspector(aid)
	elif meta_str.begins_with("culture:"):
		var cltid: int = meta_str.substr(8).to_int()
		open_culture_inspector(cltid)


func _is_entry_in_category(entry: Dictionary, filter_cat: String) -> bool:
	if filter_cat == "all":
		return true
	var c: String = str(entry.get("category", "")).to_lower()
	match filter_cat:
		"diplomacy":
			return c in ["diplomacy", "colony", "peace", "alliance", "trade"]
		"war":
			return c in ["war", "damage", "raid", "destruction"]
		"megastructures":
			return c in ["cosmos", "dyson", "supernova", "stage", "ring", "shell", "matrioshka"]
		"alchemy":
			return c in ["constants", "alchemy", "anomaly", "reaction"]
		"god_powers":
			return c in ["god_power", "god_powers", "brush", "cataclysm", "meteor", "lance", "quake"]
		"science":
			return c in ["science", "breakthrough", "plot_start", "codex", "discovery"]
		_:
			return false


func get_detailed_culture_data(culture_id: int) -> Dictionary:
	if sim == null:
		return {}
	if sim.has_method("get_detailed_culture_data"):
		return sim.get_detailed_culture_data(culture_id)
	if not sim.cultures_map.has(culture_id):
		return {}
	var cult: Dictionary = sim.cultures_map[culture_id]
	var sp_id: int = int(cult.get("subspecies_id", -1))
	var sp: Dictionary = sim.subspecies_map.get(sp_id, {})
	var member_cities: Array[Dictionary] = []
	var total_pop: float = 0.0
	var avg_cohesion: float = 0.0
	for c in sim.cities_map.values():
		if int(c.get("culture_id", -1)) == culture_id:
			member_cities.append({"id": c["id"], "name": c["name"], "pop": c["population"]})
			total_pop += float(c.get("population", 0.0))
			avg_cohesion += float(c.get("internal_cohesion", 1.0))
	if not member_cities.is_empty():
		avg_cohesion /= float(member_cities.size())
	else:
		avg_cohesion = 1.0

	return {
		"id": culture_id,
		"name": cult["name"],
		"subspecies_id": sp_id,
		"subspecies_name": sp.get("name", "Неизвестный"),
		"layout": cult.get("layout", "rings"),
		"traits": cult.get("traits", []),
		"ethos_id": cult.get("ethos_id", ""),
		"discovered_theories_count": cult.get("discovered_theories_count", 0),
		"science_points": cult.get("science_points", 0.0),
		"member_cities": member_cities,
		"total_population": total_pop,
		"cohesion": avg_cohesion,
		"color": cult.get("color", Color.WHITE)
	}


func _populate_city_inspector(city_id: int) -> void:
	if _vbox_city_content == null:
		return
	for ch in _vbox_city_content.get_children():
		ch.queue_free()

	if sim == null or not sim.cities_map.has(city_id):
		var err_l := Label.new()
		err_l.text = "Полис не найден или был разрушен."
		_vbox_city_content.add_child(err_l)
		return

	var c_data: Dictionary = sim.get_detailed_city_data(city_id)
	var c_col: Color = c_data.get("color", Color.WHITE)

	var top_hb := HBoxContainer.new()
	_vbox_city_content.add_child(top_hb)

	var title_l := Label.new()
	title_l.text = "🏙 %s [K-%.2f] — %s" % [c_data.get("name", "Полис"), float(c_data.get("kardashev_level", 0.0)), c_data.get("subspecies_name", "")]
	title_l.add_theme_font_size_override("font_size", 16)
	title_l.add_theme_color_override("font_color", c_col.lightened(0.35))
	title_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_hb.add_child(title_l)

	var btn_pan := Button.new()
	btn_pan.text = "🎯 Найти на карте"
	btn_pan.add_theme_font_size_override("font_size", 12)
	_apply_btn_theme(btn_pan, Color(0.08, 0.18, 0.30, 0.94), Color(0.32, 0.78, 1.0, 0.88), Color(0.88, 0.96, 1.0))
	var m_pos: Vector2 = c_data.get("map_pos", Vector2(960, 540))
	btn_pan.pressed.connect(func() -> void:
		camera_pan_requested.emit(m_pos)
		if camera != null and camera.has_method("pan_to"):
			camera.pan_to(m_pos)
	)
	top_hb.add_child(btn_pan)

	_vbox_city_content.add_child(HSeparator.new())

	var sec1_l := Label.new()
	sec1_l.text = "1. ДЕМОГРАФИЯ И ВЛАСТЬ"
	sec1_l.add_theme_font_size_override("font_size", 13)
	sec1_l.add_theme_color_override("font_color", Color(0.4, 0.85, 1.0))
	_vbox_city_content.add_child(sec1_l)

	var demo_hb := HBoxContainer.new()
	_vbox_city_content.add_child(demo_hb)

	var demo_info := Label.new()
	demo_info.text = "Население: %.1f тыс. | Территорий: %d | Дронов: %d" % [
		float(c_data.get("population", 0.0)),
		int(c_data.get("claimed_tiles_count", 0)),
		int(sim.cities_map[city_id].get("orbital_drones", 0))
	]
	demo_info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	demo_hb.add_child(demo_info)

	var cult_id: int = int(c_data.get("culture_id", -1))
	if cult_id != -1:
		var btn_cult := Button.new()
		btn_cult.text = "🏛 Культура: %s" % c_data.get("culture_name", "Культура")
		btn_cult.add_theme_font_size_override("font_size", 12)
		_apply_btn_theme(btn_cult, Color(0.08, 0.22, 0.18, 0.94), Color(0.38, 0.92, 0.68, 0.85), Color(0.88, 1.0, 0.94))
		btn_cult.pressed.connect(func() -> void: open_culture_inspector(cult_id))
		demo_hb.add_child(btn_cult)

	var coh_hb := HBoxContainer.new()
	coh_hb.add_theme_constant_override("separation", 8)
	_vbox_city_content.add_child(coh_hb)
	var coh_lbl := Label.new()
	coh_lbl.text = "Внутренняя сплочённость:"
	coh_lbl.custom_minimum_size = Vector2(200, 0)
	coh_hb.add_child(coh_lbl)
	var coh_bar := ProgressBar.new()
	coh_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var coh_val: float = float(c_data.get("internal_cohesion", 1.0)) * 100.0
	coh_bar.value = coh_val
	_style_progress_bar(coh_bar, Color(0.24, 0.82, 0.96, 0.92))
	coh_hb.add_child(coh_bar)

	_vbox_city_content.add_child(HSeparator.new())

	# 1.5. Империя, Лояльность, Флот, Религия, Язык, Книги и Геном (WorldBox v0.51 Meta-Systems)
	var sec5_l := Label.new()
	sec5_l.text = "2. ИМПЕРИЯ, ФЛОТ, РЕЛИГИЯ, КНИГИ И ХРОМОСОМЫ ПОДВИДА"
	sec5_l.add_theme_font_size_override("font_size", 13)
	sec5_l.add_theme_color_override("font_color", Color(1.0, 0.85, 0.35))
	_vbox_city_content.add_child(sec5_l)

	var emp_hb := HBoxContainer.new()
	emp_hb.add_theme_constant_override("separation", 8)
	_vbox_city_content.add_child(emp_hb)

	var is_cap: bool = bool(c_data.get("is_capital", false))
	var emp_lbl := Label.new()
	emp_lbl.text = "%s Империя: %s | Лояльность: %.0f%% | Верфь: %s (Кораблей: %d)" % [
		"👑 Столица" if is_cap else "🏛 Провинция",
		str(c_data.get("kingdom_name", "Свободный Полис")),
		float(c_data.get("loyalty", 100.0)),
		"Есть" if bool(c_data.get("has_dock", false)) else "Нет",
		int(c_data.get("boats_count", 0))
	]
	emp_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	emp_hb.add_child(emp_lbl)

	var btn_rebel := Button.new()
	btn_rebel.text = "⚔ Восстание"
	btn_rebel.add_theme_font_size_override("font_size", 12)
	_apply_btn_theme(btn_rebel, Color(0.28, 0.10, 0.12, 0.94), Color(0.95, 0.36, 0.40, 0.88), Color(1.0, 0.88, 0.88))
	btn_rebel.pressed.connect(func() -> void:
		sim.trigger_city_rebellion(city_id)
		_populate_city_inspector(city_id)
	)
	emp_hb.add_child(btn_rebel)

	var btn_boat := Button.new()
	btn_boat.text = "⛵ Спустить Корабль"
	btn_boat.add_theme_font_size_override("font_size", 12)
	_apply_btn_theme(btn_boat, Color(0.08, 0.18, 0.28, 0.94), Color(0.35, 0.78, 0.98, 0.85), Color(0.88, 0.96, 1.0))
	btn_boat.pressed.connect(func() -> void:
		sim.spawn_boat_for_city(city_id, "trade")
		_populate_city_inspector(city_id)
	)
	emp_hb.add_child(btn_boat)

	var meta_hb := HBoxContainer.new()
	meta_hb.add_theme_constant_override("separation", 8)
	_vbox_city_content.add_child(meta_hb)

	var meta_lbl := Label.new()
	meta_lbl.text = "🗣 Язык: %s | 🛐 Религия: %s | 📖 Книг в библиотеке: %d" % [
		str(c_data.get("language_name", "Прото-Код")),
		str(c_data.get("religion_name", "Культ Звезды")),
		int(c_data.get("books_count", 0))
	]
	meta_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	meta_hb.add_child(meta_lbl)

	var btn_rite := Button.new()
	btn_rite.text = "✨ Обряд"
	btn_rite.add_theme_font_size_override("font_size", 12)
	_apply_btn_theme(btn_rite, Color(0.24, 0.18, 0.08, 0.94), Color(0.98, 0.80, 0.32, 0.88), Color(1.0, 0.95, 0.78))
	btn_rite.pressed.connect(func() -> void:
		sim.cast_religion_rite(city_id)
		_populate_city_inspector(city_id)
	)
	meta_hb.add_child(btn_rite)

	var btn_book := Button.new()
	btn_book.text = "📖 Написать Книгу"
	btn_book.add_theme_font_size_override("font_size", 12)
	_apply_btn_theme(btn_book, Color(0.16, 0.12, 0.26, 0.94), Color(0.75, 0.55, 0.98, 0.85), Color(0.95, 0.90, 1.0))
	btn_book.pressed.connect(func() -> void:
		sim.write_city_book(city_id)
		_populate_city_inspector(city_id)
	)
	meta_hb.add_child(btn_book)

	var sp_id: int = int(c_data.get("subspecies_id", -1))
	var chromo: Array = c_data.get("chromosomes", [])
	var gene_hb := HFlowContainer.new()
	gene_hb.add_theme_constant_override("h_separation", 6)
	gene_hb.add_theme_constant_override("v_separation", 6)
	_vbox_city_content.add_child(gene_hb)

	var gene_lbl := Label.new()
	gene_lbl.text = "🧬 Хромосомы:"
	gene_hb.add_child(gene_lbl)

	for g_asset in sim.assets.gene_list:
		var gid: String = g_asset.id
		var has_g: bool = chromo.has(gid)
		var g_btn := Button.new()
		g_btn.text = "%s%s" % ["✓ " if has_g else "+ ", g_asset.title]
		g_btn.add_theme_font_size_override("font_size", 11)
		var g_bg := Color(0.08, 0.24, 0.18, 0.94) if has_g else Color(0.08, 0.12, 0.20, 0.88)
		var g_brd := Color(0.35, 0.92, 0.65, 0.92) if has_g else Color(0.26, 0.44, 0.64, 0.68)
		var g_fcol := Color(0.86, 1.0, 0.92) if has_g else Color(0.78, 0.86, 0.96)
		_apply_btn_theme(g_btn, g_bg, g_brd, g_fcol)
		g_btn.pressed.connect(func() -> void:
			sim.mutate_subspecies_gene(sp_id, gid)
			_populate_city_inspector(city_id)
		)
		gene_hb.add_child(g_btn)

	_vbox_city_content.add_child(HSeparator.new())

	var sec2_l := Label.new()
	sec2_l.text = "3. ИНВЕНТАРЬ ЗДАНИЙ И ПРОЧНОСТЬ СТРУКТУР"
	sec2_l.add_theme_font_size_override("font_size", 13)
	sec2_l.add_theme_color_override("font_color", Color(0.4, 0.85, 1.0))
	_vbox_city_content.add_child(sec2_l)

	var b_dict: Dictionary = c_data.get("buildings", {})
	var dur_dict: Dictionary = sim.cities_map[city_id].get("building_durability", {})
	if b_dict.is_empty():
		var no_b := Label.new()
		no_b.text = "Зданий нет (первобытное поселение)."
		_vbox_city_content.add_child(no_b)
	else:
		for b_id in b_dict.keys():
			var count: int = int(b_dict[b_id])
			var bo: SandboxAssetScript.BuildOrderAsset = sim.assets.build_orders.get(b_id)
			var b_title: String = bo.title if bo else str(b_id)
			var max_hp: float = (100.0 * float(bo.tier)) if bo else 100.0
			var cur_hp: float = float(dur_dict.get(b_id, max_hp))
			var pct: float = clampf((cur_hp / maxf(1.0, max_hp)) * 100.0, 0.0, 100.0)

			var b_row := HBoxContainer.new()
			b_row.add_theme_constant_override("separation", 8)
			_vbox_city_content.add_child(b_row)

			var b_name_l := Label.new()
			b_name_l.text = "• %s ×%d" % [b_title, count]
			b_name_l.custom_minimum_size = Vector2(240, 0)
			b_row.add_child(b_name_l)

			var hp_col := Color(0.24, 0.86, 0.52, 0.92) if pct > 70.0 else (Color(0.95, 0.78, 0.25, 0.92) if pct > 30.0 else Color(0.95, 0.32, 0.35, 0.92))
			var hp_bar := ProgressBar.new()
			hp_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			hp_bar.value = pct
			_style_progress_bar(hp_bar, hp_col)
			b_row.add_child(hp_bar)

			var hp_val_l := Label.new()
			hp_val_l.text = "%.0f / %.0f HP" % [cur_hp, max_hp]
			hp_val_l.custom_minimum_size = Vector2(96, 0)
			hp_val_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			hp_val_l.add_theme_color_override("font_color", hp_col.lightened(0.15))
			b_row.add_child(hp_val_l)

	_vbox_city_content.add_child(HSeparator.new())

	var sec3_l := Label.new()
	sec3_l.text = "4. ДИПЛОМАТИЧЕСКИЙ СТАТУС И ОТНОШЕНИЯ"
	sec3_l.add_theme_font_size_override("font_size", 13)
	sec3_l.add_theme_color_override("font_color", Color(0.4, 0.85, 1.0))
	_vbox_city_content.add_child(sec3_l)

	var rels: Dictionary = c_data.get("relations", {})
	if rels.is_empty():
		var no_r := Label.new()
		no_r.text = "Дипломатические контакты отсутствуют."
		_vbox_city_content.add_child(no_r)
	else:
		for other_id in rels.keys():
			var r_info: Dictionary = rels[other_id]
			var r_row := HBoxContainer.new()
			r_row.add_theme_constant_override("separation", 8)
			_vbox_city_content.add_child(r_row)

			var o_name := Label.new()
			o_name.text = str(r_info.get("other_name", "Полис"))
			o_name.custom_minimum_size = Vector2(160, 0)
			r_row.add_child(o_name)

			var status_str: String = str(r_info.get("status", "NEUTRAL"))
			var st_l := Label.new()
			st_l.text = "[%s]" % status_str
			var st_col := Color(0.8, 0.8, 0.8)
			match status_str:
				"WAR": st_col = Color(1.0, 0.3, 0.3)
				"ALLIANCE": st_col = Color(0.3, 0.85, 1.0)
				"TRADE": st_col = Color(1.0, 0.85, 0.3)
				"PEACE": st_col = Color(0.4, 0.95, 0.4)
			st_l.add_theme_color_override("font_color", st_col)
			st_l.custom_minimum_size = Vector2(90, 0)
			r_row.add_child(st_l)

			var op_l := Label.new()
			op_l.text = "Отношение: %+.0f | Истощение: %.1f%% | Торговля: %.1f ГВт" % [
				float(r_info.get("opinion", 0.0)),
				float(r_info.get("war_exhaustion", 0.0)) * 100.0,
				float(r_info.get("trade_yield", 0.0))
			]
			op_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			r_row.add_child(op_l)

			var btn_inspect_other := Button.new()
			btn_inspect_other.text = "Инфо"
			btn_inspect_other.add_theme_font_size_override("font_size", 11)
			_apply_btn_theme(btn_inspect_other, Color(0.08, 0.16, 0.26, 0.94), Color(0.32, 0.68, 0.95, 0.82))
			var o_id_val: int = int(other_id)
			btn_inspect_other.pressed.connect(func() -> void: open_city_inspector(o_id_val))
			r_row.add_child(btn_inspect_other)

	_vbox_city_content.add_child(HSeparator.new())

	var sec4_l := Label.new()
	sec4_l.text = "5. НАУЧНЫЕ И ДИПЛОМАТИЧЕСКИЕ ЗАМЫСЛЫ"
	sec4_l.add_theme_font_size_override("font_size", 13)
	sec4_l.add_theme_color_override("font_color", Color(0.4, 0.85, 1.0))
	_vbox_city_content.add_child(sec4_l)

	var p_dict: Dictionary = c_data.get("active_plot", {})
	if not p_dict.is_empty():
		var p_l := Label.new()
		var p_pct: int = int(clampf(float(p_dict.get("progress", 0.0)) / maxf(1.0, float(p_dict.get("progress_needed", 1.0))) * 100.0, 0.0, 100.0))
		p_l.text = "🔬 Научный проект: %s [%d%%]" % [p_dict.get("title", ""), p_pct]
		_vbox_city_content.add_child(p_l)

	var dp_dict: Dictionary = c_data.get("active_diplomatic_plot", {})
	if not dp_dict.is_empty():
		var dp_l := Label.new()
		var dp_pct: int = int(clampf(float(dp_dict.get("progress", 0.0)) / maxf(1.0, float(dp_dict.get("progress_needed", 1.0))) * 100.0, 0.0, 100.0))
		dp_l.text = "🤝 Дипломатический проект: %s [%d%%]" % [dp_dict.get("title", ""), dp_pct]
		_vbox_city_content.add_child(dp_l)

	var st_dict: Dictionary = c_data.get("storage", {})
	var st_l := Label.new()
	st_l.text = "📦 Склад полиса: Дерево: %d | Минералы: %d | Пища: %d | Зон 8×8: %d | Выковано в кузнице: %d" % [
		int(st_dict.get("wood", 0)),
		int(st_dict.get("minerals", 0)),
		int(st_dict.get("food", 0)),
		int(c_data.get("claimed_zones_count", 0)),
		int(c_data.get("forged_items_count", 0))
	]
	st_l.add_theme_color_override("font_color", Color(0.85, 0.95, 0.65))
	_vbox_city_content.add_child(st_l)


func _populate_actor_inspector(actor_id: int) -> void:
	if _vbox_actor_content == null:
		return
	for ch in _vbox_actor_content.get_children():
		ch.queue_free()

	if sim == null:
		return

	var a_data: Dictionary = sim.get_detailed_actor_data(actor_id)
	if a_data.is_empty():
		var err_l := Label.new()
		err_l.text = "Существо не найдено или погибло."
		_vbox_actor_content.add_child(err_l)
		return

	var top_hb := HBoxContainer.new()
	_vbox_actor_content.add_child(top_hb)

	var is_fav: bool = bool(a_data.get("is_favorite", false))
	var name_l := Label.new()
	name_l.text = "%s %s [%s]" % ["★" if is_fav else "👤", a_data.get("name", "Юнит"), a_data.get("role", "Житель")]
	name_l.add_theme_font_size_override("font_size", 16)
	name_l.add_theme_color_override("font_color", Color(1.0, 0.85, 0.35))
	name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_hb.add_child(name_l)

	var btn_fav := Button.new()
	btn_fav.text = "★ Избранный" if is_fav else "☆ В Избранные"
	btn_fav.add_theme_font_size_override("font_size", 12)
	var fav_bg := Color(0.28, 0.22, 0.06, 0.94) if is_fav else Color(0.08, 0.14, 0.24, 0.92)
	var fav_brd := Color(1.0, 0.84, 0.32, 0.95) if is_fav else Color(0.32, 0.56, 0.80, 0.78)
	_apply_btn_theme(btn_fav, fav_bg, fav_brd, Color(1.0, 0.94, 0.72) if is_fav else Color(0.88, 0.94, 1.0))
	btn_fav.pressed.connect(func() -> void:
		sim.toggle_actor_favorite(actor_id)
		_populate_actor_inspector(actor_id)
	)
	top_hb.add_child(btn_fav)

	var is_possessed: bool = bool(a_data.get("is_possessed", false))
	var btn_possess := Button.new()
	btn_possess.text = "🕹 Отпустить [ESC]" if is_possessed else "🕹 Управлять [WASD]"
	btn_possess.add_theme_font_size_override("font_size", 12)
	var pos_bg := Color(0.10, 0.28, 0.22, 0.95) if is_possessed else Color(0.08, 0.18, 0.28, 0.92)
	var pos_brd := Color(0.38, 0.95, 0.72, 0.95) if is_possessed else Color(0.32, 0.72, 0.95, 0.82)
	_apply_btn_theme(btn_possess, pos_bg, pos_brd)
	btn_possess.pressed.connect(func() -> void:
		if sim.controlled_actor_id == actor_id:
			sim.release_possession()
		else:
			sim.possess_actor(actor_id)
		_populate_actor_inspector(actor_id)
	)
	top_hb.add_child(btn_possess)

	var btn_pan := Button.new()
	btn_pan.text = "🎯 Найти на карте"
	btn_pan.add_theme_font_size_override("font_size", 12)
	_apply_btn_theme(btn_pan, Color(0.08, 0.18, 0.30, 0.94), Color(0.32, 0.78, 1.0, 0.88))
	var a_pos: Vector2 = a_data.get("pos", Vector2(960, 540))
	btn_pan.pressed.connect(func() -> void:
		camera_pan_requested.emit(a_pos)
		if camera != null and camera.has_method("pan_to"):
			camera.pan_to(a_pos, 2.5)
	)
	top_hb.add_child(btn_pan)

	_vbox_actor_content.add_child(HSeparator.new())

	var max_hp_v: int = maxi(100, int(a_data.get("max_hp", 100)))
	var hp_hb := HBoxContainer.new()
	hp_hb.add_theme_constant_override("separation", 8)
	_vbox_actor_content.add_child(hp_hb)
	var hp_lbl := Label.new()
	hp_lbl.text = "Здоровье:"
	hp_lbl.custom_minimum_size = Vector2(90, 0)
	hp_hb.add_child(hp_lbl)
	var hp_bar := ProgressBar.new()
	hp_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hp_bar.max_value = float(max_hp_v)
	hp_bar.value = float(a_data.get("hp", 100))
	_style_progress_bar(hp_bar, Color(0.28, 0.88, 0.56, 0.92))
	hp_hb.add_child(hp_bar)
	var hp_val := Label.new()
	hp_val.text = "%d / %d HP" % [int(a_data.get("hp", 100)), max_hp_v]
	hp_hb.add_child(hp_val)

	var age_l := Label.new()
	age_l.text = "Возраст: %d циклов | Подвид: %s | Клан: %s" % [
		int(a_data.get("age", 0)), a_data.get("subspecies_name", ""), a_data.get("clan_name", "—")
	]
	_vbox_actor_content.add_child(age_l)

	var combat_l := Label.new()
	combat_l.text = "⚔ Боевой опыт: Уровень %d | Побед: %d | Урон: %d | Броня: %d" % [
		int(a_data.get("level", 1)), int(a_data.get("kills", 0)),
		int(a_data.get("combat_damage", 16)), int(a_data.get("armor_defense", 0))
	]
	combat_l.add_theme_color_override("font_color", Color(1.0, 0.78, 0.42))
	_vbox_actor_content.add_child(combat_l)

	var w_id: String = str(a_data.get("weapon_id", ""))
	var ar_id: String = str(a_data.get("armor_id", ""))
	var w_title: String = sim.assets.equipments[w_id].title if sim.assets.equipments.has(w_id) else "Нет"
	var ar_title: String = sim.assets.equipments[ar_id].title if sim.assets.equipments.has(ar_id) else "Нет"
	var eq_l := Label.new()
	eq_l.text = "🛡 Снаряжение кузницы: Оружие: %s | Доспех: %s" % [w_title, ar_title]
	eq_l.add_theme_color_override("font_color", Color(0.55, 0.92, 1.0))
	_vbox_actor_content.add_child(eq_l)

	var ptrs: Array = a_data.get("personal_traits", [])
	var ptr_names: Array[String] = []
	for pt_id in ptrs:
		if sim.assets.personal_traits.has(pt_id):
			var pt_asset: SandboxAssetScript.PersonalTraitAsset = sim.assets.personal_traits[pt_id]
			ptr_names.append(pt_asset.title)
		else:
			ptr_names.append(str(pt_id))
	var ptr_l := Label.new()
	ptr_l.text = "🧬 Личные черты: %s" % (", ".join(ptr_names) if not ptr_names.is_empty() else "Обычный")
	ptr_l.add_theme_color_override("font_color", Color(0.65, 0.95, 0.75))
	_vbox_actor_content.add_child(ptr_l)

	var needs_l := Label.new()
	needs_l.text = "🍞 Сытость: %.0f%% | 😊 Счастье: %.0f%% | ⚡ Выносливость: %.0f%%" % [
		float(a_data.get("nutrition", 100.0)),
		float(a_data.get("happiness", 100.0)),
		float(a_data.get("stamina", 100.0))
	]
	needs_l.add_theme_color_override("font_color", Color(0.95, 0.88, 0.55))
	_vbox_actor_content.add_child(needs_l)

	var fam_l := Label.new()
	fam_l.text = "👪 Семья: %s | Поколение: #%d | Детей: %d | Родители: %d/%d" % [
		str(a_data.get("family_name", "—")),
		int(a_data.get("generation", 1)),
		int(a_data.get("children_count", 0)),
		int(a_data.get("parent_a_id", -1)),
		int(a_data.get("parent_b_id", -1))
	]
	fam_l.add_theme_color_override("font_color", Color(0.85, 0.78, 1.0))
	_vbox_actor_content.add_child(fam_l)

	var st_effs: Dictionary = a_data.get("status_effects", {})
	var st_titles: Array[String] = []
	for st_id in st_effs.keys():
		if sim.assets.status_effects.has(st_id):
			st_titles.append("%s (%.0fс)" % [sim.assets.status_effects[st_id].title, float(st_effs[st_id])])
		else:
			st_titles.append(str(st_id))
	var st_l := Label.new()
	st_l.text = "🔥 Статусные эффекты: %s" % (", ".join(st_titles) if not st_titles.is_empty() else "Нет")
	st_l.add_theme_color_override("font_color", Color(1.0, 0.65, 0.45))
	_vbox_actor_content.add_child(st_l)

	var c_id: int = int(a_data.get("city_id", -1))
	var c_hb := HBoxContainer.new()
	_vbox_actor_content.add_child(c_hb)
	var c_l := Label.new()
	c_l.text = "Присяга полису: %s" % a_data.get("city_name", "Дикий")
	c_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c_hb.add_child(c_l)
	if c_id != -1 and sim.cities_map.has(c_id):
		var btn_c := Button.new()
		btn_c.text = "🏛 Открыть полис"
		btn_c.add_theme_font_size_override("font_size", 12)
		_apply_btn_theme(btn_c, Color(0.08, 0.18, 0.28, 0.94), Color(0.35, 0.78, 0.98, 0.85))
		btn_c.pressed.connect(func() -> void: open_city_inspector(c_id))
		c_hb.add_child(btn_c)

	_vbox_actor_content.add_child(HSeparator.new())

	var thought_box := PanelContainer.new()
	thought_box.add_theme_stylebox_override("panel", _make_panel_style(Color(0.08, 0.12, 0.2, 0.8), Color(0.3, 0.6, 0.9, 0.5), 6))
	_vbox_actor_content.add_child(thought_box)
	var th_l := Label.new()
	th_l.text = "Мысли: «%s»" % a_data.get("thought", "...")
	th_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	th_l.add_theme_color_override("font_color", Color(0.7, 0.95, 1.0))
	thought_box.add_child(th_l)


func _populate_culture_inspector(culture_id: int) -> void:
	if _vbox_culture_content == null:
		return
	for ch in _vbox_culture_content.get_children():
		ch.queue_free()

	var cult_data: Dictionary = get_detailed_culture_data(culture_id)
	if cult_data.is_empty():
		var err_l := Label.new()
		err_l.text = "Культура не найдена."
		_vbox_culture_content.add_child(err_l)
		return

	var title_l := Label.new()
	title_l.text = "🏛 %s" % cult_data.get("name", "Культура")
	title_l.add_theme_font_size_override("font_size", 16)
	title_l.add_theme_color_override("font_color", Color(0.35, 0.95, 1.0))
	_vbox_culture_content.add_child(title_l)

	_vbox_culture_content.add_child(HSeparator.new())

	var info_l := Label.new()
	info_l.text = "Подвид: %s | Планировка: %s | Эфос: %s" % [
		cult_data.get("subspecies_name", ""),
		cult_data.get("layout", "rings"),
		cult_data.get("ethos_id", "стандарт")
	]
	_vbox_culture_content.add_child(info_l)

	var traits_arr: Array = cult_data.get("traits", [])
	var traits_l := Label.new()
	traits_l.text = "Культурные черты: %s" % (", ".join(traits_arr) if not traits_arr.is_empty() else "базовые")
	_vbox_culture_content.add_child(traits_l)

	var sci_l := Label.new()
	sci_l.text = "Открыто теорий: %d | Очки науки: %.0f ПФЛОПС" % [
		int(cult_data.get("discovered_theories_count", 0)),
		float(cult_data.get("science_points", 0.0))
	]
	_vbox_culture_content.add_child(sci_l)

	var coh_hb := HBoxContainer.new()
	coh_hb.add_theme_constant_override("separation", 8)
	_vbox_culture_content.add_child(coh_hb)
	var coh_lbl := Label.new()
	coh_lbl.text = "Средняя культурная сплочённость:"
	coh_hb.add_child(coh_lbl)
	var coh_bar := ProgressBar.new()
	coh_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	coh_bar.value = float(cult_data.get("cohesion", 1.0)) * 100.0
	_style_progress_bar(coh_bar, Color(0.28, 0.92, 0.68, 0.92))
	coh_hb.add_child(coh_bar)

	_vbox_culture_content.add_child(HSeparator.new())

	var mem_head := Label.new()
	mem_head.text = "ПОЛИСЫ КУЛЬТУРЫ:"
	mem_head.add_theme_color_override("font_color", Color(0.55, 0.92, 0.80))
	_vbox_culture_content.add_child(mem_head)

	var mem_cities: Array = cult_data.get("member_cities", [])
	for mc in mem_cities:
		var mc_hb := HBoxContainer.new()
		_vbox_culture_content.add_child(mc_hb)

		var mc_lbl := Label.new()
		mc_lbl.text = "• %s (Население: %.1f тыс.)" % [mc.get("name", "Полис"), float(mc.get("pop", 0.0))]
		mc_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		mc_hb.add_child(mc_lbl)

		var btn_insp := Button.new()
		btn_insp.text = "🏛 Открыть полис"
		btn_insp.add_theme_font_size_override("font_size", 11)
		_apply_btn_theme(btn_insp, Color(0.08, 0.18, 0.28, 0.94), Color(0.35, 0.78, 0.98, 0.85))
		var mc_id: int = int(mc.get("id", -1))
		btn_insp.pressed.connect(func() -> void: open_city_inspector(mc_id))
		mc_hb.add_child(btn_insp)


func _populate_analytics_panel() -> void:
	if _vbox_analytics_content == null:
		return
	for ch in _vbox_analytics_content.get_children():
		ch.queue_free()

	if sim == null:
		return

	var m: Dictionary = sim.get_global_world_metrics()

	var top_l := Label.new()
	top_l.text = "📊 КАРДАШЁВСКАЯ ТЕЛЕМЕТРИЯ И АНАЛИТИКА МИРА [Виток #%d | Год %.1f]" % [
		int(m.get("chrono_cycle", 1)), float(m.get("world_year", 0.0))
	]
	top_l.add_theme_font_size_override("font_size", 16)
	top_l.add_theme_color_override("font_color", Color(0.35, 0.95, 1.0))
	_vbox_analytics_content.add_child(top_l)

	_vbox_analytics_content.add_child(HSeparator.new())

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 16)
	grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_vbox_analytics_content.add_child(grid)

	# 1. Цивилизации и Кардашёв
	var q1 := PanelContainer.new()
	q1.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	q1.add_theme_stylebox_override("panel", _make_panel_style(Color(0.06, 0.09, 0.16, 0.95), Color(0.2, 0.5, 0.8, 0.6)))
	grid.add_child(q1)
	var q1_vb := VBoxContainer.new()
	q1_vb.add_theme_constant_override("separation", 6)
	q1.add_child(q1_vb)
	var q1_title := Label.new()
	q1_title.text = "1. ЦИВИЛИЗАЦИИ И ШКАЛА КАРДАШЁВА"
	q1_title.add_theme_font_size_override("font_size", 13)
	q1_title.add_theme_color_override("font_color", Color(0.4, 0.85, 1.0))
	q1_vb.add_child(q1_title)
	q1_vb.add_child(HSeparator.new())
	var q1_txt := Label.new()
	q1_txt.text = (
		"• Общее население: %.1f тыс.\n" % float(m.get("total_population", 0.0)) +
		"• Живых актеров в мире: %d\n" % int(m.get("total_actors", 0)) +
		"• Активных полисов: %d\n" % int(m.get("total_cities", 0)) +
		"• Био/техно-подвидов: %d\n" % int(m.get("total_subspecies", 0)) +
		"• Макс. уровень Кардашёва: K-%.2f" % float(m.get("max_kardashev", 0.0))
	)
	q1_vb.add_child(q1_txt)
	var k_bar := ProgressBar.new()
	k_bar.max_value = 2.0
	k_bar.value = float(m.get("max_kardashev", 0.0))
	_style_progress_bar(k_bar, Color(0.26, 0.82, 0.98, 0.92))
	q1_vb.add_child(k_bar)

	# 2. Ресурсы и Сфера Дайсона
	var q2 := PanelContainer.new()
	q2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	q2.add_theme_stylebox_override("panel", _make_panel_style(Color(0.06, 0.09, 0.16, 0.95), Color(0.2, 0.5, 0.8, 0.6)))
	grid.add_child(q2)
	var q2_vb := VBoxContainer.new()
	q2_vb.add_theme_constant_override("separation", 6)
	q2.add_child(q2_vb)
	var q2_title := Label.new()
	q2_title.text = "2. ЭНЕРГИЯ И СФЕРА ДАЙСОНА"
	q2_title.add_theme_font_size_override("font_size", 13)
	q2_title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.35))
	q2_vb.add_child(q2_title)
	q2_vb.add_child(HSeparator.new())
	var q2_txt := Label.new()
	q2_txt.text = (
		"• Запас материи: %.0f ед.\n" % float(m.get("matter_stock", 0.0)) +
		"• Генерация энергии: %.0f ГВт\n" % float(m.get("energy_gw", 0.0)) +
		"• Мощность вычислений: %.0f ПФЛОПС\n" % float(m.get("compute_pflops", 0.0)) +
		"• Этап Сферы Дайсона: Этап %d (%s)\n" % [int(m.get("dyson_stage", 1)), str(m.get("dyson_stage_name", ""))] +
		"• Сегментов готово: %d/60 | Затмение: %.0f%%\n" % [int(m.get("dyson_active_segments", 0)), float(m.get("dyson_eclipse_ratio", 0.0)) * 100.0] +
		"• Выход энергии мегаструктуры: %.0f ГВт" % float(m.get("dyson_energy_output", 0.0))
	)
	q2_vb.add_child(q2_txt)
	var dys_bar := ProgressBar.new()
	dys_bar.value = float(m.get("dyson_stage_progress", 0.0)) * 100.0
	_style_progress_bar(dys_bar, Color(0.98, 0.80, 0.28, 0.92))
	q2_vb.add_child(dys_bar)

	# 3. Геополитика и Войны
	var q3 := PanelContainer.new()
	q3.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	q3.add_theme_stylebox_override("panel", _make_panel_style(Color(0.06, 0.09, 0.16, 0.95), Color(0.2, 0.5, 0.8, 0.6)))
	grid.add_child(q3)
	var q3_vb := VBoxContainer.new()
	q3.add_child(q3_vb)
	var q3_title := Label.new()
	q3_title.text = "3. ГЕОПОЛИТИКА И ВОЙНЫ"
	q3_title.add_theme_font_size_override("font_size", 13)
	q3_title.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4))
	q3_vb.add_child(q3_title)
	q3_vb.add_child(HSeparator.new())
	var wars_c: int = int(m.get("active_wars_count", 0))
	var trades_c: int = int(m.get("active_trade_routes_count", 0))
	var alls_c: int = int(m.get("active_alliances_count", 0))
	var q3_txt := Label.new()
	q3_txt.text = (
		"• Активных войн: %d %s\n" % [wars_c, "⚔ (ВНИМАНИЕ: БОЕВЫЕ ДЕЙСТВИЯ!)" if wars_c > 0 else "✓ (Мир)"] +
		"• Торговых соглашений: %d ⚖\n" % trades_c +
		"• Оборонительных союзов: %d 🛡\n" % alls_c +
		"• Запущенных солнечных парусов: %d" % int(m.get("total_dyson_sails", 0))
	)
	q3_vb.add_child(q3_txt)

	# 4. Кодекс Науки
	var q4 := PanelContainer.new()
	q4.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	q4.add_theme_stylebox_override("panel", _make_panel_style(Color(0.06, 0.09, 0.16, 0.95), Color(0.2, 0.5, 0.8, 0.6)))
	grid.add_child(q4)
	var q4_vb := VBoxContainer.new()
	q4.add_child(q4_vb)
	var q4_title := Label.new()
	q4_title.text = "4. БЕСКОНЕЧНЫЙ КОДЕКС НАУКИ"
	q4_title.add_theme_font_size_override("font_size", 13)
	q4_title.add_theme_color_override("font_color", Color(0.3, 0.95, 0.6))
	q4_vb.add_child(q4_title)
	q4_vb.add_child(HSeparator.new())
	var q4_txt := Label.new()
	q4_txt.text = (
		"• Фундаментальных теорий открыто: %d\n" % int(m.get("codex_theories_count", 0)) +
		"• Множитель выхода материи: ×%.2f\n" % (float(sim.codex_matter_mult) if sim != null else 1.0) +
		"• Множитель мощности энергии: ×%.2f\n" % (float(sim.codex_energy_mult) if sim != null else 1.0) +
		"• Множитель скорости вычислений: ×%.2f" % (float(sim.codex_compute_mult) if sim != null else 1.0)
	)
	q4_vb.add_child(q4_txt)


func _refresh_codex_modal() -> void:
	if sim == null or _rtl_codex_list == null:
		return
	var sb := ""
	sb += "[b][color=#5ce1e6]Постоянные множители Кодекса Архитектора (Виток #%d):[/color][/b]\n" % sim.chrono_cycle
	sb += "• Выход Материи: [b]×%.2f[/b]   |   • Мощность Энергии: [b]×%.2f[/b]   |   • Скорость Вычислений: [b]×%.2f[/b]\n\n" % [
		sim.codex_matter_mult, sim.codex_energy_mult, sim.codex_compute_mult
	]
	if sim.codex_theories.is_empty():
		sb += "[i]Пока не синтезировано ни одной фундаментальной теории. Помогите городам построить Академии, ускорьте их Куполом Времени (×25) или запустите Омега-Ливень![/i]"
	else:
		for i in range(sim.codex_theories.size() - 1, -1, -1):
			var th: Dictionary = sim.codex_theories[i]
			sb += "[color=#ffd966][b]%d. %s[/b][/color] [color=#88c0d0](Цикл #%d, Полис «%s»)[/color]\n" % [
				int(th["tier"]), th["title"], int(th["cycle"]), th["discoverer_city"]
			]
			sb += "   Формула: [code]%s[/code]  →  Бонус Кодекса: [color=#72f1b8]+%d%% к %s[/color]\n\n" % [
				th["formula"], int(float(th["bonus_val"]) * 100.0), str(th["bonus_type"]).to_upper()
			]
	_rtl_codex_list.text = sb


func _refresh_laws_modal() -> void:
	if sim == null or _vbox_laws_list == null:
		return
	for ch in _vbox_laws_list.get_children():
		ch.queue_free()

	for wl in sim.assets.world_law_list:
		var cb := CheckButton.new()
		cb.button_pressed = bool(sim.active_world_laws.get(wl.id, true))
		cb.text = "%s — %s" % [wl.title, wl.description]
		_style_check_button(cb, Color(1.0, 0.82, 0.35))
		var law_id: String = wl.id
		cb.toggled.connect(func(pressed: bool) -> void:
			sim.active_world_laws[law_id] = pressed
		)
		_vbox_laws_list.add_child(cb)


# ==============================================================================
# ВЫБОР ВКЛАДКИ И БОЖЕСТВЕННОЙ СИЛЫ
# ==============================================================================
func _select_tab(tab_id: String) -> void:
	selected_tab = tab_id
	for tid in _tab_buttons.keys():
		var btn: Button = _tab_buttons[tid]
		var active: bool = (tid == selected_tab)
		var bg := Color(0.14, 0.32, 0.54, 0.98) if active else Color(0.06, 0.10, 0.18, 0.85)
		var brd := Color(0.38, 0.88, 1.0, 1.0) if active else Color(0.18, 0.35, 0.55, 0.65)
		var fcol := Color(0.96, 0.99, 1.0) if active else Color(0.76, 0.86, 0.96)
		_apply_btn_theme(btn, bg, brd, fcol)

	for ch in _hbox_powers.get_children():
		ch.queue_free()

	var first_id: String = ""
	var all_tab_powers: Array[SandboxAssetScript.GodPowerAsset] = []
	all_tab_powers.append_array(sim.assets.god_power_list)
	all_tab_powers.append_array(sim.assets.worldbox_power_list)
	for gp in all_tab_powers:
		if gp.tab_id != selected_tab:
			continue
		if first_id == "":
			first_id = gp.id
		var pb := Button.new()
		pb.text = gp.title
		pb.custom_minimum_size = Vector2(118, 40)
		pb.add_theme_font_size_override("font_size", 11)
		var pid: String = gp.id
		var p_ic: ImageTexture = _get_power_wb_icon(pid)
		if p_ic != null:
			pb.icon = p_ic
		pb.tooltip_text = "%s\n%s" % [gp.title, gp.description]
		var pcol: Color = gp.beam_color
		var is_sel: bool = (pid == selected_power_id)
		var bg := Color(pcol.r * 0.32, pcol.g * 0.32, pcol.b * 0.32, 0.95) if is_sel else Color(0.07, 0.11, 0.18, 0.92)
		var brd := pcol.lightened(0.28) if is_sel else Color(pcol.r, pcol.g, pcol.b, 0.58)
		var fcol := Color(1.0, 0.98, 0.92) if is_sel else Color(0.88, 0.94, 1.0)
		_apply_btn_theme(pb, bg, brd, fcol)
		pb.pressed.connect(func() -> void: _select_power(pid))
		_hbox_powers.add_child(pb)

	if selected_power_id == "" or sim.assets.god_powers.get(selected_power_id).tab_id != selected_tab:
		if first_id != "":
			_select_power(first_id)


func _select_power(power_id: String) -> void:
	selected_power_id = power_id
	power_selected.emit(selected_power_id)
	if selected_power_id == "":
		_lbl_power_desc.text = "Режим Наблюдения и Инспектора: наведите на человечка или тайл для осмотра, ЛКМ по существу — перетащить Магнитом, ПКМ/WASD — двигать 2D-карту, Колесо — зум."
	else:
		var gp: SandboxAssetScript.GodPowerAsset = sim.assets.god_powers.get(selected_power_id)
		if gp != null:
			_lbl_power_desc.text = "[%s]: %s (ЛКМ по 2D-карте — применить кисть, ПКМ/WASD — двигать камеру, Колесо — зум)" % [gp.title, gp.description]

	if _btn_observe != null:
		var obs_active: bool = (selected_power_id == "")
		var obs_bg := Color(0.14, 0.34, 0.52, 0.96) if obs_active else Color(0.07, 0.12, 0.20, 0.88)
		var obs_brd := Color(0.42, 0.92, 1.0, 1.0) if obs_active else Color(0.24, 0.48, 0.72, 0.72)
		_apply_btn_theme(_btn_observe, obs_bg, obs_brd, Color(0.96, 1.0, 1.0) if obs_active else Color(0.82, 0.90, 0.98))

	# Перерисуем подсветку кнопок текущей вкладки
	var all_tab_powers: Array[SandboxAssetScript.GodPowerAsset] = []
	all_tab_powers.append_array(sim.assets.god_power_list)
	all_tab_powers.append_array(sim.assets.worldbox_power_list)
	for ch in _hbox_powers.get_children():
		if ch is Button:
			var b: Button = ch
			for gp in all_tab_powers:
				if gp.tab_id == selected_tab and gp.title == b.text:
					var is_sel: bool = (gp.id == selected_power_id)
					var pcol: Color = gp.beam_color
					var bg := Color(pcol.r * 0.35, pcol.g * 0.35, pcol.b * 0.35, 0.98) if is_sel else Color(0.07, 0.11, 0.18, 0.92)
					var brd := pcol.lightened(0.35) if is_sel else Color(pcol.r, pcol.g, pcol.b, 0.58)
					var fcol := Color(1.0, 0.98, 0.92) if is_sel else Color(0.88, 0.94, 1.0)
					_apply_btn_theme(b, bg, brd, fcol)


func _update_brush_button_styles() -> void:
	var radii := [0.12, 0.22, 0.36]
	for i in range(_brush_buttons.size()):
		var b: Button = _brush_buttons[i]
		var active: bool = absf(current_brush_radius - radii[i]) < 0.01
		var bg := Color(0.16, 0.38, 0.58, 0.95) if active else Color(0.06, 0.10, 0.16, 0.85)
		var brd := Color(0.4, 0.9, 1.0) if active else Color(0.2, 0.4, 0.6, 0.6)
		_apply_btn_theme(b, bg, brd, Color(0.96, 1.0, 1.0) if active else Color(0.78, 0.88, 0.96))


func _update_cam_mode_button_styles() -> void:
	var rend := _get_cosmic_renderer()
	if rend != null and rend.get("view_mode") != null:
		current_view_mode = int(rend.get("view_mode"))
	for m_val in _cam_mode_buttons.keys():
		var b: Button = _cam_mode_buttons[m_val]
		if b == null:
			continue
		var active: bool = (int(m_val) == current_view_mode)
		var bg := Color(0.16, 0.36, 0.58, 0.96) if active else Color(0.08, 0.14, 0.24, 0.90)
		var brd := Color(0.42, 0.92, 1.0, 1.0) if active else Color(0.25, 0.55, 0.85, 0.78)
		var fcol := Color(0.98, 1.0, 1.0) if active else Color(0.82, 0.90, 0.98)
		_apply_btn_theme(b, bg, brd, fcol)


func _update_speed_button_styles() -> void:
	if _btn_pause == null:
		return
	var is_paused: bool = (sim != null and sim.paused)
	var cur_spd: float = (sim.sim_speed if sim != null else 1.0)
	var spd_defs := [
		{"btn": _btn_pause, "active": is_paused, "gold": true},
		{"btn": _btn_speed_1, "active": (not is_paused and absf(cur_spd - 1.0) < 0.1), "gold": false},
		{"btn": _btn_speed_5, "active": (not is_paused and absf(cur_spd - 5.0) < 0.1), "gold": false},
		{"btn": _btn_speed_25, "active": (not is_paused and absf(cur_spd - 25.0) < 0.1), "gold": true}
	]
	for sd in spd_defs:
		var b: Button = sd["btn"]
		if b == null:
			continue
		var act: bool = sd["active"]
		var is_gold: bool = sd["gold"]
		var bg := Color(0.10, 0.16, 0.26, 0.92)
		var brd := Color(0.28, 0.62, 0.92, 0.80)
		var fcol := Color(0.86, 0.93, 1.0)
		if act:
			bg = Color(0.32, 0.22, 0.08, 0.96) if is_gold else Color(0.14, 0.36, 0.56, 0.96)
			brd = Color(1.0, 0.84, 0.35, 1.0) if is_gold else Color(0.42, 0.92, 1.0, 1.0)
			fcol = Color(1.0, 0.95, 0.75) if is_gold else Color(0.98, 1.0, 1.0)
		_apply_btn_theme(b, bg, brd, fcol)


func _set_sim_speed(spd: float) -> void:
	if sim == null:
		return
	if spd <= 0.0:
		sim.paused = true
	else:
		sim.paused = false
		sim.sim_speed = spd
	_update_speed_button_styles()
	_refresh_telemetry_and_lists()


# ==============================================================================
# ОБНОВЛЕНИЕ ТЕЛЕМЕТРИИ, СПИСКА ГОРОДОВ И ЛОГА СОБЫТИЙ
# ==============================================================================
func _fmt_num(val: float) -> String:
	var a: float = absf(val)
	if a >= 1_000_000_000.0:
		return "%.2fB" % (val / 1_000_000_000.0)
	elif a >= 1_000_000.0:
		return "%.2fM" % (val / 1_000_000.0)
	elif a >= 10_000.0:
		return "%.1fK" % (val / 1_000.0)
	return "%.0f" % val


func _refresh_telemetry_and_lists() -> void:
	if sim == null or _lbl_system_title == null:
		return

	_update_cam_mode_button_styles()
	_update_speed_button_styles()

	var k_max: float = sim.get_max_kardashev_level()
	_lbl_system_title.text = "★ %s | Г.%d | K-%.2f" % [
		sim.star_name, int(sim.world_year), k_max
	]

	_lbl_resources.text = "МАТЕРИЯ: %s (+%s/с)  |  ЭНЕРГИЯ: %s ГВт (+%s/с)  |  НАУКА: %s ПФ (+%s/с)  |  КОДЕКС: %d" % [
		_fmt_num(sim.matter_stock), _fmt_num(sim.matter_rate),
		_fmt_num(sim.energy_gw), _fmt_num(sim.energy_rate),
		_fmt_num(sim.compute_pflops), _fmt_num(sim.compute_rate),
		sim.codex_theories.size()
	]

	var dyson_pct: float = sim.get_dyson_eclipse_ratio() * 100.0
	_lbl_star_dyson.text = "Сфера: %d пар. (%.0f%%) | Звезда: %d%%" % [
		sim.total_dyson_sails, dyson_pct, int(sim.star_stability * 100.0)
	]

	_rebuild_cities_inspector()
	if _modal_codex.visible:
		_refresh_codex_modal()


func _rebuild_cities_inspector() -> void:
	for ch in _vbox_cities.get_children():
		ch.queue_free()

	for c_id in sim.cities_map.keys():
		var city: Dictionary = sim.cities_map[c_id]
		var sp: Dictionary = sim.subspecies_map.get(int(city["subspecies_id"]), {})
		var cult: Dictionary = sim.cultures_map.get(int(city["culture_id"]), {})
		var center_tile: Dictionary = sim.tiles[int(city["center_tile"])]

		var card := PanelContainer.new()
		var c_col: Color = city["color"]
		card.add_theme_stylebox_override("panel", _make_panel_style(Color(0.06, 0.10, 0.16, 0.92), Color(c_col.r, c_col.g, c_col.b, 0.75), 6))
		_vbox_cities.add_child(card)

		var vb := VBoxContainer.new()
		vb.add_theme_constant_override("separation", 3)
		card.add_child(vb)

		var head_hb := HBoxContainer.new()
		vb.add_child(head_hb)

		var title_l := Label.new()
		title_l.text = "🏙 %s (K-%.2f)" % [city["name"], float(city["kardashev_level"])]
		title_l.add_theme_font_size_override("font_size", 13)
		title_l.add_theme_color_override("font_color", c_col.lightened(0.3))
		title_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		head_hb.add_child(title_l)

		var btn_focus := Button.new()
		btn_focus.text = "Найти"
		btn_focus.add_theme_font_size_override("font_size", 11)
		_apply_btn_theme(btn_focus, Color(0.08, 0.16, 0.26, 0.92), Color(0.30, 0.68, 0.95, 0.80))
		var c_dir: Vector3 = city["dir"]
		btn_focus.pressed.connect(func() -> void: focus_city_requested.emit(c_dir))
		head_hb.add_child(btn_focus)

		var btn_info := Button.new()
		btn_info.text = "Инфо"
		btn_info.add_theme_font_size_override("font_size", 11)
		_apply_btn_theme(btn_info, Color(0.10, 0.20, 0.30, 0.92), Color(0.38, 0.82, 1.0, 0.85))
		var cid_val: int = int(city["id"])
		btn_info.pressed.connect(func() -> void: open_city_inspector(cid_val))
		head_hb.add_child(btn_info)

		var info_l := Label.new()
		var total_b: int = int((city["building_instances"] as Array).size())
		info_l.text = "Вид: %s (Пок.%d) | Нас:%d | Зданий:%d | Флот:%d" % [
			sp.get("name", "?"), int(sp.get("generation", 1)),
			int(city["population"]), total_b, int(city["orbital_drones"])
		]
		info_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		info_l.add_theme_font_size_override("font_size", 11)
		info_l.add_theme_color_override("font_color", Color(0.80, 0.88, 0.96))
		vb.add_child(info_l)

		var plot_id: int = int(city["active_plot_id"])
		if plot_id != -1 and sim.active_plots.has(plot_id):
			var pl: Dictionary = sim.active_plots[plot_id]
			var pct: int = int(clampf(float(pl["progress"]) / maxf(1.0, float(pl["progress_needed"])) * 100.0, 0.0, 100.0))
			var plot_l := Label.new()
			plot_l.text = "🔬 %s [%d%%]" % [pl["title"], pct]
			plot_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			plot_l.add_theme_font_size_override("font_size", 11)
			plot_l.add_theme_color_override("font_color", Color(1.0, 0.86, 0.35))
			vb.add_child(plot_l)

		if float(center_tile["time_scale_mult"]) > 1.1 or float(center_tile["gravity_mult"]) < 0.9:
			var lens_l := Label.new()
			lens_l.text = "⚡ Под Линзой: Время ×%.0f | Гравитация %.2fG" % [
				float(center_tile["time_scale_mult"]), float(center_tile["gravity_mult"])
			]
			lens_l.add_theme_font_size_override("font_size", 11)
			lens_l.add_theme_color_override("font_color", Color(0.35, 0.95, 1.0))
			vb.add_child(lens_l)


func update_tile_scanner(tile_idx: int, world_pos: Vector2 = Vector2(-1.0, -1.0)) -> void:
	if sim == null or _lbl_tile_scanner == null or tile_idx < 0 or tile_idx >= sim.tiles.size():
		return
	var t: Dictionary = sim.tiles[tile_idx]
	var b_asset: SandboxAssetScript.BiomeAsset = sim.assets.biomes.get(t["biome_id"])
	var b_title: String = b_asset.title if b_asset else str(t["biome_id"])

	var sp_name := "Нет жизни"
	var s_id: int = int(t["subspecies_id"])
	if s_id != -1 and sim.subspecies_map.has(s_id):
		var sp: Dictionary = sim.subspecies_map[s_id]
		sp_name = "%s (%d черт)" % [sp["name"], (sp["traits"] as Array).size()]

	var city_name := "Дикий сектор"
	var c_id: int = int(t["city_id"])
	if c_id != -1 and sim.cities_map.has(c_id):
		city_name = "[url=city:%d]%s[/url]" % [c_id, sim.cities_map[c_id]["name"]]

	var q_pos: Vector2 = world_pos if world_pos.x >= 0.0 else (t["map_pos"] as Vector2)
	var actor: Dictionary = sim.find_closest_actor(q_pos, 48.0)
	var actor_line := "Юнит рядом: [color=#8899aa]—[/color]"
	if not actor.is_empty():
		var a_id: int = int(actor["id"])
		actor_line = "Юнит: [url=actor:%d][color=#ffd966][b]%s[/b][/color][/url] (%s, %d л.) — [i]%s[/i]" % [
			a_id, actor["name"], actor["role"], int(actor["age"]), actor["thought"]
		]

	_lbl_tile_scanner.text = (
		"[b]Тайл [%d,%d]:[/b] [color=#5ce1e6]%s[/color] (%.0f°C | Рад:%d%%)\n" % [
			int(t["gx"]), int(t["gy"]), b_title, float(t["temperature_c"]), int(float(t["radiation"]) * 100.0)
		] +
		"Время: [b]×%.1f[/b] | Грав: [b]%.2fG[/b] | Полис: [color=#ffd966]%s[/color]\n" % [
			float(t["time_scale_mult"]), float(t["gravity_mult"]), city_name
		] +
		"Вид: [color=#72f1b8]%s[/color]\n" % sp_name +
		actor_line
	)


func _on_event_logged(_entry: Dictionary) -> void:
	_rebuild_event_log()


func _on_supernova_cycle(_new_cycle: int) -> void:
	_refresh_telemetry_and_lists()
	_rebuild_event_log()


func _rebuild_event_log() -> void:
	if sim == null or _rtl_event_log == null:
		return
	var sb := ""
	var shown_count := 0
	for e in sim.event_log:
		if not _is_entry_in_category(e, current_event_filter):
			continue
		shown_count += 1
		if shown_count > 35:
			break
		var col: Color = e.get("color", Color.WHITE)
		var hex: String = col.to_html(false)
		var cat_tag: String = str(e.get("category", "")).to_upper()
		var p_link := ""
		if e.has("coords") and e["coords"] is Vector2 and (e["coords"] as Vector2) != Vector2.ZERO:
			var cp: Vector2 = e["coords"]
			p_link = " [url=pan:%.0f,%.0f][color=#5ce1e6][📌 Найти][/color][/url]" % [cp.x, cp.y]
		elif e.has("city_id") and int(e["city_id"]) != -1:
			p_link = " [url=city:%d][color=#ffd966][🏙 Инфо][/color][/url]" % int(e["city_id"])

		sb += "[color=#8899aa][Г.%d][/color] [color=#66bbff][%s][/color] [color=#%s]%s[/color]%s\n\n" % [
			int(e.get("year", 0)), cat_tag, hex, e.get("text", ""), p_link
		]
	if sb == "":
		sb = "[color=#667788][i]Нет событий в выбранной категории.[/i][/color]"
	_rtl_event_log.text = sb
