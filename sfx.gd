extends Node

var lastSfxVol = -1.0

func _ready() -> void:
	update_sfx_volume()

func update_sfx_volume() -> void:
	var sfxBus = AudioServer.get_bus_index("clicks")
	if sfxBus >= 0 and sfxBus < AudioServer.bus_count:
		var vol = float(Global.userSettings.sfxVol)
		if vol <= 0.0:
			AudioServer.set_bus_mute(sfxBus, true)
		else:
			AudioServer.set_bus_mute(sfxBus, false)
			AudioServer.set_bus_volume_db(sfxBus, linear_to_db(vol / 100.0))
	lastSfxVol = float(Global.userSettings.sfxVol)

func _process(_delta: float) -> void:
	if float(Global.userSettings.sfxVol) != lastSfxVol:
		update_sfx_volume()
