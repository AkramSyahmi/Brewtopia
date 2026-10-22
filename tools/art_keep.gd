class_name ArtKeep
extends RefCounted
## Sprites replaced by real art (listed in assets/art/KEEP.txt by tools/import_art.gd).
## The placeholder generators skip these so they never overwrite real art.

const PATH := "res://assets/art/KEEP.txt"


static func names() -> Array:
	var path := ProjectSettings.globalize_path(PATH)
	if not FileAccess.file_exists(path):
		return []
	return Array(FileAccess.get_file_as_string(path).split("\n")).map(func(l): return l.strip_edges()).filter(
		func(l): return l != "" and not l.begins_with("#"))
