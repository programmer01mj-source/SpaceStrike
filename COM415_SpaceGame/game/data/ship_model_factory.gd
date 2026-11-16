class_name ShipModelFactory
extends RefCounted
## Builds the visual model of a ship.
##
## If a real model file exists (from res://spaceships/) it is loaded, centred,
## and scaled so its longest side matches the requested size - so models of any
## size work without editing. If no model is available, a simple placeholder
## ship is built from primitive meshes so the game always runs.
##
## The returned node always faces -Z (Godot's forward direction), provided the
## "yaw_degrees" value is correct for the model.

const PLACEHOLDER_COLORS: Array[Color] = [
	Color(0.25, 0.75, 1.0),
	Color(0.35, 0.9, 0.45),
	Color(0.85, 0.4, 1.0),
	Color(1.0, 0.3, 0.25),
	Color(1.0, 0.7, 0.15),
]


static func create(model_path: String, target_size: float, yaw_degrees: float, variant: int) -> Node3D:
	var pivot := Node3D.new()
	pivot.name = "ShipVisual"
	var model: Node3D = null
	if model_path != "" and ResourceLoader.exists(model_path):
		var loaded: Resource = load(model_path)
		if loaded is PackedScene:
			var instance: Node = (loaded as PackedScene).instantiate()
			if instance is Node3D:
				model = instance
			else:
				instance.queue_free()
	if model == null:
		model = _build_placeholder(variant)
	var bounds := calculate_bounds(model, Transform3D.IDENTITY)
	var longest_side := maxf(bounds.size.x, maxf(bounds.size.y, bounds.size.z))
	var scale_factor := 1.0
	if longest_side > 0.001:
		scale_factor = target_size / longest_side
	var holder := Node3D.new()
	holder.name = "ModelHolder"
	holder.rotation.y = deg_to_rad(yaw_degrees)
	holder.scale = Vector3.ONE * scale_factor
	model.position -= bounds.get_center()
	holder.add_child(model)
	pivot.add_child(holder)
	return pivot


## Applies an emissive tint to every mesh (used to make enemies easy to spot).
static func add_glow_tint(root: Node, color: Color, strength: float) -> void:
	for child in root.get_children():
		if child is MeshInstance3D:
			var mesh_instance := child as MeshInstance3D
			for surface in range(mesh_instance.get_surface_override_material_count()):
				var source: Material = mesh_instance.get_active_material(surface)
				if source is StandardMaterial3D:
					var copy := (source as StandardMaterial3D).duplicate() as StandardMaterial3D
					copy.emission_enabled = true
					copy.emission = color
					copy.emission_energy_multiplier = strength
					mesh_instance.set_surface_override_material(surface, copy)
		add_glow_tint(child, color, strength)


static func calculate_bounds(node: Node, parent_transform: Transform3D) -> AABB:
	var result := AABB()
	var has_result := false
	var current_transform := parent_transform
	if node is Node3D:
		current_transform = parent_transform * (node as Node3D).transform
	if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
		result = current_transform * (node as MeshInstance3D).mesh.get_aabb()
		has_result = true
	for child in node.get_children():
		var child_bounds := calculate_bounds(child, current_transform)
		if child_bounds.size == Vector3.ZERO:
			continue
		if has_result:
			result = result.merge(child_bounds)
		else:
			result = child_bounds
			has_result = true
	return result


static func _build_placeholder(variant: int) -> Node3D:
	var root := Node3D.new()
	root.name = "PlaceholderShip"
	var body_color := PLACEHOLDER_COLORS[variant % PLACEHOLDER_COLORS.size()]
	var hull_material := _make_material(body_color.darkened(0.25), 0.0)
	var accent_material := _make_material(body_color, 0.6)
	var glass_material := _make_material(Color(0.1, 0.15, 0.25), 0.0)
	glass_material.metallic = 0.8
	glass_material.roughness = 0.1
	var engine_material := _make_material(Color(1.0, 0.7, 0.3), 3.0)

	# Fuselage: a long box pointing along -Z.
	_add_box(root, Vector3(0.9, 0.6, 3.6), Vector3.ZERO, hull_material)
	# Nose cone made from a prism.
	var nose := MeshInstance3D.new()
	var nose_mesh := PrismMesh.new()
	nose_mesh.size = Vector3(0.9, 1.4, 0.6)
	nose.mesh = nose_mesh
	nose.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	nose.position = Vector3(0.0, 0.0, -2.4)
	nose.material_override = accent_material
	root.add_child(nose)
	# Cockpit
	var cockpit := MeshInstance3D.new()
	var cockpit_mesh := SphereMesh.new()
	cockpit_mesh.radius = 0.4
	cockpit_mesh.height = 0.8
	cockpit.mesh = cockpit_mesh
	cockpit.position = Vector3(0.0, 0.4, -0.6)
	cockpit.scale = Vector3(1.0, 0.8, 1.6)
	cockpit.material_override = glass_material
	root.add_child(cockpit)

	match variant % 5:
		0: # Falcon: swept wings
			_add_box(root, Vector3(4.6, 0.12, 1.1), Vector3(0.0, 0.0, 0.7), accent_material)
			_add_box(root, Vector3(0.1, 0.9, 0.8), Vector3(1.0, 0.4, 1.4), accent_material)
			_add_box(root, Vector3(0.1, 0.9, 0.8), Vector3(-1.0, 0.4, 1.4), accent_material)
		1: # Titan: chunky and wide
			_add_box(root, Vector3(3.2, 0.5, 2.2), Vector3(0.0, -0.1, 0.6), hull_material)
			_add_box(root, Vector3(0.7, 0.7, 2.8), Vector3(1.7, 0.0, 0.8), accent_material)
			_add_box(root, Vector3(0.7, 0.7, 2.8), Vector3(-1.7, 0.0, 0.8), accent_material)
		2: # Phantom: thin delta
			_add_box(root, Vector3(3.8, 0.08, 2.0), Vector3(0.0, 0.0, 0.9), accent_material)
			_add_box(root, Vector3(0.08, 1.0, 1.2), Vector3(0.0, 0.5, 1.5), accent_material)
		3: # Enemy fighter: forward-swept pincers
			_add_box(root, Vector3(0.35, 0.35, 2.6), Vector3(1.3, 0.0, -0.4), accent_material)
			_add_box(root, Vector3(0.35, 0.35, 2.6), Vector3(-1.3, 0.0, -0.4), accent_material)
			_add_box(root, Vector3(2.6, 0.2, 0.5), Vector3(0.0, 0.0, 0.9), hull_material)
		_: # Enemy gunship: heavy with side cannons
			_add_box(root, Vector3(2.4, 0.9, 2.4), Vector3(0.0, 0.0, 0.8), hull_material)
			_add_box(root, Vector3(0.4, 0.4, 3.4), Vector3(1.6, -0.1, -0.2), accent_material)
			_add_box(root, Vector3(0.4, 0.4, 3.4), Vector3(-1.6, -0.1, -0.2), accent_material)

	# Engine glow at the back of the ship.
	var engine := MeshInstance3D.new()
	var engine_mesh := SphereMesh.new()
	engine_mesh.radius = 0.28
	engine_mesh.height = 0.56
	engine.mesh = engine_mesh
	engine.position = Vector3(0.0, 0.0, 1.9)
	engine.material_override = engine_material
	root.add_child(engine)
	return root


static func _add_box(parent: Node3D, size: Vector3, offset: Vector3, material: Material) -> void:
	var mesh_instance := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh_instance.mesh = box
	mesh_instance.position = offset
	mesh_instance.material_override = material
	parent.add_child(mesh_instance)


static func _make_material(color: Color, glow: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = 0.5
	material.roughness = 0.45
	if glow > 0.0:
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = glow
	return material
