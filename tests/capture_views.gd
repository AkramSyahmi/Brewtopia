extends SceneTree
## Visual check: drives one order through the 2D espresso station and saves screenshots.
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
	await shot("1_counter", 3.0)
	shift.show_step(shift.Step.BAR)
	var st: EspressoStation = shift.station
	await shot("2_bar_start")
	st.place_pf("fork")
	st.grinding = true
	await shot("3_grinding", 2.4)
	st.grinding = false
	st.place_pf("mat")
	await create_timer(0.3).timeout
	st.tamp()
	await create_timer(0.6).timeout
	st.place_pf("group")
	st.press(st.RACK_AT + Vector2(150, 30))
	st.dragging.position = st.TRAY_SPOT
	st.release()
	st.toggle_brew()
	await shot("4_brewing", 3.0)
	st.toggle_brew()
	st.drop_cup(st.SERVE_RECT.get_center())
	await shot("5_result", 1.0)
	quit()
