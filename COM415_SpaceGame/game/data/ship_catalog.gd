class_name ShipCatalog
extends RefCounted
## Data for every player spaceship and every enemy type.
##
## HOW TO USE YOUR OWN SPACESHIP MODELS
## 1. Copy your "spaceships" folder into the project root (res://spaceships/).
## 2. Either do nothing (the game auto-assigns the models in alphabetical order),
##    or type the exact file name into "model_file" below, e.g. "Bob.gltf".
## 3. If a ship flies backwards, change "model_yaw_degrees" to 180.
## See SETUP_GUIDE.md for the full step-by-step instructions.

## Folder that holds the spaceship models you add.
const SHIP_DIR := "res://spaceships/"

## File types the game accepts as ship models.
const MODEL_EXTENSIONS: PackedStringArray = ["gltf", "glb", "fbx", "obj", "tscn", "scn"]

## Longest side (in metres) every player ship model is scaled to.
const PLAYER_MODEL_SIZE := 5.0

## Longest side (in metres) every enemy model is scaled to.
const ENEMY_MODEL_SIZE := 5.5

## The three player ships. Speed and acceleration differ and are shown
## on the ship selection screen. Edit the numbers to re-balance the game.
const PLAYER_SHIPS: Array[Dictionary] = [
	{
		"id": "falcon",
		"name": "FALCON",
		"description": "Balanced all-rounder. A good first ship.",
		"max_speed": 70.0,
		"acceleration": 30.0,
		"turn_rate": 1.9,
		"max_health": 100.0,
		"damage": 12.0,
		"model_file": "",
		"model_yaw_degrees": 0.0,
		"placeholder_variant": 0,
	},
	{
		"id": "titan",
		"name": "TITAN",
		"description": "Slow and heavily armoured. Hits hard, takes a beating.",
		"max_speed": 50.0,
		"acceleration": 16.0,
		"turn_rate": 1.4,
		"max_health": 170.0,
		"damage": 16.0,
		"model_file": "",
		"model_yaw_degrees": 0.0,
		"placeholder_variant": 1,
	},
	{
		"id": "phantom",
		"name": "PHANTOM",
		"description": "Very fast and agile but fragile. Dodge everything.",
		"max_speed": 95.0,
		"acceleration": 48.0,
		"turn_rate": 2.5,
		"max_health": 70.0,
		"damage": 10.0,
		"model_file": "",
		"model_yaw_degrees": 0.0,
		"placeholder_variant": 2,
	},
]

## The two enemy types. Both fly, both shoot lasers, both use the
## Finite State Machine (wander / chase / attack) and steering behaviours.
const ENEMY_TYPES: Array[Dictionary] = [
	{
		"id": "fighter",
		"name": "FIGHTER",
		"description": "Fast and agile, low health, rapid weak shots.",
		"max_speed": 52.0,
		"acceleration": 55.0,
		"turn_rate": 2.6,
		"max_health": 40.0,
		"damage": 4.0,
		"fire_interval": 0.7,
		"detect_range": 105.0,
		"attack_range": 70.0,
		"bolt_speed": 150.0,
		"score": 100,
		"model_file": "",
		"model_yaw_degrees": 0.0,
		"model_index": 3,
		"placeholder_variant": 3,
		"icon_color": Color(1.0, 0.35, 0.25),
	},
	{
		"id": "gunship",
		"name": "GUNSHIP",
		"description": "Slow, tough and dangerous at long range.",
		"max_speed": 36.0,
		"acceleration": 30.0,
		"turn_rate": 1.5,
		"max_health": 110.0,
		"damage": 8.0,
		"fire_interval": 1.3,
		"detect_range": 125.0,
		"attack_range": 95.0,
		"bolt_speed": 170.0,
		"score": 250,
		"model_file": "",
		"model_yaw_degrees": 0.0,
		"model_index": 4,
		"placeholder_variant": 4,
		"icon_color": Color(1.0, 0.75, 0.15),
	},
]

static var _cached_model_files: Array[String] = []
static var _scan_done: bool = false


## Returns every model file found in res://spaceships/ (sorted by name).
static func get_model_files() -> Array[String]:
	if _scan_done:
		return _cached_model_files
	_scan_done = true
	_cached_model_files.clear()
	var found: Array[String] = []
	_scan_directory(SHIP_DIR, found)
	# The same ship often exists in several formats (GLTF, FBX, OBJ).
	# Keep one file per ship name, preferring the format listed first in MODEL_EXTENSIONS.
	var best_by_name: Dictionary = {}
	for path in found:
		var key := path.get_file().get_basename().to_lower()
		if not best_by_name.has(key):
			best_by_name[key] = path
		else:
			var current_rank := MODEL_EXTENSIONS.find(String(best_by_name[key]).get_extension().to_lower())
			var new_rank := MODEL_EXTENSIONS.find(path.get_extension().to_lower())
			if new_rank < current_rank:
				best_by_name[key] = path
	var unique: Array[String] = []
	for path in best_by_name.values():
		unique.append(path)
	unique.sort()
	_cached_model_files = unique
	return _cached_model_files


## Returns the model path for a ship definition, or "" if no model is available.
static func resolve_model_path(definition: Dictionary, fallback_index: int) -> String:
	var files := get_model_files()
	var explicit_name: String = definition.get("model_file", "")
	if explicit_name != "":
		var explicit_path := SHIP_DIR + explicit_name
		if ResourceLoader.exists(explicit_path):
			return explicit_path
		push_warning("ShipCatalog: model_file '%s' was not found in %s" % [explicit_name, SHIP_DIR])
	if files.is_empty():
		return ""
	return files[fallback_index % files.size()]


## Model path for player ship number [param ship_index].
static func get_player_model_path(ship_index: int) -> String:
	return resolve_model_path(PLAYER_SHIPS[ship_index], ship_index)


## Model path for enemy type number [param enemy_index].
static func get_enemy_model_path(enemy_index: int) -> String:
	var definition: Dictionary = ENEMY_TYPES[enemy_index]
	return resolve_model_path(definition, int(definition.get("model_index", enemy_index)))


## Creates the visual model for a player ship.
static func create_player_visual(ship_index: int) -> Node3D:
	var definition: Dictionary = PLAYER_SHIPS[ship_index]
	return ShipModelFactory.create(
		get_player_model_path(ship_index),
		PLAYER_MODEL_SIZE,
		float(definition["model_yaw_degrees"]),
		int(definition["placeholder_variant"])
	)


## Creates the visual model for an enemy.
static func create_enemy_visual(enemy_index: int) -> Node3D:
	var definition: Dictionary = ENEMY_TYPES[enemy_index]
	return ShipModelFactory.create(
		get_enemy_model_path(enemy_index),
		ENEMY_MODEL_SIZE,
		float(definition["model_yaw_degrees"]),
		int(definition["placeholder_variant"])
	)


static func _scan_directory(path: String, results: Array[String]) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		return
	for file_name in dir.get_files():
		# Exported games list resources with an extra ".import" or ".remap" suffix.
		var clean_name := file_name.trim_suffix(".import").trim_suffix(".remap")
		var extension := clean_name.get_extension().to_lower()
		if MODEL_EXTENSIONS.has(extension):
			var full_path := path.path_join(clean_name)
			if not results.has(full_path):
				results.append(full_path)
	for sub_dir in dir.get_directories():
		_scan_directory(path.path_join(sub_dir), results)
