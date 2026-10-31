extends SceneTree
## Run: Godot_console.exe --headless --path . --script res://tests/test_espresso_model.gd

const Model = preload("res://scripts/brewing/espresso_model.gd")
const Rewards = preload("res://scripts/economy/shift_rewards.gd")
const Drink = preload("res://scripts/brewing/drink_model.gd")
const Save = preload("res://scripts/core/save_game.gd")

var failures := 0


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: ", what)


func _init() -> void:
	var r := Model.load_recipe("res://data/recipes/double_espresso_training.json")
	check(not r.is_empty(), "recipe loads")

	var nominal := Model.evaluate(r, 18, 5, 36)
	check(nominal.quality >= 95, "nominal shot scores high (%d)" % nominal.quality)
	check(nominal.grade == "Perfect Brew", "nominal grade")
	check(nominal.tip.begins_with("Great"), "nominal tip")

	check(Model.evaluate(r, 18, 9, 36).tip.contains("finer"), "coarse grind -> grind finer")
	check(Model.evaluate(r, 18, 1, 36).tip.contains("coarser"), "fine grind -> grind coarser")
	check(Model.evaluate(r, 18, 5, 20).tip.contains("too early"), "early stop diagnosed as stop point")
	check(Model.evaluate(r, 18, 5, 50).tip.contains("too long"), "late stop")
	check(Model.evaluate(r, 15, 5, 30).tip.contains("less coffee"), "under-dose")
	check(Model.evaluate(r, 18, 9, 36).quality < nominal.quality, "coarse grind scores lower")
	check(Model.evaluate(r, 17.4, 6, 35).quality == Model.evaluate(r, 17.4, 6, 35).quality, "deterministic")
	check(Model.order_score(80, 100, 70) == 83, "GDD 7.1 example = 83")

	var loose := Model.evaluate(r, 18, 5, 36, false)
	check(loose.tip.contains("tamp"), "untamped shot diagnosed")
	check(loose.quality < nominal.quality, "untamped shot scores lower")

	# Order 3 "kaw" override: shorter 30 g shot with matching time window.
	var kaw := r.duplicate()
	kaw.merge({"target_yield_g": 30, "extraction_time_min_s": 20, "extraction_time_max_s": 25}, true)
	check(Model.evaluate(kaw, 18, 5, 30).grade == "Perfect Brew", "kaw shot at 30 g is perfect")
	check(Model.evaluate(kaw, 18, 5, 36).tip.contains("too long"), "kaw shot at 36 g ran too long")

	var s := Rewards.summary([95, 80, 50], 40)
	check(s.tips_rm == 8 and s.average == 75 and s.xp == 45 and s.wage_rm == 40, "shift summary %s" % s)

	var shift := Model.load_recipe("res://data/orders/ch1_first_shift.json")
	check(shift.orders.size() == 4, "shift has 4 orders")
	for o in shift.orders:
		check(shift.cast.has(o.customer), "cast has " + o.customer)
		for line in o.intro:
			check(line[0] == "CHOICE" or shift.cast.has(line[0]), "cast has speaker " + str(line[0]))
	for g in ["Perfect Brew", "Great Cup", "Good Effort", "Needs Practice"]:
		check(shift.reactions.has(g), "reaction for " + g)

	scoring(r)
	drinks()
	iced_drinks()
	days(shift)
	friends()
	more_drinks()
	saves()
	print("PASS" if failures == 0 else "%d FAILED" % failures)
	quit(failures)


## Fair scoring: green zones give full marks, small misses cost a little, big ones a lot.
func scoring(r: Dictionary) -> void:
	var q := func(dose: float, grind: float, yield_g: float, tamped := true) -> int:
		return Model.evaluate(r, dose, grind, yield_g, tamped).quality
	check(q.call(18, 5, 36) == 100, "perfect shot = 100")
	check(q.call(18, 5, 38) == 100 and q.call(18, 5, 34) == 100, "anywhere in the green zone = full yield marks")
	check(q.call(17.6, 5, 36) == 100, "dose inside the green bubble = full dose marks")
	var playtest: int = q.call(18, 8, 34.4)  # the user's 62: green weight, grind 3 steps coarse
	check(playtest >= 70 and playtest < 80, "green weight but grind 8 is Good, not Poor (%d)" % playtest)
	check(q.call(18, 6, 36) >= 90, "one grind step off is still Excellent")
	check(q.call(18, 7, 36) >= 80 and q.call(18, 7, 36) < 90, "two steps off is Great")
	check(q.call(18, 5, 30) < 80, "stopped well short of the green (bar says Bad) is not Great")
	check(q.call(18, 5, 20) < 70, "stopped far too early is punished")
	check(q.call(18, 1, 36) < 70, "far too fine is punished")
	check(q.call(18, 5, 36, false) < 90, "forgetting to tamp costs a grade")
	check(Model.evaluate(r, 15, 9, 25, false).grade == "Failed Order", "everything wrong fails")
	check(Model.grade_label(95) == "Excellent" and Model.grade_label(85) == "Great" and Model.grade_label(75) == "Good"
		and Model.grade_label(65) == "Needs Improvement" and Model.grade_label(50) == "Poor", "grade labels")
	check(Model.evaluate(r, 16, 5, 36).parts.flow == 100.0, "a dose mistake is only charged once (dose part, not time)")
	check(absf(Model.pace_s(r, 8) - 14.1) < 0.2, "grind 8 runs at ~14 s pace")
	for f in DirAccess.get_files_at("res://data/recipes"):  # every recipe's targets are reachable together
		if f.ends_with(".json"):
			var rec := Model.load_recipe("res://data/recipes/" + f)
			check(Model.evaluate(rec, rec.dose_g, rec.grind_ideal, rec.target_yield_g).quality == 100, f + ": targets reachable")
	var kaw := r.duplicate()
	kaw.merge({"target_yield_g": 30, "extraction_time_min_s": 20, "extraction_time_max_s": 25}, true)
	check(Model.evaluate(kaw, 18, 5, 30).quality == 100, "order override targets reachable")
	# mentor: praise what went right, one fix, tone by score
	var shot := {"dose": 18.0, "grind": 8, "tamped": true, "yield": 34.4, "cup": "glass", "milk_temp": -1.0, "syrups": {}, "toppings": []}
	var note: String = Drink.evaluate(r, shot).tip
	check(note.begins_with("Good job") and note.contains("the dose and the yield") and note.contains("finer"),
		"user's shot: praise + grind fix (%s)" % note)
	shot.grind = 5
	shot.yield = 36.0
	check(Drink.evaluate(r, shot).tip.begins_with("Excellent work! Your measurements"), "perfect: pure praise")
	shot.dose = 15.0
	shot.tamped = false
	shot.grind = 9
	check(Drink.evaluate(r, shot).tip.begins_with("Not quite") and Drink.evaluate(r, shot).tip.contains("less coffee"),
		"poor: kind, one root-cause fix")
	var latte := Model.load_recipe("res://data/recipes/latte.json")
	var good := {"dose": 18, "grind": 5, "tamped": true, "yield": 36, "cup": "cup", "milk_temp": 62.0,
		"milk_foam": 0.3, "art": 0.9, "syrups": {}, "toppings": []}
	check(Drink.evaluate(latte, good).score == 100, "perfect latte = 100")
	var coarse := good.duplicate(true)
	coarse.grind = 8
	check(Drink.evaluate(latte, coarse).score < 90, "a coarse shot keeps a latte out of Excellent")


func iced_drinks() -> void:
	var iced := Model.load_recipe("res://data/recipes/iced_latte.json")
	var good := {"dose": 18, "grind": 5, "tamped": true, "yield": 36, "time": 27.5, "cup": "iced",
		"milk_temp": 5.0, "ice": true, "syrups": {}, "toppings": []}
	var r := Drink.evaluate(iced, good)
	check(r.grade == "Perfect Brew", "perfect iced latte (%s)" % r)
	var no_ice := good.duplicate(true)
	no_ice.ice = false
	check(Drink.evaluate(iced, no_ice).tip.contains("forgot the ice"), "iced latte without ice")
	var steamed := good.duplicate(true)
	steamed.milk_temp = 62.0
	check(Drink.evaluate(iced, steamed).tip.contains("cold milk"), "steamed milk in an iced drink")
	var latte := Model.load_recipe("res://data/recipes/latte.json")
	var hot := good.duplicate(true)
	hot.cup = "cup"
	hot.milk_temp = 62.0
	check(Drink.evaluate(latte, hot).accuracy < 100, "ice in a hot latte costs accuracy")


func days(tutorial: Dictionary) -> void:
	var daily := Model.load_recipe("res://data/orders/daily.json")
	var basics := ["double_espresso_training", "latte", "gula_melaka_latte"]
	check(DayPlan.unlocked(daily, 1) == basics, "level 1 menu = the tutorial drinks")
	check(DayPlan.unlocked(daily, 5).size() == daily.recipes.size(), "everything unlocked by level 5")
	var d2 := DayPlan.build(2, tutorial, daily, 2, basics)
	check(d2.orders.size() == 5, "day 2 has 5 orders")
	check(d2.orders[0].recipe == "iced_latte" and d2.orders[1].recipe == "cappuccino",
		"new level-2 recipes come first (%s, %s)" % [d2.orders[0].recipe, d2.orders[1].recipe])
	check(d2.orders[0].intro.size() > 1, "new recipe comes with mentor lines")
	check(DayPlan.build(2, tutorial, daily, 2, basics) == d2, "day plan is deterministic")
	check(d2.patience_s < DayPlan.PATIENCE_S, "less patience on day 2")
	var low := DayPlan.build(2, tutorial, daily, 1, basics)
	for o in low.orders:
		check(o.recipe in basics, "level 1 only orders basics")
	var d6 := DayPlan.build(6, tutorial, daily, 5, daily.recipes)
	check(d6.orders.size() == 8, "day 6 is capped at 8 orders")
	var pairs := 0
	var vague := 0
	var taught := 0
	for day in range(3, 12):
		for o in DayPlan.build(day, tutorial, daily, 5, daily.recipes).orders:
			check(daily.lines.has(o.recipe), "known recipe " + o.recipe)
			check(tutorial.cast.has(o.customer), "known customer " + o.customer)
			pairs += int(o.count == 2)
			if o.count == 2:
				check(o.intro[0][1].begins_with("Two "), "pair order asks for two")
			if o.vague:
				vague += 1
				check(o.intro[0][1] in DayPlan.recipe(o.recipe).riddles, "vague order uses a riddle")
				check(o.count == 1 and not o.has("recipe_overrides"), "vague orders are single, no kaw")
	check(pairs > 0, "some two-drink orders from day 3")
	check(vague > 0, "some vague orders")
	for o in DayPlan.build(4, tutorial, daily, 5, daily.recipes).orders:  # "_vague" not seen yet
		taught += int(o.vague and o.intro.size() > 1)
	check(taught <= 1, "the vague-order tip is shown at most once a day")
	for o in d2.orders:
		check(o.count == 1, "no pairs on day 2")


func friends() -> void:
	var stories := Model.load_recipe("res://data/orders/stories.json")
	var d := Save.fresh()
	check(Friends.take_beat(d, "MAKCIK", stories).is_empty(), "no story before any hearts")
	Friends.reward(d, "MAKCIK", "Perfect Brew", stories)
	Friends.reward(d, "MAKCIK", "Good Effort", stories)
	check(Friends.hearts(d, "MAKCIK", stories) == 1, "4 points = 1 heart")
	var beat := Friends.take_beat(d, "MAKCIK", stories)
	check(not beat.is_empty() and d.story_seen.MAKCIK == 1, "first story beat unlocked")
	check(Friends.take_beat(d, "MAKCIK", stories).is_empty(), "a beat plays once")
	check(Friends.tip_multiplier(d, "MAKCIK", stories) > 1.0, "friends tip more")
	Friends.reward(d, "MENTOR", "Perfect Brew", stories)
	check(not d.friends.has("MENTOR"), "only regulars collect friendship")
	for role in stories.beats:
		for b in stories.beats[role]:
			for line in b:
				check(line[0] in ["CHOICE", "MENTOR", role], "story speaker " + str(line[0]))


func more_drinks() -> void:
	var good := {"dose": 18, "grind": 5, "tamped": true, "yield": 36, "time": 27.5, "cup": "cup",
		"milk_temp": 62.0, "milk_foam": 0.6, "syrups": {}, "toppings": ["cocoa"], "art": 1.0}
	var capp := Model.load_recipe("res://data/recipes/cappuccino.json")
	check(Drink.evaluate(capp, good).grade == "Perfect Brew", "perfect cappuccino")
	var flat := good.duplicate(true)
	flat.milk_foam = 0.3
	check(Drink.evaluate(capp, flat).tip.contains("too flat"), "cappuccino needs more foam")
	var wonky := good.duplicate(true)
	wonky.art = 0.2
	check(Drink.evaluate(capp, wonky).tip.contains("lopsided"), "bad latte art diagnosed")
	check(Drink.evaluate(capp, wonky).quality < Drink.evaluate(capp, good).quality, "latte art counts")
	var kopi := Model.load_recipe("res://data/recipes/kopi_susu_ais.json")
	var k := {"dose": 18, "grind": 5, "tamped": true, "yield": 36, "time": 27.5, "cup": "iced",
		"milk_temp": -1.0, "ice": true, "syrups": {"condensed_milk": 2}, "toppings": []}
	check(Drink.evaluate(kopi, k).grade == "Perfect Brew", "perfect kopi susu ais")
	var with_milk := k.duplicate(true)
	with_milk.milk_temp = 5.0
	check(Drink.evaluate(kopi, with_milk).tip.contains("didn't ask for milk"), "no fresh milk in kopi susu")
	var dd := Save.fresh()
	dd.money = 50
	check(Save.buy_decor(dd, "plants") and dd.money == 10 and "plants" in dd.decor, "buy decor")
	check(not Save.buy_decor(dd, "plants"), "decor bought once")
	check(not Save.buy_decor(dd, "neon"), "decor needs money")


func drinks() -> void:
	var latte := Model.load_recipe("res://data/recipes/latte.json")
	var good := {"dose": 18, "grind": 5, "tamped": true, "yield": 36, "time": 27.5, "cup": "cup",
		"milk_temp": 62.0, "syrups": {}, "toppings": []}
	var r := Drink.evaluate(latte, good)
	check(r.grade == "Perfect Brew", "perfect latte (%s)" % r)
	var no_milk := good.duplicate(true)
	no_milk.milk_temp = -1.0
	check(Drink.evaluate(latte, no_milk).tip.contains("forgot the milk"), "latte without milk")
	var hot := good.duplicate(true)
	hot.milk_temp = 80.0
	check(Drink.evaluate(latte, hot).tip.contains("too hot"), "scalded milk")
	var foamy := good.duplicate(true)
	foamy.milk_foam = 0.9
	check(Drink.evaluate(latte, foamy).tip.contains("too foamy"), "over-aerated milk")
	var silky := good.duplicate(true)
	silky.milk_foam = 0.3
	check(Drink.evaluate(latte, silky).grade == "Perfect Brew", "silky milk stays perfect")
	var glass := good.duplicate(true)
	glass.cup = "glass"
	check(Drink.evaluate(latte, glass).tip.contains("Wrong cup"), "wrong cup")
	var gm := Model.load_recipe("res://data/recipes/gula_melaka_latte.json")
	var plain := Drink.evaluate(gm, good)
	check(plain.accuracy == 70 and plain.tip.contains("syrup") and plain.score == 70, "missing syrup and topping (%s)" % plain)
	var full := good.duplicate(true)
	full.syrups = {"gula_melaka": 2}
	full.toppings = ["cinnamon"]
	check(Drink.evaluate(gm, full).accuracy == 100, "gula melaka latte complete")


func saves() -> void:
	var d := Save.fresh()
	check(not Save.buy(d, "shot_timer"), "can't buy without money")
	d.money = 100
	check(Save.buy(d, "shot_timer") and d.money == 70 and d.upgrades.shot_timer == 1, "buy level 1")
	d.xp = 150
	check(Save.level(d) == 3 and is_equal_approx(Save.xp_progress(d), 0.5), "level from xp (60 per level)")
