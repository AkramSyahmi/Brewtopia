extends SceneTree
## Visual check: drives the shift scene through each step and saves screenshots.
## Run (needs a window, not --headless):
##   Godot_console.exe --path . --script res://tests/capture_views.gd -- <out_dir>

var shift: Node


func _initialize() -> void:
	shift = load("res://scenes/cafe/cafe_shift.tscn").instantiate()
	root.add_child(shift)
	run.call_deferred()


func shot(out_dir: String, name: String) -> void:
	await create_timer(1.0).timeout
	root.get_texture().get_image().save_png(out_dir.path_join(name + ".png"))


func run() -> void:
	var out: String = OS.get_cmdline_user_args()[0]
	await shot(out, "1_counter")
	shift.dose_g = 12.0
	shift.show_step(shift.Step.DOSE)
	shift.dispensing = true
	await shot(out, "2_dose")
	shift.dispensing = false
	shift.show_step(shift.Step.GRIND)
	await shot(out, "3_grind")
	shift.show_step(shift.Step.EXTRACT)
	await create_timer(1.0).timeout
	shift.toggle_shot()
	await shot(out, "4_extract")
	shift.stop_extraction()
	await shot(out, "5_result")
	quit()
