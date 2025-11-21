@tool
class_name GlobeManager
extends Node

signal map_generated

@export var shader: ShaderMaterial
@export var waterShader: ShaderMaterial
@export var resolution: int = 20
@export var size: float = 50.0
@export var map_resolution: Vector2i = Vector2i(512, 256)
@export var noise: FastNoiseLite
@export var water_level: float = 0.2
@export var use_target_water_percent: bool = false
@export_range(0.0, 1.0) var target_water_percent: float = 0.9
@export var land_height_multiplier: float = 1.0
@export var height_scale: float = 1.0
@export var wave_speed: float = 0.5
@export var wave_global_scale: float = 0.1

var map_image: Image

@export_tool_button("Generate Mesh")
var button = genMesh

func _ready() -> void:
	if not noise:
		noise = FastNoiseLite.new()
		noise.seed = randi()
		noise.frequency = 0.01
		noise.fractal_type = FastNoiseLite.FRACTAL_FBM
		noise.fractal_octaves = 5
	genMesh()

class Chunk extends MeshInstance3D:
	func _init(startPos: Vector3, endPos: Vector3, resolution: int, size: float, shader: ShaderMaterial, waterShader: ShaderMaterial) -> void:
		var arrayMesh := ArrayMesh.new()
		var vertices := PackedVector3Array([])
		var indices := PackedInt32Array([])
		var normals := PackedVector3Array([])
		var uvs := PackedVector2Array([])
		
		var dx = endPos.x-startPos.x
		var dy = endPos.y-startPos.y
		var dz = endPos.z-startPos.z
		
		for x in range(max(sign(dx)*resolution,1)):
			for y in range(max(sign(dy)*resolution,1)):
				for z in range(max(sign(dz)*resolution,1)):
					var u_step = x/float(resolution-1)
					var v_step = y/float(resolution-1)
					var w_step = z/float(resolution-1)
					
					var dir = Vector3(
						startPos.x + u_step * abs(dx),
						startPos.y + v_step * abs(dy),
						startPos.z + w_step * abs(dz))
					
					dir = dir.normalized()
					normals.append(dir)
					
					var pos = dir * size
					vertices.append(pos)
					
					# UV Calculation (Equirectangular)
					# atan2(z, x) gives longitude. asin(y) gives latitude.
					# We need to handle the seam correctly in the shader or here.
					# Standard mapping:
					var u = atan2(dir.x, -dir.z) / (2.0 * PI) + 0.5
					var v = asin(dir.y) / PI + 0.5
					uvs.append(Vector2(u, v))
					
					var i:int = x if abs(dx) > 0 else y
					var j:int = y if abs(dx) > 0 and abs(dy) > 0 else z
					
					var index = i + j*resolution
					
					if j >= 1 and i >= 1:
						if startPos.x <= 0 and ((startPos.y >= 0) if dy==0 else (startPos.y <= 0)) and startPos.z <= 0:
							indices.append(index-resolution)
							indices.append(index-1)
							indices.append(index)
							
							indices.append(index-resolution-1)
							indices.append(index-1)
							indices.append(index-resolution)
						else:
							indices.append(index)
							indices.append(index-1)
							indices.append(index-resolution)
						
							indices.append(index-resolution-1)
							indices.append(index-resolution)
							indices.append(index-1)
		
		var vao = []
		vao.resize(Mesh.ARRAY_MAX)
		vao[Mesh.ARRAY_VERTEX] = vertices
		vao[Mesh.ARRAY_INDEX] = indices
		vao[Mesh.ARRAY_NORMAL] = normals
		vao[Mesh.ARRAY_TEX_UV] = uvs
		
		arrayMesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, vao)
		material_override = shader
		mesh = arrayMesh
		create_trimesh_collision()
		
		var waterMesh = MeshInstance3D.new()
		var waterArrayMesh = ArrayMesh.new()
		waterArrayMesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, vao)
		waterMesh.material_override = waterShader
		waterMesh.mesh = waterArrayMesh
		add_child(waterMesh)

func generate_map():
	print("Generating Map...")
	if not noise: return
	
	var img = Image.create(map_resolution.x, map_resolution.y, false, Image.FORMAT_RGBAF)
	map_image = img
	
	# 1. Generate Height
	var height_values = []
	if use_target_water_percent:
		height_values.resize(map_resolution.x * map_resolution.y)

	var raw_heights = []
	raw_heights.resize(map_resolution.x * map_resolution.y)

	for y in range(map_resolution.y):
		for x in range(map_resolution.x):
			var u = float(x) / map_resolution.x
			var v = float(y) / map_resolution.y
			
			# Equirectangular to Cartesian for 3D noise sampling
			var theta = (u - 0.5) * 2.0 * PI
			var phi = (v - 0.5) * PI
			
			var nx = cos(phi) * sin(theta)
			var ny = sin(phi)
			var nz = cos(phi) * cos(theta)
			
			# Sample noise
			var h = noise.get_noise_3d(nx*100, ny*100, nz*100)
			
			raw_heights[y * map_resolution.x + x] = h
			if use_target_water_percent:
				height_values[y * map_resolution.x + x] = h

	if use_target_water_percent:
		height_values.sort()
		var idx = int(height_values.size() * target_water_percent)
		idx = clamp(idx, 0, height_values.size() - 1)
		water_level = height_values[idx]

	# Store height in Red channel
	# Initialize Green (Distance) to -1.0 for water (unvisited), 0.0 for land
	for y in range(map_resolution.y):
		for x in range(map_resolution.x):
			var h = raw_heights[y * map_resolution.x + x]
			
			if h > water_level:
				# Apply land height multiplier
				h = water_level + (h - water_level) * land_height_multiplier
				img.set_pixel(x, y, Color(h, 0.0, 0, 1))
			else:
				img.set_pixel(x, y, Color(h, -1.0, 0, 1))

	# 2. Generate Distance Field (BFS)
	var frontier: Array[Vector2i] = []
	
	# Find initial coastline (land pixels next to water) or just start from all land
	# Starting from all land is easier
	for y in range(map_resolution.y):
		for x in range(map_resolution.x):
			if img.get_pixel(x, y).r > water_level:
				frontier.append(Vector2i(x, y))
	
	var max_dist = float(max(map_resolution.x, map_resolution.y)) / 2.0
	var current_dist = 0.0
	
	while frontier.size() > 0:
		var next_frontier: Array[Vector2i] = []
		current_dist += 1.0 / max_dist
		
		for pos in frontier:
			var neighbors = [
				Vector2i((pos.x + 1) % map_resolution.x, pos.y),
				Vector2i((pos.x - 1 + map_resolution.x) % map_resolution.x, pos.y),
				Vector2i(pos.x, min(pos.y + 1, map_resolution.y - 1)),
				Vector2i(pos.x, max(pos.y - 1, 0))
			]
			
			for n in neighbors:
				var p = img.get_pixel(n.x, n.y)
				if p.g == -1.0: # Unvisited water
					# Update distance
					img.set_pixel(n.x, n.y, Color(p.r, current_dist, 0, 1))
					next_frontier.append(n)
		
		frontier = next_frontier

	var tex = ImageTexture.create_from_image(img)
	
	if shader:
		shader.set_shader_parameter("map_texture", tex)
		shader.set_shader_parameter("water_level", water_level)
		shader.set_shader_parameter("height_scale", height_scale)
	if waterShader:
		waterShader.set_shader_parameter("map_texture", tex)
		waterShader.set_shader_parameter("water_level", water_level)
		waterShader.set_shader_parameter("height_scale", height_scale)
		waterShader.set_shader_parameter("wave_speed", wave_speed)
		waterShader.set_shader_parameter("wave_global_scale", wave_global_scale)
	
	map_generated.emit()

func get_water_height(pos: Vector3) -> float:
	# 1. Calculate UV (Equirectangular projection matching Chunk generation)
	var dir = pos.normalized()
	var u = atan2(dir.x, -dir.z) / (2.0 * PI) + 0.5
	var v = asin(dir.y) / PI + 0.5
	
	# 2. Sample Distance to Shore (Green channel)
	var dist_to_shore = 1.0
	if map_image:
		var x = clamp(int(u * (map_image.get_width() - 1)), 0, map_image.get_width() - 1)
		var y = clamp(int(v * (map_image.get_height() - 1)), 0, map_image.get_height() - 1)
		dist_to_shore = map_image.get_pixel(x, y).g
	
	# 3. Calculate Wave (Replicating Shader Math)
	# Note: Shader uses TIME. We use Time.get_ticks_msec() / 1000.0
	var time = Time.get_ticks_msec() / 1000.0
	
	# Use pos (global) which corresponds to VERTEX in shader if globe is at (0,0,0)
	var wave = sin(pos.x * 10.0 + time * wave_speed) * 0.5
	wave += cos(pos.z * 8.0 + time * wave_speed * 0.8) * 0.5
	wave += sin(pos.x * 20.0 - time * wave_speed * 1.2) * 0.2
	
	var amplitude = smoothstep(0.0, 0.1, dist_to_shore)
	var final_wave_height = wave * amplitude * wave_global_scale
	
	# Return total radius from center
	return size + (water_level * height_scale) + final_wave_height

func is_water(pos: Vector3) -> bool:
	var dir = pos.normalized()
	var u = atan2(dir.x, -dir.z) / (2.0 * PI) + 0.5
	var v = asin(dir.y) / PI + 0.5

	if map_image:
		var x = clamp(int(u * (map_image.get_width() - 1)), 0, map_image.get_width() - 1)
		var y = clamp(int(v * (map_image.get_height() - 1)), 0, map_image.get_height() - 1)
		var height = map_image.get_pixel(x, y).r
		return height <= water_level
	print("GlobeManager: No map image available to determine water height.")
	return false # Default to false if no map

func genMesh() -> void:
	print("> Started Generating Mesh...")
	
	generate_map()
	
	for child in get_children():
		child.queue_free()
	
	var chunks = [
		Chunk.new(Vector3(-.5,-.5, .5),Vector3( .5, .5, .5), resolution, size, shader,waterShader),
		Chunk.new(Vector3(-.5,-.5,-.5),Vector3( .5, .5,-.5), resolution, size, shader,waterShader),
		Chunk.new(Vector3(-.5, .5,-.5),Vector3( .5, .5, .5), resolution, size, shader,waterShader),
		Chunk.new(Vector3(-.5,-.5,-.5),Vector3( .5,-.5, .5), resolution, size, shader,waterShader),
		Chunk.new(Vector3( .5,-.5,-.5),Vector3( .5, .5, .5), resolution, size, shader,waterShader),
		Chunk.new(Vector3(-.5,-.5,-.5),Vector3(-.5, .5, .5), resolution, size, shader,waterShader)
		];
	for chunk in chunks:
		add_child(chunk)
		
	print("> Generated Mesh")
