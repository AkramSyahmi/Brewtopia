extends Control
## Chapter 1 first shift: three scripted orders (GDD 12.2).
## Per order: customer walks in -> dialogue -> dose -> grind -> extract -> result -> serve.
## Pixel art comes from tools/gen_art.gd; the world is drawn at 640x360 and scaled x2.

const SHIFT_PATH := "res://data/orders/ch1_first_shift.json"
const RECIPE_PATH := "res://data/recipes/%s.json"
const SPRITE_PATH := "res://assets/sprites/%s.png"
const MAX_YIELD_G := 70.0
const START_GRIND := 8  # left coarse by the previous barista, so the player has to adjust
const CUSTOMER_SPOT := Vector2(60, 150)
const CUP_SPOT := Vector2(297, 217)  # on the machine's drip tray
const SERVE_SPOT := Vector2(118, 217)  # counter in front of the customer

const ESPRESSO := Color("#36251D")
const CARAMEL := Color("#BE895B")
const CREAM := Color("#F5E7CA")
const SAGE := Color("#8F9C7B")

## Tuning knobs: editable in the Inspector when CafeShift is selected.
@export var DISPENSE_G_PER_S := 4.0  # grams of coffee per second while holding "Hold to grind"
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

# World (pixel art)
var world: Node2D
var customer: Sprite2D
var mentor_sprite: Sprite2D
var grinder: Sprite2D
var scale_sprite: Sprite2D
var machine: Sprite2D
var cup: Sprite2D
var stream: ColorRect
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


func _ready() -> void:
	shift = EspressoModel.load_recipe(SHIFT_PATH)  # same JSON loader
	build_world()
	build_ui()
	start_order(0)


func _process(delta: float) -> void:
	if dispensing:
		dose_g += DISPENSE_G_PER_S * delta
		readout.text = "%.1f g" % dose_g
	if extracting:
		sim_time += delta * SIM_SPEED
		yield_g = flow * sim_time
		readout.text = "%.1f g  ·  %.1f s" % [yield_g, sim_time]
		if yield_g > 8.0:
			cup.texture = tex("cup_full")
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
	progress.text = "ORDER %d / %d" % [i + 1, shift.orders.size()]
	slip.text = "%s\n%s\n%d g in · %d g out\n%d–%d s" % [
		shift.cast[current_order().customer].to_upper(), recipe.display_name,
		recipe.dose_g, recipe.target_yield_g, recipe.extraction_time_min_s, recipe.extraction_time_max_s]
	reset_cup()
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

	match step:
		Step.DIALOGUE:
			var line: Array = lines[line_index]
			focus([])
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
			focus([grinder, scale_sprite])
			title.text = "DOSE THE COFFEE  ·  target %d g" % recipe.dose_g
			readout.text = "%.1f g" % dose_g
			var hold := add_button("Hold to grind")
			hold.button_down.connect(func(): dispensing = true)
			hold.button_up.connect(func(): dispensing = false)
			add_button("Empty").pressed.connect(func():
				dose_g = 0.0
				readout.text = "0.0 g")
			add_button("Next").pressed.connect(func(): show_step(Step.GRIND))
			mentor("Hold the grinder button and let go when the scale is near %d g." % recipe.dose_g)

		Step.GRIND:
			focus([grinder])
			title.text = "SET THE GRIND  ·  1 = fine, 10 = coarse"
			readout.text = "Setting %d" % grind
			var slider := HSlider.new()
			slider.min_value = 1
			slider.max_value = 10
			slider.step = 1
			slider.value = grind
			slider.custom_minimum_size = Vector2(460, 70)
			slider.value_changed.connect(func(v):
				grind = int(v)
				readout.text = "Setting %d" % grind)
			controls.add_child(slider)
			add_button("Next").pressed.connect(func(): show_step(Step.EXTRACT))
			mentor("Finer grind slows the shot down. Coarser grind speeds it up.")

		Step.EXTRACT:
			focus([machine])
			title.text = "PULL THE SHOT  ·  target %d g in %d–%d s (simulated)" % [
				recipe.target_yield_g, recipe.extraction_time_min_s, recipe.extraction_time_max_s]
			yield_g = 0.0
			sim_time = 0.0
			reset_cup()
			readout.text = "0.0 g  ·  0.0 s"
			var btn := add_button("Start")
			btn.pressed.connect(func():
				if extracting:
					stop_extraction()
				else:
					flow = EspressoModel.flow_rate(recipe, dose_g, grind)
					extracting = true
					stream.show()
					btn.text = "Stop")
			mentor("Watch the scale. Stop when the cup reaches about %d g." % recipe.target_yield_g)

		Step.RESULT:
			focus([cup])
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
				mentor_sprite.texture = tex("mentor")
				start_order(0))


func serve(score: int, grade: String) -> void:
	scores.append(score)
	for c in controls.get_children():
		c.queue_free()
	focus([])
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
	reset_cup()
	show_step(Step.DOSE)


func next_order() -> void:
	if order_index + 1 < shift.orders.size():
		start_order(order_index + 1)
	else:
		show_step(Step.SUMMARY)


func stop_extraction() -> void:
	extracting = false
	stream.hide()
	show_step(Step.RESULT)


func reset_cup() -> void:
	cup.texture = tex("cup_empty")
	cup.position = CUP_SPOT
	cup.show()


## Pulses the equipment the current step uses, so players know where to look.
func focus(nodes: Array) -> void:
	if focus_tween:
		focus_tween.kill()
	for n in [grinder, scale_sprite, machine, cup]:
		n.modulate = Color.WHITE
	if nodes.is_empty():
		return
	focus_tween = create_tween().set_loops()
	for n in nodes:
		focus_tween.parallel().tween_property(n, "modulate", Color(1.35, 1.25, 1.05), 0.5)
	for n in nodes:
		focus_tween.parallel().tween_property(n, "modulate", Color.WHITE, 0.5).set_delay(0.5)


## Small hop on the speaking character.
func bounce(who: Sprite2D) -> void:
	if who == null:
		return
	var base_y := who.position.y
	var t := create_tween()
	t.tween_property(who, "position:y", base_y - 3, 0.08)
	t.tween_property(who, "position:y", base_y, 0.12)


func add_button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(200, 70)
	controls.add_child(b)
	return b


func sprite(sprite_name: String, pos: Vector2) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = tex(sprite_name)
	s.centered = false
	s.position = pos
	world.add_child(s)
	return s


func build_world() -> void:
	world = Node2D.new()
	world.scale = Vector2(2, 2)
	world.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(world)
	sprite("cafe_background", Vector2.ZERO)
	customer = sprite("student", CUSTOMER_SPOT)
	mentor_sprite = sprite("mentor", Vector2(470, 150))
	sprite("counter", Vector2.ZERO)
	sprite("jar_dark", Vector2(132, 212))
	sprite("jar_light", Vector2(152, 212))
	grinder = sprite("grinder", Vector2(180, 174))
	scale_sprite = sprite("scale", Vector2(216, 224))
	machine = sprite("machine", Vector2(260, 170))
	stream = ColorRect.new()
	stream.color = Color("#4A2A18")
	stream.position = Vector2(303, 213)
	stream.size = Vector2(1, 5)
	stream.hide()
	world.add_child(stream)
	cup = sprite("cup_empty", CUP_SPOT)


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


func build_ui() -> void:
	theme = Theme.new()
	theme.default_font_size = 26

	# Slim top HUD
	var bar := PanelContainer.new()
	bar.add_theme_stylebox_override("panel", panel_style(Color(ESPRESSO, 0.85), Color(ESPRESSO, 0)))
	bar.position = Vector2.ZERO
	bar.size = Vector2(1280, 44)
	add_child(bar)
	var bar_row := HBoxContainer.new()
	bar.add_child(bar_row)
	header = label(bar_row, 20, SAGE)
	header.text = shift.title
	header.size_flags_horizontal = SIZE_EXPAND_FILL
	progress = label(bar_row, 20, CARAMEL)

	# Paper order slip, pinned on the wall at the right
	var paper := PanelContainer.new()
	paper.add_theme_stylebox_override("panel", panel_style(CREAM, CARAMEL))
	paper.position = Vector2(1040, 230)
	paper.custom_minimum_size = Vector2(220, 0)
	paper.rotation_degrees = 2
	add_child(paper)
	slip = label(paper, 20, ESPRESSO)

	# Step area on the counter front
	var step_box := VBoxContainer.new()
	step_box.position = Vector2(32, 478)
	step_box.size = Vector2(1216, 120)
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
	box.size = Vector2(1232, 122)
	box.custom_minimum_size = Vector2(1232, 122)
	add_child(box)
	var talk := VBoxContainer.new()
	talk.add_theme_constant_override("separation", 2)
	box.add_child(talk)
	speaker = label(talk, 20, CARAMEL)
	tip = label(talk, 22, CREAM)
	tip.autowrap_mode = TextServer.AUTOWRAP_WORD
