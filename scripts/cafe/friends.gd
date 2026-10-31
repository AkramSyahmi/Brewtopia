class_name Friends
extends RefCounted
## Friendship with the regular customers (data/orders/stories.json). Good drinks earn
## points; every heart (points threshold) unlocks the next story beat, played the next
## time that customer comes in, and makes them tip a little more.


static func hearts(save: Dictionary, role: String, stories: Dictionary) -> int:
	var points: int = save.friends.get(role, 0)
	var n := 0
	for at in stories.hearts_at:
		if points >= int(at):
			n += 1
	return n


## Adds friendship points for a drink of `grade`; returns the hearts after.
static func reward(save: Dictionary, role: String, grade: String, stories: Dictionary) -> int:
	if stories.beats.has(role):
		save.friends[role] = int(save.friends.get(role, 0)) + int(stories.points.get(grade, 0))
	return hearts(save, role, stories)


## The next story beat earned but not seen yet ([] if none). Marks it as seen.
static func take_beat(save: Dictionary, role: String, stories: Dictionary) -> Array:
	if not stories.beats.has(role):
		return []
	var seen: int = save.story_seen.get(role, 0)
	if seen >= hearts(save, role, stories) or seen >= stories.beats[role].size():
		return []
	save.story_seen[role] = seen + 1
	return stories.beats[role][seen]


## Every regular's story has been told to the end (the finale can play).
static func all_stories_done(save: Dictionary, stories: Dictionary) -> bool:
	for role in stories.beats:
		if int(save.story_seen.get(role, 0)) < stories.beats[role].size():
			return false
	return true


static func tip_multiplier(save: Dictionary, role: String, stories: Dictionary) -> float:
	return 1.0 + float(stories.tip_bonus_per_heart) * hearts(save, role, stories)
