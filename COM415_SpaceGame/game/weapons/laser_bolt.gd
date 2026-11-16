class_name LaserBolt
extends Node3D
## A laser projectile.
##
## Instead of relying on collisions of a fast-moving body (which can tunnel through
## thin targets), every physics frame the bolt casts a ray from its old position to
## its new one. Idea based on the KidsCanCode "3D shooting" recipe:
## https://kidscancode.org/godot_recipes/3.x/3d/3d_shooting/index.html

const COLLISION_WORLD := 1
const COLLISION_PLAYER := 2
const COLLISION_ENEMY := 4

var velocity: Vector3 = Vector3.ZERO
var damage: float = 10.0
var lifetime: float = 2.5
var hit_mask: int = COLLISION_WORLD
var glow_color: Color = Color(0.3, 0.9, 1.0)

var _age: float = 0.0
var _ignored: Array[RID] = []

static var _bolt_mesh: BoxMesh = null


## Creates a bolt, adds it to [param parent] and starts it moving.
static func fire(
		parent: Node, origin: Vector3, direction: Vector3, speed: float,
		bolt_damage: float, mask: int, color: Color, shooter: CollisionObject3D) -> LaserBolt:
	var bolt := LaserBolt.new()
	bolt.velocity = direction.normalized() * speed
	bolt.damage = bolt_damage
	bolt.hit_mask = mask
	bolt.glow_color = color
	if shooter != null:
		bolt._ignored.append(shooter.get_rid())
	parent.add_child(bolt)
	var up := Vector3.UP
	if absf(direction.normalized().dot(Vector3.UP)) > 0.98:
		up = Vector3.RIGHT
	bolt.global_transform = Transform3D(Basis.looking_at(direction.normalized(), up), origin)
	return bolt


func _ready() -> void:
	if _bolt_mesh == null:
		_bolt_mesh = BoxMesh.new()
		_bolt_mesh.size = Vector3(0.18, 0.18, 3.2)
	var visual := MeshInstance3D.new()
	visual.mesh = _bolt_mesh
	visual.material_override = Effects.glow_material(glow_color)
	visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(visual)


func _physics_process(delta: float) -> void:
	_age += delta
	if _age >= lifetime:
		queue_free()
		return
	var from := global_position
	var to := from + velocity * delta
	var query := PhysicsRayQueryParameters3D.create(from, to, hit_mask, _ignored)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		global_position = to
		return
	var collider: Object = hit["collider"]
	if collider != null and collider.has_method("take_damage"):
		collider.call("take_damage", damage, hit["position"])
	Effects.sparks(get_parent(), hit["position"], glow_color)
	queue_free()
