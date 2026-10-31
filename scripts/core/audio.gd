extends Node
## Autoload "Audio": plays the game's sounds (res://assets/audio/*.wav, from
## tools/gen_audio.gd) through two buses, Music and SFX, so each can be switched
## off on its own (title screen toggles; saved in user://settings.json).
##   Audio.play("bell")         one-shot sound effect
##   Audio.loop("grind", true)  start/stop a looping effect (grind, pour, steam)
##   Audio.music(true)          background music
## Every Button in the game clicks automatically.

const SOUND := "res://assets/audio/%s.wav"
const SETTINGS := "user://settings.json"
const VOICES := 8  # one-shots that can overlap

var players: Array[AudioStreamPlayer] = []
var loops := {}  # name -> AudioStreamPlayer
var music_player: AudioStreamPlayer
var cache := {}
var music_on := true
var sfx_on := true


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for bus in ["Music", "SFX"]:
		if AudioServer.get_bus_index(bus) == -1:
			AudioServer.add_bus()
			var i := AudioServer.bus_count - 1
			AudioServer.set_bus_name(i, bus)
			AudioServer.set_bus_send(i, "Master")
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Music"), -8.0)
	for i in VOICES:
		players.append(player("SFX"))
	music_player = player("Music")
	load_settings()
	get_tree().node_added.connect(func(n: Node):
		if n is BaseButton:
			(n as BaseButton).pressed.connect(play.bind("click")))


func player(bus: String) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.bus = bus
	add_child(p)
	return p


func stream(sound_name: String) -> AudioStream:
	if not cache.has(sound_name):
		cache[sound_name] = load(SOUND % sound_name) if ResourceLoader.exists(SOUND % sound_name) else null
	return cache[sound_name]


## One-shot effect with a little random pitch so repeats don't sound robotic.
func play(sound_name: String, pitch_jitter := 0.05, volume_db := 0.0) -> void:
	var s := stream(sound_name)
	if s == null:
		return
	var p := players[0]
	for candidate in players:  # a free voice, else the first one gets cut
		if not candidate.playing:
			p = candidate
			break
	p.stream = s
	p.pitch_scale = 1.0 + randf_range(-pitch_jitter, pitch_jitter)
	p.volume_db = volume_db
	p.play()


## Starts or stops a looping effect (the WAV has loop points).
func loop(sound_name: String, on: bool, volume_db := -4.0) -> void:
	if on:
		if loops.has(sound_name):
			return
		var s := stream(sound_name)
		if s == null:
			return
		var p := player("SFX")
		p.stream = s
		p.volume_db = volume_db
		p.play()
		loops[sound_name] = p
	elif loops.has(sound_name):
		loops[sound_name].queue_free()
		loops.erase(sound_name)


func music(on: bool) -> void:
	if on and not music_player.playing:
		music_player.stream = stream("music")
		music_player.play()
	elif not on:
		music_player.stop()


func set_music_on(on: bool) -> void:
	music_on = on
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Music"), not on)
	save_settings()


func set_sfx_on(on: bool) -> void:
	sfx_on = on
	AudioServer.set_bus_mute(AudioServer.get_bus_index("SFX"), not on)
	save_settings()


func load_settings() -> void:
	if FileAccess.file_exists(SETTINGS):
		var d = JSON.parse_string(FileAccess.get_file_as_string(SETTINGS))
		if d is Dictionary:
			music_on = bool(d.get("music", true))
			sfx_on = bool(d.get("sfx", true))
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Music"), not music_on)
	AudioServer.set_bus_mute(AudioServer.get_bus_index("SFX"), not sfx_on)


func save_settings() -> void:
	var f := FileAccess.open(SETTINGS, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({"music": music_on, "sfx": sfx_on}))
