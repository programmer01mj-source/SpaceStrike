class_name LevelOverlay
extends CanvasLayer
## Full-screen panels shown during a level: PAUSED, GAME OVER and MISSION COMPLETE.
## Keeps working while the game is paused.

var _root: Control
var _panel: PanelContainer
var _title: Label
var _body: Label
var _buttons: VBoxContainer


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = Control.new()
	_root.theme = UiTheme.create()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.visible = false
	add_child(_root)
	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.05, 0.65)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(dim)
	_panel = PanelContainer.new()
	_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_panel.custom_minimum_size = Vector2(520, 0)
	_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	_root.add_child(_panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 16)
	_panel.add_child(column)
	_title = Label.new()
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 46)
	column.add_child(_title)
	_body = Label.new()
	_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_body.add_theme_font_size_override("font_size", 24)
	column.add_child(_body)
	_buttons = VBoxContainer.new()
	_buttons.add_theme_constant_override("separation", 10)
	column.add_child(_buttons)


func show_pause() -> void:
	get_tree().paused = true
	_open("PAUSED", "Take a breath, pilot.", [
		["RESUME", _resume],
		["RESTART LEVEL", _restart],
		["MAIN MENU", _main_menu],
	], Color.WHITE)


func show_game_over(kills: int, goal: int) -> void:
	get_tree().paused = true
	AudioManager.play_sfx("game_over")
	_open("GAME OVER", "Your ship was destroyed.\nEnemies destroyed: %d / %d" % [kills, goal], [
		["TRY AGAIN", _restart],
		["MAIN MENU", _main_menu],
	], Color(1.0, 0.3, 0.25))


func show_complete(time_seconds: float, best_seconds: float, is_new_best: bool) -> void:
	get_tree().paused = true
	AudioManager.play_sfx("victory")
	var text := "Time: %s\nBest: %s" % [GameState.format_time(time_seconds), GameState.format_time(best_seconds)]
	if is_new_best:
		text += "\nNEW RECORD!"
	_open("MISSION COMPLETE", text, [
		["PLAY AGAIN", _restart],
		["MAIN MENU", _main_menu],
	], Color(0.4, 1.0, 0.55))


func _open(title: String, body: String, entries: Array, title_color: Color) -> void:
	_title.text = title
	_title.add_theme_color_override("font_color", title_color)
	_body.text = body
	for child in _buttons.get_children():
		child.queue_free()
	for entry in entries:
		var button := Button.new()
		button.text = entry[0]
		button.pressed.connect(_on_button.bind(entry[1]))
		_buttons.add_child(button)
	_root.visible = true


func _on_button(action: Callable) -> void:
	AudioManager.play_sfx("ui_click")
	action.call()


func _resume() -> void:
	_root.visible = false
	get_tree().paused = false


func _restart() -> void:
	GameState.restart_level()


func _main_menu() -> void:
	GameState.go_to_main_menu()
