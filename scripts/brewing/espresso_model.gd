class_name EspressoModel
extends RefCounted
## Simplified, deterministic espresso model for teaching. Not real coffee chemistry.
## Grinder scale: 1 = finest, 10 = coarsest.

const GRIND_STEP_FACTOR := 1.25  # each step coarser makes the shot run 25% faster
const UNTAMPED_FACTOR := 1.6  # loose grounds let water rush through (channeling)


static func load_recipe(path: String) -> Dictionary:
	var data = JSON.parse_string(FileAccess.get_file_as_string(path))
	return data if data is Dictionary else {}


## Simulated espresso flow in grams per simulated second.
static func flow_rate(recipe: Dictionary, dose_g: float, grind: float, tamped := true) -> float:
	var target_time: float = (recipe.extraction_time_min_s + recipe.extraction_time_max_s) / 2.0
	var target_flow: float = recipe.target_yield_g / target_time
	var grind_factor := pow(GRIND_STEP_FACTOR, grind - recipe.grind_ideal)
	var dose_factor := pow(recipe.dose_g / maxf(dose_g, 1.0), 1.5)  # more coffee resists more
	var tamp_factor := 1.0 if tamped else UNTAMPED_FACTOR
	return target_flow * grind_factor * dose_factor * tamp_factor


## The shot's pace: seconds it takes to reach the recipe yield with this grind and
## tamping at the recipe dose. This is what the time part judges, so a dose mistake is
## only charged in the dose part (the real flow, which the dose does change, is used for
## the shot itself), and stopping early is a stop-point mistake, not a grind one.
static func pace_s(recipe: Dictionary, grind: float, tamped := true) -> float:
	return recipe.target_yield_g / flow_rate(recipe, recipe.dose_g, grind, tamped)


## Shot quality = weighted parts, each 0-100 and full marks inside the green zone the
## station shows for it (grind and tamping act only through the time, so they are not
## counted twice). Small misses cost a little, larger ones more, with a floor on time so
## one slow/fast shot never wipes out an otherwise good drink.
const W_DOSE := 0.2  # grinder bubble green: within DOSE_OK_G of the recipe
const W_YIELD := 0.4  # shot bar green: within the green zone (+/- green_g)
const W_TIME := 0.40  # projected time to the target yield inside the recipe window
const DOSE_OK_G := 0.5


static func dose_part(diff_g: float) -> float:
	var d := absf(diff_g)
	return 100.0 if d <= DOSE_OK_G else clampf(100.0 - 20.0 * (d - DOSE_OK_G), 0.0, 100.0)


## Green zone = 100; the station's "Good" band (up to 2.5x the green zone) eases to 70;
## beyond that ("Bad" on the shot bar) it falls 25 per gram.
static func yield_part(off_g: float, green_g: float) -> float:
	var o := absf(off_g)
	if o <= green_g:
		return 100.0
	if o <= green_g * 2.5:
		return 100.0 - 30.0 * (o - green_g) / (green_g * 1.5)
	return maxf(70.0 - 25.0 * (o - green_g * 2.5), 0.0)


## Seconds outside the recipe window: 3 per second for the first 2, then 6 per second,
## then 4 per second down to a floor of 10.
static func time_part(off_s: float) -> float:
	if off_s <= 0.0:
		return 100.0
	if off_s <= 2.0:
		return 100.0 - 3.0 * off_s
	if off_s <= 8.0:
		return 94.0 - 6.0 * (off_s - 2.0)
	return maxf(58.0 - 4.0 * (off_s - 8.0), 10.0)


## Scores one shot (see the parts above). The time part uses pace_s() (grind + tamping).
## `green_g` = the shot bar's green half-width (the Shot Timer upgrade widens it).
static func evaluate(recipe: Dictionary, dose_g: float, grind: float, yield_g: float,
		tamped := true, green_g := 2.0) -> Dictionary:
	var t_min: float = recipe.extraction_time_min_s
	var t_max: float = recipe.extraction_time_max_s
	var projected_time := pace_s(recipe, grind, tamped)
	var ratio := yield_g / maxf(dose_g, 0.1)
	var target_ratio: float = recipe.target_yield_g / recipe.dose_g
	var dose_diff: float = dose_g - recipe.dose_g
	var time_off := maxf(maxf(t_min - projected_time, projected_time - t_max), 0.0)

	var dose_score := dose_part(dose_diff)
	var ratio_score := yield_part(yield_g - float(recipe.target_yield_g), green_g)
	var flow_score := time_part(time_off)
	var quality := roundi(W_DOSE * dose_score + W_YIELD * ratio_score + W_TIME * flow_score)

	# What went wrong, in teaching order (root causes first), each with the quality points
	# it cost. "root" = it distorts everything after it (a clearly wrong dose, no tamping).
	var issues: Array = []
	if dose_score < 100.0:
		issues.append({"loss": W_DOSE * (100.0 - dose_score), "root": absf(dose_diff) > 1.0,
			"text": "You used %s coffee than the recipe asks for (%d g). Watch the grams bubble while you grind." % [
				"less" if dose_diff < 0.0 else "more", recipe.dose_g],
			"short": "Dose was %s the recipe amount." % ("below" if dose_diff < 0.0 else "above")})
	if not tamped:
		issues.append({"loss": W_TIME * (100.0 - flow_score), "root": true,
			"text": "You forgot to tamp. Loose grounds let the water rush through, so tamp before brewing.",
			"short": "The coffee wasn't tamped, so the water rushed through."})
	elif flow_score < 100.0:
		var much := flow_score < 80.0
		issues.append({"loss": W_TIME * (100.0 - flow_score), "root": false,
			"text": ("Your espresso ran %s (%d s, aim for %d–%d s). Try a finer grind next time." if projected_time < t_min
				else "Your espresso ran %s (%d s, aim for %d–%d s). Try a coarser grind next time.") % [
				("much too fast" if much else "a little fast") if projected_time < t_min else ("much too slowly" if much else "a little slowly"),
				roundi(projected_time), t_min, t_max],
			"short": "Extraction was %s %s than the recipe target." % ["much" if much else "a little", "faster" if projected_time < t_min else "slower"]})
	if ratio_score < 100.0:
		var early := yield_g < float(recipe.target_yield_g)
		issues.append({"loss": W_YIELD * (100.0 - ratio_score), "root": false,
			"text": ("You stopped the shot too early. Let it run closer to %d g." if early
				else "You let the shot run too long. Stop closer to %d g.") % recipe.target_yield_g,
			"short": "The shot was stopped too early." if early else "The shot ran past the target weight."})
	var tip := "Great consistency. You reached a good dose-to-yield ratio for today's recipe."
	if not issues.is_empty():
		tip = main_issue(issues).text

	return {
		"quality": quality,
		"grade": grade(quality),
		"tip": tip,
		"issues": issues,
		"projected_time_s": projected_time,
		"ratio": ratio,
		"parts": {"dose": dose_score, "ratio": ratio_score, "flow": flow_score},
	}


## The one issue to mention: a root cause if there is one, else the costliest.
static func main_issue(issues: Array) -> Dictionary:
	for i in issues:
		if i.root:
			return i
	var best: Dictionary = issues[0]
	for i in issues:
		if i.loss > best.loss:
			best = i
	return best


## GDD 7.1: weighted order score from quality, accuracy and service (each 0-100).
static func order_score(quality: float, accuracy: float, service: float) -> int:
	return roundi(0.7 * quality + 0.2 * accuracy + 0.1 * service)


## Grade keys (used by friendship points, customer reactions and sounds). A drink under
## 40 is a failed order and must be remade.
static func grade(score: int) -> String:
	if score >= 90: return "Perfect Brew"
	if score >= 80: return "Great Cup"
	if score >= 70: return "Good Effort"
	if score >= 40: return "Needs Practice"
	return "Failed Order"


## What the player sees: 90+ Excellent, 80+ Great, 70+ Good, 60+ Needs Improvement,
## under 60 Poor (under 40 is also a failed order).
static func grade_label(score: int) -> String:
	if score >= 90: return "Excellent"
	if score >= 80: return "Great"
	if score >= 70: return "Good"
	if score >= 60: return "Needs Improvement"
	return "Poor"
