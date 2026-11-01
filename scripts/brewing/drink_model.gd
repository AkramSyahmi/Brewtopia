class_name DrinkModel
extends RefCounted
## Scores a whole drink against its recipe: the espresso shot (EspressoModel), the milk
## temperature, and accuracy (right cup, milk, syrups, toppings). Deterministic.
##
## drink = {dose, grind, tamped, yield, time, cup, milk_temp (-1 = none), milk_foam (0..1,
##          optional), syrups {name: pumps}, toppings [names]}


## How far `v` is outside [lo, hi] (0 inside).
static func outside(v: float, lo: float, hi: float) -> float:
	return maxf(maxf(lo - v, v - hi), 0.0)


static func milk_score(recipe: Dictionary, temp: float, foam := -1.0) -> float:
	if temp < 0.0:
		return 0.0
	var score := 100.0 - 8.0 * outside(temp, recipe.milk.temp_min, recipe.milk.temp_max)
	if foam >= 0.0 and recipe.milk.has("foam_min"):
		score -= 150.0 * outside(foam, recipe.milk.foam_min, recipe.milk.foam_max)  # 0.1 off = -15
	return clampf(score, 0.0, 100.0)


## Latte art (pour accuracy 0..1) on the same bands as the latte art screen: 0.8+ is a
## "Beautiful rosetta" (100), 0.5+ a lopsided one (75-100), below that 40-75.
static func art_score(art: float) -> float:
	if art >= 0.8:
		return 100.0
	if art >= 0.5:
		return 75.0 + (art - 0.5) / 0.3 * 25.0
	return 40.0 + art / 0.5 * 35.0


static func evaluate(recipe: Dictionary, drink: Dictionary) -> Dictionary:
	var shot := EspressoModel.evaluate(recipe, drink.dose, drink.grind, drink.yield, drink.get("tamped", true),
		drink.get("green_g", 2.0))
	var quality: float = shot.quality
	var wants_milk := recipe.has("milk")
	var temp: float = drink.get("milk_temp", -1.0)
	var foam: float = drink.get("milk_foam", -1.0)
	var milk := milk_score(recipe, temp, foam) if wants_milk else 0.0
	var art: float = drink.get("art", -1.0)  # latte art 0..1 (only poured into ceramic cups)
	var has_art: bool = recipe.get("latte_art", false) and art >= 0.0
	if wants_milk:  # milk drinks: shot 60% + milk 40%, or shot 55% + milk 30% + latte art 15%
		quality = shot.quality * 0.55 + milk * 0.3 + art_score(art) * 0.15 if has_art else shot.quality * 0.6 + milk * 0.4

	var accuracy := 100.0
	var accuracy_tip := ""
	var accuracy_short := ""  # one line for the result screen
	var want_cup: String = recipe.get("cup", "glass")
	if drink.get("cup", want_cup) != want_cup:
		accuracy -= 30.0
		accuracy_tip = "Wrong cup! %s goes in a %s." % [recipe.display_name, {"cup": "latte cup", "glass": "glass", "iced": "plastic iced cup"}.get(want_cup, want_cup)]
		accuracy_short = "The drink was served in the wrong cup."
	if wants_milk and temp < 0.0:
		accuracy -= 40.0
		accuracy_tip = "You forgot the milk. A %s needs %s milk with the espresso." % [recipe.display_name, "cold" if recipe.get("ice", false) else "steamed"]
		accuracy_short = "The milk was missing."
	elif not wants_milk and temp >= 0.0:
		accuracy -= 20.0
		accuracy_tip = "This order didn't ask for milk."
		accuracy_short = "This drink shouldn't have milk."
	var wants_ice: bool = recipe.get("ice", false)
	if wants_ice and not drink.get("ice", false):
		accuracy -= 30.0
		if accuracy_tip == "":
			accuracy_tip = "You forgot the ice. Drop the cup on the ice bin at the bottom of the fridge."
			accuracy_short = "The ice was missing."
	elif not wants_ice and drink.get("ice", false):
		accuracy -= 20.0
		if accuracy_tip == "":
			accuracy_tip = "This one is a hot drink. No ice!"
			accuracy_short = "This drink shouldn't have ice."
	var want_syrups: Dictionary = recipe.get("syrups", {})
	var got_syrups: Dictionary = drink.get("syrups", {})
	for s in want_syrups.keys() + got_syrups.keys():
		var diff := absi(int(want_syrups.get(s, 0)) - int(got_syrups.get(s, 0)))
		if diff > 0 and accuracy_tip == "":
			accuracy_tip = "The syrup was off: the recipe asks for %s." % describe_syrups(want_syrups)
			accuracy_short = "The syrup didn't match the recipe."
		accuracy -= 10.0 * diff
	var want_tops: Array = recipe.get("toppings", [])
	var got_tops: Array = drink.get("toppings", [])
	for t in want_tops:
		if not t in got_tops:
			accuracy -= 10.0
			if accuracy_tip == "":
				accuracy_tip = "You forgot the %s on top." % t.replace("_", " ")
				accuracy_short = "The %s topping was missing." % t.replace("_", " ")
	for t in got_tops:
		if not t in want_tops:
			accuracy -= 10.0
			if accuracy_tip == "":
				accuracy_tip = "This recipe doesn't have %s on top. Check the order slip before the topping station." % t.replace("_", " ")
				accuracy_short = "A topping was added that the recipe doesn't use."
	accuracy = clampf(accuracy, 0.0, 100.0)

	# Everything that cost points, each with its cost in final-score points, so the mentor
	# can name the most useful single fix (see mentor_note).
	var shot_w := 1.0 if not wants_milk else (0.55 if has_art else 0.6)
	var issues: Array = []
	if accuracy_short == "" and accuracy < 100.0:
		accuracy_short = "The drink didn't match the recipe."
	if accuracy_tip != "":  # the wrong drink matters most
		issues.append({"loss": quality * (100.0 - accuracy) / 100.0, "root": true, "text": accuracy_tip, "short": accuracy_short})
	for i: Dictionary in shot.issues:
		issues.append({"loss": i.loss * shot_w, "root": i.root, "text": i.text, "short": i.short})
	if wants_milk and temp >= 0.0 and milk < 100.0:
		var milk_tip: String
		var milk_short: String
		var slightly := "slightly" if outside(temp, recipe.milk.temp_min, recipe.milk.temp_max) <= 3.0 else "well"
		if wants_ice and temp > recipe.milk.temp_max:
			milk_tip = "Iced drinks use cold milk straight from the fridge. Milk warmed to %d°C melts the ice!" % roundi(temp)
			milk_short = "Warm milk went into an iced drink."
		elif outside(temp, recipe.milk.temp_min, recipe.milk.temp_max) == 0.0:
			milk_tip = "The milk was %s. Keep the froth marker in the green zone: pitcher low adds air, high only heats." % (
				"too flat" if foam < recipe.milk.foam_min else "too foamy")
			milk_short = "The milk foam was %s." % ("too thin" if foam < recipe.milk.foam_min else "too thick")
		elif temp < recipe.milk.temp_min:
			milk_tip = "The milk was too cool (%d°C). Steam it until the thermometer is in the green zone (%d–%d°C)." % [
				roundi(temp), recipe.milk.temp_min, recipe.milk.temp_max]
			milk_short = "Milk temperature was %s below the ideal range." % slightly
		else:
			milk_tip = "The milk was too hot (%d°C). Overheated milk tastes flat. Stop in the green zone (%d–%d°C)." % [
				roundi(temp), recipe.milk.temp_min, recipe.milk.temp_max]
			milk_short = "Milk temperature was %s above the ideal range." % slightly
		issues.append({"loss": (100.0 - milk) * (0.3 if has_art else 0.4), "root": false, "text": milk_tip, "short": milk_short})
	if has_art and art_score(art) < 100.0:
		var art_text := "The latte art came out lopsided. Tap when the pitcher is right over the middle of the cup."
		var art_short := "The latte art was off-centre."
		match drink.get("art_result", ""):  # the round ended without a pour (same score as the lowest pour)
			"skipped":
				art_text = "You skipped the latte art. Next time tap as the pitcher passes the middle of the cup."
				art_short = "The latte art was skipped."
			"timeout":
				art_text = "The latte art ran out of time. Tap as the pitcher passes the middle of the cup."
				art_short = "The latte art ran out of time."
		issues.append({"loss": (100.0 - art_score(art)) * 0.15, "root": false, "text": art_text, "short": art_short})

	# A drink missing ingredients is the wrong drink, so accuracy scales the whole score
	# (playtest change from the GDD 7.1 weights, where accuracy was only 20%).
	var score := roundi(quality * accuracy / 100.0)
	var strengths: Array[String] = []  # what the player got right, for the mentor's praise
	if shot.parts.dose == 100.0:
		strengths.append("the dose")
	if shot.parts.ratio == 100.0:
		strengths.append("the yield")
	if shot.parts.flow == 100.0:
		strengths.append("the extraction time")
	if wants_milk and milk == 100.0:
		strengths.append("the milk")
	if has_art and art_score(art) == 100.0:
		strengths.append("the latte art")
	# Per-category scores for the result screen (only what this drink has).
	var breakdown: Array = [["Dose", shot.parts.dose], ["Yield", shot.parts.ratio], ["Extraction", shot.parts.flow]]
	if wants_milk:
		breakdown.append(["Milk", milk])
	if has_art:
		breakdown.append(["Latte art", art_score(art)])
	breakdown.append(["Recipe", accuracy])
	return {
		"quality": roundi(quality),
		"accuracy": roundi(accuracy),
		"score": score,
		"grade": EspressoModel.grade(score),
		"tip": mentor_note(score, strengths, issues),
		"breakdown": breakdown,
		"main": "" if issues.is_empty() else EspressoModel.main_issue(issues).short,  # the main penalty, one line
	}


## The mentor's note: praise for what went right, then the one fix that matters most,
## in a tone that matches the score. Built only from the recorded result.
static func mentor_note(score: int, strengths: Array[String], issues: Array) -> String:
	var fix: String = "" if issues.is_empty() else EspressoModel.main_issue(issues).text
	var praise := ""
	if strengths.size() >= 3 and fix != "" and issues.size() == 1 and EspressoModel.main_issue(issues).root:
		praise = "The coffee itself was spot on."  # only a recipe mistake (cup, syrup...)
	elif not strengths.is_empty():
		praise = "You nailed %s." % join_and(strengths)
	var parts: Array[String]
	if score >= 90:
		if fix == "":
			return "Excellent work! Your measurements and extraction were spot on. That's a lovely cup of coffee!"
		parts = ["Excellent work!", praise, "One small thing for next time: " + fix]
	elif score >= 80:
		parts = ["Great cup!", praise, fix]
	elif score >= 70:
		parts = ["Good job, you're getting the hang of it!", praise, fix]
	elif score >= 60:
		parts = ["Not bad, we're getting there.", praise, "The main thing to fix: " + fix]
	else:
		parts = ["Not quite there yet, but every barista starts here.", fix,
			"You did get %s right, so build on that." % join_and(strengths) if not strengths.is_empty() else ""]
	return " ".join(parts.filter(func(s: String): return s != ""))


static func join_and(items: Array[String]) -> String:
	if items.size() == 1:
		return items[0]
	return ", ".join(items.slice(0, items.size() - 1)) + " and " + items[-1]


static func describe_syrups(syrups: Dictionary) -> String:
	if syrups.is_empty():
		return "no syrup"
	var parts := []
	for s in syrups:
		parts.append("%d pump%s of %s" % [syrups[s], "" if syrups[s] == 1 else "s", s.replace("_", " ")])
	return ", ".join(parts)
