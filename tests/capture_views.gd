extends SceneTree
## Visual check: drives one order through the bar and saves screenshots.
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
	var bar: BarStation = shift.bar
	await shot("2_bar_start")
	bar.place_pf("fork")
	bar.grinding = true
	await shot("3_grinding", 1.5)
	bar.grinding = false
	bar.place_pf("mat")
	bar.drop_tamper(bar.pf.position + bar.PF_BASKET)
	await create_timer(0.6).timeout
	bar.place_pf("group")
	bar.cup = bar.new_cup()
	bar.drop_cup(bar.CUP_TRAY + Vector2(16, 11))
	bar.toggle_brew()
	await shot("4_brewing", 2.0)
	bar.toggle_brew()
	bar.drop_cup(bar.CUP_PASS + Vector2(16, 11))
	await shot("5_result")
	quit()
