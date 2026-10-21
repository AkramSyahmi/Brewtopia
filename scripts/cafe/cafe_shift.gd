extends Control
## Chapter 1 first shift: three scripted orders (GDD 12.2).
## Per order: customer walks in -> dialogue (counter view) -> dose, grind, extract
## (barista close-up station, GDD 8.3) -> result and serve (counter view).
## Pixel art comes from tools/gen_art.gd; worlds are drawn at base resolution and scaled x2.

const SHIFT_PATH := "res://data/orders/ch1_first_shift.json"
const RECIPE_PATH := "res://data/recipes/%s.json"
const SPRITE_PATH := "res://assets/sprites/%s.png"
const MAX_YIELD_G := 70.0
const START_GRIND := 8  # left coarse by the previous barista, so the player has to adjust

# Counter view (640x360 base)
const CUSTOMER_SPOT := Vector2(60, 150)
const CUP_SPOT := Vector2(297, 217)  # on the machine's drip tray
const SERVE_SPOT := Vector2(118, 217)  # counter in front of the customer

# Station view (960x360 base); the camera slides between grinder and machine.
const STATION_Y := -120.0  # real px; lifts the equipment above the step UI
const CAM_GRINDER := 0.0
const CAM_MACHINE := -640.0
const PORTA_DOSE := Vector2(123, 270)  # on the dose scale under the grinder spout
const PORTA_LOCKED := Vector2(520, 226)  # locked into the group head
const DIAL_CENTER := Vector2(95, 175)
const CUP_INSIDE := Rect2(522, 248, 36, 22)  # cup_big interior on the cup scale

const ESPRESSO := Color("#36251D")
const CARAMEL := Color("#BE895B")
const CREAM := Color("#F5E7CA")
const SAGE := Color("#8F9C7B")
const COFFEE := Color("#4A2A18")
const LCD_TEXT := Color("#24402A")

## Tuning knobs: editable in the Inspector when CafeShift is selected.
@export var DISPENSE_G_PER_S := 4.0  # grams of coffee per second while holding the grinder button
@export var SIM_SPEED := 2.0  # simulated seconds per real second (playtest: 3x felt too fast)

enum Step { DIALOGUE, DOSE, GRIND, EXTRACT, RESULT, SUMMARY }

var shift: Dictionary
var order_index := 0
var recipe: Dictionary  # current order's recipe with its overrides applied
var scores: Array[int] = []

var lines: Array = []
var line_index := 0
var after_dialogue: Callable

var dose_g := 0.0
var grind := START_GRIND  # carries over between orders, like a real grinder
var yield_g := 0.0
var sim_time := 0.0
var flow := 0.0
var dispensing := false
var extracting := false

# Counter view
var counter_world: Node2D
var customer: Sprite2D
var mentor_sprite: Sprite2D
var cup: Sprite2D

# Station view
var station: Node2D
var dial_sprite: Sprite2D
var grinder_btn: TextureButton
var brew_btn: TextureButton
var porta: Sprite2D
var grounds: ColorRect
var grounds_stream: ColorRect
var shot_stream: ColorRect
var cup_fill: ColorRect
var dose_lcd: Label
var cup_lcd: Label
var fade: ColorRect
var focus_tween: Tween

# UI
var header: Label
var progress: Label
var slip: Label
var title: Label
var readout: Label
var controls: HBoxContainer
var speaker: Label
var tip: Label
var shot_button: Button


func _ready() -> void:
	shift = EspressoModel.load_recipe(SHIFT_PATH)  # same JSON loader
	build_counter()
	build_station()
	build_ui()
	start_order(0)


func _process(delta: float) -> void:
	if dispensing:
		dose_g += DISPENSE_G_PER_S * delta
		update_dose_visuals()
	if extracting:
		sim_time += delta * SIM_SPEED
		yield_g = flow * sim_time
		readout.text = "%.1f g  ·  %.1f s" % [yield_g, sim_time]
		cup_lcd.text = "%.1fg %02ds" % [yield_g, int(sim_time)]
		var h := clampf(yield_g / 40.0, 0.0, 1.0) * CUP_INSIDE.size.y
		cup_fill.position.y = CUP_INSIDE.end.y - h
		cup_fill.size.y = h
		if yield_g >= MAX_YIELD_G:
			stop_extraction()


func current_order() -> Dictionary:
	return shift.orders[order_index]


func tex(sprite_name: String) -> Texture2D:
	return load(SPRITE_PATH % sprite_name)


func start_order(i: int) -> void:
	order_index = i
	recipe = EspressoModel.load_recipe(RECIPE_PATH % current_order().recipe)
	recipe.merge(current_order().get("recipe_overrides", {}), true)
	dose_g = 0.0
	update_dose_visuals()
	progress.text = "ORDER %d / %d" % [i + 1, shift.orders.size()]
	slip.text = "%s\n%s\n%d g in · %d g out\n%d–%d s" % [
		shift.cast[current_order().customer].to_upper(), recipe.display_name,
		recipe.dose_g, recipe.target_yield_g, recipe.extraction_time_min_s, recipe.extraction_time_max_s]
	cup.texture = tex("cup_empty")
	cup.position = CUP_SPOT
	cup.show()
	customer.texture = tex(shift.sprites[current_order().customer])
	customer.position = CUSTOMER_SPOT - Vector2(140, 0)
	customer.show()
	create_tween().tween_property(customer, "position", CUSTOMER_SPOT, 0.8) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	say(current_order().intro, func(): show_step(Step.DOSE))


## Plays dialogue lines ([role, text] pairs) one tap at a time, then calls `then`.
func say(new_lines: Array, then: Callable) -> void:
	lines = new_lines
	line_index = 0
	after_dialogue = then
	show_step(Step.DIALOGUE)


## Mentor guidance depends on the order's assist level: full, hints (on request) or none.
func mentor(text: String) -> void:
	speaker.text = ""
	tip.text = ""
	match current_order().assist:
		"full":
			speaker.text = shift.cast.MENTOR
			tip.text = text
		"hints":
			add_button("Hint").pressed.connect(func():
				speaker.text = shift.cast.MENTOR
				tip.text = text)


func show_step(step: Step) -> void:
	for c in controls.get_children():
		c.queue_free()
	shot_button = null
	grinder_btn.disabled = step != Step.DOSE
	brew_btn.disabled = step != Step.EXTRACT

	match step:
		Step.DIALOGUE:
			show_counter()
			focus([])
			var line: Array = lines[line_index]
			title.text = ""
			readout.text = ""
			speaker.text = shift.cast[line[0]]
			tip.text = line[1]
			bounce(mentor_sprite if line[0] == "MENTOR" else customer if line[0] != "PLAYER" else null)
			add_button("Next").pressed.connect(func():
				line_index += 1
				if line_index < lines.size():
					show_step(Step.DIALOGUE)
				else:
					after_dialogue.call())

		Step.DOSE:
			show_station(CAM_GRINDER)
			porta.position = PORTA_DOSE
			update_dose_visuals()
			focus([grinder_btn])
			title.text = "DOSE THE COFFEE  ·  target %d g" % recipe.dose_g
			add_button("Empty").pressed.connect(func():
				dose_g = 0.0
				update_dose_visuals())
			add_button("Next").pressed.connect(func(): show_step(Step.GRIND))
			mentor("Hold the red grinder button and let go when the scale shows about %d g." % recipe.dose_g)

		Step.GRIND:
			show_station(CAM_GRINDER)
			focus([dial_sprite])
			title.text = "SET THE GRIND  ·  1 = fine, 10 = coarse"
			readout.text = "Setting %d" % grind
			var slider := HSlider.new()
			slider.min_value = 1
			slider.max_value = 10
			slider.step = 1
			slider.value = grind
			slider.custom_minimum_size = Vector2(420, 70)
			slider.value_changed.connect(func(v):
				grind = int(v)
				readout.text = "Setting %d" % grind
				set_dial())
			controls.add_child(slider)
			add_button("Next").pressed.connect(func(): show_step(Step.EXTRACT))
			mentor("Turn the dial. Finer grind slows the shot down. Coarser grind speeds it up.")

		Step.EXTRACT:
			yield_g = 0.0
			sim_time = 0.0
			cup_fill.size.y = 0
			cup_lcd.text = "0.0g 00s"
			readout.text = "0.0 g  ·  0.0 s"
			grounds.hide()
			show_station(CAM_MACHINE)
			create_tween().tween_property(porta, "position", PORTA_LOCKED, 0.5) \
				.set_trans(Tween.TRANS_SINE)
			focus([brew_btn])
			title.text = "PULL THE SHOT  ·  target %d g in %d–%d s (simulated)" % [
				recipe.target_yield_g, recipe.extraction_time_min_s, recipe.extraction_time_max_s]
			shot_button = add_button("Start")
			shot_button.pressed.connect(toggle_shot)
			mentor("Press the green brew button. Stop when the scale reaches about %d g." % recipe.target_yield_g)

		Step.RESULT:
			show_counter()
			cup.texture = tex("cup_full")
			focus([])
			var r := EspressoModel.evaluate(recipe, dose_g, grind, yield_g)
			# Accuracy and service are fixed until order variety and timers exist.
			var score := EspressoModel.order_score(r.quality, 100, 100)
			var grade := EspressoModel.grade(score)
			title.text = "RESULT  ·  %.1f g in · %.1f g out · %.1f s" % [dose_g, yield_g, sim_time]
			readout.text = "%d  %s" % [score, grade]
			# Diagnosis always shows, whatever the assist level: it is the core lesson.
			speaker.text = shift.cast.MENTOR
			tip.text = r.tip
			if grade != "Failed Order":
				add_button("Serve").pressed.connect(func(): serve(score, grade))
			add_button("Remake").pressed.connect(remake)

		Step.SUMMARY:
			show_counter()
			focus([])
			var s := ShiftRewards.summary(scores, shift.wage_rm)
			customer.hide()
			mentor_sprite.texture = tex("mentor_happy")
			title.text = "SHIFT COMPLETE!"
			readout.text = "Average %d" % s.average
			progress.text = ""
			speaker.text = shift.cast.MENTOR
			tip.text = "Orders served: %d    Wage: RM%d    Tips: RM%d    XP: +%d\nJunior Barista progress unlocked. Good work today!" % [
				s.orders, s.wage_rm, s.tips_rm, s.xp]
			add_button("Play again").pressed.connect(func():
				scores.clear()
				grind = START_GRIND
				set_dial()
				mentor_sprite.texture = tex("mentor")
				start_order(0))


func toggle_shot() -> void:
	if extracting:
		stop_extraction()
		return
	flow = EspressoModel.flow_rate(recipe, dose_g, grind)
	extracting = true
	shot_stream.show()
	brew_btn.texture_normal = tex("brew_button_pressed")
	if shot_button:
		shot_button.text = "Stop"


func stop_extraction() -> void:
	extracting = false
	shot_stream.hide()
	brew_btn.texture_normal = tex("brew_button")
	await get_tree().create_timer(0.6).timeout  # let the player see the final weight
	show_step(Step.RESULT)


func serve(score: int, grade: String) -> void:
	scores.append(score)
	for c in controls.get_children():
		c.queue_free()
	var t := create_tween()
	t.tween_property(cup, "position", SERVE_SPOT, 0.6).set_trans(Tween.TRANS_SINE)
	await t.finished
	var who: String = current_order().customer
	if grade in ["Perfect Brew", "Great Cup"]:
		customer.texture = tex(shift.sprites[who] + "_happy")
	say([[who, shift.reactions[grade]]], func():
		cup.hide()
		var leave := create_tween()
		leave.tween_property(customer, "position", CUSTOMER_SPOT - Vector2(140, 0), 0.6)
		await leave.finished
		next_order())


func remake() -> void:
	dose_g = 0.0
	cup.texture = tex("cup_empty")
	show_step(Step.DOSE)


func next_order() -> void:
	if order_index + 1 < shift.orders.size():
		start_order(order_index + 1)
	else:
		show_step(Step.SUMMARY)


func update_dose_visuals() -> void:
	readout.text = "%.1f g" % dose_g if not extracting else readout.text
	dose_lcd.text = "%.1fg" % dose_g
	var h := clampf(dose_g * 0.5, 0.0, 14.0)
	grounds.position.y = PORTA_DOSE.y + 2 - h
	grounds.size.y = h
	grounds.visible = h > 0
	grounds_stream.visible = dispensing


func set_dial() -> void:
	dial_sprite.rotation_degrees = lerpf(-135.0, 135.0, (grind - 1) / 9.0)


# ---------- views ----------

func show_counter() -> void:
	if counter_world.visible:
		return
	await fade_swap(func():
		station.hide()
		counter_world.show())


func show_station(cam_x: float) -> void:
	if not station.visible:
		station.position = Vector2(cam_x, STATION_Y)
		await fade_swap(func():
			counter_world.hide()
			station.show())
	elif station.position.x != cam_x:
		create_tween().tween_property(station, "position:x", cam_x, 0.6) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func fade_swap(swap: Callable) -> void:
	var t := create_tween()
	t.tween_property(fade, "color:a", 1.0, 0.15)
	t.tween_callback(swap)
	t.tween_property(fade, "color:a", 0.0, 0.2)
	await t.finished


## Pulses the parts the current step uses, so players know where to look.
func focus(nodes: Array) -> void:
	if focus_tween:
		focus_tween.kill()
	for n in [grinder_btn, dial_sprite, brew_btn]:
		n.modulate = Color.WHITE
	if nodes.is_empty():
		return
	focus_tween = create_tween().set_loops()
	for n in nodes:
		focus_tween.parallel().tween_property(n, "modulate", Color(1.5, 1.4, 1.1), 0.45)
	for n in nodes:
		focus_tween.parallel().tween_property(n, "modulate", Color.WHITE, 0.45).set_delay(0.45)


## Small hop on the speaking character.
func bounce(who: Sprite2D) -> void:
	if who == null:
		return
	var base_y := who.position.y
	var t := create_tween()
	t.tween_property(who, "position:y", base_y - 3, 0.08)
	t.tween_property(who, "position:y", base_y, 0.12)


# ---------- building ----------

func sprite(parent: Node, sprite_name: String, pos: Vector2, centered := false) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = tex(sprite_name)
	s.centered = centered
	s.position = pos
	parent.add_child(s)
	return s


func rect_node(parent: Node, color: Color, pos: Vector2, size_px: Vector2) -> ColorRect:
	var r := ColorRect.new()
	r.color = color
	r.position = pos
	r.size = size_px
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(r)
	return r


func world_node() -> Node2D:
	var w := Node2D.new()
	w.scale = Vector2(2, 2)
	w.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(w)
	return w


func build_counter() -> void:
	counter_world = world_node()
	sprite(counter_world, "cafe_background", Vector2.ZERO)
	customer = sprite(counter_world, "student", CUSTOMER_SPOT)
	mentor_sprite = sprite(counter_world, "mentor", Vector2(470, 150))
	sprite(counter_world, "counter", Vector2.ZERO)
	sprite(counter_world, "jar_dark", Vector2(132, 212))
	sprite(counter_world, "jar_light", Vector2(152, 212))
	sprite(counter_world, "grinder", Vector2(180, 174))
	sprite(counter_world, "scale", Vector2(216, 224))
	sprite(counter_world, "machine", Vector2(260, 170))
	cup = sprite(counter_world, "cup_empty", CUP_SPOT)


func lcd(pos: Vector2) -> Label:
	var l := Label.new()
	l.position = pos
	l.add_theme_font_size_override("font_size", 9)
	l.add_theme_color_override("font_color", LCD_TEXT)
	station.add_child(l)
	return l


func world_button(sprite_name: String, pos: Vector2) -> TextureButton:
	var b := TextureButton.new()
	b.texture_normal = tex(sprite_name)
	b.texture_pressed = tex(sprite_name + "_pressed")
	b.position = pos
	station.add_child(b)
	return b


func build_station() -> void:
	station = world_node()
	station.hide()
	sprite(station, "station_background", Vector2.ZERO)
	grounds_stream = rect_node(station, COFFEE, Vector2(142, 234), Vector2(2, 36))
	grounds_stream.hide()
	grounds = rect_node(station, COFFEE, Vector2(127, PORTA_DOSE.y), Vector2(32, 0))
	porta = sprite(station, "portafilter", PORTA_DOSE)
	dial_sprite = sprite(station, "dial", DIAL_CENTER, true)
	set_dial()
	grinder_btn = world_button("grinder_button", Vector2(84, 139 + 70))
	grinder_btn.button_down.connect(func():
		dispensing = true
		update_dose_visuals())
	grinder_btn.button_up.connect(func():
		dispensing = false
		update_dose_visuals())
	brew_btn = world_button("brew_button", Vector2(524, 152))
	brew_btn.pressed.connect(toggle_shot)
	shot_stream = rect_node(station, COFFEE, Vector2(534, 243), Vector2(2, 27))
	rect_node(shot_stream, COFFEE, Vector2(12, 0), Vector2(2, 27))
	shot_stream.hide()
	cup_fill = rect_node(station, COFFEE, Vector2(CUP_INSIDE.position.x, CUP_INSIDE.end.y),
		Vector2(CUP_INSIDE.size.x, 0))
	sprite(station, "cup_big", Vector2(518, 246))
	dose_lcd = lcd(Vector2(132, 287))
	cup_lcd = lcd(Vector2(492, 275))


func panel_style(bg: Color, border: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(3)
	s.set_content_margin_all(14)
	return s


func label(parent: Node, font_size: int, color: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	parent.add_child(l)
	return l


func add_button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(200, 70)
	controls.add_child(b)
	return b


func build_ui() -> void:
	theme = Theme.new()
	theme.default_font_size = 26

	# Slim top HUD
	var bar := PanelContainer.new()
	bar.add_theme_stylebox_override("panel", panel_style(Color(ESPRESSO, 0.85), Color(ESPRESSO, 0)))
	bar.size = Vector2(1280, 44)
	add_child(bar)
	var bar_row := HBoxContainer.new()
	bar.add_child(bar_row)
	header = label(bar_row, 20, SAGE)
	header.text = shift.title
	header.size_flags_horizontal = SIZE_EXPAND_FILL
	progress = label(bar_row, 20, CARAMEL)

	# Paper order slip, pinned at the right
	var paper := PanelContainer.new()
	paper.add_theme_stylebox_override("panel", panel_style(CREAM, CARAMEL))
	paper.position = Vector2(1040, 230)
	paper.custom_minimum_size = Vector2(220, 0)
	paper.rotation_degrees = 2
	add_child(paper)
	slip = label(paper, 20, ESPRESSO)

	# Step area, on a dark strip so text reads over both views
	var strip := PanelContainer.new()
	strip.add_theme_stylebox_override("panel", panel_style(Color(ESPRESSO, 0.8), Color(ESPRESSO, 0)))
	strip.position = Vector2(24, 470)
	strip.custom_minimum_size = Vector2(1232, 116)
	strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(strip)
	var step_box := VBoxContainer.new()
	step_box.position = Vector2(32, 478)
	step_box.size = Vector2(1216, 110)
	step_box.add_theme_constant_override("separation", 6)
	add_child(step_box)
	title = label(step_box, 22, CARAMEL)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 24)
	step_box.add_child(row)
	readout = label(row, 44, CREAM)
	readout.custom_minimum_size = Vector2(420, 0)
	controls = HBoxContainer.new()
	controls.add_theme_constant_override("separation", 16)
	row.add_child(controls)

	# Dialogue box
	var box := PanelContainer.new()
	box.add_theme_stylebox_override("panel", panel_style(Color(ESPRESSO, 0.92), CARAMEL))
	box.position = Vector2(24, 590)
	box.custom_minimum_size = Vector2(1232, 122)
	add_child(box)
	var talk := VBoxContainer.new()
	talk.add_theme_constant_override("separation", 2)
	box.add_child(talk)
	speaker = label(talk, 20, CARAMEL)
	tip = label(talk, 22, CREAM)
	tip.autowrap_mode = TextServer.AUTOWRAP_WORD

	# Fade layer for view changes
	fade = ColorRect.new()
	fade.color = Color(ESPRESSO, 0.0)
	fade.size = Vector2(1280, 720)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fade)
