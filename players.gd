class_name Players
extends Node3D

@export var playerInstance: PackedScene
@export var playersList: VBoxContainer

@export var playerElement: PackedScene

@export var player: Player

var players: Dictionary[String, NetworkPlayer] = {}
var playerElements: Dictionary[String, PlayerElement] = {}
var inRace = false

var center = Vector3()
var minp = Vector3()
var maxp = Vector3()
var length = 0
var sortTimer = 0.0

func _ready() -> void:
	#if connected already, request all the player data
	Network.on_dm.connect(_on_dm)
	Network.on_player_joined.connect(_on_player_joined)
	Network.on_player_left.connect(_on_player_left)
	Network.on_disconnected.connect(_on_disconnected)
	Network.on_names.connect(_on_names)
	if Network.connected:
		Network.client.emit('getData')
	load_names(Network.names)
	
func _on_names(names):
	load_names(names)

func load_names(names):
	for id in Network.names:
		players[id] = playerInstance.instantiate()
		players[id].id = id
		if id != Network.id:
			add_child(players[id])
		playerElements[id] = playerElement.instantiate()
		playerElements[id].username = Network.names[id]
		players[id].element = playerElements[id]
		if Network.id == id:
			playerElements[id].connecting = false
		playersList.add_child(playerElements[id])

func _process(delta: float) -> void:
	var currentCenter = Vector3()
	var racingPlayers = 0
	minp = Vector3(INF, INF, INF)
	maxp = Vector3(-INF, -INF, -INF)
	if Network.id in playerElements:
		players[Network.id].itime = Global.time
		playerElements[Network.id].place = Global.place
		playerElements[Network.id].time = str(round(Global.time * 100) / 100)
		playerElements[Network.id].username = Global.username
		playerElements[Network.id].isReady = 0
		var distance = -1
		if Global.running:
			distance = Global.distance
		if distance != -1:
			playerElements[Network.id].distance = str(int(distance)) + 'm'
		else:
			playerElements[Network.id].distance = ''
		if $'../track'.progress != -1:
			playerElements[Network.id].progress = str(round($'../track'.progress * 100)) + '%'
		else:
			playerElements[Network.id].progress = ''
		if not Global.running:
			if Global.isReady:
				playerElements[Network.id].isReady = 1
			else:
				playerElements[Network.id].isReady = 2
	
	for player2 in players:
		if playerElements[player2].isReady == 0:
			racingPlayers += 1
			currentCenter += players[player2].position
			minp = Vector3(
				min(minp.x, players[player2].position.x),
				min(minp.y, players[player2].position.y),
				min(minp.z, players[player2].position.z)
			)
			maxp = Vector3(
				max(maxp.x, players[player2].position.x),
				max(maxp.y, players[player2].position.y),
				max(maxp.z, players[player2].position.z)
			)
	
	if racingPlayers > 0:
		currentCenter /= racingPlayers
	if Global.running or not Global.race:
		currentCenter = player.position
	center = center.lerp(currentCenter, clamp(delta * 10, 0, 1))
	length = (maxp - minp).length()
	
	sortTimer += delta
	if sortTimer >= 0.1:
		sortTimer = 0.0
		var children = playersList.get_children()
		children.sort_custom(func(a, b):
			var aplace = a.place != ''
			var bplace = b.place != ''
			
			if aplace != bplace:
				return aplace
			
			if aplace and bplace:
				return float(a.time) < float(b.time)
			else:
				var adist = float(a.distance.left(a.distance.length() - 1)) if a.distance.length() > 1 else 0.0
				var bdist = float(b.distance.left(b.distance.length() - 1)) if b.distance.length() > 1 else 0.0
				return adist > bdist
		)
		
		for i in range(children.size()):
			if children[i].get_index() != i:
				playersList.move_child(children[i], i)

func _on_dm(from, data):
	if from in players:
		players[from].on_data(data)

func _on_player_joined(id, username):
	players[id] = playerInstance.instantiate()
	players[id].id = id
	if Network.id != id:
		add_child(players[id])
	playerElements[id] = playerElement.instantiate()
	playerElements[id].username = username
	players[id].element = playerElements[id]
	if Network.id == id:
		playerElements[id].connecting = false
	playersList.add_child(playerElements[id])

func _on_player_left(id):
	if id != Network.id:
		players[id].queue_free()
	players.erase(id)
	
	playerElements[id].queue_free()
	playerElements.erase(id)

func _on_disconnected():
	for id in players:
		players.erase(id)
	for id in playerElements:
		playerElements.erase(id)
	
	players = {}
	playerElements = {}
	
	for child in get_children():
		child.queue_free()
	for child in playersList.get_children():
		child.queue_free()
