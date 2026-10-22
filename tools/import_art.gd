extends SceneTree
## Drops new art into the game (see ART_LIST.md). Put images in the inbox folder named
## after the sprite they replace (e.g. machine.png, grinder.jpg, station_bg.webp), then run:
##   Godot_console.exe --headless --path . --script res://tools/import_art.gd -- [inbox]
## (default inbox: ../art_inbox next to the Game folder), then `--import`.
## For each image:
##  - objects: a plain background (same colour in all 4 corners, e.g. AI white) is made
##    transparent, the picture is cropped to its content, scaled to fit the sprite's size
##    (nearest filter, crisp pixels) and placed bottom-centre (things stand on the counter);
##  - backgrounds (*_bg): scaled to cover 640x360 and centre-cropped.
## The result replaces assets/art/<name>.png, the name is added to assets/art/KEEP.txt (so
## the placeholder generators never overwrite it), the source is noted in
## assets/art/CREDITS.md (fill in where it came from), and the original moves to inbox/done/.

const ART := "res://assets/art/"
const KEY_TOLERANCE := 0.12  # how close to the corner colour counts as background


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var inbox: String = args[0] if args.size() > 0 else ProjectSettings.globalize_path("res://").path_join("../art_inbox")
	inbox = inbox.simplify_path()
	if not DirAccess.dir_exists_absolute(inbox):
		DirAccess.make_dir_recursive_absolute(inbox)
		print("Created the inbox folder: %s. Put images in it and run again." % inbox)
		quit()
		return
	DirAccess.make_dir_recursive_absolute(inbox.path_join("done"))
	var done := 0
	for file in DirAccess.get_files_at(inbox):
		if not file.get_extension().to_lower() in ["png", "jpg", "jpeg", "webp"]:
			continue
		var sprite_name := file.get_basename()
		var target := ProjectSettings.globalize_path(ART + sprite_name + ".png")
		if not FileAccess.file_exists(target):
			print("SKIP %s: no sprite called %s.png in assets/art (check ART_LIST.md for names)" % [file, sprite_name])
			continue
		var old := Image.load_from_file(target)
		var img := Image.load_from_file(inbox.path_join(file))
		if img == null or old == null:
			print("SKIP %s: could not read the image" % file)
			continue
		img.convert(Image.FORMAT_RGBA8)
		var size := Vector2i(old.get_width(), old.get_height())
		var out := fit_background(img, size) if sprite_name.ends_with("_bg") else fit_object(img, size)
		out.save_png(target)
		keep(sprite_name)
		credit(sprite_name, file)
		DirAccess.rename_absolute(inbox.path_join(file), inbox.path_join("done").path_join(file))
		print("OK   %s -> assets/art/%s.png (%dx%d)" % [file, sprite_name, size.x, size.y])
		done += 1
	print("%d image(s) imported. Now run --import, then note each source in assets/art/CREDITS.md." % done)
	quit()


## Background: scale to cover the target size, then centre-crop.
func fit_background(img: Image, size: Vector2i) -> Image:
	var s := maxf(float(size.x) / img.get_width(), float(size.y) / img.get_height())
	img.resize(maxi(roundi(img.get_width() * s), size.x), maxi(roundi(img.get_height() * s), size.y), Image.INTERPOLATE_NEAREST)
	var x := (img.get_width() - size.x) / 2
	var y := (img.get_height() - size.y) / 2
	return img.get_region(Rect2i(x, y, size.x, size.y))


## Object: key out a plain background, crop to content, fit inside the target size and
## place it bottom-centre on a transparent canvas.
func fit_object(img: Image, size: Vector2i) -> Image:
	var w := img.get_width()
	var h := img.get_height()
	var corners := [img.get_pixel(0, 0), img.get_pixel(w - 1, 0), img.get_pixel(0, h - 1), img.get_pixel(w - 1, h - 1)]
	var key: Color = corners[0]
	var plain := key.a > 0.9
	for c in corners:
		plain = plain and close(c, key)
	if plain:
		for y in h:
			for x in w:
				if close(img.get_pixel(x, y), key):
					img.set_pixel(x, y, Color(0, 0, 0, 0))
	var used := img.get_used_rect()
	if used.size.x > 0 and used.size.y > 0:
		img = img.get_region(used)
	var s := minf(float(size.x) / img.get_width(), float(size.y) / img.get_height())
	img.resize(maxi(1, roundi(img.get_width() * s)), maxi(1, roundi(img.get_height() * s)), Image.INTERPOLATE_NEAREST)
	var out := Image.create_empty(size.x, size.y, false, Image.FORMAT_RGBA8)
	out.blit_rect(img, Rect2i(Vector2i.ZERO, img.get_size()), Vector2i((size.x - img.get_width()) / 2, size.y - img.get_height()))
	return out


func close(a: Color, b: Color) -> bool:
	return absf(a.r - b.r) + absf(a.g - b.g) + absf(a.b - b.b) < KEY_TOLERANCE * 3.0


func keep(sprite_name: String) -> void:
	var path := ProjectSettings.globalize_path(ART + "KEEP.txt")
	var names: Array = ArtKeep.names()
	if sprite_name in names:
		return
	names.append(sprite_name)
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string("# Sprites replaced by real art; the placeholder generators skip these.\n" + "\n".join(names) + "\n")


func credit(sprite_name: String, file: String) -> void:
	var path := ProjectSettings.globalize_path(ART + "CREDITS.md")
	var text := FileAccess.get_file_as_string(path) if FileAccess.file_exists(path) else \
		"# Art credits\n\nWhere every replaced image came from (AI tool + plan, asset pack + licence, or who drew it).\n\n| Sprite | Source file | Source / licence |\n|---|---|---|\n"
	if text.contains("| %s |" % sprite_name):
		return
	text += "| %s | %s | TODO: fill in |\n" % [sprite_name, file]
	FileAccess.open(path, FileAccess.WRITE).store_string(text)
