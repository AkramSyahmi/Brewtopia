extends SceneTree
## Regression: plays one whole order (the shift's Gula Melaka Latte) with real mouse
## events at screen positions, so hit areas, drags, snapping, the tutorial highlight and
## the cup/liquid visuals are all exercised: grind, tamp, lock in, cup, shot, milk, latte
## art, syrups and toppings, serve. Checks alignment at each step and prints FAIL lines;
## prints "FLOW PASS" at the end when nothing failed. Screenshots go to <out_dir>.
## Run (needs a window, not --headless), optionally at another window size:
##   Godot_console.exe --path . --script res://tests/regression_flow.gd -- <out_dir> [WxH]

var shift: Node
var st: EspressoStation
var out := ""
var fails := 0


func _initialize() -> void:
	SaveGame.path = "user://test_save.json"  # never touch the player's real save
	SaveGame.reset()
	shift = load("res://scenes/cafe/cafe_shift.tscn").instantiate()
	root.add_child(shift)
	run.call_deferred()


func check(ok: bool, what: String) -> void:
	if not ok:
		fails += 1
		print("FAIL: ", what)


func shot(name: String, wait := 0.3) -> void:
	await create_timer(wait).timeout
	root.get_texture().get_image().save_png(out.path_join(name + ".png"))


## Base (world) px -> window px, through the station's scale and the window stretch.
func screen(world_px: Vector2) -> Vector2:
	return root.get_final_transform() * (st.world.position + world_px * st.SCALE)


func button(at: Vector2, down: bool) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = down
	e.position = screen(at)
	e.global_position = e.position
	root.push_input(e)
	await process_frame


func move(at: Vector2) -> void:
	var e := InputEventMouseMotion.new()
	e.position = screen(at)
	e.global_position = e.position
	root.push_input(e)
	await process_frame


func drag(from: Vector2, to: Vector2, mid_shot := "") -> void:
	await button(from, true)
	for k in range(1, 9):
		await move(from.lerp(to, k / 8.0))
		if k == 4 and mid_shot != "":
			await shot(mid_shot, 0.05)
	await button(to, false)
	await create_timer(0.25).timeout  # snap tweens


func tap(at: Vector2) -> void:
	await button(at, true)
	await button(at, false)
	await create_timer(0.1).timeout


## The highlight is on the expected target and drawn around its rect.
func guide_on(target: String) -> void:
	await create_timer(0.1).timeout
	check(st.guide_target == target, "guide target %s, expected %s (objective: %s)" % [st.guide_target, target, st.objective().title])
	if st.guide_target == target:
		var r := st.guide_rect(target).grow(st.GUIDE_PAD)
		check(st.guide_box.visible and st.guide_box.get_rect().is_equal_approx(r), "guide box not around %s" % target)


func run() -> void:
	var args := OS.get_cmdline_user_args()
	out = args[0]
	if args.size() > 1:
		var wh := args[1].split("x")
		DisplayServer.window_set_size(Vector2i(int(wh[0]), int(wh[1])))
		await create_timer(1.5).timeout  # let the OS settle the window first
	print("window ", DisplayServer.window_get_size(), " viewport ", root.get_visible_rect().size)
	await create_timer(2.0).timeout
	shift.bar.show_order(shift.recipe)
	shift.advance()
	shift.start_order(3)
	var walk_t0 := Time.get_ticks_msec()  # wait for the customer to walk up and start ordering
	while not (shift.step == shift.Step.DIALOGUE and shift.talk_box.visible) and Time.get_ticks_msec() - walk_t0 < 15000:
		await process_frame
	await create_timer(0.3).timeout
	shift.show_step(shift.Step.BAR)
	st = shift.station
	await create_timer(0.6).timeout
	var r: Dictionary = st.recipe
	var pf: EspressoStation.Portafilter = st.pfs[0]
	var basket := func() -> Vector2: return pf.sprite.position + st.PF_BASKET

	# Grind: portafilter into the fork, hold the grinder.
	await guide_on("fork")
	await drag(basket.call(), st.snap("fork"), "01_pf_drag_to_fork")
	check(pf.spot == "fork" and pf.sprite.position.is_equal_approx(st.PF_SPOTS.fork), "portafilter not seated in the fork: %s at %s" % [pf.spot, pf.sprite.position])
	await guide_on("grinder")
	await shot("02_pf_in_fork")
	await button(st.guide_rect("grinder").get_center(), true)
	var t0 := Time.get_ticks_msec()
	while pf.dose_g < r.dose_g - 0.2 and Time.get_ticks_msec() - t0 < 20000:
		await process_frame
	await button(st.guide_rect("grinder").get_center(), false)
	check(not st.grinding and pf.state == EspressoStation.PfState.DOSED, "grinder still running or not dosed")

	# Tamp.
	await guide_on("mat")
	await drag(basket.call(), st.snap("mat"))
	await guide_on("tamper")
	await tap(st.guide_rect("tamper").get_center())
	await create_timer(0.6).timeout  # the tamp animation sets TAMPED at its end
	check(pf.state == EspressoStation.PfState.TAMPED, "not tamped")

	# Lock in.
	await guide_on("group0")
	await drag(basket.call(), st.snap("group0"), "03_pf_drag_to_group")
	check(pf.spot == "group0" and pf.sprite.position.is_equal_approx(st.PF_SPOTS.group0) and pf.sprite.z_index == 2, "portafilter not locked in group0")

	# Cup from the rack onto the scale.
	await guide_on("rack_cups")
	var rack: Vector2 = st.guide_rect("rack_cups").get_center()
	await drag(rack, st.tray_centre(0) + Vector2(6, -4), "04_cup_drag")
	var cup: EspressoStation.Cup = st.cup_at("tray0")
	check(cup != null and cup.kind == r.cup, "cup not on tray0")
	if cup == null:
		return finish()
	await create_timer(0.2).timeout
	check((cup.sprite.position + st.CUPS[cup.kind].anchor).is_equal_approx(st.cup_stand(0)), "cup base off the stand: %s" % (cup.sprite.position + st.CUPS[cup.kind].anchor))
	check(cup.shadow.visible and cup.sprite.z_index < pf.sprite.z_index, "cup shadow/depth wrong")
	await shot("05_cup_on_scale")

	# Shot: the guide points at the brew button (knob0). Start with the portafilter-tap shortcut
	# (its handle: the cup covers the basket), stop with the brew button at the target.
	await guide_on("knob0")
	var handle := pf.sprite.position + Vector2(8, 10)
	check(not st.hit(cup.sprite, handle), "handle tap point is over the cup")
	await tap(handle)
	check(st.groups[0].state == EspressoStation.ShotState.EXTRACTING, "tap did not start the shot")
	var stream: ColorRect = st.groups[0].stream
	await create_timer(0.5).timeout
	var sx := stream.position.x + stream.size.x / 2.0
	check(absf(sx - st.cup_stand(0).x) <= 1.0, "stream x %s not over the cup %s" % [sx, st.cup_stand(0).x])
	await shot("06_extracting_partial")
	t0 = Time.get_ticks_msec()
	while cup.yield_g < r.target_yield_g and Time.get_ticks_msec() - t0 < 30000:
		await process_frame
	await tap(st.guide_rect("knob0").get_center())
	check(st.groups[0].state != EspressoStation.ShotState.EXTRACTING and not cup.drink.is_empty(), "shot did not stop / no drink")
	await shot("07_espresso")

	# Milk: fridge, steam wand, pour, latte art.
	await guide_on("fridge")
	var pitcher_c := func() -> Vector2: return st.pitcher.position + st.pitcher.texture.get_size() / 2
	await drag(pitcher_c.call(), st.MILK_SOURCE.get_center())
	check(st.milk_state == EspressoStation.MilkState.COLD, "pitcher not filled")
	await guide_on("steam")
	await drag(pitcher_c.call(), st.STEAM_ZONE.get_center())
	check(st.steam_panel.visible, "steam panel did not open")
	st.milk_temp = 62.0  # the steam panel's hold mechanic is unchanged by these phases
	st.milk_foam = 0.32
	st.close_steam()
	await guide_on("cup")
	await drag(pitcher_c.call(), cup.sprite.position + cup.sprite.texture.get_size() / 2)
	check(cup.drink.get("milk_temp", -1.0) > 50.0, "milk not poured")
	check(st.art_panel.visible, "latte art did not open")
	st.art_panel.finish(0.9)
	await shot("08_latte", 0.8)

	# Toppings page: press the real button, then every highlighted syrup/topping.
	await guide_on("toppings_button")
	var b: Button = st.to_toppings
	var bc := (b.get_global_rect().get_center() - st.world.position) / st.SCALE
	await tap(bc)
	await create_timer(0.7).timeout
	check(st.page == 1 and cup.spot.begins_with("slot"), "not on the topping page with the cup on a mat")
	var guard := 0
	while st.objective().id == "extras" and guard < 12:
		var t: String = st.objective().target
		await guide_on(t)
		await tap(st.guide_rect(t).get_center())
		guard += 1
	await shot("09_toppings")
	check(st.objective().id == "serve", "extras not complete: %s" % st.objective().title)

	# Serve: drag the full cup (liquid must move with it).
	await guide_on("serve2")
	var served := []
	st.served.connect(func(d): served.append(d))
	await drag(cup.sprite.position + cup.sprite.texture.get_size() / 2, st.SERVE2_RECT.get_center() + Vector2(st.PAGE_W, 0), "10_cup_drag_full")
	check(served.size() == 1, "drink not served")
	check(shift.step == shift.Step.RESULT, "result screen not shown")
	if served.size() == 1:
		print("served: ", served[0].get("toppings"), " syrups ", served[0].get("syrups"))
	await shot("11_result", 0.8)
	finish()


func finish() -> void:
	print("FLOW PASS" if fails == 0 else "FLOW FAILED (%d)" % fails)
	SaveGame.reset()
	quit()
