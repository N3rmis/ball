extends Node

var seed = 1
var username = 'Unnamed'
var race = true
var startTime = -1

var voidLevel = 0
var time = 0
var running = false
var toast = false
var place = ''

var upgrading = false
var isReady = false
var inGame = false
var scene = 'menu'
var leavingScene = 'menu'

var lastState = -1

var userSettings = {
	'volume': 100,
	'musicVol': 100,
	'sfxVol': 100,
	'fov': 75,
	'maxFps': 60,
	'resScale': 85 if OS.has_feature("web") else 100
}

var lastVolume = -1.0

var modifierModifications = {
	'speed': 2.10,
	#'dash': false,
}

var progress = -1
var progressName = ''

var distance = 0

func _ready() -> void:
	loadData()
	applySettings()

func updateAudioVolume() -> void:
	var vol = float(userSettings.volume)
	if vol <= 0.0:
		AudioServer.set_bus_mute(0, true)
	else:
		AudioServer.set_bus_mute(0, false)
		AudioServer.set_bus_volume_db(0, -1.0 / (vol / 100.0))
	lastVolume = vol

func applySettings() -> void:
	Engine.max_fps = int(userSettings.get('maxFps', 60))
	var scale_val = float(userSettings.get('resScale', 100)) / 100.0
	get_viewport().scaling_3d_scale = clamp(scale_val, 0.5, 1.0)
	updateAudioVolume()

func _process(_delta: float) -> void:
	if float(userSettings.volume) != lastVolume:
		updateAudioVolume()
	var state = 0
	if not running:
		if isReady:
			state = 1
		else:
			state = 2
	if state != lastState and "connected" in Network and Network.connected and Network.lobby != null:
		Network.client.emit('ready', state)
		lastState = state
	
func _physics_process(delta: float) -> void:
	if running:
		time += delta

func loadData():
	var config = ConfigFile.new()
	var err = config.load('user://data.cfg')
	if err == OK:
		username = config.get_value('player', 'username', 'Unnamed')
		
		for setting in userSettings:
			userSettings[setting] = config.get_value('userSettings', setting, userSettings[setting])
		#var json = JSON.new()
		#var jsonStr = config.get_value('user', 'settings', null)
		#if jsonStr != null:
			#var error = json.parse(jsonStr)
			#if error == OK:
				#userSettings = json.data
	#var json = JSON.new()
	#var error = json.parse(config.get_value())
	#if error == OK:
		#userSettings = json.data

func saveData():
	var config = ConfigFile.new()
	config.set_value('player', 'username', username)
	for setting in userSettings:
		config.set_value('userSettings', setting, userSettings[setting])
	
	config.save('user://data.cfg')
	applySettings()
