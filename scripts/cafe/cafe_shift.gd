extends Control
## A day at the café (Good Coffee, Great Coffee style), four scripted orders.
## Per order: the customer arrives at the front counter and orders (speech bubble, with
## answer choices) -> the player makes the drink at the bar (EspressoStation: espresso,
## milk, toppings) -> serving returns to the counter for the score, the mentor's tip and
## the customer's reaction. Money, XP, day and upgrades are saved (SaveGame).

const SHIFT_PATH := "res://data/orders/ch1_first_shift.json"  # day 1 tutorial
const DAILY_PATH := "res://data/orders/daily.json"  # rules for day 2 onwards (DayPlan)
const STORIES_PATH := "res://data/orders/stories.json"  # regulars' friendship stories
const RECIPE_PATH := "res://data/recipes/%s.json"
const START_GRIND := 8  # left coarse by the previous barista, so the player has to adjust
const OPEN_MINUTES := 8 * 60  # the café opens at 8:00 AM
const MINUTES_PER_ORDER := 20
const FEEDBACK_S := 4.0  # bottom-bar feedback fades after this many seconds at the bar

const ESPRESSO := Color("#36251D")
const CARAMEL := Color("#E8BE88")  # result headline / details: light enough on the brown sign
const CREAM := Color("#F5E7CA")
const SAGE := Color("#8F9C7B")
const PAPER := Color("#FBF4EA")
const GOLD := Color("#F2C14E")  # speaker names
const HUD_ART := "res://assets/ui/hud/%s.png"  # made by tools/make_menu_art.gd
const MENU_ART := "res://assets/ui/main_menu/%s.png"
const TICKET_W := 256.0
const OBJECTIVE_W := 420.0  # CURRENT OBJECTIVE panel, top left under the HUD
const TALK_SIZE := Vector2(560, 128)  # speech bubble: width, and its height with a short line
const TALK_TEXT_W := 314.0  # the line's column (cup on the left, Next on the right)
const TALK_TEXT_PX := 20
const TALK_PAGE_LINES := 3  # a longer line is shown in pages (Next turns the page)

## Tuning knobs: editable in the Inspector when CafeShift is selected.
@export var DISPENSE_G_PER_S := 4.0  # grams of coffee per second while holding the grinder
@export var SIM_SPEED := 2.0  # simulated seconds per real second (playtest: 3x felt too fast)

enum Step { DIALOGUE, BAR, RESULT, SUMMARY }

var shift: Dictionary
var save: Dictionary
var stories: Dictionary
var order_index := 0
var recipe: Dictionary  # current order's recipe with its overrides applied
var scores: Array[int] = []
var services: Array[float] = []  # patience left when each drink was served (0..1)
var results: Array = []  # DrinkModel results for the drinks served so far this order
var patience := 1.0
var waiting := false  # the customer is waiting for their drink (patience drains)

## Seconds a customer waits before their patience runs out.
const PATIENCE_S := 150.0
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
var hud_buttons: Array[Button] = []  # Recipes, Hint, Menu: icon only when the HUD row is short of room
var progress: Label
var next_button: Button
var choice_box: VBoxContainer
var ticket: PanelContainer  # the order slip (top right)
var order_note_open := true  # the player can close the slip (red X) and reopen it (ORDER badge)
var slip_name: Label
var slip_friend: Label
var slip_order: Label
var slip_hint: Label
var clock_icon: TextureRect  # sun by day, moon from 6 PM
var bold: FontVariation
var talk_art: TextureRect  # the cup picture in the speech bubble
var talk_pointer: TextureRect
var in_cafe := false  # the talk box is the speech bubble (not the station tip bar)
var pages: PackedStringArray = []  # the rest of the current line, one bubble-full each
var strip: Control
var title: Label
var readout: Label
var result_grid: GridContainer  # per-category ratings on the result strip
var result_main: Label
var result_grade: Label  # "Good", "Excellent"... under the big score
var result_details: Label
var controls: HBoxContainer
var speaker: Label
var tip: Label
var talk_box: PanelContainer
var objective_panel: PanelContainer  # CURRENT OBJECTIVE (top-left at the bar)
var objective_title: Label
var objective_text: Label
var objective_hint: Label
var objective_feedback: Label  # what just happened ("Tamped!"), fades; replaces the old bottom tip bar
var objective_toggle: TextureButton  # collapse / expand the instruction
var objective_collapsed := false
var feedback_on := false
var feedback_id := 0  # latest feedback message (older fade timers leave it alone)
var modal_dim: ColorRect  # dark backdrop behind the recipe book / shop / menu; blocks the game
var settings: PanelContainer  # the Menu window (music volume, mute, sound, main menu); pauses the game
var bubble_style: StyleBoxTexture



func _ready() -> void:
	save = SaveGame.load_save()
	stories = EspressoModel.load_recipe(STORIES_PATH)
	shift = shift_for_day(save.day)
	mouse_filter = MOUSE_FILTER_IGNORE  # let clicks reach the bar's drag and drop
	bar = CounterScreen.new()
	add_child(bar)
	bar.set_decor(save.decor)
	station = EspressoStation.new()
	station.dispense_g_per_s = DISPENSE_G_PER_S
	station.sim_speed = SIM_SPEED
	add_child(station)
	station.hide()
	station.set_grind(START_GRIND)
	apply_upgrades()
	station.changed.connect(refresh_hint)
	station.message.connect(show_feedback)
	station.served.connect(on_served)
	build_ui()
	bar.avoid_rects = func() -> Array:  # the order bubble keeps off the visible UI panels
		var rects := []
		for c: Control in [ticket, talk_box]:
			if c.is_visible_in_tree():
				rects.append(c.get_global_rect().grow(6))
		if talk_pointer.visible:
			rects.append(talk_pointer.get_global_rect())
		return rects
	Sfx.music("cafe")
	start_order(0)


func apply_upgrades() -> void:
	station.green_zone_g = 2.0 + save.upgrades.shot_timer
	station.steam_rate = 12.0 - 2.0 * save.upgrades.steam_control


## Day 1 is the scripted tutorial; later days are generated by DayPlan.
func shift_for_day(day: int) -> Dictionary:
	var tutorial := EspressoModel.load_recipe(SHIFT_PATH)  # same JSON loader
	if day <= 1:
		return tutorial
	return DayPlan.build(day, tutorial, EspressoModel.load_recipe(DAILY_PATH), SaveGame.level(save),
		save.recipes_seen)


func current_order() -> Dictionary:
	return shift.orders[order_index]


func is_vague() -> bool:
	return current_order().get("vague", false)


func drinks_needed() -> int:
	return int(current_order().get("count", 1))


func look_of(role: String) -> String:
	return shift.sprites[role]


func person_of(role: String) -> Node:
	return bar.mentor if role == "MENTOR" else null if role in ["PLAYER", "CHOICE"] else bar.customer


func start_order(i: int) -> void:
	order_index = i
	recipe = EspressoModel.load_recipe(RECIPE_PATH % current_order().recipe)
	recipe.merge(current_order().get("recipe_overrides", {}), true)
	results.clear()
	progress.text = "ORDER %d/%d" % [i + 1, shift.orders.size()]
	progress.get_parent().show()
	set_order_note(true)  # a new customer: fresh slip, shown
	set_slip(order_slip())
	bar.hide_served_cup()
	bar.set_happy(false)
	bar.hide_order()
	station.start_order(recipe)
	show_cafe()
	strip.hide()
	speaker.text = ""
	tip.text = ""
	talk_box.hide()
	refresh_hud()
	# Remember what the player has been taught (DayPlan introduces new things once).
	for seen in [current_order().recipe, "_vague" if is_vague() else ""]:
		if seen != "" and not seen in save.recipes_seen:
			save.recipes_seen.append(seen)
	var who: String = current_order().customer
	var intro: Array = Friends.take_beat(save, who, stories) + current_order().intro  # story first
	SaveGame.write(save)
	Sfx.play("bell", 0.0)
	await bar.customer_enter(look_of(who)).finished
	bar.emote(bar.customer, "!")
	say(intro.duplicate(true), func():
		bar.show_order(recipe, drinks_needed(), is_vague())
		patience = 1.0
		waiting = true
		show_step(Step.BAR))
	var nxt := order_index + 1
	bar.show_queue(look_of(shift.orders[nxt].customer) if nxt < shift.orders.size() else "")


func order_slip() -> String:
	var who: String = current_order().customer
	var t: String = shift.cast[who].to_upper()
	if stories.beats.has(who):
		t += "\nFriend %d/%d" % [Friends.hearts(save, who, stories), stories.hearts_at.size()]
	if is_vague():  # the player has to work out the drink from what they said
		return t + "\n???\n(listen to the order,\ncheck the Recipe Book)"
	t += "\n%s%s" % ["2 x " if drinks_needed() > 1 else "", recipe.display_name]
	if not recipe.has("milk"):
		t += "\n%d g in · %d g out" % [recipe.dose_g, recipe.target_yield_g]
	for s in recipe.get("syrups", {}):
		t += "\n+ %d %s" % [recipe.syrups[s], s.replace("_", " ")]
	for top in recipe.get("toppings", []):
		t += "\n+ " + top.replace("_", " ")
	return t


## Shows or hides the order slip. Only visibility changes: the order, its slip text and
## friendship are untouched, so reopening shows the same order.
func set_order_note(open: bool) -> void:
	order_note_open = open
	ticket.visible = open


## Fills the ticket from order_slip(): first line = name, a "Friend" line, the order lines,
## and a "(...)" hint in smaller type.
func set_slip(text: String) -> void:
	var parts := text.split("\n")
	slip_name.text = parts[0]
	slip_friend.text = ""
	var order: PackedStringArray = []
	var hint: PackedStringArray = []
	for k in range(1, parts.size()):
		if parts[k].begins_with("Friend") and slip_friend.text == "":
			slip_friend.text = parts[k]
		elif parts[k].begins_with("(") or not hint.is_empty():
			hint.append(parts[k])
		else:
			order.append(parts[k])
	slip_order.text = "\n".join(order)
	slip_hint.text = " ".join(hint)
	slip_friend.visible = slip_friend.text != ""
	slip_hint.get_parent().visible = slip_hint.text != ""


## Word-wraps a line to the bubble's text column with the label's own font and splits it
## into pages of TALK_PAGE_LINES lines. Wrapping here (not with Label autowrap) gives the
## bubble its exact height on the first frame: an autowrap label measured before layout
## (at zero width) reports a huge height and the bubble would stretch down the screen.
func paginate(text: String) -> PackedStringArray:
	var font := tip.get_theme_font("font")
	var rows: PackedStringArray = []
	var row := ""
	for word in text.split(" ", false):
		var longer := word if row == "" else row + " " + word
		if row != "" and font.get_string_size(longer, HORIZONTAL_ALIGNMENT_LEFT, -1, TALK_TEXT_PX).x > TALK_TEXT_W:
			rows.append(row)
			row = word
		else:
			row = longer
	rows.append(row)
	var out: PackedStringArray = []
	for k in range(0, rows.size(), TALK_PAGE_LINES):
		out.append("\n".join(rows.slice(k, k + TALK_PAGE_LINES)))
	return out


## Plays dialogue lines ([role, text] pairs) one tap at a time, then calls `then`.
## A ["CHOICE", [options...]] line shows answer buttons; the pick is said by the player.
func say(new_lines: Array, then: Callable) -> void:
	lines = new_lines
	line_index = 0
	pages.clear()
	after_dialogue = then
	show_step(Step.DIALOGUE)


func advance() -> void:
	if line_index >= lines.size():  # already finished: a second tap on Next does nothing
		return
	if not pages.is_empty():  # more of this line: turn the page
		tip.text = pages[0]
		pages.remove_at(0)
		return
	line_index += 1
	if line_index < lines.size():
		show_step(Step.DIALOGUE)
	else:
		next_button.hide()  # no Next while the customer walks off / the next step starts
		after_dialogue.call()


## Mentor guidance at the bar depends on the order's assist level (data: "assist"):
##  "full"  = the objective panel spells the step out with the recipe's target values
##            (objective().full), the equipment gets the outline and the bobbing arrow;
##  "hints" = a short line without exact measurements (objective().text), the outline
##            only; the numbers are one tap away on the Hint button;
##  "none"  = expert orders: no panel, highlight or Hint button.
## In every level the feedback line (show_feedback) still says what just happened or why
## an action can't go ahead. The panel and highlight follow station.objective(), worked
## out from the live state, so they only move on after a successful action. Vague orders
## hide anything that would reveal which drink they meant until it is served.
func refresh_hint() -> void:
	if step != Step.BAR:
		objective_panel.hide()
		return
	var full: bool = current_order().assist == "full"
	var guided: bool = current_order().assist != "none"
	hint_button.visible = guided
	objective_panel.visible = (guided or feedback_on) and not station.art_panel.visible  # latte art is a modal: keep it clear
	objective_feedback.visible = feedback_on
	for c: Control in [objective_title, objective_toggle]:
		c.visible = guided
	objective_text.visible = guided and not objective_collapsed
	if objective_collapsed:
		objective_hint.hide()
	objective_panel.reset_size.call_deferred()  # fit the lines shown now (no empty space)
	if not guided:
		station.guide_on = false
		station.refresh_guide()
		return
	var o := station.objective()
	var line: String = o.full if full else o.text
	var secret: bool = is_vague() and not o.id in ["grind", "tamp", "lock", "brew"]
	if secret:  # don't give away the drink
		o.title = "Make what they described"
		line = "Work out their drink, then make it. The Recipe Book can help."
	station.guide_on = not secret
	station.guide_strong = full
	station.refresh_guide()
	var title: String = "Step %d of %d: %s" % [o.step, o.total, o.title] if not is_vague() else "Step %d: %s" % [o.step, o.title]
	if title != objective_title.text or line != objective_text.text:
		objective_hint.hide()  # a new objective: the old hint no longer applies
	objective_title.text = title
	objective_text.text = line


## The Hint button: more detail for the current objective, or for a vague order only a
## nudge until the drink is known (no spoilers).
func hint_text() -> String:
	var o := station.objective()
	if is_vague() and not o.id in ["grind", "tamp", "lock", "brew"]:
		return "They said: \"%s\" Which drink is that? Check the Recipe Book." % current_order().intro[0][1]
	return o.hint


## Short feedback ("Tamped! Nice and level.", warnings, shot ratings) on the objective
## panel's last line; it fades after a few seconds. On expert orders (no guidance) the
## panel shows only this line while it is up.
func show_feedback(text: String) -> void:
	objective_feedback.text = text
	feedback_on = true
	feedback_id += 1
	var mine := feedback_id
	refresh_hint()
	await get_tree().create_timer(FEEDBACK_S).timeout
	if mine == feedback_id:
		feedback_on = false
		refresh_hint()


func set_objective_collapsed(collapsed: bool) -> void:
	objective_collapsed = collapsed
	objective_toggle.texture_normal = load(HUD_ART % ("icon_arrow_down" if collapsed else "icon_arrow"))
	objective_toggle.tooltip_text = "Show the instruction" if collapsed else "Hide the instruction"
	refresh_hint()


func show_step(new_step: Step) -> void:
	step = new_step
	for c in controls.get_children():
		c.queue_free()
	for c in choice_box.get_children():
		choice_box.remove_child(c)  # out of the bubble's layout now, so it can shrink back
		c.queue_free()
	hint_button.hide()
	objective_panel.hide()
	strip.visible = step in [Step.RESULT, Step.SUMMARY]
	for c in result_grid.get_children():  # the breakdown belongs to one result only
		c.queue_free()
	result_main.hide()
	result_details.hide()
	result_grade.hide()
	readout.remove_theme_font_override("font")  # back to the text font (the summary writes words here)
	readout.add_theme_font_size_override("font_size", 38)
	strip.reset_size.call_deferred()  # fit what this step shows (no leftover height)
	next_button.visible = step == Step.DIALOGUE
	talk_box.show()
	tip.show()  # (hidden only while the player picks an answer)

	match step:
		Step.DIALOGUE:
			show_cafe()
			var line: Array = lines[line_index]
			title.text = ""
			readout.text = ""
			tip.visible = line[0] != "CHOICE"  # the answers say it's the player's turn
			if line[0] == "CHOICE":
				next_button.hide()
				speaker.text = shift.cast.PLAYER
				tip.text = "..."
				for option in line[1]:
					var b := Button.new()
					b.text = option
					b.custom_minimum_size = Vector2(430, 44)  # fixed width (fits the 560 px bubble), so the wrapped height is known up front
					b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART  # long answers wrap inside the bubble
					b.add_theme_font_size_override("font_size", 20)
					b.pressed.connect(func():
						lines[line_index] = ["PLAYER", option]
						show_step(Step.DIALOGUE))
					choice_box.add_child(b)
			else:
				speaker.text = shift.cast[line[0]]
				pages = paginate(line[1])
				tip.text = pages[0]
				pages.remove_at(0)
				bar.hop(person_of(line[0]))
			talk_box.reset_size.call_deferred()  # fit this line (short or long) once laid out

		Step.BAR:
			show_station()
			speaker.text = ""
			tip.text = ""
			refresh_hint()

		Step.SUMMARY:
			show_cafe()
			talk_box.hide()
			var s := ShiftRewards.summary(scores, shift.wage_rm)
			var tips_raw := 0.0  # slow service shrinks the tip
			for k in scores.size():
				tips_raw += ShiftRewards.tip_rm(scores[k]) * services[k]
			var tip_mult: float = 1.0 + 0.25 * save.upgrades.tip_jar + SaveGame.DECOR_TIP_BONUS * save.decor.size()
			var tips_rm := roundi(tips_raw * tip_mult)
			var earned: int = s.wage_rm + tips_rm
			save.money += earned
			var level_before := SaveGame.level(save)
			save.xp += s.xp
			var daily := EspressoModel.load_recipe(DAILY_PATH)
			var new_recipes := DayPlan.unlocked(daily, SaveGame.level(save)).filter(
				func(id): return not id in DayPlan.unlocked(daily, level_before))
			SaveGame.write(save)
			refresh_hud()
			bar.hide_served_cup()
			bar.set_mentor_happy(true)
			bar.emote(bar.mentor, "*", 3.0)
			bar.hop(bar.mentor)
			title.text = "DAY %d COMPLETE!   Orders %d · Wage RM%d · Tips RM%d · XP +%d" % [
				save.day, s.orders, s.wage_rm, tips_rm, s.xp]
			readout.text = "Average %d" % s.average
			Sfx.play("coins", 0.0)
			if SaveGame.level(save) > level_before:
				readout.text = "LEVEL %d!" % SaveGame.level(save)
				Sfx.play("levelup", 0.0)
				if not new_recipes.is_empty():
					title.text += "\nNew recipes tomorrow: " + ", ".join(new_recipes.map(
						func(id): return DayPlan.recipe(id).display_name))
			progress.text = ""
			progress.get_parent().hide()  # no empty pill, no stale order slip on the summary
			ticket.hide()  # day summary: no order (the ORDER badge is hidden too)
			add_button("Shop").pressed.connect(func(): shop.open(save))
			add_button("Next day").pressed.connect(func():
				if Friends.all_stories_done(save, stories) and not save.finale_seen:
					play_finale(start_next_day)  # once: every regular's story is finished
				else:
					start_next_day())


func start_next_day() -> void:
	save.day += 1
	SaveGame.write(save)
	shift = shift_for_day(save.day)
	scores.clear()
	services.clear()
	bar.set_mentor_happy(false)
	start_order(0)


## The end of the story: the mentor's farewell (stories.json "finale"), then the credits.
## Saved as seen first, so it plays once; the café carries on afterwards.
func play_finale(then: Callable) -> void:
	save.finale_seen = true
	SaveGame.write(save)
	bar.emote(bar.mentor, "<3", 3.0)
	say(stories.finale.duplicate(true), show_credits.bind(then))


## Credits roll: a dark curtain, the credits on a cream sign rising into view, then a
## button to carry on.
func show_credits(then: Callable) -> void:
	talk_box.hide()
	var layer := ui_layer(3)  # above the HUD and the modals
	var dim := ColorRect.new()
	dim.color = Color(0.08, 0.05, 0.03, 0.0)
	dim.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	layer.add_child(dim)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", PixelUI.cream_panel(34.0))
	panel.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	layer.add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 18)
	panel.add_child(col)
	var head := label(col, 34, Color("#8A4A26"))
	head.add_theme_font_override("font", PixelUI.font(700))
	head.text = "The end of the first chapter"
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var body := label(col, 22, Color("#36251D"))
	body.text = TitleScreen.CREDITS
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var go := Button.new()
	go.text = "Keep the café open"
	go.custom_minimum_size = Vector2(300, 60)
	go.size_flags_horizontal = SIZE_SHRINK_CENTER
	go.modulate.a = 0.0
	go.disabled = true
	col.add_child(go)
	panel.reset_size()
	var centre := (Vector2(1280, 720) - panel.size) / 2.0
	panel.position = Vector2(centre.x, 720)
	Sfx.play("levelup", 0.0)
	var t := create_tween()
	t.tween_property(dim, "color:a", 0.78, 0.8)
	t.tween_property(panel, "position:y", centre.y, 3.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t.tween_property(go, "modulate:a", 1.0, 0.4)
	t.tween_callback(func(): go.disabled = false)
	go.pressed.connect(func():
		layer.get_parent().queue_free()  # the whole CanvasLayer
		then.call())


## The drink reached the serve area: back to the counter to score it.
## Two-drink orders: the first drink is scored quietly and the player stays at the bar;
## the result screen shows the average once both are served.
func on_served(drink: Dictionary) -> void:
	var r := DrinkModel.evaluate(recipe, drink)
	if r.grade != "Failed Order":
		results.append(r)
		if results.size() < drinks_needed():
			show_feedback("Drink %d of %d served (%s). Now make the next one!" % [results.size(), drinks_needed(), EspressoModel.grade_label(r.score)])
			Sfx.play("good", 0.0)
			return
		r = combined(results)
	show_step(Step.RESULT)
	show_cafe()
	talk_box.show()
	bar.show_served_cup(drink.cup)
	# The pace (time to reach the recipe yield with this grind) is what the timing score
	# judges; the raw time also depends on where the shot was stopped.
	var details := "%.1f g in · %.1f g out · %.1f s (pace %d s, aim %d–%d) · grind %d%s" % [
		drink.dose, drink.yield, drink.time, roundi(EspressoModel.pace_s(recipe, drink.grind, drink.tamped)),
		recipe.extraction_time_min_s, recipe.extraction_time_max_s, drink.grind, "" if drink.tamped else " · not tamped"]
	if drink.milk_temp >= 0.0:
		details += " · milk %d°C" % roundi(drink.milk_temp)
	waiting = false
	title.text = "RESULT  ·  Drink quality %d  ·  Recipe accuracy %d  ·  Service %d%%" % [r.quality, r.accuracy, roundi(patience * 100)]
	if is_vague():  # reveal what they meant
		title.text = "They wanted: %s  ·  %s" % [recipe.display_name, title.text]
	readout.text = str(r.score)
	readout.add_theme_font_override("font", load(PixelUI.NUMBER_FONT))  # clear digits for the score
	readout.add_theme_font_size_override("font_size", PixelUI.NUMBER_PX)
	show_breakdown(r, details)
	Sfx.play({"Perfect Brew": "perfect", "Great Cup": "perfect", "Good Effort": "good"}.get(r.grade, "fail"), 0.0)
	# Diagnosis always shows, whatever the assist level: it is the core lesson.
	speaker.text = shift.cast.MENTOR
	tip.text = "\n".join(paginate(r.tip))  # the whole note, wrapped to the bubble (it shows with the result, no paging)
	talk_box.reset_size.call_deferred()
	var who: String = current_order().customer
	if r.grade == "Failed Order":
		bar.emote(bar.customer, "?")
		add_button("Make it again").pressed.connect(func():
			say([[who, "Hmm, this isn't right. Could you make it again?"]], func():
				bar.hide_served_cup()
				station.go_page(0, false)
				waiting = true
				show_step(Step.BAR)))
		return
	add_button("Continue").pressed.connect(func():
		scores.append(r.score)
		var hearts_before := Friends.hearts(save, who, stories)
		var hearts := Friends.reward(save, who, r.grade, stories)
		services.append(patience * Friends.tip_multiplier(save, who, stories))  # friends tip more
		SaveGame.write(save)
		refresh_hud()
		var great: bool = r.grade in ["Perfect Brew", "Great Cup"]
		bar.set_happy(great)
		bar.emote(bar.customer, "<3" if great else ":)")
		var reaction: Array = [[who, shift.reactions[r.grade]]]
		if hearts > hearts_before:
			reaction.append(["MENTOR", "%s likes you more now! (Friend %d/%d)" % [shift.cast[who], hearts,
				stories.hearts_at.size()]])
		say(reaction, func():
			bar.hide_served_cup()
			strip.hide()
			talk_box.hide()
			await bar.customer_leave().finished
			next_order()))


## The result strip's breakdown: one rating per scored category (from the real scores,
## only the ones this drink has), the main penalty in one line, and a Details button for
## the raw numbers.
func show_breakdown(r: Dictionary, details: String) -> void:
	for c in result_grid.get_children():
		c.queue_free()
	for part: Array in r.breakdown:
		var cell := hrow(8)
		var dot := ColorRect.new()  # pixel status square
		dot.custom_minimum_size = Vector2(12, 12)
		dot.size_flags_vertical = SIZE_SHRINK_CENTER
		dot.color = rating_color(roundi(part[1]))
		cell.add_child(dot)
		label(cell, 17, CREAM).text = "%s  %s" % [part[0], EspressoModel.grade_label(roundi(part[1]))]
		result_grid.add_child(cell)
	result_grade.text = EspressoModel.grade_label(r.score)
	result_grade.add_theme_color_override("font_color", rating_color(r.score))
	result_grade.show()
	result_main.text = ("To improve: " + r.main) if r.main != "" else "Everything was spot on!"
	result_main.show()
	result_details.text = details
	var more := add_button("Details")
	more.custom_minimum_size = Vector2(120, 50)
	more.pressed.connect(func():
		result_details.visible = not result_details.visible
		more.text = "Hide" if result_details.visible else "Details"
		strip.reset_size.call_deferred())


static func rating_color(score: int) -> Color:
	if score >= 80:
		return Color("#A8E07A")  # Excellent / Great
	if score >= 70:
		return Color("#F2C14E")  # Good
	if score >= 60:
		return Color("#F0A35A")  # Needs Improvement
	return Color("#E8705A")  # Poor


## Averages the drinks of one order; the tip comes from the weakest drink.
func combined(rs: Array) -> Dictionary:
	if rs.size() == 1:
		return rs[0]
	var worst: Dictionary = rs[0]
	var q := 0.0
	var a := 0.0
	var s := 0.0
	for x in rs:
		q += x.quality
		a += x.accuracy
		s += x.score
		if x.score < worst.score:
			worst = x
	var score := roundi(s / rs.size())
	return {"quality": roundi(q / rs.size()), "accuracy": roundi(a / rs.size()), "score": score,
		"grade": EspressoModel.grade(score), "tip": worst.tip, "breakdown": worst.breakdown, "main": worst.main}


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
	clock_label.text = "Day %d · %d:%02d %s" % [save.day, (h - 1) % 12 + 1, minutes % 60, "AM" if h < 12 else "PM"]
	clock_icon.texture = load(HUD_ART % ("icon_sun" if h < 18 else "icon_moon"))
	if scores.is_empty():
		mood_label.text = "--%"
	else:
		var avg := 0.0
		for s in scores:
			avg += s
		mood_label.text = "%d%%" % roundi(avg / scores.size())
	money_label.text = "RM %d" % save.money


# ---------- building ----------

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


## A 9-slice pixel frame (see PixelUI).
func frame(path: String, margin: Vector4i, content: Vector4 = Vector4(-1, -1, -1, -1)) -> StyleBoxTexture:
	return PixelUI.frame(path, margin, content)


## A HUD sign button with a pixel icon on the left.
func hud_button(text: String, icon: String) -> Button:
	var b := Button.new()
	b.text = text
	b.tooltip_text = text
	b.icon = load(HUD_ART % icon)
	b.add_theme_constant_override("h_separation", 8)
	sign_button(b, "charcoal", Vector4(14, 5, 16, 9))
	hud_buttons.append(b)
	return b


## Drops the Recipes / Hint / Menu captions (icons stay, the tooltip names them) when the
## HUD row would run past the screen edge: late-day clocks and big money need the room.
## Text only changes when the answer does, so the resize it causes can't loop.
func fit_hud(hud: HBoxContainer) -> void:
	var compact := hud_buttons[0].text == ""
	var need := hud.get_combined_minimum_size().x
	if compact:  # add back what the captions would take
		for b in hud_buttons:
			if b.visible:
				need += b.get_theme_font("font").get_string_size(b.tooltip_text, HORIZONTAL_ALIGNMENT_LEFT, -1, b.get_theme_font_size("font_size")).x + 8
	var room := hud.get_parent_area_size().x - hud.offset_left + hud.offset_right  # an over-full row grows past its anchors, so not hud.size
	if (need > room) != compact:
		for b in hud_buttons:
			b.text = "" if not compact else b.tooltip_text


## Pixel-art picture (icons, clip, cup) at its drawn size.
func pic(parent: Node, file: String) -> TextureRect:
	var r := TextureRect.new()
	r.texture = load(HUD_ART % file)
	r.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	r.size_flags_vertical = SIZE_SHRINK_CENTER
	r.mouse_filter = MOUSE_FILTER_IGNORE
	parent.add_child(r)
	return r


## Wooden (or charcoal) sign styles on a button; `pad` = content margins (l, t, r, b).
func sign_button(b: Button, kind: String, pad: Vector4) -> void:
	var files := {"normal": "normal", "hover": "hover", "pressed": "pressed", "hover_pressed": "pressed", "disabled": "normal"}
	for state in files:
		var path: String = (MENU_ART % ("button_wood_" + files[state])) if kind == "wood" else (HUD_ART % ("button_" + files[state]))
		b.add_theme_stylebox_override(state, frame(path, Vector4i(15, 15, 15, 18), pad))


## A HUD badge: dark wood pill (or the gold-lined ORDER badge) around `inner`.
func badge(parent: Node, inner: Control, kind := "pill") -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", frame(HUD_ART % kind, Vector4i(12, 9, 12, 12), Vector4(16, 5, 16, 9)))
	p.mouse_filter = MOUSE_FILTER_IGNORE
	p.add_child(inner)
	parent.add_child(p)
	return p


func hrow(separation: int) -> HBoxContainer:
	var r := HBoxContainer.new()
	r.add_theme_constant_override("separation", separation)
	r.mouse_filter = MOUSE_FILTER_IGNORE
	return r


func build_ui() -> void:
	theme = Theme.new()
	var font := PixelUI.font(600)  # Pixelify Sans (SIL OFL 1.1), as on the title screen
	theme.default_font = font
	theme.default_font_size = 22
	bold = PixelUI.font(700)
	theme.set_color("font_color", "Button", CREAM)
	theme.set_color("font_hover_color", "Button", Color.WHITE)
	theme.set_color("font_pressed_color", "Button", CREAM)
	theme.set_color("font_focus_color", "Button", CREAM)
	theme.set_font("font", "Button", bold)
	for state in ["normal", "hover", "pressed", "disabled"]:  # every gameplay button is a wooden sign
		theme.set_stylebox(state, "Button", frame(MENU_ART % ("button_wood_" + ("normal" if state == "disabled" else state)),
			Vector4i(15, 15, 15, 18), Vector4(18, 8, 18, 11)))
	var focus := StyleBoxFlat.new()
	focus.draw_center = false
	focus.border_color = Color("#F0C978")
	focus.set_border_width_all(3)
	theme.set_stylebox("focus", "Button", focus)
	for popup: Control in [station.art_panel, station.steam_panel]:  # on their own CanvasLayer: no inherited theme
		popup.theme = theme

	# UI layering: the station's sprites use z_index (tamper/pitcher 1, cups 2-3, steam
	# popup 10) on the default canvas, so anything that must stay above them lives on its
	# own CanvasLayer (layers always draw above lower layers, whatever the z_index).
	# Layer 1: HUD, order ticket, dialogue / tip bar, objective panel. Layer 2: modals
	# (recipe book, shop, latte art).
	var talk_layer := ui_layer(1)
	talk_layer.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST  # pixel-art frames and icons

	# HUD across the top: level + XP, day + clock, satisfaction, money | recipes, hint, menu, order.
	var hud := hrow(6)
	hud.set_anchors_and_offsets_preset(PRESET_TOP_WIDE)
	hud.offset_left = 12
	hud.offset_right = -12
	hud.offset_top = 8
	hud.offset_bottom = 52
	talk_layer.add_child(hud)
	var lv := hrow(12)
	level_label = label(lv, 22, CREAM)
	PixelUI.number_label(level_label, 24, 700)  # numbers: Silkscreen digits, Pixelify letters
	xp_bar = ProgressBar.new()
	xp_bar.custom_minimum_size = Vector2(72, 15)
	xp_bar.show_percentage = false
	xp_bar.size_flags_vertical = SIZE_SHRINK_CENTER
	xp_bar.add_theme_stylebox_override("background", frame(HUD_ART % "bar_bg", Vector4i(6, 6, 6, 6)))
	xp_bar.add_theme_stylebox_override("fill", frame(HUD_ART % "bar_fill", Vector4i(6, 6, 6, 6)))
	xp_bar.mouse_filter = MOUSE_FILTER_IGNORE
	lv.add_child(xp_bar)
	badge(hud, lv)
	var day := hrow(10)
	clock_icon = pic(day, "icon_sun")
	clock_label = PixelUI.number_label(label(day, 22, CREAM), 24)
	badge(hud, day)
	var mood := hrow(10)
	pic(mood, "icon_smiley")
	mood_label = label(mood, 22, Color("#FFD34D"))
	PixelUI.number_label(mood_label, 24, 700)
	badge(hud, mood)
	money_label = Label.new()
	money_label.add_theme_font_size_override("font_size", 22)
	money_label.add_theme_color_override("font_color", Color("#A8E07A"))
	PixelUI.number_label(money_label, 24, 700)
	badge(hud, money_label)
	var spacer := Control.new()
	spacer.size_flags_horizontal = SIZE_EXPAND_FILL
	spacer.mouse_filter = MOUSE_FILTER_IGNORE
	hud.add_child(spacer)
	var recipes := hud_button("Recipes", "icon_book")
	recipes.pressed.connect(func(): book.open(SaveGame.level(save)))
	hud.add_child(recipes)
	hint_button = hud_button("Hint", "icon_bulb")
	hint_button.hide()
	hint_button.pressed.connect(func():  # detail goes in the objective panel, under the step
		objective_hint.text = "Hint: " + hint_text()
		set_objective_collapsed(false)  # a hint needs the full panel
		objective_hint.show()
		objective_panel.reset_size.call_deferred())
	hud.add_child(hint_button)
	var menu_button := hud_button("Menu", "icon_menu")
	menu_button.pressed.connect(open_settings)  # music volume and mute, sound, resume or main menu
	hud.add_child(menu_button)
	hud.minimum_size_changed.connect(fit_hud.bind(hud))
	hud.resized.connect(fit_hud.bind(hud))
	progress = Label.new()
	progress.add_theme_font_size_override("font_size", 22)
	progress.add_theme_color_override("font_color", CREAM)
	PixelUI.number_label(progress, 24, 700)
	var order_badge := badge(hud, progress, "badge")  # tap: show / hide the order slip
	order_badge.mouse_filter = MOUSE_FILTER_STOP
	order_badge.mouse_default_cursor_shape = CURSOR_POINTING_HAND
	order_badge.tooltip_text = "Show or hide the order note"
	order_badge.mouse_entered.connect(func(): order_badge.modulate = Color(1.15, 1.12, 1.05))
	order_badge.mouse_exited.connect(func(): order_badge.modulate = Color.WHITE)
	order_badge.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
			order_badge.modulate = Color(0.85, 0.82, 0.78) if e.pressed else Color(1.15, 1.12, 1.05)  # pressed feedback
			if not e.pressed:
				set_order_note(not order_note_open))

	# Order ticket: a parchment slip clipped under the top-right HUD. Anchored to the right
	# edge with a fixed width and wrapping text, so it can never run off the screen.
	ticket = PanelContainer.new()
	ticket.add_theme_stylebox_override("panel", frame(HUD_ART % "ticket", Vector4i(21, 21, 21, 21), Vector4(18, 24, 22, 20)))
	ticket.set_anchors_preset(PRESET_TOP_RIGHT)
	ticket.offset_left = -TICKET_W - 12
	ticket.offset_right = -12
	ticket.offset_top = 62
	ticket.mouse_filter = MOUSE_FILTER_IGNORE
	talk_layer.add_child(ticket)
	var paper := VBoxContainer.new()
	paper.add_theme_constant_override("separation", 2)
	paper.mouse_filter = MOUSE_FILTER_IGNORE
	ticket.add_child(paper)
	var head := hrow(4)  # name + red X
	paper.add_child(head)
	slip_name = label(head, 22, ESPRESSO)
	slip_name.add_theme_font_override("font", bold)
	slip_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	slip_name.size_flags_horizontal = SIZE_EXPAND_FILL
	var close := TextureButton.new()  # red X: closes the slip (reopen with the ORDER badge)
	close.texture_normal = load(HUD_ART % "close_normal")
	close.texture_hover = load(HUD_ART % "close_hover")
	close.texture_pressed = load(HUD_ART % "close_pressed")
	close.size_flags_vertical = SIZE_SHRINK_BEGIN
	close.tooltip_text = "Close the order note (tap ORDER to open it again)"
	close.pressed.connect(set_order_note.bind(false))
	head.add_child(close)
	var body := hrow(4)  # friendship + the order, with the drink cup on the right
	paper.add_child(body)
	var lines_col := VBoxContainer.new()
	lines_col.size_flags_horizontal = SIZE_EXPAND_FILL
	lines_col.add_theme_constant_override("separation", 2)
	lines_col.mouse_filter = MOUSE_FILTER_IGNORE
	body.add_child(lines_col)
	slip_friend = label(lines_col, 19, Color("#5A3414"))
	slip_order = label(lines_col, 19, ESPRESSO)
	slip_order.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	pic(body, "icon_cup_small").size_flags_vertical = SIZE_SHRINK_BEGIN
	var foot := hrow(4)
	paper.add_child(foot)
	slip_hint = label(foot, 16, Color("#6A4A30"))
	slip_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	slip_hint.size_flags_horizontal = SIZE_EXPAND_FILL
	pic(foot, "icon_bean").size_flags_vertical = SIZE_SHRINK_END
	var clip := TextureRect.new()  # the wooden clip holding the slip
	clip.texture = load(HUD_ART % "icon_clip")
	clip.set_anchors_preset(PRESET_TOP_RIGHT)
	clip.offset_left = -12 - TICKET_W / 2.0 - 12
	clip.offset_right = clip.offset_left + 24  # its own size (8x9 art), not stretched to the edge
	clip.offset_bottom = 50 + 27
	clip.offset_top = 50
	clip.mouse_filter = MOUSE_FILTER_IGNORE
	talk_layer.add_child(clip)
	ticket.visibility_changed.connect(func(): clip.visible = ticket.visible)

	# Result / summary strip, over the counter
	strip = PanelContainer.new()
	strip.add_theme_stylebox_override("panel", frame(HUD_ART % "badge", Vector4i(12, 9, 12, 12), Vector4(20, 12, 22, 18)))  # same sign as the speech bubble
	strip.position = Vector2(24, 560)
	strip.custom_minimum_size = Vector2(1232, 140)
	strip.resized.connect(func(): strip.position.y = 710.0 - strip.size.y)  # sits on the bottom edge, grows upward
	add_child(strip)
	var step_box := VBoxContainer.new()
	step_box.add_theme_constant_override("separation", 4)
	strip.add_child(step_box)
	title = PixelUI.number_label(label(step_box, 17, CARAMEL), 16)  # result headline (quality, accuracy, service)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 24)
	step_box.add_child(row)
	var score_col := VBoxContainer.new()  # the big score, its rating under it
	score_col.add_theme_constant_override("separation", 0)
	score_col.custom_minimum_size = Vector2(200, 0)
	score_col.size_flags_vertical = SIZE_SHRINK_CENTER
	row.add_child(score_col)
	readout = label(score_col, 38, CREAM)
	result_grade = label(score_col, 20, GOLD)
	result_grade.hide()
	result_grid = GridContainer.new()  # per-category ratings (result only), 2 columns so it fits 1280 px
	result_grid.columns = 2
	result_grid.add_theme_constant_override("h_separation", 26)
	result_grid.add_theme_constant_override("v_separation", 4)
	result_grid.size_flags_horizontal = SIZE_EXPAND_FILL
	result_grid.size_flags_vertical = SIZE_SHRINK_CENTER
	row.add_child(result_grid)
	controls = HBoxContainer.new()
	controls.add_theme_constant_override("separation", 16)
	controls.size_flags_vertical = SIZE_SHRINK_CENTER
	row.add_child(controls)
	result_main = label(step_box, 18, GOLD)  # the main penalty, one line
	result_details = PixelUI.number_label(label(step_box, 15, CARAMEL), 16)  # raw numbers, behind the Details button
	result_main.hide()
	result_details.hide()

	# Speech bubble (counter): the brown objective-panel sign with the cup picture, the speaker's name in
	# gold, the line in cream, and Next (or the player's answers) inside it, plus a pointer
	# under it. It grows with the text. At the station the same box is the bottom tip bar.
	bubble_style = frame(HUD_ART % "badge", Vector4i(12, 9, 12, 12), Vector4(20, 12, 22, 18))  # the objective panel's brown, gold-rimmed sign
	talk_box = PanelContainer.new()
	talk_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	talk_layer.add_child(talk_box)
	var talk_row := hrow(16)
	talk_box.add_child(talk_row)
	talk_art = pic(talk_row, "icon_cup_big")  # the drink, with its steam
	var talk := VBoxContainer.new()
	talk.size_flags_horizontal = SIZE_EXPAND_FILL
	talk.custom_minimum_size.x = TALK_TEXT_W
	talk.add_theme_constant_override("separation", 4)
	talk.mouse_filter = MOUSE_FILTER_IGNORE
	talk_row.add_child(talk)
	speaker = label(talk, 28, GOLD)
	speaker.add_theme_font_override("font", bold)
	speaker.clip_text = true  # one line: a very long name is cut with an ellipsis, never widens the bubble
	speaker.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	tip = label(talk, TALK_TEXT_PX, CREAM)
	tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	choice_box = VBoxContainer.new()  # the player's answers, inside the bubble
	choice_box.add_theme_constant_override("separation", 8)
	choice_box.mouse_filter = MOUSE_FILTER_IGNORE
	talk.add_child(choice_box)
	next_button = Button.new()
	next_button.text = "Next"
	next_button.icon = load(HUD_ART % "icon_arrow")
	next_button.icon_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	next_button.size_flags_vertical = SIZE_SHRINK_CENTER
	next_button.hide()
	next_button.pressed.connect(advance)
	talk_row.add_child(next_button)
	talk_pointer = TextureRect.new()
	talk_pointer.texture = load(HUD_ART % "badge_pointer")
	talk_pointer.mouse_filter = MOUSE_FILTER_IGNORE
	talk_layer.add_child(talk_pointer)
	talk_box.resized.connect(place_pointer)
	talk_box.visibility_changed.connect(place_pointer)
	build_objective_panel(talk_layer)

	# Modal windows: a dim backdrop that swallows every click (so nothing on the bar can be
	# grabbed or pressed through it; tapping it closes the window), then the window itself.
	var modal_layer := ui_layer(2)
	modal_dim = ColorRect.new()
	modal_dim.color = Color(0, 0, 0, 0.45)
	modal_dim.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	modal_dim.mouse_filter = MOUSE_FILTER_STOP
	modal_dim.hide()
	modal_dim.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed:
			book.hide()
			shop.hide()
			close_settings())
	modal_dim.process_mode = Node.PROCESS_MODE_ALWAYS  # still clickable while the Menu pauses the game
	modal_layer.add_child(modal_dim)
	book = RecipeBook.new()
	modal_layer.add_child(book)
	shop = UpgradeShop.new()
	modal_layer.add_child(shop)
	build_settings(modal_layer)
	for w: Control in [book, shop, settings]:
		w.visibility_changed.connect(func(): modal_dim.visible = book.visible or shop.visible or settings.visible)
	shop.bought.connect(func():
		apply_upgrades()
		bar.set_decor(save.decor)
		refresh_hud())


## "CURRENT OBJECTIVE" panel, top-left under the HUD (clear of the grinder, the machine
## and the order slip). Shows the step, one short instruction, and the Hint text once the
## Hint button is pressed. Ignores the mouse so it never blocks drag and drop.
func build_objective_panel(parent: Control) -> void:
	objective_panel = PanelContainer.new()  # dark wood, gold line (the ORDER badge art, 9-slice)
	objective_panel.add_theme_stylebox_override("panel", frame(HUD_ART % "badge", Vector4i(12, 9, 12, 12), Vector4(18, 12, 16, 16)))
	objective_panel.position = Vector2(10, 58)
	objective_panel.custom_minimum_size = Vector2(OBJECTIVE_W, 0)
	objective_panel.mouse_filter = MOUSE_FILTER_IGNORE
	parent.add_child(objective_panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 2)
	col.mouse_filter = MOUSE_FILTER_IGNORE
	objective_panel.add_child(col)
	var head := hrow(8)  # clipboard, heading, collapse arrow
	col.add_child(head)
	pic(head, "icon_clipboard")
	var heading := label(head, 16, GOLD)
	heading.text = "CURRENT OBJECTIVE"
	heading.add_theme_font_override("font", bold)
	heading.size_flags_horizontal = SIZE_EXPAND_FILL
	heading.size_flags_vertical = SIZE_SHRINK_CENTER
	objective_toggle = TextureButton.new()  # only this takes the mouse; the panel never blocks drags
	objective_toggle.texture_normal = load(HUD_ART % "icon_arrow")
	objective_toggle.stretch_mode = TextureButton.STRETCH_KEEP_CENTERED
	objective_toggle.custom_minimum_size = Vector2(30, 30)
	objective_toggle.mouse_default_cursor_shape = CURSOR_POINTING_HAND
	objective_toggle.tooltip_text = "Hide the instruction"
	objective_toggle.pressed.connect(func(): set_objective_collapsed(not objective_collapsed))
	head.add_child(objective_toggle)
	objective_title = label(col, 20, CREAM)
	objective_title.add_theme_font_override("font", bold)
	objective_text = label(col, 17, Color("#E9DCC8"))
	objective_hint = label(col, 16, Color("#FFE066"))
	objective_feedback = label(col, 16, Color("#A8E07A"))
	for l: Label in [objective_title, objective_text, objective_hint, objective_feedback]:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(OBJECTIVE_W - 34, 0)  # fixed wrap width: exact height from the first frame
		l.mouse_filter = MOUSE_FILTER_IGNORE
	objective_hint.hide()
	objective_feedback.hide()
	objective_panel.hide()


## A CanvasLayer drawn above the game at `layer`, holding a full-screen root Control that
## passes clicks through and carries this screen's theme (themes don't cross CanvasLayers).
## The Menu window: music volume (0-100 %, the Music bus via linear_to_db), Mute music
## (keeps the volume), Sound effects, Resume and Main menu. Open, it pauses the game (the
## music keeps playing: the Audio autoload always runs).
func build_settings(parent: Control) -> void:
	settings = PanelContainer.new()
	settings.add_theme_stylebox_override("panel", PixelUI.cream_panel(30.0))
	settings.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	settings.process_mode = Node.PROCESS_MODE_ALWAYS
	settings.hide()
	parent.add_child(settings)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 18)
	settings.add_child(col)
	var head := label(col, 34, Color("#8A4A26"))
	head.add_theme_font_override("font", PixelUI.font(700))
	head.text = "Menu"
	var row := hrow(16)
	col.add_child(row)
	label(row, 22, Color("#36251D")).text = "Music volume"
	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.01
	slider.custom_minimum_size = Vector2(300, 32)
	slider.size_flags_vertical = SIZE_SHRINK_CENTER
	var track := StyleBoxFlat.new()
	track.bg_color = Color("#C9A27C")
	track.content_margin_top = 4
	track.content_margin_bottom = 4
	var filled := track.duplicate() as StyleBoxFlat
	filled.bg_color = Color("#8A4A26")
	slider.add_theme_stylebox_override("slider", track)
	slider.add_theme_stylebox_override("grabber_area", filled)
	slider.add_theme_stylebox_override("grabber_area_highlight", filled)
	row.add_child(slider)
	var pct := PixelUI.number_label(label(row, 24, Color("#36251D")), 24)
	pct.custom_minimum_size.x = 80
	var mute := Button.new()
	mute.toggle_mode = true
	mute.custom_minimum_size = Vector2(0, 56)
	col.add_child(mute)
	var sound := Button.new()
	sound.toggle_mode = true
	sound.custom_minimum_size = Vector2(0, 56)
	col.add_child(sound)
	var audio := Sfx.audio()
	var refresh := func():
		pct.text = "%d%%" % roundi(slider.value * 100.0)
		mute.text = "Music: muted" if mute.button_pressed else "Music: on"
		sound.text = "Sound effects: off" if not sound.button_pressed else "Sound effects: on"
	settings.visibility_changed.connect(func():  # show the saved settings each time it opens
		if settings.visible and audio:
			slider.set_value_no_signal(audio.music_volume)
			mute.set_pressed_no_signal(not audio.music_on)
			sound.set_pressed_no_signal(audio.sfx_on)
			refresh.call())
	slider.value_changed.connect(func(v: float):
		if audio:
			audio.set_music_volume(v)  # live, while dragging
		refresh.call())
	mute.toggled.connect(func(on: bool):
		if audio:
			audio.set_music_on(not on)
		refresh.call())
	sound.toggled.connect(func(on: bool):
		if audio:
			audio.set_sfx_on(on)
		refresh.call())
	var buttons := hrow(16)
	col.add_child(buttons)
	var resume := Button.new()
	resume.text = "Resume"
	resume.custom_minimum_size = Vector2(240, 60)
	resume.pressed.connect(close_settings)
	buttons.add_child(resume)
	var main_menu := Button.new()
	main_menu.text = "Main menu"
	main_menu.custom_minimum_size = Vector2(240, 60)
	main_menu.pressed.connect(func():  # the save keeps the day; that day restarts from its first order
		get_tree().paused = false
		get_tree().change_scene_to_file("res://scenes/ui/title_screen.tscn"))
	buttons.add_child(main_menu)


func open_settings() -> void:
	settings.show()
	settings.reset_size()
	settings.position = (Vector2(1280, 720) - settings.size) / 2.0
	get_tree().paused = true


func close_settings() -> void:
	if settings.visible:
		settings.hide()
		get_tree().paused = false


func ui_layer(layer: int) -> Control:
	var cl := CanvasLayer.new()
	cl.layer = layer
	add_child(cl)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	root.mouse_filter = MOUSE_FILTER_IGNORE
	root.theme = theme
	cl.add_child(root)
	return root


func show_cafe() -> void:
	station.hide()
	bar.show()
	# Speech bubble near the top, above the people's heads (GCGC style).
	talk_box.add_theme_stylebox_override("panel", bubble_style)
	talk_box.position = Vector2(24, 64)  # under the HUD, over the back wall, clear of faces
	talk_box.custom_minimum_size = TALK_SIZE
	talk_box.reset_size()
	speaker.show()
	talk_art.show()
	tip.add_theme_font_size_override("font_size", TALK_TEXT_PX)
	tip.autowrap_mode = TextServer.AUTOWRAP_OFF  # paginate() breaks the lines itself (exact height)
	tip.add_theme_color_override("font_color", CREAM)
	in_cafe = true
	place_pointer()


## The bubble's pointer sits under its bottom edge, towards the customer (counter only).
func place_pointer() -> void:
	talk_pointer.visible = in_cafe and talk_box.visible
	talk_pointer.position = talk_box.position + Vector2(150, talk_box.size.y - 9)


## At the bar the talk box is not shown: instructions are in the objective panel and
## short feedback appears on its last line (show_feedback), so the counter stays clear.
func show_station() -> void:
	bar.hide()
	station.show()
	talk_box.hide()
	in_cafe = false
	place_pointer()


func _process(delta: float) -> void:
	if waiting:  # a two-drink order gets twice the time
		patience = maxf(patience - delta / (float(shift.get("patience_s", PATIENCE_S)) * drinks_needed()), 0.0)
