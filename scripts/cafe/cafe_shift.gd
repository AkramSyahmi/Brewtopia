extends Control
## A day at the café (Good Coffee, Great Coffee style), four scripted orders.
## Per order: the customer arrives at the front counter and orders (speech bubble, with
## answer choices) -> the player makes the drink at the bar (EspressoStation: espresso,
## milk, toppings) -> serving returns to the counter for the score, the mentor's tip and
## the customer's reaction. Money, XP, day and upgrades are saved (SaveGame).

const SHIFT_PATH := "res://data/orders/ch1_first_shift.json"
const RECIPE_PATH := "res://data/recipes/%s.json"
const START_GRIND := 8  # left coarse by the previous barista, so the player has to adjust
const OPEN_MINUTES := 8 * 60  # the café opens at 8:00 AM
const MINUTES_PER_ORDER := 20

const ESPRESSO := Color("#36251D")
const CARAMEL := Color("#BE895B")
const CREAM := Color("#F5E7CA")
const SAGE := Color("#8F9C7B")
const PAPER := Color("#FBF4EA")

## Tuning knobs: editable in the Inspector when CafeShift is selected.
@export var DISPENSE_G_PER_S := 4.0  # grams of coffee per second while holding the grinder
@export var SIM_SPEED := 2.0  # simulated seconds per real second (playtest: 3x felt too fast)

enum Step { DIALOGUE, BAR, RESULT, SUMMARY }

var shift: Dictionary
var save: Dictionary
var order_index := 0
var recipe: Dictionary  # current order's recipe with its overrides applied
var scores: Array[int] = []
var step := Step.DIALOGUE

var lines: Array = []
var line_index := 0
var after_dialogue: Callable

var bar: CounterScreen  # front counter with the customer and mentor
var station: EspressoStation  # where drinks are made
var book: RecipeBook
var shop: UpgradeShop

# UI
var level_label: Label
var xp_bar: ProgressBar
var clock_label: Label
var mood_label: Label
var money_label: Label
var hint_button: Button
var progress: Label
var next_button: Button
var choice_box: HBoxContainer
var slip: Label
var strip: Control
var title: Label
var readout: Label
var controls: HBoxContainer
var speaker: Label
var tip: Label
var talk_box: PanelContainer
var bubble_style: StyleBoxFlat
var bar_style: StyleBoxFlat


func _ready() -> void:
	shift = EspressoModel.load_recipe(SHIFT_PATH)  # same JSON loader
	save = SaveGame.load_save()
	mouse_filter = MOUSE_FILTER_IGNORE  # let clicks reach the bar's drag and drop
	bar = CounterScreen.new()
	add_child(bar)
	station = EspressoStation.new()
	station.dispense_g_per_s = DISPENSE_G_PER_S
	station.sim_speed = SIM_SPEED
	add_child(station)
	station.hide()
	station.set_grind(START_GRIND)
	apply_upgrades()
	station.changed.connect(refresh_hint)
	station.message.connect(func(text):
		speaker.text = ""
		tip.text = text)
	station.served.connect(on_served)
	build_ui()
	start_order(0)


func apply_upgrades() -> void:
	station.green_zone_g = 2.0 + save.upgrades.shot_timer
	station.steam_rate = 12.0 - 2.0 * save.upgrades.steam_control


func current_order() -> Dictionary:
	return shift.orders[order_index]


func look_of(role: String) -> String:
	return shift.sprites[role]


func person_of(role: String) -> Node:
	return bar.mentor if role == "MENTOR" else null if role in ["PLAYER", "CHOICE"] else bar.customer


func start_order(i: int) -> void:
	order_index = i
	recipe = EspressoModel.load_recipe(RECIPE_PATH % current_order().recipe)
	recipe.merge(current_order().get("recipe_overrides", {}), true)
	progress.text = "ORDER %d / %d" % [i + 1, shift.orders.size()]
	slip.text = order_slip()
	bar.hide_served_cup()
	bar.set_happy(false)
	station.start_order(recipe)
	show_cafe()
	strip.hide()
	speaker.text = ""
	tip.text = ""
	talk_box.hide()
	refresh_hud()
	await bar.customer_enter(look_of(current_order().customer)).finished
	bar.emote(bar.customer, "!")
	say(current_order().intro, func(): show_step(Step.BAR))


func order_slip() -> String:
	var t := "%s\n%s" % [shift.cast[current_order().customer].to_upper(), recipe.display_name]
	if not recipe.has("milk"):
		t += "\n%d g in · %d g out" % [recipe.dose_g, recipe.target_yield_g]
	for s in recipe.get("syrups", {}):
		t += "\n+ %d %s" % [recipe.syrups[s], s.replace("_", " ")]
	for top in recipe.get("toppings", []):
		t += "\n+ " + top.replace("_", " ")
	return t


## Plays dialogue lines ([role, text] pairs) one tap at a time, then calls `then`.
## A ["CHOICE", [options...]] line shows answer buttons; the pick is said by the player.
func say(new_lines: Array, then: Callable) -> void:
	lines = new_lines
	line_index = 0
	after_dialogue = then
	show_step(Step.DIALOGUE)


func advance() -> void:
	line_index += 1
	if line_index < lines.size():
		show_step(Step.DIALOGUE)
	else:
		after_dialogue.call()


## Mentor guidance at the bar depends on the order's assist level:
## full = always shows the next suggested action, hints = on request, none = nothing.
func refresh_hint() -> void:
	if step != Step.BAR:
		return
	hint_button.visible = current_order().assist == "hints"
	if current_order().assist == "full":
		tip.text = station.next_hint()


func show_step(new_step: Step) -> void:
	step = new_step
	for c in controls.get_children():
		c.queue_free()
	for c in choice_box.get_children():
		c.queue_free()
	hint_button.hide()
	strip.visible = step in [Step.RESULT, Step.SUMMARY]
	next_button.visible = step == Step.DIALOGUE
	talk_box.show()

	match step:
		Step.DIALOGUE:
			show_cafe()
			var line: Array = lines[line_index]
			title.text = ""
			readout.text = ""
			if line[0] == "CHOICE":
				next_button.hide()
				speaker.text = shift.cast.PLAYER
				tip.text = "..."
				for option in line[1]:
					var b := Button.new()
					b.text = option
					b.custom_minimum_size = Vector2(0, 56)
					b.pressed.connect(func():
						lines[line_index] = ["PLAYER", option]
						show_step(Step.DIALOGUE))
					choice_box.add_child(b)
			else:
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
			talk_box.hide()
			var s := ShiftRewards.summary(scores, shift.wage_rm)
			var tips_rm := roundi(s.tips_rm * (1.0 + 0.25 * save.upgrades.tip_jar))
			var earned: int = s.wage_rm + tips_rm
			save.money += earned
			save.xp += s.xp
			SaveGame.write(save)
			refresh_hud()
			bar.hide_served_cup()
			bar.set_mentor_happy(true)
			bar.emote(bar.mentor, "*", 3.0)
			bar.hop(bar.mentor)
			title.text = "DAY %d COMPLETE!   Orders %d · Wage RM%d · Tips RM%d · XP +%d" % [
				save.day, s.orders, s.wage_rm, tips_rm, s.xp]
			readout.text = "Average %d" % s.average
			progress.text = ""
			add_button("Upgrades").pressed.connect(func(): shop.open(save))
			add_button("Next day").pressed.connect(func():
				save.day += 1
				SaveGame.write(save)
				scores.clear()
				bar.set_mentor_happy(false)
				start_order(0))


## The drink reached the serve area: back to the counter to score it.
func on_served(drink: Dictionary) -> void:
	show_step(Step.RESULT)
	show_cafe()
	talk_box.show()
	bar.show_served_cup(drink.cup)
	var r := DrinkModel.evaluate(recipe, drink)
	var details := "%.1f g in · %.1f g out · %.1f s · grind %d%s" % [
		drink.dose, drink.yield, drink.time, drink.grind, "" if drink.tamped else " · not tamped"]
	if drink.milk_temp >= 0.0:
		details += " · milk %d°C" % roundi(drink.milk_temp)
	title.text = "RESULT  ·  quality %d · accuracy %d  ·  %s" % [r.quality, r.accuracy, details]
	readout.text = "%d  %s" % [r.score, r.grade]
	# Diagnosis always shows, whatever the assist level: it is the core lesson.
	speaker.text = shift.cast.MENTOR
	tip.text = r.tip
	var who: String = current_order().customer
	if r.grade == "Failed Order":
		bar.emote(bar.customer, "?")
		add_button("Make it again").pressed.connect(func():
			say([[who, "Hmm, this isn't right. Could you make it again?"]], func():
				bar.hide_served_cup()
				station.clear_cup()
				station.go_page(0, false)
				show_step(Step.BAR)))
		return
	add_button("Continue").pressed.connect(func():
		scores.append(r.score)
		refresh_hud()
		var great: bool = r.grade in ["Perfect Brew", "Great Cup"]
		bar.set_happy(great)
		bar.emote(bar.customer, "<3" if great else ":)")
		say([[who, shift.reactions[r.grade]]], func():
			bar.hide_served_cup()
			strip.hide()
			talk_box.hide()
			await bar.customer_leave().finished
			next_order()))


func next_order() -> void:
	if order_index + 1 < shift.orders.size():
		start_order(order_index + 1)
	else:
		show_step(Step.SUMMARY)


func refresh_hud() -> void:
	level_label.text = "Lv %d" % SaveGame.level(save)
	xp_bar.value = SaveGame.xp_progress(save) * 100.0
	var minutes := OPEN_MINUTES + order_index * MINUTES_PER_ORDER
	var h := int(minutes / 60.0)
	clock_label.text = "Day %d  ·  %d:%02d %s" % [save.day, (h - 1) % 12 + 1, minutes % 60, "AM" if h < 12 else "PM"]
	if scores.is_empty():
		mood_label.text = ":)  --%"
	else:
		var avg := 0.0
		for s in scores:
			avg += s
		mood_label.text = ":)  %d%%" % roundi(avg / scores.size())
	money_label.text = "RM %d" % save.money


# ---------- building ----------

func panel_style(bg: Color, border: Color, radius := 0) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(3)
	s.set_corner_radius_all(radius)
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
	b.custom_minimum_size = Vector2(200, 64)
	controls.add_child(b)
	return b


## A rounded HUD pill (GCGC style) holding the given control.
func pill(parent: Node, inner: Control) -> void:
	var p := PanelContainer.new()
	var s := panel_style(Color("#5A4436"), Color("#3A2A20"), 16)
	s.content_margin_top = 2
	s.content_margin_bottom = 2
	p.add_theme_stylebox_override("panel", s)
	p.add_child(inner)
	parent.add_child(p)


func build_ui() -> void:
	theme = Theme.new()
	theme.default_font_size = 22

	# GCGC-style HUD: level + XP, day + clock, satisfaction, money, recipes, hint, order.
	var hud := HBoxContainer.new()
	hud.position = Vector2(10, 6)
	hud.size = Vector2(1260, 40)
	hud.add_theme_constant_override("separation", 10)
	add_child(hud)
	var lv := HBoxContainer.new()
	lv.add_theme_constant_override("separation", 8)
	level_label = label(lv, 20, CREAM)
	xp_bar = ProgressBar.new()
	xp_bar.custom_minimum_size = Vector2(110, 14)
	xp_bar.show_percentage = false
	xp_bar.size_flags_vertical = SIZE_SHRINK_CENTER
	lv.add_child(xp_bar)
	pill(hud, lv)
	clock_label = Label.new()
	clock_label.add_theme_font_size_override("font_size", 20)
	clock_label.add_theme_color_override("font_color", CREAM)
	pill(hud, clock_label)
	mood_label = Label.new()
	mood_label.add_theme_font_size_override("font_size", 20)
	mood_label.add_theme_color_override("font_color", Color("#FFE066"))
	pill(hud, mood_label)
	money_label = Label.new()
	money_label.add_theme_font_size_override("font_size", 20)
	money_label.add_theme_color_override("font_color", Color("#9FE08A"))
	pill(hud, money_label)
	var spacer := Control.new()
	spacer.size_flags_horizontal = SIZE_EXPAND_FILL
	hud.add_child(spacer)
	var recipes := Button.new()
	recipes.text = "Recipes"
	recipes.add_theme_font_size_override("font_size", 18)
	recipes.pressed.connect(func(): book.show())
	hud.add_child(recipes)
	hint_button = Button.new()
	hint_button.text = "Hint"
	hint_button.add_theme_font_size_override("font_size", 18)
	hint_button.hide()
	hint_button.pressed.connect(func(): tip.text = station.next_hint())
	hud.add_child(hint_button)
	progress = Label.new()
	progress.add_theme_font_size_override("font_size", 18)
	progress.add_theme_color_override("font_color", CREAM)
	pill(hud, progress)

	# Paper order slip, pinned at the top right
	var paper := PanelContainer.new()
	paper.add_theme_stylebox_override("panel", panel_style(CREAM, CARAMEL))
	paper.position = Vector2(1070, 58)
	paper.custom_minimum_size = Vector2(190, 0)
	paper.rotation_degrees = 2
	paper.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(paper)
	slip = label(paper, 17, ESPRESSO)

	# Result / summary strip, over the counter
	strip = PanelContainer.new()
	strip.add_theme_stylebox_override("panel", panel_style(Color(ESPRESSO, 0.9), CARAMEL, 14))
	strip.position = Vector2(24, 560)
	strip.custom_minimum_size = Vector2(1232, 140)
	add_child(strip)
	var step_box := VBoxContainer.new()
	step_box.add_theme_constant_override("separation", 4)
	strip.add_child(step_box)
	title = label(step_box, 17, CARAMEL)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 24)
	step_box.add_child(row)
	readout = label(row, 38, CREAM)
	readout.custom_minimum_size = Vector2(440, 0)
	controls = HBoxContainer.new()
	controls.add_theme_constant_override("separation", 16)
	row.add_child(controls)

	# Speech bubble (counter) / one-line tip bar (station)
	bubble_style = panel_style(PAPER, Color("#65422F"), 22)
	bubble_style.content_margin_right = 170
	bar_style = panel_style(Color(ESPRESSO, 0.92), CARAMEL)
	bar_style.content_margin_top = 6
	bar_style.content_margin_bottom = 6
	talk_box = PanelContainer.new()
	talk_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(talk_box)
	var talk := VBoxContainer.new()
	talk.add_theme_constant_override("separation", 2)
	talk_box.add_child(talk)
	speaker = label(talk, 20, CARAMEL)
	tip = label(talk, 22, ESPRESSO)
	tip.autowrap_mode = TextServer.AUTOWRAP_WORD

	next_button = Button.new()
	next_button.text = "Next  >"
	next_button.custom_minimum_size = Vector2(140, 52)
	next_button.hide()
	next_button.pressed.connect(advance)
	add_child(next_button)
	choice_box = HBoxContainer.new()
	choice_box.position = Vector2(300, 196)
	choice_box.add_theme_constant_override("separation", 16)
	add_child(choice_box)

	book = RecipeBook.new()
	add_child(book)
	shop = UpgradeShop.new()
	add_child(shop)
	shop.bought.connect(func():
		apply_upgrades()
		refresh_hud())


func show_cafe() -> void:
	station.hide()
	bar.show()
	# Speech bubble near the top, above the people's heads (GCGC style).
	talk_box.add_theme_stylebox_override("panel", bubble_style)
	talk_box.position = Vector2(240, 60)
	talk_box.custom_minimum_size = Vector2(800, 120)
	talk_box.reset_size()
	next_button.position = Vector2(880, 114)
	speaker.show()
	tip.add_theme_font_size_override("font_size", 22)
	tip.add_theme_color_override("font_color", ESPRESSO)


func show_station() -> void:
	bar.hide()
	station.show()
	# One-line tip bar along the bottom edge, out of the way of the equipment.
	talk_box.add_theme_stylebox_override("panel", bar_style)
	speaker.hide()
	tip.add_theme_font_size_override("font_size", 16)
	tip.add_theme_color_override("font_color", CREAM)
	talk_box.position = Vector2(0, 688)
	talk_box.custom_minimum_size = Vector2(1280, 0)
	talk_box.reset_size()
