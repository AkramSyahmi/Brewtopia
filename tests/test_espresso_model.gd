extends SceneTree
## Run: Godot_console.exe --headless --path . --script res://tests/test_espresso_model.gd

const Model = preload("res://scripts/brewing/espresso_model.gd")

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

	print("PASS" if failures == 0 else "%d FAILED" % failures)
	quit(failures)
