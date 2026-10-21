extends SceneTree
## Renders the placeholder pixel-art sprites listed in ART_LIST.md from the 3D props:
## front view, slight top-down angle, orthographic, flat 2-tone lighting, 1px outline,
## rendered straight at the sprite's pixel size (no AA) for crisp pixels.
## Run (needs a window, not --headless):
##   Godot_console.exe --path . --script res://tools/render_sprites.gd
## A sprite is skipped if a file of that name is marked as hand-made in KEEP below.

const OUT := "res://assets/art/"
const PITCH := -14.0
const KEEP := []  # file names (without .png) replaced by AI/pack art; never overwrite these

var jobs := []


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	jobs = [
		["grinder", Vector2i(96, 180), func(n): Props.grinder(n, Vector3.ZERO)],
		["machine", Vector2i(300, 290), func(n): Props.machine2(n)],
		["portafilter_empty", Vector2i(64, 40), func(n): pf(n, "empty")],
		["portafilter_dosed", Vector2i(64, 40), func(n): pf(n, "dosed")],
		["portafilter_tamped", Vector2i(64, 40), func(n): pf(n, "tamped")],
		["portafilter_used", Vector2i(64, 40), func(n): pf(n, "used")],
		["tamper", Vector2i(40, 56), func(n): Props.tamper(n)],
		["tamp_mat", Vector2i(150, 40), func(n): Props.tamp_mat(n, Vector3.ZERO)],
		["cup_espresso", Vector2i(36, 36), func(n): Props.shot_glass(n)],
		["cup_latte", Vector2i(56, 44), func(n): Props.cup(n)],
		["cups_rack", Vector2i(200, 70), func(n): Props.cups_rack(n)],
		["pitcher", Vector2i(60, 64), func(n): Props.pitcher(n, Vector3.ZERO)],
		["pitcher_rack", Vector2i(100, 110), func(n): Props.pitcher_rack(n)],
		["milk_fridge", Vector2i(70, 240), func(n): Props.milk_fridge(n)],
		["knock_box", Vector2i(56, 44), func(n): Props.knock_box(n, Vector3.ZERO)],
		["bean_bag", Vector2i(56, 70), func(n): Props.bean_bag(n)],
		["syrup_vanilla", Vector2i(44, 96), func(n): Props.syrup_bottle(n, Color("#F2E3B3"))],
		["syrup_caramel", Vector2i(44, 96), func(n): Props.syrup_bottle(n, Color("#C98B55"))],
		["syrup_chocolate", Vector2i(44, 96), func(n): Props.syrup_bottle(n, Color("#5A2F1A"))],
		["syrup_pandan", Vector2i(44, 96), func(n): Props.syrup_bottle(n, Color("#7DBF5A"))],
		["syrup_gula_melaka", Vector2i(44, 96), func(n): Props.syrup_bottle(n, Color("#8A4A22"))],
		["topping_cream", Vector2i(70, 50), func(n): Props.topping_box(n, Color("#FBF6EC"))],
		["topping_choc_chips", Vector2i(70, 50), func(n): Props.topping_box(n, Color("#4A2614"))],
		["topping_cinnamon", Vector2i(70, 50), func(n): Props.topping_box(n, Color("#A0623A"), false)],
		["counter_bg", Vector2i(640, 360), cafe_interior, {"pitch": -6.0, "zoom": 0.86}],
		["counter_front", Vector2i(640, 120), front_counter, {"pitch": -22.0, "zoom": 0.9}],
	]
	for who in Bar3D.LOOKS:
		for happy in [false, true]:
			var look: Dictionary = Bar3D.LOOKS[who].duplicate()
			look.happy = happy
			jobs.append(["char_%s%s" % [who, "_happy" if happy else ""], Vector2i(120, 170),
				func(n): Props.person(n, look), {"min_y": 0.72, "pitch": -4.0}])
	run.call_deferred()


## Café seating area seen from behind the counter (background of the front-counter screen).
func cafe_interior(n: Node3D) -> void:
	var wall := IsoKit.box(n, Vector3(8, 3.2, 0.1), Vector3(0, 1.6, -3.2), Color("#E9D2A6"), false, false, false)
	wall.name = "Wall"
	for x in range(-38, 40, 4):
		IsoKit.box(n, Vector3(0.18, 3.2, 0.01), Vector3(x * 0.1, 1.6, -3.14), Color("#DFC392"), false, false, false)
	IsoKit.box(n, Vector3(8, 0.1, 6), Vector3(0, -0.05, -0.5), Color("#C8B79E"), false, false, false)
	for wx in [-2.4, 1.1]:  # big windows with the street outside
		IsoKit.box(n, Vector3(2.0, 1.6, 0.06), Vector3(wx, 1.65, -3.1), Color("#7A5236"))
		IsoKit.box(n, Vector3(1.85, 1.45, 0.04), Vector3(wx, 1.65, -3.07), Color("#BFE0E6"))
		for i in 3:  # shophouses across the street
			IsoKit.box(n, Vector3(0.5, 0.7 + i * 0.12, 0.02), Vector3(wx - 0.6 + i * 0.6, 1.25 + i * 0.06, -3.06),
				[Color("#E8A9A0"), Color("#F2D49B"), Color("#A9C9A0")][i], false, false, false)
		IsoKit.box(n, Vector3(0.04, 1.45, 0.05), Vector3(wx, 1.65, -3.05), Color("#7A5236"))
	IsoKit.box(n, Vector3(1.1, 2.3, 0.06), Vector3(3.2, 1.15, -3.1), Color("#7A5236"))  # door
	IsoKit.box(n, Vector3(0.9, 2.0, 0.04), Vector3(3.2, 1.15, -3.07), Color("#BFE0E6"))
	var sign := Label3D.new()
	sign.text = "OPEN"
	sign.font_size = 64
	sign.pixel_size = 0.004
	sign.modulate = Color("#F5E7CA")
	sign.outline_size = 12
	sign.outline_modulate = Color("#7A3A2A")
	sign.position = Vector3(3.2, 1.75, -3.0)
	n.add_child(sign)
	IsoKit.box(n, Vector3(1.0, 0.7, 0.04), Vector3(-0.65, 2.55, -3.1), Color("#2E2622"))  # menu board
	for i in 3:
		IsoKit.box(n, Vector3(0.7, 0.04, 0.01), Vector3(-0.65, 2.75 - i * 0.18, -3.07), Color("#F5E7CA"), false, false, false)
	for x in [-2.0, 0.5, 2.6]:  # pendant lamps
		IsoKit.cyl(n, 0.01, 0.6, Vector3(x, 2.9, -1.8), Props.BLACK)
		IsoKit.cyl(n, 0.18, 0.16, Vector3(x, 2.55, -1.8), Color("#F5E7CA"), false, false, 0.05)
	CafeRoom.table_set(n, Vector3(-1.4, 0, -1.9))
	CafeRoom.table_set(n, Vector3(1.6, 0, -2.2))
	for px in [-3.5, 0.0]:  # plants
		IsoKit.cyl(n, 0.2, 0.35, Vector3(px - 0.2 if px == 0.0 else px, 0.17, -2.8), Color("#B97F52"), false, false, 0.16)
		IsoKit.sphere(n, 0.38, Vector3(px - 0.2 if px == 0.0 else px, 0.7, -2.8), Color("#5E8F5A"))


## The counter as seen by the barista: top surface, pastry case, register and tip jar.
func front_counter(n: Node3D) -> void:
	IsoKit.box(n, Vector3(6.4, 0.06, 0.7), Vector3(0, 0.97, 0), Color("#C9925F"))
	IsoKit.box(n, Vector3(6.4, 0.3, 0.05), Vector3(0, 0.8, 0.33), Color("#8A5634"))
	var pos := Vector3(-2.2, 1.0, -0.05)  # register
	IsoKit.box(n, Vector3(0.5, 0.05, 0.4), pos + Vector3(0, 0.025, 0), Props.STEEL_DARK, true)
	var screen := IsoKit.box(n, Vector3(0.55, 0.36, 0.04), pos + Vector3(0, 0.32, 0), Color("#E9EEF2"))
	screen.rotation_degrees = Vector3(-10, 0, 0)
	IsoKit.box(n, Vector3(0.47, 0.28, 0.01), pos + Vector3(0, 0.32, 0.025), Color("#3B4A5A"), false, false, false)
	var case_at := Vector3(0.2, 1.0, 0)  # pastry case
	IsoKit.box(n, Vector3(1.6, 0.06, 0.6), case_at + Vector3(0, 0.03, 0), Props.STEEL, true)
	IsoKit.box(n, Vector3(1.6, 0.5, 0.6), case_at + Vector3(0, 0.3, 0), Color("#DDE9EE"), false, true)
	for i in 6:
		IsoKit.cyl(n, 0.1, 0.08, case_at + Vector3(-0.6 + i * 0.24, 0.1, 0.05),
			[Color("#E8A0A8"), Color("#9FCF6A"), Color("#E8C04A"), Color("#B97F52"), Color("#F2D49B"), Color("#C98B55")][i])
	IsoKit.cyl(n, 0.12, 0.25, Vector3(-1.3, 1.12, 0), Color("#DDE9EE"), false, true)  # tip jar
	IsoKit.box(n, Vector3(0.6, 0.02, 0.5), Vector3(1.9, 1.01, 0), Color("#A7C77A"), false, false, false)  # pass mat


func pf(n: Node3D, state: String) -> void:
	var p := Props.portafilter(n)
	p.rotation_degrees = Vector3(0, -55, 0)
	Props.set_portafilter_state(p, state)


func run() -> void:
	for job in jobs:
		if job[0] in KEEP:
			continue
		await render(job[0], job[1], job[2], job[3] if job.size() > 3 else {})
	print("sprites rendered: %d" % jobs.size())
	quit()


func render(sprite_name: String, size: Vector2i, build: Callable, opts: Dictionary) -> void:
	var vp := SubViewport.new()
	vp.size = size
	vp.transparent_bg = true
	vp.msaa_3d = Viewport.MSAA_DISABLED
	vp.own_world_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)

	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_CLEAR_COLOR
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color("#FFF1E0")
	e.ambient_light_energy = 0.75
	env.environment = e
	vp.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45, -35, 0)
	sun.light_energy = 0.55
	vp.add_child(sun)

	var holder := Node3D.new()
	vp.add_child(holder)
	build.call(holder)

	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.rotation_degrees = Vector3(opts.get("pitch", PITCH), 0, 0)
	vp.add_child(cam)
	await process_frame
	fit(cam, holder, size, opts.get("min_y", -INF), opts.get("zoom", 1.04))
	await process_frame
	await process_frame
	await process_frame
	var img := vp.get_texture().get_image()
	img.save_png(ProjectSettings.globalize_path(OUT + sprite_name + ".png"))
	vp.queue_free()


## Points the camera at the props' bounding box and sizes it to fill the sprite.
func fit(cam: Camera3D, holder: Node3D, size: Vector2i, min_y := -INF, zoom := 1.04) -> void:
	var box := AABB()
	var first := true
	for mi in holder.find_children("*", "MeshInstance3D", true, false):
		var b: AABB = mi.global_transform * mi.get_aabb()
		if b.end.y < min_y or mi.name == "Wall":
			continue
		if b.position.y < min_y:
			b = AABB(Vector3(b.position.x, min_y, b.position.z), Vector3(b.size.x, b.end.y - min_y, b.size.z))
		box = b if first else box.merge(b)
		first = false
	var centre := box.get_center()
	var basis := cam.global_transform.basis
	var corners := []
	for i in 8:
		corners.append(box.get_endpoint(i) - centre)
	var w := 0.0
	var h := 0.0
	for c in corners:
		w = maxf(w, absf(c.dot(basis.x)))
		h = maxf(h, absf(c.dot(basis.y)))
	cam.keep_aspect = Camera3D.KEEP_HEIGHT
	cam.size = maxf(h * 2.0, w * 2.0 * size.y / size.x) * zoom
	cam.global_position = centre + basis.z * 5.0
