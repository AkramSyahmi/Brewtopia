class_name ShiftRewards
extends RefCounted
## Illustrative game-balance wages, tips and XP (GDD 7.5). Not real-world figures.


static func tip_rm(score: int) -> int:
	if score >= 90: return 5
	if score >= 75: return 3
	if score >= 60: return 1
	return 0


static func summary(scores: Array, wage_rm: int) -> Dictionary:
	var tips := 0
	var total := 0
	for s in scores:
		tips += tip_rm(s)
		total += s
	return {
		"orders": scores.size(),
		"average": roundi(float(total) / maxi(scores.size(), 1)),
		"wage_rm": wage_rm,
		"tips_rm": tips,
		"xp": int(total / 5.0),  # about one level per day of good service
	}
