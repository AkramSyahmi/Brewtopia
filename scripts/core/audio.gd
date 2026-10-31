extends Node
## Autoload "Audio": plays the game's sounds (res://assets/audio/*.wav, from
## tools/gen_audio.gd) and the background music (res://assets/audio/bgm/*.mp3) through
## two buses under Master, Music and SFX, so each is controlled on its own. Settings
## (music volume and mute, sound on/off) are saved in user://settings.json.
##   Audio.play("bell")         one-shot sound effect
##   Audio.loop("grind", true)  start/stop a looping effect (grind, pour, steam)
##   Audio.music("cafe")        background track by name ("" stops); fades between tracks
## Every Button in the game clicks automatically.

const SOUND := "res://assets/audio/%s.wav"
const TRACKS := {  # looping background music
	"cafe": "res://assets/audio/bgm/Steam_Over_Ceramic.mp3",  # instrumental: café and stations
	"title": "res://assets/audio/bgm/Sunshine_on_the_Saucer.mp3",
}
const FADE_S := 0.6
const SETTINGS := "user://settings.json"
const VOICES := 8  # one-shots that can overlap

var players: Array[AudioStreamPlayer] = []
var loops := {}  # name -> AudioStreamPlayer
var music_player: AudioStreamPlayer
var track := ""  # the music track playing ("" = none)
var music_fade: Tween
var cache := {}
var music_on := true  # false = the Music bus is muted (the volume is kept)
var music_volume := 0.7  # 0..1, the Music bus at linear_to_db(music_volume)
var sfx_on := true


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for bus in ["Music", "SFX"]:
		if AudioServer.get_bus_index(bus) == -1:
			AudioServer.add_bus()
			var i := AudioServer.bus_count - 1
			AudioServer.set_bus_name(i, bus)
			AudioServer.set_bus_send(i, "Master")
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


## Plays a looping track from TRACKS ("" = silence). The same track keeps playing (no
## restart when the scene changes); another one fades out, then the new one fades in.
func music(track_name: String) -> void:
	if track_name == track and (music_player.playing or track_name == ""):
		return
	track = track_name
	if music_fade:
		music_fade.kill()
	music_fade = create_tween()
	if music_player.playing:
		music_fade.tween_property(music_player, "volume_db", -40.0, FADE_S)
	music_fade.tween_callback(func():
		music_player.stop()
		if track_name == "":
			return
		var s: AudioStreamMP3 = load(TRACKS[track_name])
		s.loop = true  # MP3 imports don't loop by default
		music_player.stream = s
		music_player.volume_db = -40.0
		music_player.play())
	if track_name != "":
		music_fade.tween_property(music_player, "volume_db", 0.0, FADE_S)


## Mute the Music bus without touching the volume, so unmuting restores the slider level.
func set_music_on(on: bool) -> void:
	music_on = on
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Music"), not on)
	save_settings()


## Music bus volume from a 0..1 slider, through linear_to_db so it sounds even.
func set_music_volume(v: float, save := true) -> void:
	music_volume = clampf(v, 0.0, 1.0)
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Music"), linear_to_db(music_volume))
	if save:
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
			music_volume = clampf(float(d.get("music_volume", music_volume)), 0.0, 1.0)
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Music"), not music_on)
	AudioServer.set_bus_mute(AudioServer.get_bus_index("SFX"), not sfx_on)
	set_music_volume(music_volume, false)


func save_settings() -> void:
	var f := FileAccess.open(SETTINGS, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({"music": music_on, "sfx": sfx_on, "music_volume": music_volume}))
