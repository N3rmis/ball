class_name Camera
extends Camera3D

@export var player: Player
@export var players: Players

var originalOffset = Vector3()
var followPos = Vector3()
var followQuat = Quaternion()
var offset = Vector3()

var currentOff = Vector2()

var turn = 0
var updown = 0

var distance = 1

#my essential interpolation functions
func lerpn(start, end, multiply, step):
	multiply = 1 - (1 - multiply) ** step
	if multiply > 1:
		multiply = 1
	if multiply < 0:
		multiply = 0
	return start + (end - start) * multiply

func lerp5(start, end, step):
	return lerpn(start, end, 0.5, step)

func _ready() -> void:
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	originalOffset = position
	followPos = position
	offset = position
	currentOff = Vector2(0, position.z)
	
func getTargetPos():
	var pos = player.position
	if not Global.running and Global.race and Global.startTime == -1:
		pos = players.center
	return pos
	
func _physics_process(delta: float) -> void:
	fov = Global.userSettings.fov
	var move = Vector2(Input.get_axis('camera_left', 'camera_right'), Input.get_axis('camera_down', 'camera_up')).normalized()
	
	turn += move.x * delta
	updown += move.y * delta * 2
	updown = clamp(updown, -PI/2, PI/2)
	
	offset = originalOffset.rotated(Vector3(1, 0, 0), updown)
	
	turn *= 0.85
	
	var targetPos = getTargetPos()
	
	#var offset2 = offset * distance

	#var hoverxz = offset2.z
	#var xzlength = sqrt(
		#(followPos.x - targetPos.x) ** 2 +
		#(followPos.z - targetPos.z) ** 2
	#)
	#var dif = Vector2(targetPos.x - followPos.x, targetPos.z - followPos.z)
	#dif = dif.rotated(turn)
	#var nearest = Vector2(
		#targetPos.x + (-dif.x / xzlength) * hoverxz,
		#targetPos.z + (-dif.y / xzlength) * hoverxz,
	#)
	currentOff = currentOff.rotated(turn)
	var currentOff2 = currentOff * distance + Vector2(targetPos.x, targetPos.z)
	followPos.x = lerp5(followPos.x, currentOff2.x, delta * 20 * 10);
	followPos.z = lerp5(followPos.z, currentOff2.y, delta * 20 * 10);
	
	#extract the rotation along the x and z axis and store it for player movement
	var targetQuaternion = Quaternion()
	var dummy = Transform3D()
	dummy.origin = followPos
	
	var targetPoint = Vector3(
		followPos.x * 2 - targetPos.x,
		followPos.y,
		followPos.z * 2 - targetPos.z
	)
	
	dummy = dummy.looking_at(targetPoint, Vector3.UP)
	targetQuaternion = dummy.basis.get_rotation_quaternion()
	
	var multiply = 1 - (1 - 0.5) ** (delta * 50 * 10)
	followQuat = followQuat.slerp(targetQuaternion, multiply)

func _process(delta: float) -> void:
	var spectating = not Global.running and Global.race and Global.startTime == -1 and players.length != INF
	
	offset = originalOffset.rotated(Vector3(1, 0, 0), 0)
	
	if spectating:
		distance = lerp5(distance, players.length / offset.length() + 1, delta * 15)
	else:
		distance = lerp5(distance, 1, delta * 15)
	
	var targetPos = getTargetPos()
	var offset2 = offset * distance
	
	#if spectating:
		#offset2.y /= 100
		
	#smoothly move the camera to the target position
	position = Vector3(
		lerp5(position.x, followPos.x, delta * 25),
		lerp5(position.y, targetPos.y + offset2.y, delta * 25),
		lerp5(position.z, followPos.z, delta * 25),
	)
	
	#smoothly rotate the camera to point at the player
	var dummy2 = Transform3D()
	dummy2.origin = position
	dummy2 = dummy2.looking_at(targetPos + Vector3(0, 0.2, 0), Vector3.UP)
	
	var multiply2 = 1 - (1 - 0.5) ** (delta * 10)
	quaternion = quaternion.slerp(dummy2.basis.get_rotation_quaternion(), multiply2)
