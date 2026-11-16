class_name Hud
extends CanvasLayer
## Heads-up display: hull bar, objective, timer, speed, boost, touch controls,
## messages, damage flash and the loading screen.

var level: LevelController = null
var player: PlayerShip = null
var overlay: LevelOverlay = null

var _root: Control
var _markers: HudMarkers
var _joystick: ShipJoystick
var _fire_button: TouchButton
var _boost_button: TouchButton
var _health_bar: ProgressBar
var _health_label: Label
var _boost_bar: ProgressBar
var _speed_label: Label
var _objective_label: Label
var _timer_label: Label
var _message_label: Label
var _flash: ColorRect
var _loading: ColorRect
var _loading_label: Label
var _message_tween: Tween
var _low_health_timer: float = 0.0


func _ready() -> void:
	layer = 10
	_root = Control.new()
	_root.theme = UiTheme.create()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	_markers = HudMarkers.new()
	_markers.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(_markers)

	_flash = ColorRect.new()
	_flash.color = Color(1.0, 0.1, 0.1, 0.0)
	_flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_flash)

	_build_top_left()
	_build_top_center()
	_build_top_right()
	_build_controls()

	_message_label = Label.new()
	_message_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_message_label.offset_top = 150.0
	_message_label.offset_left = -500.0
	_message_label.offset_right = 500.0
	_message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message_label.add_theme_font_size_override("font_size", 34)
	_message_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.5))
	_message_label.modulate.a = 0.0
	_message_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_message_label)

	_loading = ColorRect.new()
	_loading.color = Color(0.02, 0.03, 0.08, 1.0)
	_loading.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(_loading)
	_loading_label = Label.new()
	_loading_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_loading_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_loading_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_loading_label.add_theme_font_size_override("font_size", 34)
	_loading_label.text = "LOADING MISSION..."
	_loading.add_child(_loading_label)

	overlay = LevelOverlay.new()
	add_child(overlay)


func bind(level_controller: LevelController) -> void:
	level = level_controller
	player = level.player
	_markers.level = level
	player.health_changed.connect(_on_health_changed)
	player.damaged.connect(_on_damaged)
	level.kills_changed.connect(_on_kills_changed)
	_on_health_changed(player.health, player.max_health)
	_on_kills_changed(level.kills, level.enemy_goal)


func set_loading(text: String) -> void:
	_loading.visible = true
	_loading_label.text = text


func hide_loading() -> void:
	_loading.visible = false


func show_message(text: String, seconds: float = 3.0) -> void:
	_message_label.text = text
	if _message_tween != null:
		_message_tween.kill()
	_message_label.modulate.a = 1.0
	_message_tween = create_tween()
	_message_tween.tween_interval(seconds)
	_message_tween.tween_property(_message_label, "modulate:a", 0.0, 0.8)


func _process(delta: float) -> void:
	if level == null or player == null:
		return
	player_input_update()
	_timer_label.text = GameState.format_time(level.elapsed)
	_speed_label.text = "%d km/h" % int(player.speed * 3.6)
	_boost_bar.value = player.boost_energy
	if _flash.color.a > 0.0:
		_flash.color.a = maxf(0.0, _flash.color.a - delta * 1.8)
	if player.is_alive and player.health / player.max_health < 0.3:
		_low_health_timer += delta
		if _low_health_timer > 1.4:
			_low_health_timer = 0.0
			AudioManager.play_sfx("warning", -10.0)
	if Input.is_action_just_pressed("pause") and level.phase == LevelController.Phase.PLAYING:
		overlay.show_pause()


func player_input_update() -> void:
	if not player.is_alive:
		return
	player.steer_input = _joystick.value
	player.fire_pressed = _fire_button.is_held
	player.boost_pressed = _boost_button.is_held


func _on_health_changed(current: float, maximum: float) -> void:
	_health_bar.max_value = maximum
	_health_bar.value = current
	_health_label.text = "HULL  %d / %d" % [int(ceil(current)), int(maximum)]
	var ratio := current / maximum
	var color := Color(0.3, 0.95, 0.45)
	if ratio < 0.3:
		color = Color(1.0, 0.25, 0.2)
	elif ratio < 0.6:
		color = Color(1.0, 0.8, 0.2)
	_health_bar.add_theme_stylebox_override("fill", UiTheme.bar_fill_box(color))


func _on_damaged(_amount: float) -> void:
	_flash.color.a = 0.45
	if level != null and level.chase_camera != null:
		level.chase_camera.add_shake(1.0)


func _on_kills_changed(kills: int, goal: int) -> void:
	if kills >= goal:
		_objective_label.text = "REACH THE JUMP GATE!"
		_objective_label.add_theme_color_override("font_color", Color(0.4, 1.0, 0.55))
	else:
		_objective_label.text = "DESTROY ENEMIES  %d / %d" % [kills, goal]
		_objective_label.add_theme_color_override("font_color", Color.WHITE)


func _build_top_left() -> void:
	var panel := PanelContainer.new()
	panel.position = Vector2(20, 16)
	panel.custom_minimum_size = Vector2(300, 0)
	_root.add_child(panel)
	var box := VBoxContainer.new()
	panel.add_child(box)
	_health_label = Label.new()
	_health_label.add_theme_font_size_override("font_size", 18)
	box.add_child(_health_label)
	_health_bar = _make_bar(Color(0.3, 0.95, 0.45), 18.0)
	box.add_child(_health_bar)


func _build_top_center() -> void:
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	panel.offset_left = -190.0
	panel.offset_right = 190.0
	panel.offset_top = 16.0
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(panel)
	var box := VBoxContainer.new()
	panel.add_child(box)
	_objective_label = Label.new()
	_objective_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_objective_label.add_theme_font_size_override("font_size", 22)
	box.add_child(_objective_label)
	_timer_label = Label.new()
	_timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_timer_label.add_theme_font_size_override("font_size", 18)
	_timer_label.add_theme_color_override("font_color", Color(0.6, 0.9, 1.0))
	box.add_child(_timer_label)


func _build_top_right() -> void:
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	panel.offset_left = -330.0
	panel.offset_right = -20.0
	panel.offset_top = 16.0
	_root.add_child(panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	panel.add_child(row)
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(column)
	_speed_label = Label.new()
	_speed_label.add_theme_font_size_override("font_size", 20)
	column.add_child(_speed_label)
	_boost_bar = _make_bar(Color(0.3, 0.7, 1.0), 12.0)
	column.add_child(_boost_bar)
	var boost_text := Label.new()
	boost_text.text = "BOOST"
	boost_text.add_theme_font_size_override("font_size", 12)
	column.add_child(boost_text)
	var pause_button := Button.new()
	pause_button.text = "II"
	pause_button.pressed.connect(_on_pause_pressed)
	row.add_child(pause_button)


func _build_controls() -> void:
	_joystick = ShipJoystick.new()
	_joystick.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
	_joystick.anchor_right = 0.5
	_joystick.offset_right = 0.0
	_joystick.offset_top = 110.0
	_root.add_child(_joystick)

	_fire_button = TouchButton.new()
	_fire_button.label_text = "FIRE"
	_fire_button.tint = Color(1.0, 0.4, 0.3)
	_fire_button.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	_fire_button.offset_left = -230.0
	_fire_button.offset_top = -230.0
	_fire_button.offset_right = -60.0
	_fire_button.offset_bottom = -60.0
	_root.add_child(_fire_button)

	_boost_button = TouchButton.new()
	_boost_button.label_text = "BOOST"
	_boost_button.tint = Color(0.35, 0.7, 1.0)
	_boost_button.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	_boost_button.offset_left = -400.0
	_boost_button.offset_top = -170.0
	_boost_button.offset_right = -270.0
	_boost_button.offset_bottom = -40.0
	_root.add_child(_boost_button)


func _make_bar(color: Color, height: float) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(0, height)
	bar.show_percentage = false
	bar.min_value = 0.0
	bar.max_value = 100.0
	bar.value = 100.0
	bar.add_theme_stylebox_override("background", UiTheme.bar_background_box())
	bar.add_theme_stylebox_override("fill", UiTheme.bar_fill_box(color))
	return bar


func _on_pause_pressed() -> void:
	AudioManager.play_sfx("ui_click")
	if level != null and level.phase == LevelController.Phase.PLAYING:
		overlay.show_pause()
