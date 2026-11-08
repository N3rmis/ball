extends Node3D

signal globalModTime

@export var material: Material

@export var csgMesh: CSGPolygon3D

@export var finish: Node3D

@export var island: PackedScene
@export var islands: Node3D

var trackPoints: PackedVector2Array
var allPositions = []
var islandI = 0

var generationSeed = -1

var thread: Thread

var mutex: Mutex
var mesh_data_ready = false
var mesh_vertices = PackedVector3Array()
var mesh_indices = PackedInt32Array()
var mesh_uvs = PackedVector2Array()
var mesh_uvs2 = PackedVector2Array()
var mesh_normals = PackedVector3Array()
var mesh_faces = PackedVector3Array()

var first = 0.6
var progression = [first/7*1, first/7*2, first/7*3, first/7*4, first/7*5, first/7*6, first/7*7, 1]
var progressionStep = 0.001

var progress = -1
var minX = 0

var types = []
var typeCurve = Curve3D.new()

var animationPlayer
func generate_track():
	var currentSeed = generationSeed
	
	mutex = Mutex.new()
	mesh_data_ready = false
	
	var pos = Vector3()
	var forward = Quaternion()
		
	const scalar = 0.1
	
	var tvel = Vector3(0, -0.2, 0)
	var vel = tvel
	
	var curve = Curve3D.new()
	curve.add_point(Vector3())
	
	seed(Network.options.seed)
	
	allPositions = []
	
	var positions = []
	var quaternions = []
	
	var typeCurve = Curve3D.new()
	var types = []
	
	var currentType = 0
	var currentRow = 0
	
	var currentProgress = 0
	
	for i in range(Network.options.length * 100):
		
		if generationSeed != currentSeed:
			return
		
		var p = i / Network.options.length / 100
		if (p - currentProgress) * progression[0] > progressionStep:
			currentProgress = p
			call_deferred('_on_progress', currentProgress * progression[0])
		
		pos += Vector3(0, 0, -1 * scalar) * forward
		curve.add_point(pos)
		
		if i % 100 == 0:
			typeCurve.add_point(pos)
			currentRow += 1
			
			var pleaseSkip = currentType == 3
			var willSkip = randf() > (0.9 ** currentRow) or (pleaseSkip and randf() > (0.5 ** currentRow))
			if willSkip:
				currentRow = 0
				currentType = randi_range(0, 3)
			
			if Network.globalMod == 'ice':
				currentType = 2
			if Network.globalMod == 'bouncy':
				currentType = 3
			if Network.globalMod == 'sticky':
				currentType = 1
			if Network.globalMod == 'boost':
				currentType = 4
			
			types.append(currentType)
		
		if i % int(2 / scalar) == 0:
			allPositions.append(pos)
		
		if i >= Network.options.length * 100 - 2:
			positions.append(pos)
			quaternions.append(forward)
		
		var turnFactor = Network.options.turning
		if turnFactor < 0:
			turnFactor = 1 / abs(turnFactor)
		tvel.x += randf_range(-0.5, 0.5) * scalar * turnFactor
		tvel.y += randf_range(-0.1, 0.1) * scalar * turnFactor
		
		tvel.y = clamp(tvel.y, -0.5, 0)
		
		tvel.x -= (tvel.x ** 3) * scalar * 10 / turnFactor
		tvel.x = clamp(tvel.x, -2, 2)
		
		vel = vel.lerp(tvel, 0.025)
		
		pos.y += vel.y * scalar
		
		forward *= Quaternion(Vector3(0, 1, 0), vel.x * scalar / Network.options.trackSize) 
		
		Global.voidLevel = min(Global.voidLevel, pos.y - 5)
	
	var mesh = gen_mesh(curve, csgMesh.polygon, Network.options.length * 100, types)
	
	if generationSeed != currentSeed:
		return
	#
	#var arrays = []
	#arrays.resize(Mesh.ARRAY_MAX)
	#arrays[Mesh.ARRAY_VERTEX] = mesh.vertices
	#arrays[Mesh.ARRAY_INDEX] = mesh.indices
	#arrays[Mesh.ARRAY_TEX_UV] = mesh.uvs
	#arrays[Mesh.ARRAY_NORMAL] = mesh.normals
	#
	#var arrayMesh = ArrayMesh.new()
	#arrayMesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	#
	var faces = gen_collision(mesh.vertices, mesh.indices)
	
	if generationSeed != currentSeed:
		return
	
	mutex.lock()
	mesh_vertices = mesh.vertices
	mesh_indices = mesh.indices
	mesh_uvs = mesh.uvs
	mesh_uvs2 = mesh.uvs2
	mesh_normals = mesh.normals
	mesh_faces = faces
	#mesh_shape = 
	mesh_data_ready = true
	mutex.unlock()
	
	if generationSeed != currentSeed:
		return
	
	call_deferred('_points_generated', positions, quaternions, types, typeCurve)
		#forward2 *= Quaternion(Vector3(0, 1, 0), vel.y)
		
		#var perp = Vector3(1, 0, 0) * forward2
		#forward *= Quaternion(perp, vel.x)

func _on_seed():
	generationSeed = Network.options.seed
	progress = 0
	Global.progressName = 'generation'
	minX = INF
	var points = trackPoints.duplicate()
	for i in range(len(points)):
		if points[i].x < 0:
			points[i] = points[i] - Vector2(Network.options.trackSize - 1, 0)
		if points[i].x > 0:
			points[i] = points[i] + Vector2(Network.options.trackSize - 1, 0)
		minX = min(minX, points[i].x)
	csgMesh.polygon = points
	finish.visible = false
	
	thread = Thread.new()
	thread.start(generate_track)
	#animationPlayer.play("transOut")

func _on_progress(percentage):
	progress = percentage

func _points_generated(positions, quaternions, ntypes, ntypeCurve):
	types = ntypes
	typeCurve = ntypeCurve
	_load_when_ready(positions, quaternions)
	#add_child(npath)
	#csgMesh.path_node = npath.get_path()
	#finish.position = positions[0] - $Path3D.global_position
	#
	#for island2 in islands.get_children():
		#island2.queue_free()
	#
	#islandI = -1
	#_next_island()
		
	## Calculate the actual forward direction from the last quaternion
	#var track_forward = Vector3(0, 0, -1) * quaternions[0]
	#var track_up = Vector3(0, 1, 0) * quaternions[0]
	#
	## Create a basis from the track direction and set it
	#var finish_basis = Basis()
	#finish_basis.z = -track_forward.normalized()  # Forward is -Z in Godot
	#finish_basis.y = track_up.normalized()
	#finish_basis.x = finish_basis.y.cross(finish_basis.z).normalized()
	#finish_basis = finish_basis.orthonormalized()
	#
	#finish.basis = finish_basis
	##finish.quaternion = quaternions[len(quaternions) - 1]
	##finish.rotation = $Path3D.global_rotation * finishQ
	#
	#var current_path = csgMesh.path_node
	#csgMesh.path_node = NodePath("")
	#csgMesh.path_node = current_path

func _load_when_ready(positions, quaternions):
	mutex.lock()
	var isReady = mesh_data_ready
	mutex.unlock()
	
	if not isReady:
		await get_tree().process_frame
		_load_when_ready(positions, quaternions)
		return
	
	var currentSeed = generationSeed
	
	mutex.lock()
	var vertices = mesh_vertices
	var indices = mesh_indices
	var uvs = mesh_uvs
	var uvs2 = mesh_uvs2
	var normals = mesh_normals
	var faces = mesh_faces
	#var arrayMesh = mesh_mesh
	#var shape = mesh_shape
	mesh_data_ready = false
	mutex.unlock()
	
	var arrays = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_INDEX] = indices
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_TEX_UV2] = uvs2
	arrays[Mesh.ARRAY_NORMAL] = normals
	
	var arrayMesh = ArrayMesh.new()
	arrayMesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	
	arrayMesh.surface_set_material(0, material)
	$mesh.mesh = arrayMesh
	
	for island2 in islands.get_children():
		island2.queue_free()
	
	islandI = -1
	_next_island()
	
	for shape in $collisions.get_children():
		shape.queue_free()
	
	var currentProgress = 0
	Global.progressName = 'collisions'
	
	var chunks = split_into_chunks(faces, 30000)
	var i = 0
	for chunk in chunks:
		if generationSeed != currentSeed:
			return
		var p = float(i) / len(chunks)
		if (p - currentProgress) * (progression[7] - progression[6]) > progressionStep:
			currentProgress = p
			_on_progress(currentProgress * (progression[7] - progression[6]) + progression[6])
		var shape = ConcavePolygonShape3D.new()
		shape.set_faces(chunk)
		
		var cshape = CollisionShape3D.new()
		cshape.shape = shape
		$collisions.add_child(cshape)
		
		await get_tree().process_frame
		
		i += 1
	
	progress = -1
	
	#var shape = ConcavePolygonShape3D.new()
	#shape.set_faces(vertices)
	#shape.set_faces(arrayMesh.get_faces())
	#$collisions/shape.shape = shape
	
	Network.emit('loaded')
	
	finish.visible = true
	finish.position = positions[0]
	
	# Calculate the actual forward direction from the last quaternion
	var track_forward = Vector3(0, 0, -1) * quaternions[0]
	var track_up = Vector3(0, 1, 0) * quaternions[0]
	
	# Create a basis from the track direction and set it
	var finish_basis = Basis()
	finish_basis.z = -track_forward.normalized()  # Forward is -Z in Godot
	finish_basis.y = track_up.normalized()
	finish_basis.x = finish_basis.y.cross(finish_basis.z).normalized()
	finish_basis = finish_basis.orthonormalized()
	
	finish.basis = finish_basis
	#finish.quaternion = quaternions[len(quaternions) - 1]
	#finish.rotation = $Path3D.global_rotation * finishQ
	
func _next_island():
	islandI += 1
	if islandI >= len(allPositions):
		return
	var pos1 = allPositions[islandI]
	if randf() > 0.9:
		var offset = Vector3(0, 0, 0)
		for try in range(10):
			offset = Vector3(randf_range(-1, 1), randf_range(0, 0.25), randf_range(-1, 1)).normalized() * randf_range(10, 20)
			var again = false
			for pos2 in allPositions:
				if (pos1 + offset).distance_to(pos2) < 10:
					again = true
			if not again:
				break
		
		var newIsland = island.instantiate()
		newIsland.position = pos1 + offset
		newIsland.noiseSeed = randi()
		newIsland.on_generated.connect(_next_island)
		newIsland.start_generate()
		islands.add_child(newIsland)
	else:
		_next_island()

func _exit_tree() -> void:
	if thread and thread.is_alive():
		thread.wait_to_finish()

func _ready() -> void:
	Network.on_seed.connect(_on_seed)
	Network.cancel_start.connect(_cancel_start)
	
	trackPoints = csgMesh.polygon
	_on_seed()


func _cancel_start():
	generationSeed = -1
	progress = -1

func gen_mesh(curve: Curve3D, cross: PackedVector2Array, segments: int, types):
	var vertices = PackedVector3Array()
	var indices = PackedInt32Array()
	var uvs = PackedVector2Array()
	var uvs2 = PackedVector2Array()
	
	var currentProgress = 0
	var currentSeed = generationSeed
	
	var typeUvs = [
		Vector2(0, 0),
		Vector2(0.5, 0),
		Vector2(0, 0.5),
		Vector2(0.5, 0.5)
	]
	
	Global.progressName = 'mesh'
	
	for i in range(segments + 1):
		if generationSeed != currentSeed:
			return
		var p = float(i) / segments
		if (p - currentProgress) * (progression[1] - progression[0]) > progressionStep:
			currentProgress = p
			call_deferred('_on_progress', currentProgress * (progression[1] - progression[0]) + progression[0])
		
		var t = float(i) / segments
		var point = curve.sample_baked(t * curve.get_baked_length())
		var forward = (curve.sample_baked(t * curve.get_baked_length() + 0.1) - point).normalized()
		
		var up = Vector3.UP
		if abs(forward.dot(up)) > 0.99:
			up = Vector3.RIGHT
		var right = forward.cross(up).normalized()
		up = right.cross(forward).normalized()
		
		for vpoint in cross:
			var vertex = point + right * vpoint.x + up * vpoint.y
			vertices.append(vertex)
			
			var type_idx = min(int(floor(float(i) / 100.0)), types.size() - 1)
			var type = types[type_idx] if type_idx >= 0 and type_idx < types.size() else 0
			
			uvs.append(Vector2(vpoint.x / 1.5, t * segments / 20))
			uvs2.append(typeUvs[type])
	
	currentProgress = 0
	
	var csc = cross.size()
	for i in range(segments):
		if generationSeed != currentSeed:
			return
		var p = float(i) / segments
		if (p - currentProgress) * (progression[2] - progression[1]) > progressionStep:
			currentProgress = p
			call_deferred('_on_progress', currentProgress * (progression[2] - progression[1]) + progression[1])
		for j in range(csc):
			var current = i * csc + j
			var next = current + csc
			
			indices.append(current)
			indices.append(next)
			indices.append(current + 1 if j < csc - 1 else i * csc)
			
			indices.append(current + 1 if j < csc - 1 else i * csc)
			indices.append(next)
			indices.append(next + 1 if j < csc - 1 else (i + 1) * csc)
	
	return {
		'vertices': vertices,
		'indices': indices,
		'uvs': uvs,
		'uvs2': uvs2,
		'normals': calculate_normals(vertices, indices)
	}

func calculate_normals(vertices: PackedVector3Array, indices: PackedInt32Array):
	var normals = PackedVector3Array()
	normals.resize(vertices.size())
	var currentSeed = generationSeed
	var currentProgress = 0
	
	for i in range(vertices.size()):
		if generationSeed != currentSeed:
			return
		var p = float(i) / vertices.size()
		if (p - currentProgress) * (progression[3] - progression[2]) > progressionStep:
			currentProgress = p
			call_deferred('_on_progress', currentProgress * (progression[3] - progression[2]) + progression[2])
		normals[i] = Vector3.ZERO
	
	currentProgress = 0
	
	for i in range(0, indices.size(), 3):
		if generationSeed != currentSeed:
			return
		var p = float(i) / indices.size()
		if (p - currentProgress) * (progression[4] - progression[3]) > progressionStep:
			currentProgress = p
			call_deferred('_on_progress', currentProgress * (progression[4] - progression[3]) + progression[3])
		
		var i0 = indices[i]
		var i1 = indices[i + 1]
		var i2 = indices[i + 2]
		
		var v0 = vertices[i0]
		var v1 = vertices[i1]
		var v2 = vertices[i2]
		
		var edge1 = v1 - v0
		var edge2 = v2 - v0
		var normal = edge1.cross(edge2).normalized()
		
		normals[i0] -= normal
		normals[i1] -= normal
		normals[i2] -= normal
	
	currentProgress = 0
	
	for i in range(normals.size()):
		if generationSeed != currentSeed:
			return
		var p = float(i) / normals.size()
		if (p - currentProgress) * (progression[5] - progression[4]) > progressionStep:
			currentProgress = p
			call_deferred('_on_progress', currentProgress * (progression[5] - progression[4]) + progression[4])
		
		normals[i] = normals[i].normalized()
	
	return normals

func gen_collision(vertices: PackedVector3Array, indices: PackedInt32Array):
	var currentSeed = generationSeed
	var currentProgress = 0
	var faces = PackedVector3Array()
	for i in range(0, indices.size(), 3):
		if generationSeed != currentSeed:
			return
		var p = float(i) / indices.size()
		if (p - currentProgress) * (progression[6] - progression[5]) > progressionStep:
			currentProgress = p
			call_deferred('_on_progress', currentProgress * (progression[6] - progression[5]) + progression[5])
		faces.append(vertices[indices[i]])
		faces.append(vertices[indices[i + 1]])
		faces.append(vertices[indices[i + 2]])
	return faces
	
func split_into_chunks(all_faces: PackedVector3Array, chunk_size: int) -> Array:
	var chunks = []
	for i in range(0, all_faces.size(), chunk_size):
		chunks.append(all_faces.slice(i, i + chunk_size))
	return chunks

func get_track_type(pos: Vector3):
	if typeCurve.point_count == 0 or types.is_empty(): 
		return 0
	var closest = typeCurve.get_closest_offset(pos)
	return get_track_type_from_distance(closest)

func get_track_type_from_distance(dist: float) -> int:
	if types.is_empty() or typeCurve.point_count == 0:
		return 0
	var length = typeCurve.get_baked_length()
	if length <= 0.0:
		return 0
	var interval = length / float(types.size())
	if interval <= 0.0:
		return 0

	var index = int(floor(dist / interval))
	if index < 0 or index >= types.size():
		return 0
	
	return types[index]

func get_distance(pos: Vector3):
	if typeCurve.point_count == 0: 
		return 0
	
	return typeCurve.get_closest_offset(pos)

func get_point(distance: float):
	if typeCurve.point_count == 0: 
		return Vector3()
	return typeCurve.sample_baked(distance)
