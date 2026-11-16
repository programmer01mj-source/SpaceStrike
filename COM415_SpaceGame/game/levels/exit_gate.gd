class_name ExitGate
extends Node3D
## The glowing ring the player must fly through after destroying enough enemies.
## Dim red while locked, bright green and pulsing once it is open.

var radius: float = 22.0
var is_open: bool = false

var _ring_material: StandardMaterial3D
var _beam_material: StandardMaterial3D
var _light: OmniLight3D
var _time: float = 0.0


func _ready() -> void:
	_ring_material = StandardMaterial3D.new()
	_ring_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_ring_material.emission_enabled = true
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.outer_radius = radius
	torus.inner_radius = radius * 0.9
	torus.rings = 32
	torus.ring_segments = 8
	ring.mesh = torus
	ring.rotation_degrees = Vector3(90.0, 0.0, 0.0)
	ring.material_override = _ring_material
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ring)

	_beam_material = StandardMaterial3D.new()
	_beam_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_beam_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_beam_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	var beam := MeshInstance3D.new()
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = 1.2
	cylinder.bottom_radius = 1.2
	cylinder.height = 260.0
	cylinder.radial_segments = 8
	beam.mesh = cylinder
	beam.material_override = _beam_material
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(beam)

	_light = OmniLight3D.new()
	_light.omni_range = radius * 3.0
	add_child(_light)
	set_open(false)


func set_open(open: bool) -> void:
	is_open = open
	var color := Color(0.2, 1.0, 0.45) if open else Color(0.9, 0.15, 0.15)
	_ring_material.albedo_color = color
	_ring_material.emission = color
	_ring_material.emission_energy_multiplier = 3.0 if open else 0.8
	_beam_material.albedo_color = Color(color.r, color.g, color.b, 0.35 if open else 0.08)
	_light.light_color = color
	_light.light_energy = 3.0 if open else 0.6


func _process(delta: float) -> void:
	_time += delta
	if is_open:
		var pulse := 1.0 + sin(_time * 4.0) * 0.04
		scale = Vector3.ONE * pulse
