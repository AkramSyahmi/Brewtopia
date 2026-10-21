extends Control
## Chapter 1 first shift: three scripted orders (GDD 12.2).
## Per order: dialogue -> dose -> grind -> extract -> result -> customer reaction.
## Placeholder visuals; UI is built in code until pixel art arrives.

const SHIFT_PATH := "res://data/orders/ch1_first_shift.json"
const RECIPE_PATH := "res://data/recipes/%s.json"
const MAX_YIELD_G := 70.0
const START_GRIND := 8  # left coarse by the previous barista, so the player has to adjust

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

var header: Label
var order_label: Label
var title: Label
var readout: Label
var controls: HBoxContainer
var speaker: Label
var tip: Label


func _ready() -> void:
	shift = EspressoModel.load_recipe(SHIFT_PATH)  # same JSON loader
	build_ui()
	start_order(0)


func _process(delta: float) -> void:
	if dispensing:
		dose_g += DISPENSE_G_PER_S * delta
		readout.text = "%.1f g" % dose_g
	if extracting:
		sim_time += delta * SIM_SPEED
		yield_g = flow * sim_time
		readout.text = "%.1f g   ·   %.1f s (simulated)" % [yield_g, sim_time]
		if yield_g >= MAX_YIELD_G:
			stop_extraction()


func current_order() -> Dictionary:
	return shift.orders[order_index]


func start_order(i: int) -> void:
	order_index = i
	recipe = EspressoModel.load_recipe(RECIPE_PATH % current_order().recipe)
	recipe.merge(current_order().get("recipe_overrides", {}), true)
	dose_g = 0.0
	order_label.text = "ORDER %d / %d  ·  %s  ·  %s  ·  %d g in · %d g out" % [
		i + 1, shift.orders.size(), shift.cast[current_order().customer],
		recipe.display_name, recipe.dose_g, recipe.target_yield_g]
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
			title.text = ""
			readout.text = ""
			speaker.text = shift.cast[line[0]]
			tip.text = line[1]
			add_button("Next").pressed.connect(func():
				line_index += 1
				if line_index < lines.size():
					show_step(Step.DIALOGUE)
				else:
					after_dialogue.call())

		Step.DOSE:
			title.text = "Dose the coffee (target %d g)" % recipe.dose_g
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
			title.text = "Set the grind size (1 = fine, 10 = coarse)"
			readout.text = "Setting %d" % grind
			var slider := HSlider.new()
			slider.min_value = 1
			slider.max_value = 10
			slider.step = 1
			slider.value = grind
			slider.custom_minimum_size = Vector2(600, 60)
			slider.value_changed.connect(func(v):
				grind = int(v)
				readout.text = "Setting %d" % grind)
			controls.add_child(slider)
			add_button("Next").pressed.connect(func(): show_step(Step.EXTRACT))
			mentor("Finer grind slows the shot down. Coarser grind speeds it up.")

		Step.EXTRACT:
			title.text = "Pull the shot (target %d g in %d–%d s)" % [
				recipe.target_yield_g, recipe.extraction_time_min_s, recipe.extraction_time_max_s]
			yield_g = 0.0
			sim_time = 0.0
			readout.text = "0.0 g   ·   0.0 s (simulated)"
			var btn := add_button("Start")
			btn.pressed.connect(func():
				if extracting:
					stop_extraction()
				else:
					flow = EspressoModel.flow_rate(recipe, dose_g, grind)
					extracting = true
					btn.text = "Stop")
			mentor("Watch the scale. Stop when the cup reaches about %d g." % recipe.target_yield_g)

		Step.RESULT:
			var r := EspressoModel.evaluate(recipe, dose_g, grind, yield_g)
			# Accuracy and service are fixed until order variety and timers exist.
			var score := EspressoModel.order_score(r.quality, 100, 100)
			var grade := EspressoModel.grade(score)
			title.text = "Result: %.1f g in · %.1f g out · %.1f s" % [dose_g, yield_g, sim_time]
			readout.text = "%d  ·  %s" % [score, grade]
			# Diagnosis always shows, whatever the assist level: it is the core lesson.
			speaker.text = shift.cast.MENTOR
			tip.text = r.tip
			if grade == "Failed Order":
				add_button("Remake").pressed.connect(remake)
			else:
				add_button("Serve").pressed.connect(func():
					scores.append(score)
					var who: String = current_order().customer
					say([[who, shift.reactions[grade]]], next_order))
				add_button("Remake").pressed.connect(remake)

		Step.SUMMARY:
			var s := ShiftRewards.summary(scores, shift.wage_rm)
			title.text = "Shift complete!"
			readout.text = "Average score %d" % s.average
			speaker.text = ""
			tip.text = "Orders served: %d    Wage: RM%d    Tips: RM%d    XP: +%d\nJunior Barista progress unlocked." % [
				s.orders, s.wage_rm, s.tips_rm, s.xp]
			order_label.text = shift.title
			add_button("Play again").pressed.connect(func():
				scores.clear()
				grind = START_GRIND
				start_order(0))


func remake() -> void:
	dose_g = 0.0
	show_step(Step.DOSE)


func next_order() -> void:
	if order_index + 1 < shift.orders.size():
		start_order(order_index + 1)
	else:
		show_step(Step.SUMMARY)


func stop_extraction() -> void:
	extracting = false
	show_step(Step.RESULT)


func add_button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(220, 90)
	controls.add_child(b)
	return b


func build_ui() -> void:
	theme = Theme.new()
	theme.default_font_size = 30

	var bg := ColorRect.new()
	bg.color = Color("#36251D")
	bg.set_anchors_preset(PRESET_FULL_RECT)
	add_child(bg)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 40)
	add_child(margin)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 24)
	margin.add_child(col)

	header = Label.new()
	header.text = shift.title
	header.add_theme_font_size_override("font_size", 22)
	header.add_theme_color_override("font_color", Color("#8F9C7B"))
	col.add_child(header)

	order_label = Label.new()
	order_label.add_theme_color_override("font_color", Color("#BE895B"))
	col.add_child(order_label)

	title = Label.new()
	col.add_child(title)

	readout = Label.new()
	readout.add_theme_font_size_override("font_size", 64)
	readout.add_theme_color_override("font_color", Color("#F5E7CA"))
	col.add_child(readout)

	controls = HBoxContainer.new()
	controls.add_theme_constant_override("separation", 24)
	col.add_child(controls)

	var spacer := Control.new()
	spacer.size_flags_vertical = SIZE_EXPAND_FILL
	col.add_child(spacer)

	speaker = Label.new()
	speaker.add_theme_color_override("font_color", Color("#BE895B"))
	col.add_child(speaker)

	tip = Label.new()
	tip.autowrap_mode = TextServer.AUTOWRAP_WORD
	tip.add_theme_color_override("font_color", Color("#F5E7CA"))
	col.add_child(tip)
