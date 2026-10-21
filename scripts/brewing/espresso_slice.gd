extends Control
## Espresso vertical slice: dose -> grind -> extract -> evaluate.
## Placeholder visuals; UI is built in code until pixel art arrives.

const RECIPE_PATH := "res://data/recipes/double_espresso_training.json"
## Tuning knobs: editable in the Inspector when EspressoSlice is selected.
@export var DISPENSE_G_PER_S := 4.0  # grams of coffee per second while holding "Hold to grind"
@export var SIM_SPEED := 2.0  # simulated seconds per real second (playtest: 3x felt too fast)
const MAX_YIELD_G := 70.0
const START_GRIND := 8  # left coarse by the previous barista, so the player has to adjust

enum Step { DOSE, GRIND, EXTRACT, RESULT }

var recipe: Dictionary
var dose_g := 0.0
var grind := START_GRIND
var yield_g := 0.0
var sim_time := 0.0
var flow := 0.0
var dispensing := false
var extracting := false

var title: Label
var readout: Label
var tip: Label
var controls: HBoxContainer


func _ready() -> void:
	recipe = EspressoModel.load_recipe(RECIPE_PATH)
	theme = Theme.new()
	theme.default_font_size = 30

	var bg := ColorRect.new()
	bg.color = Color("#36251D")
	bg.set_anchors_preset(PRESET_FULL_RECT)
	add_child(bg)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 48)
	add_child(margin)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 32)
	margin.add_child(col)

	var order := Label.new()
	order.text = "ORDER: %s  ·  %d g in  ·  %d g out" % [recipe.display_name, recipe.dose_g, recipe.target_yield_g]
	order.add_theme_color_override("font_color", Color("#BE895B"))
	col.add_child(order)

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

	tip = Label.new()
	tip.autowrap_mode = TextServer.AUTOWRAP_WORD
	tip.add_theme_color_override("font_color", Color("#8F9C7B"))
	col.add_child(tip)

	show_step(Step.DOSE)


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


func show_step(step: Step) -> void:
	for c in controls.get_children():
		c.queue_free()

	match step:
		Step.DOSE:
			title.text = "Step 1 · Dose the coffee (target %d g)" % recipe.dose_g
			readout.text = "%.1f g" % dose_g
			tip.text = "MENTOR: Hold the grinder button and let go when the scale is near %d g." % recipe.dose_g
			var hold := add_button("Hold to grind")
			hold.button_down.connect(func(): dispensing = true)
			hold.button_up.connect(func(): dispensing = false)
			add_button("Empty").pressed.connect(func():
				dose_g = 0.0
				readout.text = "0.0 g")
			add_button("Next").pressed.connect(func(): show_step(Step.GRIND))

		Step.GRIND:
			title.text = "Step 2 · Set the grind size (1 = fine, 10 = coarse)"
			readout.text = "Setting %d" % grind
			tip.text = "MENTOR: Finer grind slows the shot down. Coarser grind speeds it up."
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

		Step.EXTRACT:
			title.text = "Step 3 · Pull the shot (target %d g in %d–%d s)" % [
				recipe.target_yield_g, recipe.extraction_time_min_s, recipe.extraction_time_max_s]
			yield_g = 0.0
			sim_time = 0.0
			readout.text = "0.0 g   ·   0.0 s (simulated)"
			tip.text = "MENTOR: Watch the scale. Stop when the cup reaches about %d g." % recipe.target_yield_g
			var btn := add_button("Start")
			btn.pressed.connect(func():
				if extracting:
					stop_extraction()
				else:
					flow = EspressoModel.flow_rate(recipe, dose_g, grind)
					extracting = true
					btn.text = "Stop")

		Step.RESULT:
			var r := EspressoModel.evaluate(recipe, dose_g, grind, yield_g)
			# Accuracy and service are fixed until orders and timers exist.
			var score := EspressoModel.order_score(r.quality, 100, 100)
			title.text = "Result: %.1f g in · %.1f g out · %.1f s" % [dose_g, yield_g, sim_time]
			readout.text = "%d  ·  %s" % [score, EspressoModel.grade(score)]
			tip.text = "MENTOR: " + r.tip
			add_button("Try again").pressed.connect(func():
				dose_g = 0.0
				show_step(Step.DOSE))


func stop_extraction() -> void:
	extracting = false
	show_step(Step.RESULT)


func add_button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(220, 90)
	controls.add_child(b)
	return b
