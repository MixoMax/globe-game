@tool
extends Node

@export var shader: ShaderMaterial
@export var waterShader: ShaderMaterial
@export var resolution: int = 10
@export var size: float = 1
@export_tool_button("Generate Mesh")
var button = genMesh

		
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	genMesh()

var vertices:Array[Vector3] = []

class Chunk extends MeshInstance3D:
	func _init(startPos: Vector3, endPos: Vector3, resolution: int, size: float, shader: ShaderMaterial, waterShader: ShaderMaterial) -> void:
		print("new chunk")
		var arrayMesh := ArrayMesh.new()
		var vertices := PackedVector3Array([])
		var indices := PackedInt32Array([])
		var normals := PackedVector3Array([])
		
		
		
		var dx = endPos.x-startPos.x
		var dy = endPos.y-startPos.y
		var dz = endPos.z-startPos.z
		
		
		
		for x in range(max(sign(dx)*resolution,1)):
			for y in range(max(sign(dy)*resolution,1)):
				for z in range(max(sign(dz)*resolution,1)):
					var dir = Vector3(
						startPos.x + x/float(resolution-1),
						startPos.y + y/float(resolution-1),
						startPos.z + z/float(resolution-1))
					dir = dir.normalized()
					normals.append(dir)
					
					var pos = Vector3(dir)
					pos *= size
					vertices.append(pos)
					
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
		
		arrayMesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, vao)
		#arrayMesh.surface_get_material(0).set("size",size);
		material_override = shader
		mesh = arrayMesh
		
		var waterMesh = MeshInstance3D.new()
		var waterArrayMesh = ArrayMesh.new()
		waterArrayMesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, vao)
		waterMesh.material_override = waterShader
		waterMesh.mesh = waterArrayMesh
		add_child(waterMesh)
	
	func generate():
		pass


func genMesh() -> void:
	print("> Started Generating Mesh...")
	
	vertices = []
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
