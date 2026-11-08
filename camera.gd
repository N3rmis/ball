class_name Camera
extends Camera3D

@export var player: Player
@export var players: Players

var originalOffset = Vector3()
var followPos = Vector3()
var followQuat = Quaternion()
var offset = Vector3()

var currentOff = Vector2()

var turn = 0.0
var updown = 0.0

var distance = 1.0

func exp_decay_f(current: float, target: float, decay: float, delta: float) -> float:
	return target + (current - target) * exp(-decay * delta)

func exp_decay_v3(current: Vector3, target: Vector3, decay: float, delta: float) -> Vector3:
	return target + (current - target) * exp(-decay * delta)

func _ready() -> void:
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	originalOffset = position
	followPos = position
	offset = position
	currentOff = Vector2(0, position.z)

func getTargetPos() -> Vector3:
	if not Global.running and Global.race and Global.startTime == -1 and players:
		return players.center
	if is_instance_valid(player):
		return player.get_global_transform_interpolated().origin
	return Vector3.ZERO

func _physics_process(_delta: float) -> void:
	fov = Global.userSettings.fov
	var cam_angle = atan2(currentOff.x, currentOff.y)
	followQuat = Quaternion(Vector3.UP, cam_angle)

func _process(delta: float) -> void:
	var move = Vector2(Input.get_axis('camera_left', 'camera_right'), Input.get_axis('camera_down', 'camera_up')).normalized()
	turn += move.x * delta * 2.5
	updown += move.y * delta * 2.0
	updown = clamp(updown, -PI/2, PI/2)
	
	if abs(turn) > 0.0001:
		currentOff = currentOff.rotated(turn)
		turn = exp_decay_f(turn, 0.0, 15.0, delta)

	var spectating = not Global.running and Global.race and Global.startTime == -1 and players and players.length != INF
	offset = originalOffset.rotated(Vector3(1, 0, 0), updown)
	
	if spectating:
		distance = exp_decay_f(distance, players.length / offset.length() + 1.0, 10.0, delta)
	else:
		distance = exp_decay_f(distance, 1.0, 10.0, delta)
	
	var targetPos = getTargetPos()
	
	var desiredPos = Vector3(
		targetPos.x + currentOff.x * distance,
		targetPos.y + offset.y * distance,
		targetPos.z + currentOff.y * distance
	)
	
	followPos = desiredPos
	position = exp_decay_v3(position, desiredPos, 20.0, delta)
	
	var look_target = targetPos + Vector3(0, 0.2, 0)
	if position.distance_squared_to(look_target) > 0.001:
		var target_basis = Transform3D().looking_at(look_target - position, Vector3.UP).basis
		var rot_factor = 1.0 - exp(-15.0 * delta)
		quaternion = quaternion.slerp(target_basis.get_rotation_quaternion(), rot_factor)
