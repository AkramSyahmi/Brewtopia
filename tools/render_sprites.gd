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
	]
	run.call_deferred()


func pf(n: Node3D, state: String) -> void:
	var p := Props.portafilter(n)
	p.rotation_degrees = Vector3(0, -55, 0)
	Props.set_portafilter_state(p, state)


func run() -> void:
	for job in jobs:
		if job[0] in KEEP:
			continue
		await render(job[0], job[1], job[2])
	print("sprites rendered: %d" % jobs.size())
	quit()


func render(sprite_name: String, size: Vector2i, build: Callable) -> void:
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
	cam.rotation_degrees = Vector3(PITCH, 0, 0)
	vp.add_child(cam)
	await process_frame
	fit(cam, holder, size)
	await process_frame
	await process_frame
	await process_frame
	var img := vp.get_texture().get_image()
	img.save_png(ProjectSettings.globalize_path(OUT + sprite_name + ".png"))
	vp.queue_free()


## Points the camera at the props' bounding box and sizes it to fill the sprite.
func fit(cam: Camera3D, holder: Node3D, size: Vector2i) -> void:
	var box := AABB()
	var first := true
	for mi in holder.find_children("*", "MeshInstance3D", true, false):
		var b: AABB = mi.global_transform * mi.get_aabb()
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
	cam.size = maxf(h * 2.0, w * 2.0 * size.y / size.x) * 1.04
	cam.global_position = centre + basis.z * 5.0
