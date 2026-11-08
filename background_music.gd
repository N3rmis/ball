extends AudioStreamPlayer

var lastVol = -1.0
var lastMusicVol = -1.0

func _ready() -> void:
	update_volume()

func update_volume() -> void:
	var master_vol = float(Global.userSettings.volume) / 100.0
	var music_vol = float(Global.userSettings.musicVol) / 100.0
	if master_vol <= 0.0 or music_vol <= 0.0:
		volume_db = -80.0
	else:
		volume_db = -5.0 + linear_to_db(master_vol) + linear_to_db(music_vol)
	lastVol = float(Global.userSettings.volume)
	lastMusicVol = float(Global.userSettings.musicVol)

func _process(_delta: float) -> void:
	if float(Global.userSettings.volume) != lastVol or float(Global.userSettings.musicVol) != lastMusicVol:
		update_volume()
