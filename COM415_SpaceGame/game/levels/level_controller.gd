class_name LevelController
extends Node3D
## Runs one level from start to finish.
##
## Flow: build world -> bake FlightNavigation3D -> spawn player, enemies and
## exit gate -> play -> kill enough enemies -> fly through the gate (or die).

signal kills_changed(kills: int, goal: int)

enum Phase { LOADING, PLAYING, COMPLETE, GAME_OVER }

const NAVIGATION_SCENE := "res://addons/flight_navigation_3d/core/src/flight_navigation_3d.tscn"
## Extra enemies beyond the kill goal, so the goal can always be reached.
const SPARE_ENEMIES := 2
const MIN_ENEMY_SPAWN_DISTANCE := 120.0

var level_def: Dictionary = {}
var world: WorldBase
var player: PlayerShip
var chase_camera: ChaseCamera
var navigation: FlightNavigation3D
var path_service: PathService
var projectile_root: Node3D
var enemy_root: Node3D
var gate: ExitGate
var hud: Hud

var phase: Phase = Phase.LOADING
var elapsed: float = 0.0
var kills: int = 0
var enemy_goal: int = 5
var gate_is_open: bool = false
var navigation_ready: bool = false
var navigation_build_seconds: float = 0.0


func _ready() -> void:
	level_def = LevelCatalog.get_level(GameState.selected_level_index)
	enemy_goal = int(level_def["enemy_goal"])
	EnemyShip.shared_agents.clear()

	world = (load(level_def["world_script"]) as GDScript).new() as WorldBase
	world.name = "World"
	add_child(world)
	world.build()

	projectile_root = Node3D.new()
	projectile_root.name = "Projectiles"
	add_child(projectile_root)
	enemy_root = Node3D.new()
	enemy_root.name = "Enemies"
	add_child(enemy_root)

	hud = Hud.new()
	hud.name = "Hud"
	add_child(hud)
	hud.set_loading("BUILDING FLIGHT NAVIGATION...")
	# Let the loading screen appear before the (slow) navigation bake begins.
	await get_tree().process_frame
	await get_tree().process_frame
	await _build_navigation()

	_spawn_player()
	_spawn_gate()
	_spawn_enemies()
	hud.bind(self)
	hud.hide_loading()
	AudioManager.play_music(world.music_key)
	phase = Phase.PLAYING
	hud.show_message("%s\nDESTROY %d ENEMIES" % [String(level_def["name"]), enemy_goal], 4.0)


func _process(delta: float) -> void:
	if phase != Phase.PLAYING:
		return
	elapsed += delta
	if gate_is_open and player.is_alive:
		if player.global_position.distance_to(gate.global_position) < world.gate_radius * 0.9:
			_complete_level()


## Keeps a position inside the playable volume.
func clamp_to_bounds(point: Vector3) -> Vector3:
	var area := world.bounds
	return Vector3(
		clampf(point.x, area.position.x, area.end.x),
		clampf(point.y, area.position.y, area.end.y),
		clampf(point.z, area.position.z, area.end.z)
	)


func get_random_patrol_point() -> Vector3:
	return world.random_free_point(world.patrol_area, 20.0)


# --- Setup --------------------------------------------------------------------

## Creates the FlightNavigation3D node, voxelises the obstacles and prepares path finding.
func _build_navigation() -> void:
	var start_time := Time.get_ticks_msec()
	navigation = (load(NAVIGATION_SCENE) as PackedScene).instantiate() as FlightNavigation3D
	navigation.name = "FlightNavigation3D"
	navigation.size = Vector3.ONE * world.nav_size
	navigation.position = world.nav_center
	var voxelizer := SvoVoxelizer.new()
	voxelizer.name = "SvoVoxelizer"
	voxelizer.layer_count = world.nav_layers
	navigation.add_child(voxelizer)
	navigation.pathfinder = GreedyAStar.new()
	add_child(navigation)
	# The CSG volume must stay "visible" while baking, but must not be drawn.
	navigation.layers = 0
	for child in navigation.get_children():
		if child is MeshInstance3D:
			(child as MeshInstance3D).visible = false

	await navigation.build_navigation()
	navigation_ready = navigation.sparse_voxel_octree != null
	navigation.visible = false  # stops CSG updates now the bake is finished
	navigation_build_seconds = (Time.get_ticks_msec() - start_time) / 1000.0
	print("[Level] navigation baked in %.2f s (ready=%s)" % [navigation_build_seconds, navigation_ready])

	path_service = PathService.new()
	path_service.name = "PathService"
	path_service.navigation = navigation
	path_service.is_ready = navigation_ready
	add_child(path_service)


func _spawn_player() -> void:
	player = PlayerShip.new()
	player.name = "PlayerShip"
	player.setup(GameState.selected_ship_index, self)
	player.projectile_root = projectile_root
	player.transform = Transform3D(Basis.looking_at(world.player_facing, Vector3.UP), world.player_start)
	add_child(player)
	player.died.connect(_on_player_died)
	player.collided.connect(_on_player_collided)

	chase_camera = ChaseCamera.new()
	chase_camera.name = "ChaseCamera"
	chase_camera.target = player
	add_child(chase_camera)


func _spawn_gate() -> void:
	gate = ExitGate.new()
	gate.name = "ExitGate"
	gate.radius = world.gate_radius
	gate.position = world.gate_position
	add_child(gate)


func _spawn_enemies() -> void:
	var total := enemy_goal + SPARE_ENEMIES
	for i in range(total):
		var type_index := 1 if i % 3 == 2 else 0
		var spawn_point := world.random_free_point(world.patrol_area, 25.0)
		for attempt in range(20):
			if spawn_point.distance_to(world.player_start) >= MIN_ENEMY_SPAWN_DISTANCE:
				break
			spawn_point = world.random_free_point(world.patrol_area, 25.0)
		var enemy := EnemyShip.new()
		enemy.name = "Enemy%d" % i
		enemy.setup(type_index, self, player)
		var heading := Vector3(randf_range(-1, 1), randf_range(-0.2, 0.2), randf_range(-1, 1)).normalized()
		enemy.transform = Transform3D(Basis.looking_at(heading, Vector3.UP), spawn_point)
		enemy_root.add_child(enemy)
		enemy.died.connect(_on_enemy_died)


# --- Events -------------------------------------------------------------------

func _on_enemy_died(_enemy: EnemyShip) -> void:
	kills += 1
	kills_changed.emit(kills, enemy_goal)
	if kills >= enemy_goal and not gate_is_open and phase == Phase.PLAYING:
		gate_is_open = true
		gate.set_open(true)
		hud.show_message("ALL TARGETS DESTROYED!\nFLY THROUGH THE JUMP GATE", 5.0)
		AudioManager.play_sfx("warning", -4.0, 1.4)


func _on_player_collided(_impact_speed: float) -> void:
	chase_camera.add_shake(1.2)


func _on_player_died() -> void:
	if phase != Phase.PLAYING:
		return
	phase = Phase.GAME_OVER
	chase_camera.add_shake(2.5)
	await get_tree().create_timer(1.8).timeout
	hud.overlay.show_game_over(kills, enemy_goal)


func _complete_level() -> void:
	phase = Phase.COMPLETE
	var level_id := String(level_def["id"])
	var is_new_best := GameState.record_time(level_id, elapsed)
	var best := float(GameState.best_times.get(level_id, elapsed))
	player.fire_pressed = false
	hud.show_message("JUMP SUCCESSFUL!", 2.0)
	await get_tree().create_timer(0.9).timeout
	hud.overlay.show_complete(elapsed, best, is_new_best)
