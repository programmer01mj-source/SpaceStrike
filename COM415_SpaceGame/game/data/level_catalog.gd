class_name LevelCatalog
extends RefCounted
## Describes the playable levels. Add a new dictionary to LEVELS (and a new
## world script) to add another level.

const LEVELS: Array[Dictionary] = [
	{
		"id": "space_01",
		"name": "ASTEROID BELT",
		"subtitle": "Deep Space",
		"description": "Hunt the raider fleet hiding among the asteroids and ancient planets, then jump out through the gate.",
		"world_script": "res://game/levels/space_world.gd",
		"enemy_goal": 8,
		"music": "space",
		"accent_color": Color(0.35, 0.55, 1.0),
	},
	{
		"id": "planet_01",
		"name": "CRIMSON CANYON",
		"subtitle": "Planet Surface",
		"description": "Skim low over an alien world. Weave between rock spires, trees and ruins while the defence squadron hunts you.",
		"world_script": "res://game/levels/planet_world.gd",
		"enemy_goal": 6,
		"music": "planet",
		"accent_color": Color(1.0, 0.55, 0.25),
	},
]


static func get_level(index: int) -> Dictionary:
	return LEVELS[clampi(index, 0, LEVELS.size() - 1)]
