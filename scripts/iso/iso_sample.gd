extends Control
## Style sample: an isometric café bar built from simple 3D shapes and rendered as
## pixel art (low-res SubViewport, nearest filter, toon shading, outlines, shadows).

const PIXEL_SCALE := 3  # 1280x720 window -> 426x240 render

const STONE := Color("#CBB497")
const WOOD := Color("#B98A5E")
const CREAM := Color("#EFE6D8")
const STEEL := Color("#B7BCC4")
const DARK := Color("#2E2A2C")
const YELLOW := Color("#E8C04A")
const COFFEE := Color("#5A2F1A")

var world: Node3D
var pov := false  ## true = first-person barista camera behind the counter


func _ready() -> void:
	var container := SubViewportContainer.new()
	container.stretch = true
	container.stretch_shrink = PIXEL_SCALE
	container.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	container.set_anchors_preset(PRESET_FULL_RECT)
	add_child(container)
	var vp := SubViewport.new()
	vp.msaa_3d = Viewport.MSAA_DISABLED
	vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
	container.add_child(vp)

	world = Node3D.new()
	vp.add_child(world)
	lights_and_camera()
	room()
	counter()
	espresso_machine(Vector3(-0.2, 0.95, -0.15))
	grinder(Vector3(0.75, 0.95, -0.25))
	grinder(Vector3(1.2, 0.95, -0.25))
	props()


func lights_and_camera() -> void:
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color("#A89A8A")
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color("#FFE9D0")
	e.ambient_light_energy = 0.35
	env.environment = e
	world.add_child(env)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, -35, 0)
	sun.light_energy = 0.85
	sun.light_color = Color("#FFF1DC")
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 20.0
	world.add_child(sun)

	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 2.7
	cam.rotation_degrees = Vector3(-35, 45, 0)
	cam.position = Vector3(0.1, 0.95, -0.2) + Vector3(0.579, 0.574, 0.579) * 10.0
	if pov:
		# Barista standing at the counter, eyes 1.55 m up, looking down at the machine.
		cam.projection = Camera3D.PROJECTION_PERSPECTIVE
		cam.fov = 50
		cam.position = Vector3(0.3, 2.0, 0.75)
		cam.rotation_degrees = Vector3(-50, 0, 0)
	world.add_child(cam)


func room() -> void:
	var floor_mat := StandardMaterial3D.new()
	floor_mat.albedo_texture = IsoKit.checker(Color("#BDB6A8"), Color("#A9A293"))
	floor_mat.uv1_scale = Vector3(24, 24, 1)
	floor_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	floor_mat.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
	var floor_mesh := PlaneMesh.new()
	floor_mesh.size = Vector2(12, 12)
	var f := MeshInstance3D.new()
	f.mesh = floor_mesh
	f.material_override = floor_mat
	world.add_child(f)
	IsoKit.box(world, Vector3(12, 3, 0.1), Vector3(0, 1.5, -1.2), Color("#A8957F"), false, false, false)
	IsoKit.box(world, Vector3(0.1, 3, 12), Vector3(-2.6, 1.5, 0), Color("#B9A893"), false, false, false)
	# window frame on the back wall
	IsoKit.box(world, Vector3(1.6, 1.6, 0.08), Vector3(-1.6, 1.9, -1.12), Color("#7A5236"))
	IsoKit.box(world, Vector3(1.4, 1.4, 0.05), Vector3(-1.6, 1.9, -1.08), Color("#9FC4C8"), false, true)
	# pegboard shelf with bean bags
	IsoKit.box(world, Vector3(1.2, 0.9, 0.04), Vector3(1.3, 1.75, -1.13), Color("#D2B07E"))
	IsoKit.box(world, Vector3(1.0, 0.04, 0.22), Vector3(1.3, 1.55, -1.0), Color("#C49A68"))
	IsoKit.box(world, Vector3(0.18, 0.28, 0.12), Vector3(1.05, 1.71, -1.0), Color("#B63A3A"))
	IsoKit.box(world, Vector3(0.18, 0.28, 0.12), Vector3(1.35, 1.71, -1.0), Color("#3A5DB6"))


func counter() -> void:
	IsoKit.box(world, Vector3(3.6, 0.06, 1.0), Vector3(0.0, 0.92, -0.2), STONE)  # top
	IsoKit.box(world, Vector3(3.5, 0.86, 0.9), Vector3(0.0, 0.45, -0.2), Color("#C4A06E"))  # cabinet
	for x in [-1.75, -0.6, 0.6, 1.75]:
		IsoKit.box(world, Vector3(0.05, 0.88, 0.05), Vector3(x, 0.45, 0.27), STEEL, true)  # alu frame
	IsoKit.box(world, Vector3(3.5, 0.05, 0.05), Vector3(0, 0.86, 0.27), STEEL, true)
	IsoKit.box(world, Vector3(1.0, 0.7, 0.02), Vector3(-1.15, 0.45, 0.26), Color("#9AA0A8"), true)  # fridge door
	IsoKit.box(world, Vector3(1.0, 0.7, 0.02), Vector3(0.0, 0.45, 0.26), Color("#9AA0A8"), true)


func espresso_machine(at: Vector3) -> void:
	var m := Node3D.new()
	m.position = at
	world.add_child(m)
	IsoKit.box(m, Vector3(0.9, 0.42, 0.55), Vector3(0, 0.21, 0), STEEL, true)  # body
	IsoKit.box(m, Vector3(0.06, 0.46, 0.6), Vector3(-0.46, 0.23, 0), YELLOW)  # side panels
	IsoKit.box(m, Vector3(0.06, 0.46, 0.6), Vector3(0.46, 0.23, 0), YELLOW)
	IsoKit.box(m, Vector3(0.86, 0.02, 0.5), Vector3(0, 0.43, 0), Color("#8E949C"), true)  # cup warmer grate
	IsoKit.box(m, Vector3(0.86, 0.05, 0.22), Vector3(0, 0.03, 0.33), DARK)  # drip tray
	for gx in [-0.2, 0.2]:
		IsoKit.cyl(m, 0.07, 0.08, Vector3(gx, 0.3, 0.3), STEEL, true)  # group head
		IsoKit.cyl(m, 0.06, 0.04, Vector3(gx, 0.24, 0.32), STEEL, true)  # portafilter basket
		IsoKit.box(m, Vector3(0.04, 0.03, 0.16), Vector3(gx + 0.02, 0.24, 0.45), Color("#7A4A2A"))  # handle
		IsoKit.cyl(m, 0.035, 0.07, Vector3(gx, 0.09, 0.33), CREAM, false, true)  # shot glass
	IsoKit.cyl(m, 0.012, 0.3, Vector3(0.36, 0.2, 0.3), STEEL, true)  # steam wand
	IsoKit.cyl(m, 0.05, 0.03, Vector3(-0.32, 0.3, 0.29), STEEL, true)  # gauge


func grinder(at: Vector3) -> void:
	var g := Node3D.new()
	g.position = at
	world.add_child(g)
	IsoKit.box(g, Vector3(0.26, 0.06, 0.3), Vector3(0, 0.03, 0.02), DARK)  # base
	IsoKit.cyl(g, 0.1, 0.36, Vector3(0, 0.24, -0.02), CREAM)  # body
	IsoKit.box(g, Vector3(0.1, 0.06, 0.02), Vector3(0, 0.33, 0.085), DARK)  # display
	IsoKit.cyl(g, 0.11, 0.2, Vector3(0, 0.52, -0.02), Color("#DCE8EC"), false, true, 0.13)  # hopper
	IsoKit.cyl(g, 0.09, 0.1, Vector3(0, 0.48, -0.02), COFFEE)  # beans
	IsoKit.cyl(g, 0.13, 0.03, Vector3(0, 0.635, -0.02), DARK)  # lid


func props() -> void:
	# POS tablet
	IsoKit.box(world, Vector3(0.36, 0.24, 0.03), Vector3(-1.2, 1.12, -0.3), DARK)
	IsoKit.box(world, Vector3(0.08, 0.12, 0.08), Vector3(-1.2, 1.0, -0.33), STEEL, true)
	# tamper, pitcher, milk carton, cups
	IsoKit.cyl(world, 0.04, 0.02, Vector3(0.75, 0.96, 0.15), STEEL, true)
	IsoKit.cyl(world, 0.015, 0.08, Vector3(0.75, 1.01, 0.15), Color("#7A4A2A"))
	IsoKit.sphere(world, 0.025, Vector3(0.75, 1.06, 0.15), Color("#7A4A2A"))
	IsoKit.cyl(world, 0.07, 0.16, Vector3(1.4, 1.03, 0.1), STEEL, true, false, 0.08)
	IsoKit.box(world, Vector3(0.12, 0.22, 0.12), Vector3(1.15, 1.06, 0.12), Color("#F3F6FA"))
	IsoKit.box(world, Vector3(0.122, 0.08, 0.122), Vector3(1.15, 1.04, 0.12), Color("#3B6FD1"))
	for i in 3:
		IsoKit.cyl(world, 0.05, 0.3, Vector3(-0.85 + i * 0.12, 1.1, -0.55), Color("#DDE6EA"), false, true, 0.055)
	IsoKit.cyl(world, 0.06, 0.07, Vector3(-0.55, 0.99, 0.15), CREAM)  # cup on counter
	IsoKit.cyl(world, 0.05, 0.005, Vector3(-0.55, 1.03, 0.15), COFFEE)
