extends SceneTree
## Visual check: drives one order through the 3D bar and saves screenshots.
## Run (needs a window, not --headless):
##   Godot_console.exe --path . --script res://tests/capture_views.gd -- <out_dir>

var shift: Node
var out := ""


func _initialize() -> void:
	shift = load("res://scenes/cafe/cafe_shift.tscn").instantiate()
	root.add_child(shift)
	run.call_deferred()


func shot(name: String, wait := 0.8) -> void:
	await create_timer(wait).timeout
	root.get_texture().get_image().save_png(out.path_join(name + ".png"))


func run() -> void:
	out = OS.get_cmdline_user_args()[0]
	await shot("1_counter")
	shift.show_step(shift.Step.BAR)
	var bar: Bar3D = shift.bar
	await shot("2_bar_start")
	bar.set_hover(bar.pf)
	bar.place_pf("fork")
	bar.grinding = true
	await shot("3_grinding", 2.2)
	bar.grinding = false
	bar.place_pf("mat")
	await create_timer(0.3).timeout
	bar.tamper.global_position = bar.pf.global_position + Vector3(0, 0.07, 0)
	bar.drop_tamper()
	await create_timer(0.6).timeout
	bar.place_pf("group")
	bar.take_cup().global_position = bar.spots.tray
	bar.drop_cup()
	bar.toggle_brew()
	await shot("4_brewing", 3.0)
	bar.toggle_brew()
	bar.cup.global_position = bar.SERVE_AT
	bar.drop_cup()
	await shot("5_result")
	quit()
