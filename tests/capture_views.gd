extends SceneTree
## Visual check: drives the counter, a Gula Melaka Latte through the bar (espresso, milk,
## toppings), the result, the shop and the recipe book, saving a screenshot of each.
## Run (needs a window, not --headless):
##   Godot_console.exe --path . --script res://tests/capture_views.gd -- <out_dir>

var shift: Node
var out := ""


func _initialize() -> void:
	SaveGame.path = "user://test_save.json"  # never touch the player's real save
	SaveGame.reset()
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
	await shot("3_makcik", 4.5)  # after the walk up from the line
	shift.show_step(shift.Step.BAR)
	var st: EspressoStation = shift.station
	var pf: EspressoStation.Portafilter = st.pfs[0]
	pf.dose_g = 18.0
	pf.grind = 5
	pf.state = EspressoStation.PfState.TAMPED
	st.place_pf(pf, "group0")
	var cup := st.new_cup("cup", st.tray_centre(0))
	st.put_cup(cup, "tray0")
	var iced := st.new_cup("iced", st.tray_centre(1))  # second group: an iced shot at the same time
	st.add_ice(iced)
	st.put_cup(iced, "tray1")
	var pf2: EspressoStation.Portafilter = st.pfs[1]
	pf2.dose_g = 18.0
	pf2.state = EspressoStation.PfState.TAMPED
	st.toggle_brew(0)
	st.toggle_brew(1)
	await shot("4_brewing", 2.0)
	while cup.yield_g < 36.0:
		await create_timer(0.05).timeout
	st.toggle_brew(0)
	st.toggle_brew(1)
	st.set_milk(EspressoStation.MilkState.COLD)
	st.pitcher.position = st.STEAM_ZONE.get_center() - st.pitcher.texture.get_size() / 2
	st.open_steam()
	st.milk_temp = 62.0
	st.milk_foam = 0.32
	await shot("5_steam")
	st.close_steam()
	st.pour_milk(cup)
	await shot("5b_latte_art")
	st.art_panel.finish(0.95)
	st.set_milk(EspressoStation.MilkState.COLD)
	st.pour_milk(iced)  # cold milk over ice
	await shot("6_latte")
	st.remove_cup(iced)
	st.go_page(1)
	await create_timer(0.6).timeout
	st.add_syrup("gula_melaka")
	st.add_syrup("gula_melaka")
	st.add_topping("cinnamon")
	await shot("7_toppings")
	st.drop_cup(cup, st.SERVE2_RECT.get_center() + Vector2(st.PAGE_W, 0))
	await shot("8_result")
	shift.shop.open(shift.save)
	await shot("9_shop")
	shift.shop.show_tab("Decor")
	await shot("9b_decor")
	shift.shop.hide()
	shift.book.show()
	await shot("10_book")
	quit()
