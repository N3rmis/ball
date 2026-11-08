class_name NetworkPlayer
extends Node3D

@export var mesh: Node3D
@export var label: Label3D

var element: PlayerElement

var isNetworkPlayer = true

var id = ''

var username = 'Unnamed'

var x = 0
var lx = 0

var y = 0
var ly = 0

var z = 0
var lz = 0

var rx = 0
var lrx = 0

var ry = 0
var lry = 0

var rz = 0
var lrz = 0

var time = 0
var ltime = 0

var itime = 0

var peer: WebRTCPeerConnection
var channel: WebRTCDataChannel
var eventChannel: WebRTCDataChannel
var myId = 0

var relay = true

var connected = false

var accumulator = 0

var start = 0

var latency = 0

var offset = Vector3()

var reconnect_cooldown = 0

func _ready() -> void:
	if Network.connected:
		_socket_ready()
	else:
		Network.on_connected.connect(_socket_ready)
	
	Network.on_create_offer.connect(_on_create_offer)
	Network.on_session.connect(_on_session_received)
	Network.on_candidate.connect(_on_candidate_received)
	Network.broadcast_data.connect(_broadcast_data)

func _socket_ready():
	connect_peer()

func connect_peer():
	reconnect_cooldown = 2
	if peer:
		peer.close()
	peer = WebRTCPeerConnection.new()
	
	var iceServers = {
		"iceServers": [
			{"urls": ["stun:stun.l.google.com:19302"]}
		]
	}
	peer.initialize(iceServers)
	
	peer.ice_candidate_created.connect(_on_ice_canditate)
	peer.session_description_created.connect(_on_session_created)
	
	channel = peer.create_data_channel('game', {'id': 1, 'negotiated': true, 'ordered': false, 'maxRetransmits': 0})
	eventChannel = peer.create_data_channel('event', {'id': 2, 'negotiated': true, 'ordered': true})
	
	Network.emit('startwebrtc', id)
	
func _on_create_offer(tid):
	if tid == id:
		peer.create_offer()

func _on_ice_canditate(mid, index, sdp):
	Network.client.emit('candidate', [id, mid, index, sdp])
	
func _on_session_created(type, sdp):
	Network.client.emit('session', [id, type, sdp])
	peer.set_local_description(type, sdp)
	
func _on_session_received(tid, type, sdp):
	if tid == id:
		peer.set_remote_description(type, sdp)

func _on_candidate_received(tid, mid, index, sdp):
	if tid == id:
		peer.add_ice_candidate(mid, index, sdp)

#my little interpolation functions
func lerp(start: float, end: float, multiply: float):
	if multiply > 1:
		multiply = 1
	if multiply < 0:
		multiply = 0
	return start + (end - start) * multiply

func interpVar(current: float, last: float, tickrate: float, accumulator: float):
	return lerp(last, current, accumulator / (1 / tickrate))

func _process(delta: float) -> void:
	accumulator += delta
	
	var peerOk = peer.get_connection_state() < 3
	var channelOk = channel.get_ready_state() < 2
	var eventChannelOk = eventChannel.get_ready_state() < 2
	
	connected = channel and peer and peer.get_connection_state() == WebRTCPeerConnection.STATE_CONNECTED and channel.get_ready_state() == WebRTCDataChannel.STATE_OPEN and eventChannel.get_ready_state() == WebRTCDataChannel.STATE_OPEN
	element.connecting = !connected
	peer.poll()
	if channel.get_ready_state() == WebRTCDataChannel.STATE_OPEN:
		while channel.get_available_packet_count() > 0:
			on_data(channel.get_packet().get_string_from_utf8())
			
	if eventChannel.get_ready_state() == WebRTCDataChannel.STATE_OPEN:
		while eventChannel.get_available_packet_count() > 0:
			on_data(eventChannel.get_packet().get_string_from_utf8())
	
	if (not peerOk) or (not channelOk) or (not eventChannelOk):
		relay = true
		reconnect_cooldown -= delta
		if reconnect_cooldown <= 0:
			connect_peer()
	
	if connected:
		relay = false
	
	label.text = username
	
	if time < ltime:
		ltime = time
	itime = interpVar(time, ltime, Network.updateRate, accumulator)
	
	var offsetTarget = Vector3(x - lx, y - ly, z - lz) * (1 + latency / (1000.0 / Network.updateRate))
	if offsetTarget.length() > 10:
		offsetTarget = Vector3()
	offset = offset.lerp(offsetTarget, clamp(delta * 5, 0, 1))
	
	var target = Vector3(
		interpVar(x, lx, Network.updateRate, accumulator),
		interpVar(y, ly, Network.updateRate, accumulator),
		interpVar(z, lz, Network.updateRate, accumulator)
	) + offset
	
	#do some weird interpolation stuff using the accumulator from network.gd
	position = position.lerp(target, delta * 20)
	
	var lastQuat = Quaternion.from_euler(Vector3(lrx, lry, lrz))
	var quat = Quaternion.from_euler(Vector3(rx, ry, rz))
	
	var multiply = clamp(accumulator / (1.0 / Network.updateRate), 0, 1)
	
	mesh.quaternion = lastQuat.slerp(quat, multiply)
	
	element.time = str(round(itime * 100) / 100)
	if element.time == '0.0':
		element.time = '0'
		
	$CollisionShape3D.disabled = not Global.running
	
	var camera = get_viewport().get_camera_3d()
	if camera:
		var should_fix = camera.global_position.distance_to($Label3D.global_position) > 1.0
		if $Label3D.fixed_size != should_fix:
			$Label3D.fixed_size = should_fix
	
func _broadcast_data(data):
	send_msg('data', Network.data, false)

func send_msg(event, data, reliable):
	if relay and Network.connected:
		Network.client.emit('dm', [id, event + '|' + JSON.stringify(data)])
	elif connected:
		if reliable:
			channel.put_packet((event + '|' + JSON.stringify(data)).to_utf8_buffer())
		else:
			eventChannel.put_packet((event + '|' + JSON.stringify(data)).to_utf8_buffer())

func on_data(data):
	var event = ''
	while data[0] != '|':
		event += data[0]
		data = data.substr(1)
	data = data.substr(1)
	data = JSON.parse_string(data)
	on_msg(event, data)

func on_msg(event, data):
	if event == 'data':
		accumulator = 0
		
		lx = x
		ly = y
		lz = z
		lrx = rx
		lry = ry
		lrz = rz
		ltime = time
		
		x = data.x
		y = data.y
		z = data.z
		rx = data.rx
		ry = data.ry
		rz = data.rz
		time = data.time
		username = data.username
		
		element.username = data.username
		element.isReady = data.ready
		element.place = data.place
		
		if data.progress != -1:
			element.progress = str(round(data.progress * 100)) + '%'
		else:
			element.progress = ''
		
		if data.distance != -1:
			element.distance = str(int(data.distance)) + 'm'
		else:
			element.distance = ''
	elif event == 'ping':
		send_msg('ping2', {}, false)
	elif event == 'ping2':
		var unix_timestamp_ms = Time.get_unix_time_from_system() * 1000
		latency = unix_timestamp_ms - start
		element.latency = str(int(round(latency))) + 'ms'
	elif event == 'launch':
		Network.launch.emit(data)

func _on_timer_timeout() -> void:
	var unix_timestamp_ms = Time.get_unix_time_from_system() * 1000
	start = unix_timestamp_ms
	send_msg('ping', {}, false)
