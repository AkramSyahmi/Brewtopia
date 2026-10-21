class_name SaveGame
extends RefCounted
## Player progress saved to user://brewtopia_save.json: money, XP, level, day and
## upgrade levels. Missing or broken saves fall back to a fresh game.

const PATH := "user://brewtopia_save.json"
const XP_PER_LEVEL := 100

## Upgrades bought with wages (GCGC-style machine stats). Each has 3 levels.
const UPGRADES := {
	"shot_timer": {"name": "Shot Timer Pro", "stat": "Accuracy",
		"desc": "Wider green zone on the shot timing bar.", "costs": [30, 60, 100]},
	"steam_control": {"name": "Steam Control", "stat": "Steam Control",
		"desc": "Milk heats more slowly, so it's easier to stop in the green zone.", "costs": [30, 60, 100]},
	"tip_jar": {"name": "Bigger Tip Jar", "stat": "Tips",
		"desc": "Customers tip 25% more per level.", "costs": [40, 80, 120]},
}


static func fresh() -> Dictionary:
	return {"money": 0, "xp": 0, "day": 1, "upgrades": {"shot_timer": 0, "steam_control": 0, "tip_jar": 0}}


static func load_save() -> Dictionary:
	var data := fresh()
	if FileAccess.file_exists(PATH):
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		if parsed is Dictionary:
			for k in ["money", "xp", "day"]:
				data[k] = maxi(int(parsed.get(k, data[k])), 0)
			var ups: Dictionary = parsed.get("upgrades", {}) if parsed.get("upgrades") is Dictionary else {}
			for u in UPGRADES:
				data.upgrades[u] = clampi(int(ups.get(u, 0)), 0, 3)
	data.day = maxi(data.day, 1)
	return data


## Writes to a temp file first, then swaps it in, so a crash can't corrupt the save.
static func write(data: Dictionary) -> void:
	var tmp := PATH + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify(data))
	f.close()
	DirAccess.rename_absolute(ProjectSettings.globalize_path(tmp), ProjectSettings.globalize_path(PATH))


static func level(data: Dictionary) -> int:
	return 1 + int(data.xp / XP_PER_LEVEL)


static func xp_progress(data: Dictionary) -> float:
	return float(int(data.xp) % XP_PER_LEVEL) / XP_PER_LEVEL


## Cost of the next level of an upgrade, or -1 when it is maxed out.
static func next_cost(data: Dictionary, upgrade: String) -> int:
	var lvl: int = data.upgrades[upgrade]
	var costs: Array = UPGRADES[upgrade].costs
	return costs[lvl] if lvl < costs.size() else -1


static func buy(data: Dictionary, upgrade: String) -> bool:
	var cost := next_cost(data, upgrade)
	if cost < 0 or data.money < cost:
		return false
	data.money -= cost
	data.upgrades[upgrade] += 1
	return true
