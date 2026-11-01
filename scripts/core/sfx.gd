class_name Sfx
extends RefCounted
## Static shortcuts to the "Audio" autoload (scripts/core/audio.gd). Game classes call
## these instead of the autoload's global name, so they still compile and run silently
## where autoloads don't exist (tool and test scripts run with --script).


static func audio() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	return tree.root.get_node_or_null("Audio") if tree else null


static func play(sound_name: String, pitch_jitter := 0.05, volume_db := 0.0) -> void:
	var a := audio()
	if a:
		a.play(sound_name, pitch_jitter, volume_db)


static func loop(sound_name: String, on: bool, volume_db := -4.0) -> void:
	var a := audio()
	if a:
		a.loop(sound_name, on, volume_db)


static func music(track_name: String) -> void:
	var a := audio()
	if a:
		a.music(track_name)


## A short phone vibration (haptic tick) for touch feedback: phones only (`mobile` feature), so
## desktop, tools and tests never call it. Needs the Android export's VIBRATE permission
## (export_presets.cfg: permissions/vibrate=true). `ms`: ~20 a tap, ~40 a success, ~90 a big moment.
static func buzz(ms: int) -> void:
	if OS.has_feature("mobile"):
		Input.vibrate_handheld(ms)
