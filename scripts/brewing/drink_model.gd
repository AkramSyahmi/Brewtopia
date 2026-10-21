class_name DrinkModel
extends RefCounted
## Scores a whole drink against its recipe: the espresso shot (EspressoModel), the milk
## temperature, and accuracy (right cup, milk, syrups, toppings). Deterministic.
##
## drink = {dose, grind, tamped, yield, time, cup, milk_temp (-1 = none), syrups {name: pumps},
##          toppings [names]}


static func milk_score(recipe: Dictionary, temp: float) -> float:
	if temp < 0.0:
		return 0.0
	var off := maxf(maxf(recipe.milk.temp_min - temp, temp - recipe.milk.temp_max), 0.0)
	return clampf(100.0 - 8.0 * off, 0.0, 100.0)


static func evaluate(recipe: Dictionary, drink: Dictionary) -> Dictionary:
	var shot := EspressoModel.evaluate(recipe, drink.dose, drink.grind, drink.yield, drink.get("tamped", true))
	var quality: float = shot.quality
	var wants_milk := recipe.has("milk")
	var temp: float = drink.get("milk_temp", -1.0)
	if wants_milk:
		quality = (shot.quality * 2.0 + milk_score(recipe, temp)) / 3.0

	var accuracy := 100.0
	var accuracy_tip := ""
	var want_cup: String = recipe.get("cup", "glass")
	if drink.get("cup", want_cup) != want_cup:
		accuracy -= 30.0
		accuracy_tip = "Wrong cup! %s goes in a %s." % [recipe.display_name, "latte cup" if want_cup == "cup" else "glass"]
	if wants_milk and temp < 0.0:
		accuracy -= 40.0
		accuracy_tip = "You forgot the milk. A %s needs steamed milk on top of the espresso." % recipe.display_name
	elif not wants_milk and temp >= 0.0:
		accuracy -= 20.0
		accuracy_tip = "This order didn't ask for milk."
	var want_syrups: Dictionary = recipe.get("syrups", {})
	var got_syrups: Dictionary = drink.get("syrups", {})
	for s in want_syrups.keys() + got_syrups.keys():
		var diff := absi(int(want_syrups.get(s, 0)) - int(got_syrups.get(s, 0)))
		if diff > 0 and accuracy_tip == "":
			accuracy_tip = "The syrup was off: the recipe asks for %s." % describe_syrups(want_syrups)
		accuracy -= 10.0 * diff
	var want_tops: Array = recipe.get("toppings", [])
	var got_tops: Array = drink.get("toppings", [])
	for t in want_tops:
		if not t in got_tops:
			accuracy -= 10.0
			if accuracy_tip == "":
				accuracy_tip = "You forgot the %s on top." % t.replace("_", " ")
	for t in got_tops:
		if not t in want_tops:
			accuracy -= 10.0
	accuracy = clampf(accuracy, 0.0, 100.0)

	var tip: String = shot.tip
	if accuracy_tip != "":
		tip = accuracy_tip
	elif wants_milk and milk_score(recipe, temp) < minf(shot.quality, 99.0):
		if temp < recipe.milk.temp_min:
			tip = "The milk was too cool (%d°C). Steam it until the thermometer is in the green zone (%d–%d°C)." % [
				roundi(temp), recipe.milk.temp_min, recipe.milk.temp_max]
		else:
			tip = "The milk was too hot (%d°C). Overheated milk tastes flat. Stop in the green zone (%d–%d°C)." % [
				roundi(temp), recipe.milk.temp_min, recipe.milk.temp_max]

	# A drink missing ingredients is the wrong drink, so accuracy scales the whole score
	# (playtest change from the GDD 7.1 weights, where accuracy was only 20%).
	var score := roundi(quality * accuracy / 100.0)
	return {
		"quality": roundi(quality),
		"accuracy": roundi(accuracy),
		"score": score,
		"grade": EspressoModel.grade(score),
		"tip": tip,
	}


static func describe_syrups(syrups: Dictionary) -> String:
	if syrups.is_empty():
		return "no syrup"
	var parts := []
	for s in syrups:
		parts.append("%d pump%s of %s" % [syrups[s], "" if syrups[s] == 1 else "s", s.replace("_", " ")])
	return ", ".join(parts)
