class_name Player
extends CharacterBody3D

var upgradesGot = {
	'speedUp': 0,
	'rhinoMode': false,
	'grab': false
}

@export var camera: Camera

@export var username: Label3D
@export var mesh: Node3D
@export var core: Node3D
@export var scaleNode: Node3D

@export var speed = 5 / 100
@export var jumpHeight = 3
@export var gravity = 10
#@export var backSpeed = 5
#@export var minSpeed = 0
#@export var maxSpeed = 50
#@export var turnSpeed = 0.02
#@export var friction = 0.01

#dont need half those variables anymore

var floort = 0.0
var bounceFactor = 1.0
var moveSpeed = 0.0

var scaleVel = Vector3()
var lastPosition = Vector3()

var respawnTime = -1

#Camera vars
#@export var mouseSens = 1000
func _ready() -> void:
	_upgrades()
	Network.launch.connect(_launch)
	Network.spawn.connect(_spawn)
	username.text = Global.username
	lastPosition = position
	Sfx.get_node("wind_sfx").play()
	$speed_lines.visible = false
	
func tp(pos):
	var dif = pos - position
	position += dif
	lastPosition += dif
	reset_physics_interpolation()
	camera.position += dif
	camera.followPos += dif

func reset():
	position = Vector3()
	lastPosition = Vector3()
	velocity = Vector3()
	reset_physics_interpolation()
	camera.position = camera.offset
	camera.look_at(position + Vector3(0, 0.2, 0))
	camera.followPos = camera.offset + position
	camera.followQuat = camera.quaternion

func _physics_process(delta: float) -> void:
	speed = Network.options.speed / 100
	# get mouse to be used :O
	#if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		#Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	#elif Input.is_action_pressed("esc"):
		#Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	#if velocity.length() < 10:
	if Global.running:
		var speed_val = velocity.length()
		var density = min(speed_val / 30.0, 0.7)
		if density > 0.05:
			if not $speed_lines.visible:
				$speed_lines.visible = true
			$speed_lines.material.set_shader_parameter("line_density", density)
		else:
			if $speed_lines.visible:
				$speed_lines.visible = false
		Sfx.get_node("wind_sfx").volume_db = min(speed_val * 1.4 - 50, -20)
		Sfx.get_node("wind_sfx").pitch_scale = min(speed_val / 40.0 + 1, 2)
	else:
		if $speed_lines.visible:
			$speed_lines.visible = false
		Sfx.get_node("wind_sfx").volume_db = -100
	#print_debug(min(max(velocity.length()/40-10, 0)+1, 2))
	
	var currentDist = Global.distance
	if floort > 0:
		currentDist = $'../track'.get_distance(global_position)
		Global.distance = currentDist
	
	var trackType = $'../track'.get_track_type_from_distance(currentDist)
	
	var bounceModifier = 1
	var frictionModifier = 1
	
	if trackType == 1: #sticky
		bounceModifier = 0
		frictionModifier = 2
	
	if trackType == 2: #ice
		bounceModifier = 0.5
		frictionModifier = 0.5
	
	if trackType == 3: #bouncy
		bounceModifier = 3
		frictionModifier = 1
	
	if floort <= 0:
		frictionModifier = 0.25
	
	lastPosition = global_position
	var upgradeSpeedInc = 1 + upgradesGot.speedUp * Global.modifierModifications.speed
	moveSpeed = lerp(moveSpeed, Vector2(velocity.x, velocity.z).length() / 5 / upgradeSpeedInc, delta * 2)
	
	if Global.running:
		velocity.y -= gravity * delta
	
	#get input axis relative to camera direction
	var wasd = Vector3(Input.get_axis('left', 'right'), 0, Input.get_axis('slow', 'go')).normalized()
	camera.turn += wasd.x / 150
	wasd.x *= 0.5
	wasd *= camera.followQuat
	wasd *= -1
		
	if not Global.running:
		wasd *= 0
	
	floort -= delta
	
	var addSpeed = clamp(1 + moveSpeed ** 2 / 3, 1, 10)
	
	#print_debug(Vector2(velocity.x, velocity.z).normalized())
	#var diffModifier = 1 + (1 - (Vector2(velocity.x, velocity.z).normalized().dot(Vector2(wasd.x, -wasd.z)) + 1) / 2) 
	var diffModifier = 1
	
	frictionModifier *= diffModifier
	
	#add input axis onto velocity
	velocity.x += wasd.x * (speed * upgradeSpeedInc) * addSpeed * frictionModifier * diffModifier 
	velocity.z -= wasd.z * (speed * upgradeSpeedInc) * addSpeed * frictionModifier * diffModifier 
	
	#friction
	velocity.x *= 0.99 ** frictionModifier
	velocity.z *= 0.99 ** frictionModifier
	
	if not Global.running:
		velocity *= 0.99
	
	var oldVel = velocity
	var remaining_delta = delta
	var max_bounces = 4 
	var bounce_count = 0

	while remaining_delta > 0 and bounce_count < max_bounces:
		var collision = move_and_collide(velocity * remaining_delta, false, 0.001, false)
		
		if not collision:
			break
		
		bounce_count += 1
		var collider = collision.get_collider()
		var normal = collision.get_normal()
		
		if 'isNetworkPlayer' in collider:
			var launch = oldVel + Vector3(0, 0.2, 0) * Vector2(velocity.x, velocity.z).length()
			if collider.connected:
				collider.send_msg('launch', [launch.x, launch.y, launch.z], true)
		
		var is_floor = normal.dot(Vector3.UP) > 0.5
		var is_wall = normal.dot(Vector3.UP) <= 0.5 and normal.dot(Vector3.UP) > -0.5
		
		if is_floor:
			floort = 0.25
		
		var bounciness = 0.3 * bounceModifier
		var velocity_along_normal = velocity.dot(normal)
		
		if velocity_along_normal < 0:
			if is_wall:
				var tangent_vel = velocity - (velocity.dot(normal) * normal)
				var normal_vel = velocity.dot(normal) * normal
				var wall_friction = 0.99 ** frictionModifier
				tangent_vel *= wall_friction
				velocity = tangent_vel + normal_vel
			
			if trackType == 3 or velocity_along_normal < -1.5:
				var bounce_vel = velocity_along_normal * normal * (1.0 + bounciness * bounceFactor)
				if trackType == 3:
					bounce_vel -= normal
				velocity -= bounce_vel
				bounceFactor = 1.0
			else:
				velocity -= velocity_along_normal * normal
		
		var travel_len = collision.get_travel().length()
		var expected_len = (oldVel * delta).length()
		if expected_len > 0.0001:
			remaining_delta *= (1.0 - travel_len / expected_len)
		else:
			break
		
		if remaining_delta < 0.001:
			break
	
	# jump
	if Network.options.jumps == true:
		if Input.is_action_pressed("jump") && floort > 0:
			velocity.y = jumpHeight
			floort = 0
	
	if respawnTime != -1:
		respawnTime -= delta
		$core/scale.scale = Vector3.ONE * respawnTime * 5
	else:
		$core/scale.scale = Vector3.ONE
	
	# respawn
	if Input.is_action_pressed("respawn") and Global.running:
		respawnTime = 0.2
	
	#void
	if position.y < Global.voidLevel or (respawnTime <= 0 and respawnTime != -1):
		moveSpeed = 0.0
		velocity = Vector3(0, velocity.y, 0)
		if velocity.y > 0:
			velocity.y = 0
		tp($'../track'.get_point(max(Global.distance - 10, 0)) + Vector3(0, 1, 0))
		respawnTime = -1
		bounceFactor = 0
	
	#networking
	Network.data.x = position.x
	Network.data.y = position.y
	Network.data.z = position.z
	
	mesh.rotate(Vector3(0, 0, 1), -velocity.x * delta * 2)
	mesh.rotate(Vector3(1, 0, 0), velocity.z * delta * 2)
	
	Network.data.rx = mesh.rotation.x
	Network.data.ry = mesh.rotation.y
	Network.data.rz = mesh.rotation.z

func _process(_delta: float) -> void:
	var should_fix = camera.global_position.distance_to($core/Label3D.global_position) > 1.0
	if $core/Label3D.fixed_size != should_fix:
		$core/Label3D.fixed_size = should_fix

func _input(event):
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		if event is InputEventMouseMotion:
			pass
			#i don't think we need this for now
			#rotate(Vector3(0, 1, 0), -event.relative.x / mouseSens)

func _launch(vel):
	velocity += Vector3(vel[0], vel[1], vel[2])

func _spawn(index):
	position = Vector3(index * 0.25, 0, 0)
	velocity = Vector3()
	reset_physics_interpolation()
	respawnTime = -1
	
	camera.followPos = camera.offset + position
	camera.followQuat = Quaternion()
	
	#camera.position = camera.offset + position
	#camera.look_at(position + Vector3(0, 0.2, 0))
	#camera.followPos = camera.offset + position
	#camera.followQuat = camera.quaternion

func _upgrades():
	upgradesGot.speedUp = Network.activeModifiers.speed
	upgradesGot.rhinoMode = Network.activeModifiers.dash
	upgradesGot.grab = Network.activeModifiers.grab
