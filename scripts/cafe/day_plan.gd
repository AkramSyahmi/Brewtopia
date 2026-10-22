class_name DayPlan
extends RefCounted
## Builds the orders for day 2 onwards (day 1 is the scripted tutorial). Same shape as
## data/orders/ch1_first_shift.json, so CafeShift plays it the same way. Deterministic
## per day (seeded RNG), driven by data/orders/daily.json and each recipe's
## `unlock_level` / `riddles`:
##  - more customers each day (4 + day - 1, up to 8) and less patience,
##  - recipes unlock by player level; one the player hasn't seen yet is ordered first,
##    with the mentor explaining it,
##  - some customers describe their drink instead of naming it ("vague" orders): the
##    player works out the recipe (first time: the mentor explains),
##  - from day 3, some customers order two of the same drink (one for a friend),
##  - the Coffee Lover asks for a "kaw" (shorter, stronger) espresso.

const MAX_ORDERS := 8
const PAIR_FROM_DAY := 3
const PAIR_CHANCE := 0.3
const VAGUE_CHANCE := 0.35
const PATIENCE_S := 150.0  # day 1; drops 8% a day down to half
const RECIPE_PATH := "res://data/recipes/%s.json"


static func patience_s(day: int) -> float:
	return PATIENCE_S * maxf(0.5, 1.0 - 0.08 * (day - 1))


static func recipe(id: String) -> Dictionary:
	return EspressoModel.load_recipe(RECIPE_PATH % id)


## Recipe ids available at `level`, in menu order.
static func unlocked(daily: Dictionary, level: int) -> Array[String]:
	var ids: Array[String] = []
	for id in daily.recipes:
		if int(recipe(id).get("unlock_level", 1)) <= level:
			ids.append(id)
	return ids


## `seen` = recipe ids the player has already been taught (plus "_vague" once the
## vague-order tip was shown).
static func build(day: int, tutorial: Dictionary, daily: Dictionary, level: int, seen: Array) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = day * 7919
	var plan := {
		"shift_id": "day_%d" % day,
		"wage_rm": int(daily.wage_rm) + 5 * (day - 2),
		"cast": tutorial.cast,
		"sprites": tutorial.sprites,
		"reactions": tutorial.reactions,
		"patience_s": patience_s(day),
		"orders": [],
	}
	var recipes := unlocked(daily, level)
	var regulars: Array = daily.regulars
	var last := ""
	var vague_taught := "_vague" in seen
	for i in mini(3 + day, MAX_ORDERS):
		var who: String = regulars[rng.randi() % regulars.size()]
		if who == last:
			who = regulars[(regulars.find(who) + 1) % regulars.size()]
		last = who
		var order := {"customer": who, "assist": "hints", "count": 1, "vague": false}
		var fresh := ""  # an unlocked recipe the player hasn't been taught yet
		for id in recipes:
			if not id in seen and not plan.orders.any(func(o): return o.recipe == id):
				fresh = id
				break
		order.recipe = fresh if fresh != "" else recipes[rng.randi() % recipes.size()]
		if fresh == "" and not plan.orders.is_empty() and order.recipe == plan.orders[-1].recipe:
			order.recipe = recipes[(recipes.find(order.recipe) + 1) % recipes.size()]  # no repeats in a row
		var lines: Array = daily.lines[order.recipe]
		var line: String = lines[rng.randi() % lines.size()]
		var roll := rng.randf()
		if fresh == "" and day >= PAIR_FROM_DAY and roll < PAIR_CHANCE:
			order.count = 2
			line = daily.pair_line % (recipe(order.recipe).display_name + "s")
		elif fresh == "" and roll > 1.0 - VAGUE_CHANCE and recipe(order.recipe).has("riddles"):
			order.vague = true
			var riddles: Array = recipe(order.recipe).riddles
			line = riddles[rng.randi() % riddles.size()]
		if order.recipe == "double_espresso_training" and who == "COFFEE_ENTHUSIAST" and not order.vague:
			order.recipe_overrides = daily.kaw_overrides
			order.count = 1
			line = "Double espresso, kaw ya. Short and strong."
		order.intro = [[who, line]]
		if fresh != "":
			order.intro += daily.new_recipe_intro.get(fresh,
				[["MENTOR", daily.new_recipe_generic % recipe(fresh).display_name]])
		elif order.vague and not vague_taught:
			order.intro += daily.vague_intro
			vague_taught = true
		plan.orders.append(order)
	return plan
