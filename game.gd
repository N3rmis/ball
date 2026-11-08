extends Node3D

@export var player: Player
@export var camera: Camera
@export var start: Label

var from = 'menu'

func _ready() -> void:
	#print_debug(Network.upgrades)
	Network.upgradeTime.connect(_upgrades)
	#Network.newRace.connect(_global_modifier)
	Network.spawn.connect(_on_spawn)
	BackgroundMusic.bus = "inGame"
	if not $CanvasLayer/Control/optionsMenu.settingsClosed.is_connected(_settingsClosed):
		$CanvasLayer/Control/optionsMenu.settingsClosed.connect(_settingsClosed)
	Global.running = not Global.race
	#Global.isReady = true
	if Global.running == true:
		Global.isReady = false
		#$CanvasLayer/Control/AnimationPlayer.play("transOut")
	#elif Global.running == false:
		#$CanvasLayer/Control/AnimationPlayer.play("transOut")
	#elif Global.upgrading == true:
		#Global.isReady = true
		#BackgroundMusic.bus = "pause"
		#Global.isReady = false
		#$CanvasLayer/Control/AnimationPlayer.play("transOut")
		#await get_tree().create_timer(0.2).timeout
		#$CanvasLayer/Control/upgradeSelect/AnimationPlayer.play("upgradesShow")
	else:
		#pass
		#$CanvasLayer/Control/AnimationPlayer.play("transOut")
		Global.isReady = true

func _on_spawn(_index):
	print_debug("spawn")
	if Global.leavingScene != "upgrade" and from == 'menu':
		from = 'game'
		$CanvasLayer/Control/AnimationPlayer.play("transOut")
		#$CanvasLayer/Control/upgradeSelect/AnimationPlayer.play("exit2")
		await get_tree().create_timer(0.8).timeout
	else:
		#$CanvasLayer/Control/upgradeSelect/AnimationPlayer.play("exit2")
		Global.isReady = true
		Global.time = 0
		player.reset()
		#if $CanvasLayer/Control/AnimationPlayer.current_animation == "globalModDetected":
			#$CanvasLayer/Control/AnimationPlayer.seek(0, true)
		if Global.running == false or Global.upgrading == true:
			pass
			#Global.isReady = false
			#Global.upgrading = true
			#await get_tree().create_timer(0.2).timeout
			#$CanvasLayer/Control/upgradeSelect/AnimationPlayer.play("upgradesShow")
		#else:
	if Network.globalMod != null:
		$CanvasLayer/Control/AnimationPlayer.play("globalModDetected")
		await get_tree().create_timer(3).timeout
	$CanvasLayer/Control/start.text = "3"
	$CanvasLayer/Control/AnimationPlayer.play("startTimer")
	#await get_tree().create_timer(2).timeout
	

func _physics_process(_delta: float) -> void:
	if Input.is_action_just_pressed('ready'):
		$CanvasLayer/Control/optionsMenu.visible = false
		if Global.race:
			if not Global.running:
				Global.isReady = not Global.isReady
		elif not Global.running:
			Global.running = true
			Global.time = 0
			player.reset()
	
	var unix_timestamp_ms = Network.get_time()
	if unix_timestamp_ms < Global.startTime:
		start.text = str(int(min(3, ceil((Global.startTime - unix_timestamp_ms) / 1000))))
	#else:
		#start.text = ''
	
	if Global.startTime != -1 and unix_timestamp_ms >= Global.startTime:
		if Network.globalMod != null:
			pass
			await get_tree().create_timer(4).timeout
		if from == "menu":
			await get_tree().create_timer(1).timeout
		Global.startTime = -1
		Global.time = 0
		Global.running = true
		Global.toast = true
		Global.isReady = false
	
	if Input.is_action_just_pressed("esc"):
		var wind = Sfx.get_child(2)
		if BackgroundMusic.bus == "inGame":
			BackgroundMusic.bus = "pause"
			#wind.bus = "pause"
		elif BackgroundMusic.bus == "pause":
			BackgroundMusic.bus = "inGame"
			#wind.bus = "inGame"
		$CanvasLayer/Control/pauseMenu.visible = !$CanvasLayer/Control/pauseMenu.visible
	
	$CanvasLayer/Control/loading/name.text = Global.progressName
	Global.progress = $track.progress
	if $track.progress != -1:
		$CanvasLayer/Control/loading.visible = true
		$CanvasLayer/Control/loading/progress.value = $track.progress * 100
	else:
		$CanvasLayer/Control/loading.visible = false

#func _global_modifier():
	#$CanvasLayer/Control/AnimationPlayer.play("globalModDetected")
	


func _on_settings_button_pressed() -> void:
	Sfx.get_node("clickSFX").play()
	$CanvasLayer/Control/pauseMenu.visible = !$CanvasLayer/Control/pauseMenu.visible
	$CanvasLayer/Control/optionsMenu.visible = true
	$CanvasLayer/Control/optionsMenu/AnimationPlayer.play("optionsPressed")

func _on_lobby_button_pressed() -> void:
	Global.leavingScene = 'game'
	BackgroundMusic.bus = "menu"
	Sfx.get_node("clickSFX").play()
	Global.scene = 'lobby'
	$CanvasLayer/Control/AnimationPlayer.play("leave game")
	await get_tree().create_timer(0.5).timeout
	get_tree().change_scene_to_file("res://lobby_menu.tscn")

func _on_close_button_pressed() -> void:
	BackgroundMusic.bus = "inGame"
	$CanvasLayer/Control/pauseMenu.visible = false
	Sfx.get_node("clickSFX").play()

func _settingsClosed():
	$CanvasLayer/Control/pauseMenu.visible = true

func _upgrades():
	#pass
	$CanvasLayer/Control/upgradeSelect/AnimationPlayer.play("upgradesShow")

func _on_mouse_hover() -> void:
	Sfx.get_node("browseSFX").play()
func _clicksound():
	Sfx.get_node("clickSFX").play()

func _on_upgrade_select_lock_in() -> void:
	print("ads")
	#$CanvasLayer/Control/upgradeSelect/AnimationPlayer.play("exit2")
	Global.leavingScene = "upgrade"
	Global.isReady = true
	#Global.running = true
	Global.time = 0
	player.reset()
	
