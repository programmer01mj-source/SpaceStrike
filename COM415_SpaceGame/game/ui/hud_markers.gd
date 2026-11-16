class_name HudMarkers
extends Control
## Draws the in-world HUD: aiming reticle, enemy target brackets (with health and
## distance), off-screen arrows and the exit gate marker.

const CROSSHAIR := "res://assets/ui/crosshairs/crosshair-010.png"

var level: LevelController = null

var _crosshair: Texture2D = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_crosshair = load(CROSSHAIR) as Texture2D


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if level == null or level.player == null or level.chase_camera == null:
		return
	var camera := level.chase_camera
	var player := level.player
	if not player.is_alive:
		return
	var font := ThemeDB.fallback_font
	if get_theme_default_font() != null:
		font = get_theme_default_font()

	# Aiming reticle: where the lasers will go, projected in front of the ship.
	var aim_point := player.global_position + player.get_forward() * 160.0
	if not camera.is_position_behind(aim_point):
		var aim_screen := camera.unproject_position(aim_point)
		var half := 36.0
		draw_texture_rect(_crosshair, Rect2(aim_screen - Vector2(half, half), Vector2(half, half) * 2.0), false, Color(0.4, 1.0, 1.0, 0.9))

	for node in get_tree().get_nodes_in_group("enemies"):
		var enemy := node as EnemyShip
		if enemy == null:
			continue
		_draw_marker(camera, enemy.global_position, enemy.icon_color, enemy.get_health_ratio(), font, true)
	if level.gate != null:
		var gate_color := Color(0.3, 1.0, 0.5) if level.gate_is_open else Color(0.8, 0.25, 0.25, 0.7)
		if level.gate_is_open:
			_draw_marker(camera, level.gate.global_position, gate_color, -1.0, font, false)


func _draw_marker(camera: Camera3D, world_position: Vector3, color: Color, health_ratio: float, font: Font, is_enemy: bool) -> void:
	var distance := camera.global_position.distance_to(world_position)
	var view_size := get_viewport_rect().size
	var margin := 50.0
	var behind := camera.is_position_behind(world_position)
	var screen := camera.unproject_position(world_position)
	var on_screen := not behind and screen.x > margin and screen.x < view_size.x - margin \
			and screen.y > margin and screen.y < view_size.y - margin
	if on_screen:
		var size := clampf(2600.0 / maxf(distance, 40.0), 14.0, 34.0)
		var box := Rect2(screen - Vector2(size, size), Vector2(size, size) * 2.0)
		var corner := size * 0.45
		for corner_index in range(4):
			var origin := box.position + Vector2(box.size.x * (corner_index % 2), box.size.y * (corner_index / 2))
			var dx := corner if corner_index % 2 == 0 else -corner
			var dy := corner if corner_index / 2 == 0 else -corner
			draw_line(origin, origin + Vector2(dx, 0), color, 2.5)
			draw_line(origin, origin + Vector2(0, dy), color, 2.5)
		if health_ratio >= 0.0 and is_enemy:
			var bar := Rect2(box.position + Vector2(0, -10), Vector2(box.size.x, 5))
			draw_rect(bar, Color(0, 0, 0, 0.6))
			draw_rect(Rect2(bar.position, Vector2(bar.size.x * health_ratio, bar.size.y)), color)
		var text := "%dm" % int(distance)
		draw_string(font, box.position + Vector2(0, box.size.y + 20.0), text, HORIZONTAL_ALIGNMENT_CENTER, box.size.x, 16, color)
		if not is_enemy:
			draw_string(font, box.position + Vector2(-40, -18), "JUMP GATE", HORIZONTAL_ALIGNMENT_CENTER, box.size.x + 80, 18, color)
	else:
		# Off-screen arrow on the edge of the screen pointing towards the target.
		var centre := view_size * 0.5
		var direction := screen - centre
		if behind:
			direction = -direction
		if direction.length_squared() < 1.0:
			direction = Vector2.DOWN
		direction = direction.normalized()
		var edge_scale := minf(
			(view_size.x * 0.5 - margin) / maxf(absf(direction.x), 0.001),
			(view_size.y * 0.5 - margin) / maxf(absf(direction.y), 0.001)
		)
		var arrow_position := centre + direction * edge_scale
		var side := Vector2(-direction.y, direction.x)
		var points := PackedVector2Array([
			arrow_position + direction * 16.0,
			arrow_position - direction * 10.0 + side * 12.0,
			arrow_position - direction * 10.0 - side * 12.0,
		])
		draw_colored_polygon(points, color)
