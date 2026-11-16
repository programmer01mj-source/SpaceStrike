extends Control
## Main menu: title screen -> ship + level selection -> launch.
## A 3D scene (rotating ship in front of a planet) is shown behind the menus.

enum Screen { MAIN, SELECT, HELP }

var _screens: Dictionary = {}
var _ship_holder: Node3D
var _ship_visual: Node3D
var _planet: Node3D
var _ship_name_label: Label
var _ship_description_label: Label
var _stat_bars: Dictionary = {}
var _level_buttons: Array[Button] = []
var _level_title_label: Label
var _level_description_label: Label
var _level_best_label: Label


func _ready() -> void:
	theme = UiTheme.create()
	_build_background()
	_build_main_screen()
	_build_select_screen()
	_build_help_screen()
	_show_screen(Screen.MAIN)
	_refresh_ship()
	_refresh_level()
	AudioManager.play_music("menu")


func _process(delta: float) -> void:
	if _ship_holder != null:
		_ship_holder.rotate_y(delta * 0.6)
	if _planet != null:
		_planet.rotate_y(delta * 0.05)


# --- Background -----------------------------------------------------------------

func _build_background() -> void:
	var container := SubViewportContainer.new()
	container.stretch = true
	container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(container)
	var viewport := SubViewport.new()
	viewport.own_world_3d = true
	viewport.msaa_3d = Viewport.MSAA_2X
	container.add_child(viewport)

	var sky_material := ShaderMaterial.new()
	sky_material.shader = load("res://game/levels/space_sky.gdshader") as Shader
	var sky := Sky.new()
	sky.sky_material = sky_material
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.4, 0.45, 0.7)
	environment.ambient_light_energy = 0.6
	environment.glow_enabled = true
	var world_environment := WorldEnvironment.new()
	world_environment.environment = environment
	viewport.add_child(world_environment)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-25.0, 40.0, 0.0)
	sun.light_energy = 1.7
	viewport.add_child(sun)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(20.0, -140.0, 0.0)
	fill.light_color = Color(0.4, 0.5, 1.0)
	fill.light_energy = 0.6
	viewport.add_child(fill)

	var camera := Camera3D.new()
	camera.position = Vector3(0.0, 1.2, 9.0)
	camera.fov = 55.0
	viewport.add_child(camera)

	_planet = Node3D.new()
	viewport.add_child(_planet)
	var planet_model := (load("res://assets/environment/Planet_3.gltf") as PackedScene).instantiate() as Node3D
	planet_model.scale = Vector3.ONE * 9.0
	_planet.add_child(planet_model)
	_planet.position = Vector3(-26.0, -10.0, -52.0)

	_ship_holder = Node3D.new()
	_ship_holder.position = Vector3(2.6, 0.0, 0.0)
	_ship_holder.rotation_degrees = Vector3(12.0, 140.0, 0.0)
	viewport.add_child(_ship_holder)


# --- Screens --------------------------------------------------------------------

func _build_main_screen() -> void:
	var screen := MarginContainer.new()
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen.add_theme_constant_override("margin_left", 90)
	screen.add_theme_constant_override("margin_top", 60)
	add_child(screen)
	_screens[Screen.MAIN] = screen
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 18)
	column.custom_minimum_size = Vector2(420, 0)
	column.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	screen.add_child(column)
	var title := Label.new()
	title.text = "SPACE\nSTRIKE"
	title.add_theme_font_size_override("font_size", 82)
	title.add_theme_color_override("font_color", Color(0.45, 0.9, 1.0))
	column.add_child(title)
	var subtitle := Label.new()
	subtitle.text = "Arcade space combat"
	subtitle.add_theme_font_size_override("font_size", 22)
	subtitle.add_theme_color_override("font_color", Color(0.8, 0.85, 1.0))
	column.add_child(subtitle)
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 24)
	column.add_child(spacer)
	column.add_child(_make_button("START GAME", func(): _show_screen(Screen.SELECT)))
	column.add_child(_make_button("HOW TO PLAY", func(): _show_screen(Screen.HELP)))
	if OS.get_name() != "Web":
		column.add_child(_make_button("QUIT", func(): get_tree().quit()))


func _build_select_screen() -> void:
	var screen := MarginContainer.new()
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		screen.add_theme_constant_override("margin_" + side, 36)
	add_child(screen)
	_screens[Screen.SELECT] = screen
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 12)
	screen.add_child(root)

	var heading := Label.new()
	heading.text = "CHOOSE YOUR SHIP AND MISSION"
	heading.add_theme_font_size_override("font_size", 32)
	heading.add_theme_color_override("font_color", Color(0.45, 0.9, 1.0))
	root.add_child(heading)

	var columns := HBoxContainer.new()
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columns.add_theme_constant_override("separation", 24)
	root.add_child(columns)

	# Ship panel (left)
	var ship_panel := PanelContainer.new()
	ship_panel.custom_minimum_size = Vector2(430, 0)
	columns.add_child(ship_panel)
	var ship_column := VBoxContainer.new()
	ship_column.add_theme_constant_override("separation", 10)
	ship_panel.add_child(ship_column)
	var arrows := HBoxContainer.new()
	arrows.add_theme_constant_override("separation", 10)
	ship_column.add_child(arrows)
	arrows.add_child(_make_button("PREV", func(): _change_ship(-1)))
	_ship_name_label = Label.new()
	_ship_name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_ship_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_ship_name_label.add_theme_font_size_override("font_size", 30)
	arrows.add_child(_ship_name_label)
	arrows.add_child(_make_button("NEXT", func(): _change_ship(1)))
	_ship_description_label = Label.new()
	_ship_description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_ship_description_label.add_theme_font_size_override("font_size", 18)
	ship_column.add_child(_ship_description_label)
	for stat in ["SPEED", "ACCELERATION", "HANDLING", "HULL"]:
		var label := Label.new()
		label.text = stat
		label.add_theme_font_size_override("font_size", 16)
		ship_column.add_child(label)
		var bar := ProgressBar.new()
		bar.custom_minimum_size = Vector2(0, 16)
		bar.show_percentage = false
		bar.max_value = 1.0
		bar.add_theme_stylebox_override("background", UiTheme.bar_background_box())
		bar.add_theme_stylebox_override("fill", UiTheme.bar_fill_box(Color(0.35, 0.85, 1.0)))
		ship_column.add_child(bar)
		_stat_bars[stat] = bar

	var middle_spacer := Control.new()
	middle_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	middle_spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	columns.add_child(middle_spacer)

	# Level panel (right)
	var level_panel := PanelContainer.new()
	level_panel.custom_minimum_size = Vector2(430, 0)
	columns.add_child(level_panel)
	var level_column := VBoxContainer.new()
	level_column.add_theme_constant_override("separation", 10)
	level_panel.add_child(level_column)
	var level_heading := Label.new()
	level_heading.text = "MISSION"
	level_heading.add_theme_font_size_override("font_size", 20)
	level_column.add_child(level_heading)
	for i in range(LevelCatalog.LEVELS.size()):
		var button := _make_button(String(LevelCatalog.LEVELS[i]["name"]), _select_level.bind(i))
		level_column.add_child(button)
		_level_buttons.append(button)
	_level_title_label = Label.new()
	_level_title_label.add_theme_font_size_override("font_size", 22)
	_level_title_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.5))
	level_column.add_child(_level_title_label)
	_level_description_label = Label.new()
	_level_description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_level_description_label.add_theme_font_size_override("font_size", 18)
	level_column.add_child(_level_description_label)
	_level_best_label = Label.new()
	_level_best_label.add_theme_font_size_override("font_size", 18)
	_level_best_label.add_theme_color_override("font_color", Color(0.6, 0.9, 1.0))
	level_column.add_child(_level_best_label)

	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 20)
	root.add_child(bottom)
	bottom.add_child(_make_button("BACK", func(): _show_screen(Screen.MAIN)))
	var fill := Control.new()
	fill.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom.add_child(fill)
	bottom.add_child(_make_button("LAUNCH!", _launch))


func _build_help_screen() -> void:
	var screen := CenterContainer.new()
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(screen)
	_screens[Screen.HELP] = screen
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(760, 0)
	screen.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	panel.add_child(column)
	var title := Label.new()
	title.text = "HOW TO PLAY"
	title.add_theme_font_size_override("font_size", 38)
	title.add_theme_color_override("font_color", Color(0.45, 0.9, 1.0))
	column.add_child(title)
	var text := Label.new()
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.add_theme_font_size_override("font_size", 20)
	text.text = "LEFT THUMB: touch and drag anywhere on the left side to steer (pitch and turn).\n\nFIRE: hold the red button to shoot lasers. A little aim assist helps you hit targets.\n\nBOOST: hold the blue button for a speed burst (uses boost energy).\n\nGOAL: destroy the required number of enemies, then fly through the glowing JUMP GATE. Avoid rocks and the ground: crashing hurts!\n\nOn a PC: WASD or arrows steer, SPACE fires, SHIFT boosts, ESC pauses."
	column.add_child(text)
	column.add_child(_make_button("BACK", func(): _show_screen(Screen.MAIN)))


# --- Logic ----------------------------------------------------------------------

func _show_screen(screen: Screen) -> void:
	for key in _screens:
		(_screens[key] as Control).visible = (key == screen)
	_ship_holder.visible = (screen != Screen.HELP)
	# Keep the ship preview on the right of the main title screen and centred between panels on select.
	if _ship_visual != null:
		_ship_visual.scale = Vector3.ONE * (0.9 if screen == Screen.MAIN else 0.45)
	_ship_holder.position = Vector3(3.2, 0.0, 0.0) if screen == Screen.MAIN else Vector3(0.0, -1.0, 0.0)


func _change_ship(direction: int) -> void:
	var count := ShipCatalog.PLAYER_SHIPS.size()
	GameState.select_ship((GameState.selected_ship_index + direction + count) % count)
	AudioManager.play_sfx("ui_switch")
	_refresh_ship()


func _select_level(index: int) -> void:
	GameState.select_level(index)
	_refresh_level()


func _launch() -> void:
	AudioManager.stop_music()
	GameState.start_level()


func _refresh_ship() -> void:
	var index := GameState.selected_ship_index
	var definition: Dictionary = ShipCatalog.PLAYER_SHIPS[index]
	_ship_name_label.text = String(definition["name"])
	_ship_description_label.text = String(definition["description"])
	_stat_bars["SPEED"].value = float(definition["max_speed"]) / 100.0
	_stat_bars["ACCELERATION"].value = float(definition["acceleration"]) / 50.0
	_stat_bars["HANDLING"].value = float(definition["turn_rate"]) / 2.6
	_stat_bars["HULL"].value = float(definition["max_health"]) / 175.0
	if _ship_visual != null:
		_ship_visual.queue_free()
	_ship_visual = ShipCatalog.create_player_visual(index)
	_ship_visual.scale = Vector3.ONE * (0.9 if _screens[Screen.MAIN].visible else 0.45)
	_ship_holder.add_child(_ship_visual)


func _refresh_level() -> void:
	var index := GameState.selected_level_index
	var definition := LevelCatalog.get_level(index)
	for i in range(_level_buttons.size()):
		_level_buttons[i].modulate = Color(1, 1, 1) if i == index else Color(0.6, 0.6, 0.7)
	_level_title_label.text = "%s - %s" % [String(definition["name"]), String(definition["subtitle"])]
	_level_description_label.text = "%s\n\nDestroy %d enemies, then reach the jump gate." % [
		String(definition["description"]), int(definition["enemy_goal"])
	]
	var level_id := String(definition["id"])
	if GameState.best_times.has(level_id):
		_level_best_label.text = "BEST TIME: %s" % GameState.format_time(float(GameState.best_times[level_id]))
	else:
		_level_best_label.text = "BEST TIME: --"


func _make_button(text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.pressed.connect(func():
		AudioManager.play_sfx("ui_click")
		action.call()
	)
	button.mouse_entered.connect(func(): AudioManager.play_sfx("ui_hover", -8.0))
	return button
