extends SceneTree
## Visual check: drives the counter, a Gula Melaka Latte through the bar (espresso, milk,
## toppings), the result, the shop and the recipe book, saving a screenshot of each.
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
	await shot("1_counter", 2.5)
	shift.bar.show_order(shift.recipe)
	shift.advance()
	await shot("2_choices")
	shift.start_order(3)
	await shot("3_makcik", 2.5)
	shift.show_step(shift.Step.BAR)
	var st: EspressoStation = shift.station
	st.dose_g = 18.0
	st.shot_grind = 5
	st.tamped = true
	st.place_pf("group")
	st.new_cup("cup", st.TRAY_CENTRE)
	st.cup.position = st.TRAY_CENTRE - st.cup.texture.get_size() / 2
	st.cup_spot = "tray"
	st.toggle_brew()
	await shot("4_brewing", 2.0)
	while st.cup_yield < 36.0:
		await create_timer(0.05).timeout
	st.toggle_brew()
	st.pitcher_milk = true
	st.pitcher.position = st.STEAM_ZONE.get_center() - st.pitcher.texture.get_size() / 2
	st.open_steam()
	st.milk_temp = 62.0
	await shot("5_steam")
	st.close_steam()
	st.pour_milk()
	await shot("6_latte")
	st.go_page(1)
	await create_timer(0.6).timeout
	st.add_syrup("gula_melaka")
	st.add_syrup("gula_melaka")
	st.add_topping("cinnamon")
	await shot("7_toppings")
	st.drop_cup(st.SERVE2_RECT.get_center() + Vector2(st.PAGE_W, 0))
	await shot("8_result")
	shift.shop.open(shift.save)
	await shot("9_shop")
	shift.shop.hide()
	shift.book.show()
	await shot("10_book")
	quit()
