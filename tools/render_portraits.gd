extends SceneTree
## Renders the dialogue portraits: each character look in Bar3D.LOOKS (the Kenney chibi
## models the café uses, with the game's toon shading and outline), head and shoulders, front
## on, orthographic, straight at the portrait's pixel size (no AA) so it stays crisp. The talk
## box shows them at 3 screen px per art px, like the other UI icons.
## Writes new files only: assets/ui/portraits/<look>.png (nothing else is touched).
## Run (needs a window, not --headless):
##   Godot_console.exe --path . --script res://tools/render_portraits.gd [-- <out_dir>]

const OUT := "res://assets/ui/portraits/"
const SIZE := Vector2i(32, 32)  # art px (96 screen px in the talk box)
const HEAD_Y := 0.9  # camera aim (m): the chibi head's centre is ~0.92 m; a touch lower shows the shoulders
const VIEW_M := 1.0  # orthographic view height (m): the whole head with hair, bun or tudung, and shoulders
const PITCH := -6.0  # a slight look down, like the café camera


func _initialize() -> void:
	var out: String = OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else OUT
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out) if out.begins_with("res://") else out)
	render_all.call_deferred(out)


func render_all(out: String) -> void:
	for look_name in Bar3D.LOOKS:
		var vp := SubViewport.new()
		vp.size = SIZE
		vp.transparent_bg = true
		vp.own_world_3d = true
		vp.msaa_3d = Viewport.MSAA_DISABLED
		vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
		vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		root.add_child(vp)
		var world := Node3D.new()
		vp.add_child(world)
		light(world)
		var p := Props.person(world, Bar3D.LOOKS[look_name])
		if p.has_meta("anim"):  # the idle pose's first frame, held still: the same portrait every run
			var anim := p.get_meta("anim") as AnimationPlayer
			anim.play("idle")
			anim.seek(0.0, true)
			anim.pause()
		var cam := Camera3D.new()
		cam.projection = Camera3D.PROJECTION_ORTHOGONAL
		cam.size = VIEW_M
		cam.rotation_degrees = Vector3(PITCH, 0, 0)
		cam.position = Vector3(0, HEAD_Y, 0) + cam.transform.basis.z * 4.0
		world.add_child(cam)
		for i in 4:
			await process_frame
		await RenderingServer.frame_post_draw
		var img := vp.get_texture().get_image()
		var path := out.path_join(look_name + ".png")
		img.save_png(path)
		print("wrote ", path)
		vp.queue_free()
	quit()


## Warm front light plus ambient, close to the café's (Bar3D.build_room), so the faces match.
func light(world: Node3D) -> void:
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_CLEAR_COLOR
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color("#FFE9D0")
	e.ambient_light_energy = 0.45
	env.environment = e
	world.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-35, -20, 0)
	sun.light_energy = 0.85
	sun.light_color = Color("#FFF1DC")
	world.add_child(sun)
