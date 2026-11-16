extends Node
## Global game state (autoload "GameState").
##
## Remembers which ship and level the player picked, stores the best times,
## and owns the scene transitions between the main menu and a level.

signal selection_changed

const MAIN_MENU_SCENE := "res://game/scenes/main_menu.tscn"
const LEVEL_SCENE := "res://game/scenes/level.tscn"
const SAVE_PATH := "user://space_strike_save.cfg"

var selected_ship_index: int = 0
var selected_level_index: int = 0

## Best completion time in seconds for each level id.
var best_times: Dictionary = {}


func _ready() -> void:
	_register_keyboard_controls()
	_load_progress()


func select_ship(index: int) -> void:
	selected_ship_index = clampi(index, 0, ShipCatalog.PLAYER_SHIPS.size() - 1)
	selection_changed.emit()


func select_level(index: int) -> void:
	selected_level_index = clampi(index, 0, LevelCatalog.LEVELS.size() - 1)
	selection_changed.emit()


func start_level() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(LEVEL_SCENE)


func restart_level() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()


func go_to_main_menu() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)


## Stores a finished time. Returns true when it is a new best time.
func record_time(level_id: String, seconds: float) -> bool:
	var is_new_best := not best_times.has(level_id) or seconds < float(best_times[level_id])
	if is_new_best:
		best_times[level_id] = seconds
		_save_progress()
	return is_new_best


## Formats seconds as MM:SS.cc
func format_time(seconds: float) -> String:
	var minutes := int(seconds) / 60
	var secs := int(seconds) % 60
	var hundredths := int((seconds - floorf(seconds)) * 100.0)
	return "%02d:%02d.%02d" % [minutes, secs, hundredths]


func _load_progress() -> void:
	var config := ConfigFile.new()
	if config.load(SAVE_PATH) != OK:
		return
	var saved: Variant = config.get_value("progress", "best_times", {})
	if saved is Dictionary:
		best_times = saved


func _save_progress() -> void:
	var config := ConfigFile.new()
	config.set_value("progress", "best_times", best_times)
	config.save(SAVE_PATH)


## Keyboard controls so the game can also be tested on a computer.
func _register_keyboard_controls() -> void:
	_add_key_action("steer_left", [KEY_A, KEY_LEFT])
	_add_key_action("steer_right", [KEY_D, KEY_RIGHT])
	_add_key_action("steer_up", [KEY_W, KEY_UP])
	_add_key_action("steer_down", [KEY_S, KEY_DOWN])
	_add_key_action("fire", [KEY_SPACE])
	_add_key_action("boost", [KEY_SHIFT])
	_add_key_action("pause", [KEY_ESCAPE, KEY_P])


func _add_key_action(action_name: StringName, keys: Array[int]) -> void:
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name)
	for keycode in keys:
		var event := InputEventKey.new()
		event.physical_keycode = keycode as Key
		InputMap.action_add_event(action_name, event)
