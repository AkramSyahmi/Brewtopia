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


## Scores one shot. Each part is 0-100; quality is their average.
## Flow is judged on the time the shot needs to reach the recipe yield,
## so stopping early is reported as a stop-point mistake, not a grind mistake.
static func evaluate(recipe: Dictionary, dose_g: float, grind: float, yield_g: float,
		tamped := true) -> Dictionary:
	var flow := flow_rate(recipe, dose_g, grind, tamped)
	var t_min: float = recipe.extraction_time_min_s
	var t_max: float = recipe.extraction_time_max_s
	var projected_time: float = recipe.target_yield_g / flow
	var ratio := yield_g / maxf(dose_g, 0.1)
	var target_ratio: float = recipe.target_yield_g / recipe.dose_g
	var dose_diff: float = dose_g - recipe.dose_g
	var time_off := maxf(maxf(t_min - projected_time, projected_time - t_max), 0.0)

	var dose_score := clampf(100.0 - 25.0 * absf(dose_diff), 0.0, 100.0)
	var ratio_score := clampf(100.0 - 150.0 * absf(ratio - target_ratio), 0.0, 100.0)
	var flow_score := clampf(100.0 - 10.0 * time_off, 0.0, 100.0)
	var quality := roundi((dose_score + ratio_score + flow_score) / 3.0)

	var tip: String
	if dose_diff < -1.0:
		tip = "You used less coffee than the recipe asked for. Try measuring more carefully."
	elif dose_diff > 1.0:
		tip = "You used more coffee than the recipe asked for. Try measuring more carefully."
	elif not tamped:
		tip = "You forgot to tamp. Loose grounds let the water rush through. Tamp before brewing."
	elif projected_time < t_min:
		tip = "The shot ran faster than this recipe's target. Try grinding a little finer."
	elif projected_time > t_max:
		tip = "The shot ran slowly. Your grind might be too fine. Try a little coarser."
	elif ratio < target_ratio - 0.2:
		tip = "You stopped the shot too early. Let it run closer to %d g." % recipe.target_yield_g
	elif ratio > target_ratio + 0.2:
		tip = "You let the shot run too long. Stop closer to %d g." % recipe.target_yield_g
	else:
		tip = "Great consistency. You reached a good dose-to-yield ratio for today's recipe."

	return {
		"quality": quality,
		"grade": grade(quality),
		"tip": tip,
		"projected_time_s": projected_time,
		"ratio": ratio,
		"parts": {"dose": dose_score, "ratio": ratio_score, "flow": flow_score},
	}


## GDD 7.1: weighted order score from quality, accuracy and service (each 0-100).
static func order_score(quality: float, accuracy: float, service: float) -> int:
	return roundi(0.7 * quality + 0.2 * accuracy + 0.1 * service)


static func grade(score: int) -> String:
	if score >= 90: return "Perfect Brew"
	if score >= 75: return "Great Cup"
	if score >= 60: return "Good Effort"
	if score >= 40: return "Needs Practice"
	return "Failed Order"
