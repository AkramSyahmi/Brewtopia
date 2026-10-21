extends SceneTree
## Run: Godot_console.exe --headless --path . --script res://tests/test_espresso_model.gd

const Model = preload("res://scripts/brewing/espresso_model.gd")
const Rewards = preload("res://scripts/economy/shift_rewards.gd")

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
	check(s.tips_rm == 8 and s.average == 75 and s.xp == 22 and s.wage_rm == 40, "shift summary %s" % s)

	var shift := Model.load_recipe("res://data/orders/ch1_first_shift.json")
	check(shift.orders.size() == 3, "shift has 3 orders")
	for o in shift.orders:
		check(shift.cast.has(o.customer), "cast has " + o.customer)
		for line in o.intro:
			check(shift.cast.has(line[0]), "cast has speaker " + line[0])
	for g in ["Perfect Brew", "Great Cup", "Good Effort", "Needs Practice"]:
		check(shift.reactions.has(g), "reaction for " + g)

	print("PASS" if failures == 0 else "%d FAILED" % failures)
	quit(failures)
