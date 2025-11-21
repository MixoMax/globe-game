extends RigidBody3D

@export_group("Ship Settings")
@export var move_force = 10.0
@export var turn_torque = 1.5
@export var throttle_response = 0.5
@export var rudder_response = 2.0
@export var max_speed = 0.5
@export var buoyancy_force = 10.0
@export var stabilization_torque = 0.5
@export var linear_damp_water = 2.0
@export var angular_damp_water = 3.0
@export var globe_manager: Node

@export_group("Camera Settings")
@export var camera_smooth_speed: float = 5.0
@export var camera_lag_speed: float = 2.0
# Presets: Position (Vector3), Rotation Degrees (Vector3)
var camera_presets: Array[Dictionary] = [
	{"pos": Vector3(0, 0.2, 0.4), "rot": Vector3(-15, 0, 0)},   # Standard (Behind & slightly up)
	{"pos": Vector3(0, 0.6, 1.0), "rot": Vector3(-25, 0, 0)},   # Far (More overview)
	{"pos": Vector3(0, 1.5, 0.1), "rot": Vector3(-85, 0, 0)},   # Top-Down
	{"pos": Vector3(0, 0.15, -0.2), "rot": Vector3(0, 0, 0)},    # First Person / Bow
	{"pos": Vector3(1.0, 0.5, 0.0), "rot": Vector3(0, 90, 0)},    # Side View (Starboard)
	{"pos": Vector3(-1.0, 0.5, 0.0), "rot": Vector3(0, -90, 0)}   # Side View (Port)
]
var current_cam_index: int = 0
@onready var camera_node: Camera3D = $Camera3D

@export_group("Buoyancy Grid")
@export var points_x: int = 5
@export var points_y: int = 100
@export var points_z: int = 5
@export var debug_points: bool = true

@export_group("Debug")
@export var show_debug_vectors: bool = true
@export var vector_scale: float = 0.5

const GRAVITY_STRENGTH = 9.81 / 2
var globe_radius = 5.0
var water_height = 5.0

# Variables to store vectors for drawing
var _debug_gravity_vec := Vector3.ZERO
var _debug_buoyancy_vec := Vector3.ZERO
var _debug_move_vec := Vector3.ZERO
var _debug_torque_vec := Vector3.ZERO

# Debug Mesh setup (Same as your code)
var debug_mesh_instance: MeshInstance3D
var debug_mesh: ImmediateMesh
var debug_material: StandardMaterial3D

var inputs = {
	"move_forward": false,
	"move_backward": false,
	"turn_left": false,
	"turn_right": false,
}

var current_throttle: float = 0.0
var current_rudder: float = 0.0

var buoyancy_points: Array[Vector3] = []
var buoyancy_point_status: Array[bool] = [] # true if underwater
var buoyancy_point_forces: Array[Vector3] = []

func _ready() -> void:
	# Generate buoyancy points grid
	generate_buoyancy_points()

	# IMPORTANT: Disable Godot's default linear gravity for this object
	gravity_scale = 0.0
	
	setup_debug_mesh()
	
	if camera_node:
		camera_node.top_level = true

func generate_buoyancy_points():
	buoyancy_points.clear()
	
	# Get the collision shape to fit points inside
	var col_shape_node = get_node_or_null("CollisionShape3D")
	if not col_shape_node:
		print("Ship: No CollisionShape3D found, using default box")
		_generate_box_points(Vector3(0.5, 0.5, 1.0))
		return

	var shape = col_shape_node.shape
	# We need to generate points in the Shape's local space, then transform them to Ship's local space
	var shape_transform = col_shape_node.transform
	
	if shape is CapsuleShape3D:
		var radius = shape.radius
		var height = shape.height
		# CapsuleShape3D is always Y-aligned in its own local space
		var bounds = Vector3(radius * 2, height, radius * 2)
		
		for x in range(points_x):
			for y in range(points_y):
				for z in range(points_z):
					var u = float(x) / max(1, points_x - 1)
					var v = float(y) / max(1, points_y - 1)
					var w = float(z) / max(1, points_z - 1)
					
					# Point in Shape Local Space (centered at 0,0,0 relative to shape node)
					var px = lerp(-bounds.x/2, bounds.x/2, u)
					var py = lerp(-bounds.y/2, bounds.y/2, v)
					var pz = lerp(-bounds.z/2, bounds.z/2, w)
					
					# Check if inside vertical capsule
					var dist_from_axis = Vector2(px, pz).length() # XZ plane distance
					var half_height = height / 2.0 - radius
					
					var inside = false
					if abs(py) <= half_height:
						if dist_from_axis <= radius:
							inside = true
					else:
						var sphere_center_y = half_height * sign(py)
						var dist_from_sphere = Vector3(px, py - sphere_center_y, pz).length()
						if dist_from_sphere <= radius:
							inside = true
							
					if inside:
						# Transform from Shape Space to Ship Space
						var pt_ship_space = shape_transform * Vector3(px, py, pz)
						buoyancy_points.append(pt_ship_space)
	else:
		# Fallback for other shapes (Box, etc) - just use a box approximation
		_generate_box_points(Vector3(1,1,2))

	print("Ship: Generated ", buoyancy_points.size(), " buoyancy points.")
	buoyancy_point_status.resize(buoyancy_points.size())
	buoyancy_point_status.fill(false)
	buoyancy_point_forces.resize(buoyancy_points.size())
	buoyancy_point_forces.fill(Vector3.ZERO)

func _generate_box_points(size: Vector3):
	for x in range(points_x):
		for y in range(points_y):
			for z in range(points_z):
				var u = float(x) / max(1, points_x - 1)
				var v = float(y) / max(1, points_y - 1)
				var w = float(z) / max(1, points_z - 1)
				var pt = Vector3(
					lerp(-size.x/2, size.x/2, u),
					lerp(-size.y/2, size.y/2, v),
					lerp(-size.z/2, size.z/2, w)
				)
				buoyancy_points.append(pt)
	
	if not globe_manager:
		var parent = get_parent()
		if parent:
			for child in parent.get_children():
				if child.has_method("get_water_height"):
					globe_manager = child
					print("Ship: Found GlobeManager automatically: ", child.name)
					break
	
	if globe_manager:
		if globe_manager.get("map_image"): # Check property safely
			find_spawn_point()
		else:
			print("Ship: Waiting for map generation...")
			if globe_manager.has_signal("map_generated"):
				globe_manager.map_generated.connect(find_spawn_point)
	else:
		print("Ship: Warning - GlobeManager not found!")

func _process(delta):
	if show_debug_vectors:
		draw_debug_lines()
	else:
		debug_mesh.clear_surfaces()
	
	_update_camera(delta)

func _update_camera(delta):
	if not camera_node:
		return
		
	var target = camera_presets[current_cam_index]
	
	# Calculate target global transform
	var target_local_pos = target["pos"]
	var target_local_rot_deg = target["rot"]
	var target_basis = Basis.from_euler(target_local_rot_deg * (PI / 180.0))
	var target_local_transform = Transform3D(target_basis, target_local_pos)
	
	var target_global_transform = global_transform * target_local_transform
	
	# Smoothly interpolate global position (Honey effect)
	camera_node.global_position = camera_node.global_position.lerp(target_global_transform.origin, delta * camera_lag_speed)
	
	# Smoothly interpolate global rotation
	var current_quat = camera_node.global_transform.basis.get_rotation_quaternion()
	var target_quat = target_global_transform.basis.get_rotation_quaternion()
	var new_quat = current_quat.slerp(target_quat, delta * camera_lag_speed)
	camera_node.global_transform.basis = Basis(new_quat)

func _integrate_forces(state: PhysicsDirectBodyState3D):
	var boat_position = global_transform.origin
	
	# 1. Calculate "Down" and "Up" relative to the sphere center
	# This defines the local gravity direction
	var up_direction = boat_position.normalized()
	var gravity_direction = -up_direction
	
	# Reset debug vectors
	_debug_gravity_vec = Vector3.ZERO
	_debug_buoyancy_vec = Vector3.ZERO
	_debug_move_vec = Vector3.ZERO
	_debug_torque_vec = Vector3.ZERO
	
	if globe_manager:
		globe_radius = globe_manager.size
		water_height = globe_manager.get_water_height(boat_position)
	
	# --- 1) Spherical Gravity ---
	# We use Apply Force (Continuous) rather than Impulse (Instant)
	var gravity_f = gravity_direction * GRAVITY_STRENGTH * mass
	state.apply_central_force(gravity_f)
	_debug_gravity_vec = gravity_f

	# --- 2) Spherical Buoyancy ---
	var points_underwater_count = 0
	var total_points = buoyancy_points.size()
	if total_points == 0: return

	# Pre-calculate force per point to avoid division in loop
	var force_per_point = buoyancy_force / float(total_points)
	var damp_per_point = linear_damp_water / float(total_points)
	
	for i in range(total_points):
		var point = buoyancy_points[i]
		var global_point = state.transform * point
		var dist_from_center = global_point.length()
		
		var local_water_height = water_height
		if globe_manager:
			local_water_height = globe_manager.get_water_height(global_point)
		else:
			print("Ship: Warning - GlobeManager not found during buoyancy calculation!")
			
		if dist_from_center < local_water_height:
			buoyancy_point_status[i] = true
			points_underwater_count += 1
			
			var depth = local_water_height - dist_from_center
			var point_up = global_point.normalized()
			
			# Calculate force for this point
			var force_mag = force_per_point * (clamp(depth, 1.0, 5.0)**2) * mass
			var buoy_f = point_up * force_mag
			buoyancy_point_forces[i] = buoy_f
			
			# Apply force at position (offset from center)
			var offset = global_point - state.transform.origin
			state.apply_force(buoy_f, offset)
			
			_debug_buoyancy_vec += buoy_f
			
			# Apply Drag at this point
			var point_velocity = state.get_velocity_at_local_position(point)
			var drag_force = -point_velocity * damp_per_point * mass
			state.apply_force(drag_force, offset)
		else:
			buoyancy_point_status[i] = false
			buoyancy_point_forces[i] = Vector3.ZERO

	var is_underwater = points_underwater_count > 0

	if is_underwater:
		# Additional Angular Damping
		state.angular_velocity *= (1.0 - state.step * angular_damp_water)
		
		# --- 3) Orientation Alignment (The Slingshot Fix) ---
		# We must torque the ship so its local Y axis matches the Sphere's Normal (up_direction)
		var current_up = global_transform.basis.y
		
		# Cross product gives us the axis to rotate around to get from A to B
		var align_torque = current_up.cross(up_direction)
		state.apply_torque(align_torque * stabilization_torque * mass)

	# --- 4) Movement ---
	# Calculate target throttle based on input
	var target_throttle = 0.0
	if inputs["move_forward"]: target_throttle += 1.0
	if inputs["move_backward"]: target_throttle -= 1.0
	
	# Ramp throttle towards target
	current_throttle = move_toward(current_throttle, target_throttle, throttle_response * state.step)
	
	# Limit max speed
	if abs(current_throttle) > max_speed / move_force:
		current_throttle = sign(current_throttle) * (max_speed / move_force)

	if abs(current_throttle) > 0.01 and is_underwater:
		# Apply force relative to ship's forward direction (-Z)
		var forward_dir = -global_transform.basis.z
		var move_f = forward_dir * current_throttle * move_force * mass
		state.apply_central_force(move_f)
		_debug_move_vec = move_f

	# --- 5) Turning ---
	var target_turn = 0.0
	if inputs["turn_left"]: target_turn += 1.0
	if inputs["turn_right"]: target_turn -= 1.0
	
	# Ramp rudder towards target
	current_rudder = move_toward(current_rudder, target_turn, rudder_response * state.step)
		
	if abs(current_rudder) > 0.01 and is_underwater:
		# Calculate forward speed (projection of velocity onto forward vector)
		# Assuming -Z is forward
		var forward_dir = -state.transform.basis.z
		var forward_speed = state.linear_velocity.dot(forward_dir)
		
		# Scale turning by speed to prevent "turntable" spinning in place.
		# We use abs(forward_speed) so steering works in reverse too.
		# 5.0 is a reference speed for max turning effectiveness.
		var speed_factor = clamp(abs(forward_speed) / 5.0, 0.0, 1.0)
		
		# Invert steering when reversing for more natural "car/boat" feel
		var direction_factor = 1.0
		if forward_speed < -0.1:
			direction_factor = -1.0
			
		# Rotate around the ship's local Y axis (which we are aligning to the sphere normal)
		var turn_t = state.transform.basis.y * current_rudder * turn_torque * mass * speed_factor * direction_factor
		state.apply_torque(turn_t)
		_debug_torque_vec = turn_t

# ... (Keep your setup_debug_mesh, draw_debug_lines, find_spawn_point, and _input functions exactly as they were) ...

func setup_debug_mesh():
	debug_mesh_instance = MeshInstance3D.new()
	debug_mesh = ImmediateMesh.new()
	debug_material = StandardMaterial3D.new()
	debug_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	debug_material.vertex_color_use_as_albedo = true
	debug_mesh_instance.mesh = debug_mesh
	debug_mesh_instance.material_override = debug_material
	debug_mesh_instance.top_level = true 
	debug_mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(debug_mesh_instance)

func draw_debug_lines():
	debug_mesh.clear_surfaces()
	
	# 1. Draw Vectors (Lines)
	debug_mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	var origin = global_transform.origin
	var add_line = func(vec: Vector3, color: Color):
		debug_mesh.surface_set_color(color)
		debug_mesh.surface_add_vertex(origin)
		debug_mesh.surface_set_color(color)
		debug_mesh.surface_add_vertex(origin + vec)

	if _debug_gravity_vec.length_squared() > 0.01: add_line.call(_debug_gravity_vec.normalized() * 2.0, Color.RED)
	if _debug_buoyancy_vec.length_squared() > 0.01: add_line.call(_debug_buoyancy_vec.normalized() * 2.0, Color.CYAN)
	if _debug_move_vec.length_squared() > 0.01: add_line.call(_debug_move_vec.normalized() * 2.0, Color.GREEN)
	if _debug_torque_vec.length_squared() > 0.01: add_line.call(_debug_torque_vec.normalized() * 2.0, Color.YELLOW)
	debug_mesh.surface_end()

	# 2. Draw Buoyancy Points
	if debug_points and buoyancy_points.size() > 0:
		debug_mesh.surface_begin(Mesh.PRIMITIVE_POINTS)
		for i in range(buoyancy_points.size()):
			var pt = global_transform * buoyancy_points[i]
			if buoyancy_point_status[i]:
				debug_mesh.surface_set_color(Color.BLUE) # Underwater
			else:
				debug_mesh.surface_set_color(Color.RED) # Above water
			debug_mesh.surface_add_vertex(pt)
		debug_mesh.surface_end()
		
		# Draw per-point buoyancy forces
		if buoyancy_points.size() > 0:
			debug_mesh.surface_begin(Mesh.PRIMITIVE_LINES)
			for i in range(buoyancy_points.size()):
				if buoyancy_point_status[i]:
					var pt = global_transform * buoyancy_points[i]
					var f = buoyancy_point_forces[i]
					# Scale up slightly since per-point forces are small, but keep them "very short"
					var end = pt + f * vector_scale * 0.1
					
					debug_mesh.surface_set_color(Color.GREEN_YELLOW)
					debug_mesh.surface_add_vertex(pt)
					debug_mesh.surface_add_vertex(end)
			debug_mesh.surface_end()

		# Draw a line from the first point to the water surface to visualize the discrepancy
		if buoyancy_points.size() > 0:
			debug_mesh.surface_begin(Mesh.PRIMITIVE_LINES)
			var pt = global_transform * buoyancy_points[0]
			var water_h = water_height
			if globe_manager:
				water_h = globe_manager.get_water_height(pt)
			
			var center_dir = pt.normalized()
			var water_pos = center_dir * water_h
			
			debug_mesh.surface_set_color(Color.MAGENTA)
			debug_mesh.surface_add_vertex(pt)
			debug_mesh.surface_add_vertex(water_pos)
			debug_mesh.surface_end()

func cycle_camera():
	current_cam_index = (current_cam_index + 1) % camera_presets.size()

func find_spawn_point():
	var spawn_point_found = false
	var attempts = 0
	while not spawn_point_found and attempts < 1000:
		var random_direction = Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)).normalized()
		var potential_position = random_direction * (globe_manager.size + 1.0)

		if globe_manager.has_method("is_water") and globe_manager.is_water(potential_position):
			global_transform.origin = potential_position
			# Pre-orient the ship so it doesn't tumble immediately
			look_at_from_position(potential_position, Vector3.ZERO, Vector3.UP)
			spawn_point_found = true
			
			# Snap camera to new position immediately
			if camera_node:
				var target = camera_presets[current_cam_index]
				var target_basis = Basis.from_euler(target["rot"] * (PI / 180.0))
				var target_local = Transform3D(target_basis, target["pos"])
				camera_node.global_transform = global_transform * target_local
				
			print("Ship spawned at: ", potential_position)
		attempts += 1
	if not spawn_point_found:
		print("Ship: Could not find a valid spawn point.")
		global_transform.origin = Vector3(0, globe_manager.size + 1.0, 0)

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_W: inputs["move_forward"] = true
			KEY_S: inputs["move_backward"] = true
			KEY_A: inputs["turn_left"] = true
			KEY_D: inputs["turn_right"] = true
			KEY_C: cycle_camera()
	elif event is InputEventKey and not event.pressed:
		match event.keycode:
			KEY_W: inputs["move_forward"] = false
			KEY_S: inputs["move_backward"] = false
			KEY_A: inputs["turn_left"] = false
			KEY_D: inputs["turn_right"] = false
