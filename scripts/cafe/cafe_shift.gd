extends Control
## Chapter 1 first shift: three scripted orders (GDD 12.2).
## Per order: customer walks in and orders (counter view) -> the player makes the drink
## hands-on at the bar (BarStation, barista POV) -> serving at the pass returns to the
## counter for the score, the mentor's diagnosis and the customer's reaction.
## Pixel art comes from tools/gen_art.gd; worlds are drawn at 640x360 and scaled x2.

const SHIFT_PATH := "res://data/orders/ch1_first_shift.json"
const RECIPE_PATH := "res://data/recipes/%s.json"
const SPRITE_PATH := "res://assets/sprites/%s.png"
const START_GRIND := 8  # left coarse by the previous barista, so the player has to adjust

const CUSTOMER_SPOT := Vector2(60, 150)
const CUP_SPOT := Vector2(297, 217)  # on the machine's drip tray (counter view)
const SERVE_SPOT := Vector2(118, 217)  # counter in front of the customer

const ESPRESSO := Color("#36251D")
const CARAMEL := Color("#BE895B")
const CREAM := Color("#F5E7CA")
const SAGE := Color("#8F9C7B")

## Tuning knobs: editable in the Inspector when CafeShift is selected.
@export var DISPENSE_G_PER_S := 4.0  # grams of coffee per second while holding the grinder button
@export var SIM_SPEED := 2.0  # simulated seconds per real second (playtest: 3x felt too fast)

enum Step { DIALOGUE, BAR, RESULT, SUMMARY }

var shift: Dictionary
var order_index := 0
var recipe: Dictionary  # current order's recipe with its overrides applied
var scores: Array[int] = []
var step := Step.DIALOGUE

var lines: Array = []
var line_index := 0
var after_dialogue: Callable

# Counter view
var counter_world: Node2D
var customer: Sprite2D
var mentor_sprite: Sprite2D
var cup: Sprite2D

var bar: Bar3D
var fade: ColorRect

# UI
var header: Label
var progress: Label
var hint_button: Button
var slip: Label
var strip: Control
var title: Label
var readout: Label
var controls: HBoxContainer
var speaker: Label
var tip: Label


func _ready() -> void:
	shift = EspressoModel.load_recipe(SHIFT_PATH)  # same JSON loader
	mouse_filter = MOUSE_FILTER_IGNORE  # let clicks reach the bar's drag and drop
	build_counter()
	bar = Bar3D.new()
	bar.dispense_g_per_s = DISPENSE_G_PER_S
	bar.sim_speed = SIM_SPEED
	bar.hide()
	add_child(bar)
	bar.set_grind(START_GRIND)
	bar.changed.connect(refresh_hint)
	bar.message.connect(func(text):
		speaker.text = ""
		tip.text = text)
	bar.served.connect(on_served)
	build_ui()
	start_order(0)


func current_order() -> Dictionary:
	return shift.orders[order_index]


func tex(sprite_name: String) -> Texture2D:
	return load(SPRITE_PATH % sprite_name)


func start_order(i: int) -> void:
	order_index = i
	recipe = EspressoModel.load_recipe(RECIPE_PATH % current_order().recipe)
	recipe.merge(current_order().get("recipe_overrides", {}), true)
	progress.text = "ORDER %d / %d" % [i + 1, shift.orders.size()]
	slip.text = "%s\n%s\n%d g in · %d g out\n%d–%d s" % [
		shift.cast[current_order().customer].to_upper(), recipe.display_name,
		recipe.dose_g, recipe.target_yield_g, recipe.extraction_time_min_s, recipe.extraction_time_max_s]
	cup.hide()
	customer.texture = tex(shift.sprites[current_order().customer])
	customer.position = CUSTOMER_SPOT - Vector2(140, 0)
	customer.show()
	create_tween().tween_property(customer, "position", CUSTOMER_SPOT, 0.8) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	bar.start_order(recipe)
	say(current_order().intro, func(): show_step(Step.BAR))


## Plays dialogue lines ([role, text] pairs) one tap at a time, then calls `then`.
func say(new_lines: Array, then: Callable) -> void:
	lines = new_lines
	line_index = 0
	after_dialogue = then
	show_step(Step.DIALOGUE)


## Mentor guidance at the bar depends on the order's assist level:
## full = always shows the next suggested action, hints = on request, none = nothing.
func refresh_hint() -> void:
	if step != Step.BAR:
		return
	hint_button.visible = current_order().assist == "hints"
	if current_order().assist == "full":
		speaker.text = shift.cast.MENTOR
		tip.text = bar.next_hint()


func show_step(new_step: Step) -> void:
	step = new_step
	for c in controls.get_children():
		c.queue_free()
	hint_button.hide()
	strip.visible = step != Step.BAR

	match step:
		Step.DIALOGUE:
			show_view(counter_world)
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

		Step.BAR:
			show_view(bar)
			speaker.text = ""
			tip.text = ""
			refresh_hint()

		Step.SUMMARY:
			show_view(counter_world)
			var s := ShiftRewards.summary(scores, shift.wage_rm)
			customer.hide()
			cup.hide()
			mentor_sprite.texture = tex("mentor_happy")
			title.text = "SHIFT COMPLETE!"
			readout.text = "Average %d" % s.average
			progress.text = ""
			speaker.text = shift.cast.MENTOR
			tip.text = "Orders served: %d    Wage: RM%d    Tips: RM%d    XP: +%d\nJunior Barista progress unlocked. Good work today!" % [
				s.orders, s.wage_rm, s.tips_rm, s.xp]
			add_button("Play again").pressed.connect(func():
				scores.clear()
				mentor_sprite.texture = tex("mentor")
				start_order(0))


## The cup reached the pass: score it at the counter.
func on_served(shot: Dictionary) -> void:
	show_step(Step.RESULT)
	show_view(counter_world)
	cup.texture = tex("cup_full")
	cup.position = SERVE_SPOT
	cup.show()
	var r := EspressoModel.evaluate(recipe, shot.dose, shot.grind, shot.yield, shot.tamped)
	# Accuracy and service are fixed until order variety and timers exist.
	var score := EspressoModel.order_score(r.quality, 100, 100)
	var grade := EspressoModel.grade(score)
	title.text = "RESULT  ·  %.1f g in · %.1f g out · %.1f s · grind %d%s" % [
		shot.dose, shot.yield, shot.time, shot.grind, "" if shot.tamped else " · not tamped"]
	readout.text = "%d  %s" % [score, grade]
	# Diagnosis always shows, whatever the assist level: it is the core lesson.
	speaker.text = shift.cast.MENTOR
	tip.text = r.tip
	var who: String = current_order().customer
	if grade == "Failed Order":
		add_button("Make it again").pressed.connect(func():
			say([[who, "Hmm, this isn't right. Could you make it again?"]], func():
				cup.hide()
				bar.clear_cup()
				show_step(Step.BAR)))
		return
	add_button("Continue").pressed.connect(func():
		scores.append(score)
		if grade in ["Perfect Brew", "Great Cup"]:
			customer.texture = tex(shift.sprites[who] + "_happy")
		say([[who, shift.reactions[grade]]], func():
			cup.hide()
			var leave := create_tween()
			leave.tween_property(customer, "position", CUSTOMER_SPOT - Vector2(140, 0), 0.6)
			await leave.finished
			next_order()))


func next_order() -> void:
	if order_index + 1 < shift.orders.size():
		start_order(order_index + 1)
	else:
		show_step(Step.SUMMARY)


# ---------- views ----------

func show_view(view: CanvasItem) -> void:
	if view.visible:
		return
	var t := create_tween()
	t.tween_property(fade, "color:a", 1.0, 0.15)
	t.tween_callback(func():
		counter_world.visible = view == counter_world
		bar.visible = view == bar)
	t.tween_property(fade, "color:a", 0.0, 0.2)


## Small hop on the speaking character.
func bounce(who: Sprite2D) -> void:
	if who == null:
		return
	var base_y := who.position.y
	var t := create_tween()
	t.tween_property(who, "position:y", base_y - 3, 0.08)
	t.tween_property(who, "position:y", base_y, 0.12)


# ---------- building ----------

func sprite(parent: Node, sprite_name: String, pos: Vector2) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = tex(sprite_name)
	s.centered = false
	s.position = pos
	parent.add_child(s)
	return s


func build_counter() -> void:
	counter_world = Node2D.new()
	counter_world.scale = Vector2(2, 2)
	counter_world.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(counter_world)
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
	b.custom_minimum_size = Vector2(220, 70)
	controls.add_child(b)
	return b


func build_ui() -> void:
	theme = Theme.new()
	theme.default_font_size = 26

	# Slim top HUD
	var bar_panel := PanelContainer.new()
	bar_panel.add_theme_stylebox_override("panel", panel_style(Color(ESPRESSO, 0.85), Color(ESPRESSO, 0)))
	bar_panel.size = Vector2(1280, 44)
	add_child(bar_panel)
	var bar_row := HBoxContainer.new()
	bar_row.add_theme_constant_override("separation", 20)
	bar_panel.add_child(bar_row)
	header = label(bar_row, 20, SAGE)
	header.text = shift.title
	header.size_flags_horizontal = SIZE_EXPAND_FILL
	hint_button = Button.new()
	hint_button.text = "Hint"
	hint_button.add_theme_font_size_override("font_size", 18)
	hint_button.hide()
	hint_button.pressed.connect(func():
		speaker.text = shift.cast.MENTOR
		tip.text = bar.next_hint())
	bar_row.add_child(hint_button)
	progress = label(bar_row, 20, CARAMEL)

	# Paper order slip, pinned at the top right
	var paper := PanelContainer.new()
	paper.add_theme_stylebox_override("panel", panel_style(CREAM, CARAMEL))
	paper.position = Vector2(1060, 60)
	paper.custom_minimum_size = Vector2(200, 0)
	paper.rotation_degrees = 2
	add_child(paper)
	slip = label(paper, 18, ESPRESSO)

	# Step area (counter view only), on a dark strip
	strip = PanelContainer.new()
	strip.add_theme_stylebox_override("panel", panel_style(Color(ESPRESSO, 0.8), Color(ESPRESSO, 0)))
	strip.position = Vector2(24, 470)
	strip.custom_minimum_size = Vector2(1232, 116)
	add_child(strip)
	var step_box := VBoxContainer.new()
	step_box.add_theme_constant_override("separation", 4)
	strip.add_child(step_box)
	title = label(step_box, 20, CARAMEL)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 24)
	step_box.add_child(row)
	readout = label(row, 40, CREAM)
	readout.custom_minimum_size = Vector2(440, 0)
	controls = HBoxContainer.new()
	controls.add_theme_constant_override("separation", 16)
	row.add_child(controls)

	# Dialogue / mentor box
	var box := PanelContainer.new()
	box.add_theme_stylebox_override("panel", panel_style(Color(ESPRESSO, 0.92), CARAMEL))
	box.position = Vector2(24, 596)
	box.custom_minimum_size = Vector2(1232, 116)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
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
