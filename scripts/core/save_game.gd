class_name SaveGame
extends RefCounted
## Player progress saved to user://brewtopia_save.json: money, XP, level, day and
## upgrade levels. Missing or broken saves fall back to a fresh game.

## Where the save lives. Test scripts point this at user://test_save.json so they never
## touch the player's real save.
static var path := "user://brewtopia_save.json"
const XP_PER_LEVEL := 60  # about one level per day early on (recipes unlock by level)

## Upgrades bought with wages (GCGC-style machine stats). Each has 3 levels.
const UPGRADES := {
	"shot_timer": {"name": "Shot Timer Pro", "stat": "Accuracy",
		"desc": "Wider green zone on the shot timing bar.", "costs": [30, 60, 100]},
	"steam_control": {"name": "Steam Control", "stat": "Steam Control",
		"desc": "Milk heats more slowly, so it's easier to stop in the green zone.", "costs": [30, 60, 100]},
	"tip_jar": {"name": "Bigger Tip Jar", "stat": "Tips",
		"desc": "Customers tip 25% more per level.", "costs": [40, 80, 120]},
}


## Café decorations: each one shows up in the café and makes customers tip more.
const DECOR := {
	"plants": {"name": "Potted Plant", "desc": "A big leafy plant by the window.", "cost": 40},
	"lamps": {"name": "Pendant Lamps", "desc": "Warm lamps over the counter.", "cost": 60},
	"batik": {"name": "Batik Wall Art", "desc": "A colourful batik panel on the wall.", "cost": 80},
	"bookshelf": {"name": "Book Corner", "desc": "A shelf of books for regulars.", "cost": 100},
	"neon": {"name": "Neon Sign", "desc": "A glowing BREWTOPIA sign.", "cost": 150},
}
const DECOR_TIP_BONUS := 0.05  # +5% tips per decoration


static func fresh() -> Dictionary:
	return {"money": 0, "xp": 0, "day": 1, "upgrades": {"shot_timer": 0, "steam_control": 0, "tip_jar": 0},
		"friends": {}, "story_seen": {}, "decor": [], "recipes_seen": [], "finale_seen": false}


static func load_save() -> Dictionary:
	var data := fresh()
	if FileAccess.file_exists(path):
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
		if parsed is Dictionary:
			for k in ["money", "xp", "day"]:
				data[k] = maxi(int(parsed.get(k, data[k])), 0)
			var ups: Dictionary = parsed.get("upgrades", {}) if parsed.get("upgrades") is Dictionary else {}
			for u in UPGRADES:
				data.upgrades[u] = clampi(int(ups.get(u, 0)), 0, 3)
			for k in ["friends", "story_seen"]:  # {role: int}
				if parsed.get(k) is Dictionary:
					for role in parsed[k]:
						data[k][str(role)] = maxi(int(parsed[k][role]), 0)
			if parsed.get("decor") is Array:
				data.decor = parsed.decor.filter(func(d): return DECOR.has(d))
			data.finale_seen = parsed.get("finale_seen") == true  # the farewell and credits played (all four stories done)
			if parsed.get("recipes_seen") is Array:
				data.recipes_seen = parsed.recipes_seen.map(func(r): return str(r))
	data.day = maxi(data.day, 1)
	return data


static func exists() -> bool:
	return FileAccess.file_exists(path)


## New game: removes the save so the next load starts fresh.
static func reset() -> void:
	if exists():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


static func buy_decor(data: Dictionary, id: String) -> bool:
	if not DECOR.has(id) or id in data.decor or data.money < DECOR[id].cost:
		return false
	data.money -= DECOR[id].cost
	data.decor.append(id)
	return true


## Writes to a temp file first, then swaps it in, so a crash can't corrupt the save.
static func write(data: Dictionary) -> void:
	var tmp := path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify(data))
	f.close()
	DirAccess.rename_absolute(ProjectSettings.globalize_path(tmp), ProjectSettings.globalize_path(path))


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
