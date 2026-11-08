extends Control

@export var lobby: LineEdit
@export var username: LineEdit
@export var race: CheckBox

func _ready() -> void:
	#print_debug(Network.activeModifiers.keys().pick_random())
	if Global.leavingScene == 'lobby':
		$AnimationPlayer.play("resetFromLobby")
		await $AnimationPlayer.animation_finished
		$AnimationPlayer.play_backwards("sceneTransition")
		#print_debug("wat")
		#await get_tree().create_timer(0.5).timeout
		#$AnimationPlayer.play_backwards("settingsPressed")
	elif Global.leavingScene == 'menu':
		BackgroundMusic.bus = "menu"
		lobby.text = str(Global.seed)
		username.text = Global.username
		$AnimationPlayer.play_backwards("opening")
	else:
		connect("settingsClosed", _settingsClosed)
		BackgroundMusic.bus = "menu"
		lobby.text = str(Global.seed)
		username.text = Global.username
		$AnimationPlayer.play_backwards("settingsPressed")
		await get_tree().create_timer(0.15).timeout
		$BALL.playing = true
	

func _on_play_button_down() -> void:
	Global.leavingScene = 'menu'
	$AnimationPlayer.play("sceneTransition")
	await get_tree().create_timer(0.5).timeout
	
	# If network is still handshaking with the server, wait up to 3.5s for it to finish
	if not Network.connected:
		var wait_count = 0
		while not Network.connected and wait_count < 35:
			await get_tree().create_timer(0.1).timeout
			wait_count += 1
	
	if Network.connected:
		Network.client.emit('join', [str(Global.seed), race.button_pressed, Global.username])
		# Wait for server to confirm with 'joined' event
		var wait_joined = 0
		while Global.scene == 'menu' and wait_joined < 40:
			await get_tree().create_timer(0.1).timeout
			wait_joined += 1
		# If server did not respond in 4s, proceed into game directly
		if Global.scene == 'menu':
			Global.scene = 'game'
			Global.race = false
			Global.running = true
			get_tree().change_scene_to_file("res://game.tscn")
	else:
		# Offline / server unreachable: launch game directly
		Global.scene = 'game'
		Global.race = false
		Global.running = true
		get_tree().change_scene_to_file("res://game.tscn")

func _on_lobby_text_changed(new_text: String) -> void:
	if int(new_text):
		Global.seed = int(new_text)

func _on_username_text_changed(new_text: String) -> void:
	Global.username = new_text
	Global.saveData()

func _on_race_toggled(toggled_on: bool) -> void:
	Global.race = toggled_on

#user settings tab
func _on_settings_pressed() -> void:
	$AnimationPlayer.play("settingsPressed")
	await get_tree().create_timer(0.6).timeout
	$optionsMenu/AnimationPlayer.play("optionsPressed")

func _settingsClosed() -> void:
	$AnimationPlayer.play_backwards("settingsPressed")

func _on_mouse_hover() -> void:
	Sfx.get_node("browseSFX").play()
func _clicksound():
	Sfx.get_node("clickSFX").play()

func _on_button_pressed() -> void:
	get_tree().change_scene_to_file("res://upgrade_select.tscn")
