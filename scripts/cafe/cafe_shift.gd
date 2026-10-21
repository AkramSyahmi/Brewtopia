extends Control
## Chapter 1 first shift: three scripted orders (GDD 12.2).
## Per order: a customer walks into the café and orders (isometric view) -> the camera
## swoops into the barista's eyes and the player makes the drink hands-on (Bar3D, POV)
## -> serving swoops back out for the score, the mentor's diagnosis and the reaction.

const SHIFT_PATH := "res://data/orders/ch1_first_shift.json"
const RECIPE_PATH := "res://data/recipes/%s.json"
const START_GRIND := 8  # left coarse by the previous barista, so the player has to adjust

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

var bar: Bar3D  # café overview + customers (to be redone in 2D)
var station: EspressoStation  # where drinks are made

# UI
var header: Label
var progress: Label
var hint_button: Button
var next_button: Button
var slip: Label
var strip: Control
var title: Label
var readout: Label
var controls: HBoxContainer
var speaker: Label
var tip: Label
var talk_box: PanelContainer


func _ready() -> void:
	shift = EspressoModel.load_recipe(SHIFT_PATH)  # same JSON loader
	mouse_filter = MOUSE_FILTER_IGNORE  # let clicks reach the bar's drag and drop
	bar = Bar3D.new()
	add_child(bar)
	station = EspressoStation.new()
	station.dispense_g_per_s = DISPENSE_G_PER_S
	station.sim_speed = SIM_SPEED
	add_child(station)
	station.hide()
	station.set_grind(START_GRIND)
	bar.set_view("iso", false)
	station.changed.connect(refresh_hint)
	station.message.connect(func(text):
		speaker.text = ""
		tip.text = text)
	station.served.connect(on_served)
	build_ui()
	start_order(0)


func current_order() -> Dictionary:
	return shift.orders[order_index]


func look_of(role: String) -> String:
	return shift.sprites[role]


func person_of(role: String) -> Node3D:
	return bar.mentor if role == "MENTOR" else null if role == "PLAYER" else bar.customer


func start_order(i: int) -> void:
	order_index = i
	recipe = EspressoModel.load_recipe(RECIPE_PATH % current_order().recipe)
	recipe.merge(current_order().get("recipe_overrides", {}), true)
	progress.text = "ORDER %d / %d" % [i + 1, shift.orders.size()]
	slip.text = "%s\n%s\n%d g in · %d g out\n%d–%d s" % [
		shift.cast[current_order().customer].to_upper(), recipe.display_name,
		recipe.dose_g, recipe.target_yield_g, recipe.extraction_time_min_s, recipe.extraction_time_max_s]
	bar.hide_served_cup()
	station.start_order(recipe)
	show_cafe()
	strip.hide()
	speaker.text = ""
	tip.text = ""
	await bar.customer_enter(look_of(current_order().customer)).finished
	bar.emote(bar.customer, "!")
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
		tip.text = station.next_hint()


func show_step(new_step: Step) -> void:
	step = new_step
	for c in controls.get_children():
		c.queue_free()
	hint_button.hide()
	strip.visible = step in [Step.RESULT, Step.SUMMARY]
	next_button.visible = step == Step.DIALOGUE

	match step:
		Step.DIALOGUE:
			show_cafe()
			var line: Array = lines[line_index]
			title.text = ""
			readout.text = ""
			speaker.text = shift.cast[line[0]]
			tip.text = line[1]
			bar.hop(person_of(line[0]))

		Step.BAR:
			show_station()
			speaker.text = ""
			tip.text = ""
			refresh_hint()

		Step.SUMMARY:
			show_cafe()
			var s := ShiftRewards.summary(scores, shift.wage_rm)
			bar.hide_served_cup()
			bar.emote(bar.mentor, "*", 3.0)
			bar.hop(bar.mentor)
			title.text = "SHIFT COMPLETE!"
			readout.text = "Average %d" % s.average
			progress.text = ""
			speaker.text = shift.cast.MENTOR
			tip.text = "Orders served: %d    Wage: RM%d    Tips: RM%d    XP: +%d\nJunior Barista progress unlocked. Good work today!" % [
				s.orders, s.wage_rm, s.tips_rm, s.xp]
			add_button("Play again").pressed.connect(func():
				scores.clear()
				start_order(0))


## The cup reached the serve tray: swoop out and score it at the front counter.
func on_served(shot: Dictionary) -> void:
	show_step(Step.RESULT)
	show_cafe()
	bar.show_served_cup()
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
		bar.emote(bar.customer, "?")
		add_button("Make it again").pressed.connect(func():
			say([[who, "Hmm, this isn't right. Could you make it again?"]], func():
				bar.hide_served_cup()
				station.clear_cup()
				show_step(Step.BAR)))
		return
	add_button("Continue").pressed.connect(func():
		scores.append(score)
		bar.emote(bar.customer, "<3" if grade in ["Perfect Brew", "Great Cup"] else ":)")
		say([[who, shift.reactions[grade]]], func():
			bar.hide_served_cup()
			strip.hide()
			await bar.customer_leave().finished
			next_order()))


func next_order() -> void:
	if order_index + 1 < shift.orders.size():
		start_order(order_index + 1)
	else:
		show_step(Step.SUMMARY)


# ---------- building ----------

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
		tip.text = station.next_hint())
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

	# Result / summary strip, on a dark panel
	strip = PanelContainer.new()
	strip.add_theme_stylebox_override("panel", panel_style(Color(ESPRESSO, 0.85), Color(ESPRESSO, 0)))
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
	talk_box = box
	var box_style := panel_style(Color(ESPRESSO, 0.92), CARAMEL)
	box_style.content_margin_right = 170  # room for the Next button
	box_style.content_margin_top = 8
	box_style.content_margin_bottom = 8
	box.add_theme_stylebox_override("panel", box_style)
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

	next_button = Button.new()
	next_button.text = "Next  >"
	next_button.position = Vector2(1100, 630)
	next_button.custom_minimum_size = Vector2(140, 56)
	next_button.hide()
	next_button.pressed.connect(func():
		line_index += 1
		if line_index < lines.size():
			show_step(Step.DIALOGUE)
		else:
			after_dialogue.call())
	add_child(next_button)


func show_cafe() -> void:
	station.hide()
	bar.show()
	bar.set_view("iso", false)
	talk_box.position = Vector2(24, 596)  # dialogue at the bottom
	talk_box.custom_minimum_size = Vector2(1232, 116)
	(talk_box.get_theme_stylebox("panel") as StyleBoxFlat).content_margin_right = 170  # Next button
	talk_box.reset_size()
	speaker.show()
	tip.add_theme_font_size_override("font_size", 22)


func show_station() -> void:
	bar.hide()
	station.show()
	# One-line tip bar along the bottom edge, out of the way of the equipment.
	speaker.hide()
	tip.add_theme_font_size_override("font_size", 16)
	(talk_box.get_theme_stylebox("panel") as StyleBoxFlat).content_margin_right = 14
	talk_box.position = Vector2(0, 686)
	talk_box.custom_minimum_size = Vector2(1280, 0)
	talk_box.reset_size()
