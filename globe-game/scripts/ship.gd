extends RigidBody3D

@export var move_force = 5.0
@export var turn_torque = 1.0
@export var buoyancy_force = 20.0
@export var globe_manager: Node

const gravity_strength = 9.8
var globe_radius = 5.0
var water_height = 5.0

var inputs = {
	"move_forward": false,
	"move_backward": false,
	"turn_left": false,
	"turn_right": false,
}

func _ready() -> void:
	if not globe_manager:
		# Try to find GlobeManager in the scene (siblings)
		var parent = get_parent()
		if parent:
			for child in parent.get_children():
				if child.has_method("get_water_height"):
					globe_manager = child
					print("Ship: Found GlobeManager automatically: ", child.name)
					break
	
	if globe_manager:
		if globe_manager.map_image:
			find_spawn_point()
		else:
			print("Ship: Waiting for map generation...")
			globe_manager.map_generated.connect(find_spawn_point)
	else:
		print("Ship: Warning - GlobeManager not found! Water height will not update and cannot find spawn point.")

func find_spawn_point():
	var spawn_point_found = false
	var attempts = 0
	while not spawn_point_found and attempts < 1000:
		var random_direction = Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)).normalized()
		var potential_position = random_direction * (globe_manager.size + 1.0)

		if globe_manager.has_method("is_water") and globe_manager.is_water(potential_position):
			global_transform.origin = potential_position
			spawn_point_found = true
			print("Ship spawned at: ", potential_position)
		attempts += 1
	if not spawn_point_found:
		print("Ship: Could not find a valid spawn point in water after 1000 attempts.")
		global_transform.origin = Vector3(0, globe_manager.size + 1.0, 0)

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_W:
				inputs["move_forward"] = true
			KEY_S:
				inputs["move_backward"] = true
			KEY_A:
				inputs["turn_left"] = true
			KEY_D:
				inputs["turn_right"] = true
	elif event is InputEventKey and not event.pressed:
		match event.keycode:
			KEY_W:
				inputs["move_forward"] = false
			KEY_S:
				inputs["move_backward"] = false
			KEY_A:
				inputs["turn_left"] = false
			KEY_D:
				inputs["turn_right"] = false

func _integrate_forces(state):
	# Aply gravity toward (0, 0, 0), as we are on a globe
	# Apply buoyancy based on wave height
	# handle WASD input for movement and turning (relative and custom because of globe)
	var boat_position = global_transform.origin
	var gravity_direction = -boat_position.normalized()

	
	if globe_manager:
		globe_radius = globe_manager.size
		water_height = globe_manager.get_water_height(boat_position)
	
	print("Boat Position: ", boat_position)
	print("Water Height at Boat Position: ", water_height)
	print("Boat height", boat_position.length())
	

	# Apply gravity
	# get distance from center of globe
	var distance_from_center = boat_position.length()
	var gravity_magnitude = gravity_strength * (distance_from_center / globe_radius)
	# we should always strive towards the center of the globe (0,0,0)
	state.apply_central_impulse(gravity_direction * gravity_magnitude * mass * state.step)

	# Rotate boat to align with globe surface normal
	var surface_normal = boat_position.normalized()
	var current_up = global_transform.basis.y
	var rotation_axis = current_up.cross(surface_normal)
	var angle_difference = acos(current_up.dot(surface_normal))
	if angle_difference > 0.001:
		var rotation_amount = rotation_axis.normalized() * angle_difference * 5.0 * state.step
		var new_basis = global_transform.basis.rotated(rotation_axis.normalized(), angle_difference * 5.0 * state.step)
		global_transform.basis = new_basis.orthonormalized()
	
	

	# Calculate wave height at boat position
	if distance_from_center < water_height:
		var depth = water_height - distance_from_center
		state.apply_central_impulse(-gravity_direction * buoyancy_force * depth * mass * state.step)
		# Add some drag/damping in water
		state.linear_velocity *= 0.98
		state.angular_velocity *= 0.95
	
	# Handle input
	# since we are on a globe, we need to define "forward" and "right" relative to the boat's orientation
	# forward is -Z in local space, right is +X
	var input_vector = Vector3.ZERO
	if inputs["move_forward"]:
		input_vector -= global_transform.basis.z
	if inputs["move_backward"]:
		input_vector += global_transform.basis.z
	if inputs["turn_left"]:
		print("Applying turn torque: ", global_transform.basis.y * turn_torque * mass * state.step)
		state.apply_torque_impulse(global_transform.basis.y * turn_torque * mass * state.step)
	if inputs["turn_right"]:
		print("Applying turn torque: ", global_transform.basis.y * -turn_torque * mass * state.step)
		state.apply_torque_impulse(global_transform.basis.y * -turn_torque * mass * state.step)
	if input_vector != Vector3.ZERO:
		input_vector = input_vector.normalized()
		print("Applying move force: ", input_vector * move_force * mass * state.step)
		state.apply_central_impulse(input_vector * move_force * mass * state.step)
