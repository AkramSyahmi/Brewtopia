class_name CafeRoom
extends RefCounted
## Builds the café around the back bar: floor, walls, window, door, front counter,
## seating and decor. Coordinates in metres; the back bar counter top is at y 0.95,
## its front edge at z 0.18; the front (customer) counter runs along z 1.35.

const FLOOR_A := Color("#BDB6A8")
const FLOOR_B := Color("#A39C8E")
const WALL := Color("#B8A58F")
const WALL_SIDE := Color("#C9B8A2")
const ALU := Color("#B9BEC6")
const COUNTER_TOP := Color("#C7AE90")
const CABINET := Color("#C4A06E")
const WOOD := Color("#8A5634")
const DOOR_GLASS := Color("#9FC4C8")

const FRONT_Z := 1.35
const FRONT_TOP := 1.0
const SERVE_SPOT := Vector3(0.15, FRONT_TOP, FRONT_Z)
const CUSTOMER_SPOT := Vector3(0.15, 0, 1.95)
const DOOR_SPOT := Vector3(-2.3, 0, 3.4)
const MENTOR_SPOT := Vector3(-0.85, 0, 0.75)


static func build(world: Node3D) -> void:
	floor_and_walls(world)
	back_bar(world)
	front_counter(world)
	seating(world)
	decor(world)


static func floor_and_walls(world: Node3D) -> void:
	var tile := Image.create_empty(16, 16, false, Image.FORMAT_RGBA8)
	for y in 16:
		for x in 16:
			var d := absi(x - 8) + absi(y - 8)  # diamond motif
			tile.set_pixel(x, y, FLOOR_B if d < 4 or d > 12 else FLOOR_A)
	var m := StandardMaterial3D.new()
	m.albedo_texture = ImageTexture.create_from_image(tile)
	m.uv1_scale = Vector3(18, 18, 1)
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	m.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
	var f := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(9, 9)
	f.mesh = pm
	f.material_override = m
	f.position = Vector3(0.4, 0, 2.0)
	world.add_child(f)

	var wall_mat := StandardMaterial3D.new()
	wall_mat.albedo_texture = IsoKit.checker(Color("#EFE3CC"), Color("#E6D7BC"))
	wall_mat.uv1_scale = Vector3(14, 6, 1)
	wall_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	wall_mat.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
	var tiles := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(3.2, 0.9, 0.02)
	tiles.mesh = bm
	tiles.material_override = wall_mat
	tiles.position = Vector3(0, 1.4, -0.63)
	world.add_child(tiles)  # tiled splashback behind the bar
	IsoKit.box(world, Vector3(9, 2.8, 0.1), Vector3(0.4, 1.4, -0.7), WALL, false, false, false)
	IsoKit.box(world, Vector3(0.1, 2.8, 9), Vector3(-2.7, 1.4, 3.8), WALL_SIDE, false, false, false)
	IsoKit.box(world, Vector3(9, 0.12, 0.12), Vector3(0.4, 0.06, -0.62), Color("#7A6A58"))  # skirting

	# window on the side wall
	IsoKit.box(world, Vector3(0.08, 1.3, 1.6), Vector3(-2.64, 1.55, 1.6), WOOD)
	IsoKit.box(world, Vector3(0.06, 1.15, 1.45), Vector3(-2.6, 1.55, 1.6), DOOR_GLASS, false, true)
	IsoKit.box(world, Vector3(0.1, 0.04, 1.6), Vector3(-2.6, 1.55, 1.6), WOOD)
	# entrance door on the side wall, with an OPEN sign
	IsoKit.box(world, Vector3(0.08, 2.2, 1.1), Vector3(-2.64, 1.1, 3.5), WOOD)
	IsoKit.box(world, Vector3(0.06, 1.95, 0.9), Vector3(-2.6, 1.1, 3.5), DOOR_GLASS, false, true)
	var sign := Label3D.new()
	sign.text = "OPEN"
	sign.font_size = 48
	sign.pixel_size = 0.004
	sign.modulate = Color("#F5E7CA")
	sign.outline_size = 10
	sign.outline_modulate = Color("#7A3A2A")
	sign.rotation_degrees = Vector3(0, 90, 0)
	sign.position = Vector3(-2.55, 1.8, 3.5)
	world.add_child(sign)


static func cabinet_run(world: Node3D, width: float, at: Vector3, depth: float, top_y: float) -> void:
	IsoKit.box(world, Vector3(width, 0.05, depth), Vector3(at.x, top_y - 0.025, at.z), COUNTER_TOP)
	IsoKit.box(world, Vector3(width - 0.05, top_y - 0.08, depth - 0.05), Vector3(at.x, (top_y - 0.08) / 2.0 + 0.03, at.z), CABINET)
	var front := at.z + depth / 2.0
	var n := int(width / 0.6)
	for i in n + 1:
		var x := at.x - width / 2.0 + 0.02 + i * (width - 0.04) / n
		IsoKit.box(world, Vector3(0.04, top_y - 0.05, 0.04), Vector3(x, (top_y - 0.05) / 2.0, front), ALU, true)
	IsoKit.box(world, Vector3(width, 0.04, 0.04), Vector3(at.x, top_y - 0.07, front), ALU, true)
	IsoKit.box(world, Vector3(width, 0.04, 0.04), Vector3(at.x, 0.06, front), ALU, true)


static func back_bar(world: Node3D) -> void:
	cabinet_run(world, 3.2, Vector3(0, 0, -0.22), 0.8, 0.95)
	# pegboard with bean bags and a shelf
	IsoKit.box(world, Vector3(1.2, 0.8, 0.03), Vector3(2.1, 1.75, -0.64), Color("#D2B07E"))
	for i in 3:
		IsoKit.box(world, Vector3(0.18, 0.26, 0.1), Vector3(1.75 + i * 0.32, 1.88, -0.57),
			[Color("#B63A3A"), Color("#3A5DB6"), Color("#C9A04A")][i])
	IsoKit.box(world, Vector3(1.1, 0.03, 0.18), Vector3(2.1, 1.74, -0.55), WOOD)
	IsoKit.box(world, Vector3(2.4, 0.03, 0.18), Vector3(-0.3, 1.9, -0.55), WOOD)  # cup shelf
	for i in 6:
		IsoKit.cyl(world, 0.04, 0.07, Vector3(-1.2 + i * 0.3, 1.95, -0.55), Props.PORCELAIN)
	# side counter to the right of the bar with syrups
	cabinet_run(world, 1.2, Vector3(2.1, 0, -0.22), 0.8, 0.95)
	for i in 3:
		IsoKit.cyl(world, 0.04, 0.2, Vector3(1.8 + i * 0.12, 1.05, -0.4),
			[Color("#7A3A1E"), Color("#5A1E28"), Color("#E9EEF2")][i], false, false, 0.03)


static func front_counter(world: Node3D) -> void:
	cabinet_run(world, 2.6, Vector3(-0.1, 0, FRONT_Z), 0.6, FRONT_TOP)
	# POS tablet
	var pos := Vector3(-0.75, FRONT_TOP, FRONT_Z)
	IsoKit.box(world, Vector3(0.12, 0.02, 0.12), pos + Vector3(0, 0.01, 0), Props.STEEL_DARK, true)
	IsoKit.box(world, Vector3(0.04, 0.14, 0.04), pos + Vector3(0, 0.08, 0), Props.STEEL, true)
	var screen := IsoKit.box(world, Vector3(0.36, 0.24, 0.03), pos + Vector3(0, 0.25, 0.02), Props.BLACK)
	screen.rotation_degrees = Vector3(-20, 180, 0)
	# cup holder tubes
	for i in 3:
		IsoKit.cyl(world, 0.05, 0.32, Vector3(-0.35 + i * 0.12, FRONT_TOP + 0.16, FRONT_Z - 0.15),
			Color("#DDE6EA"), false, true, 0.055)
	IsoKit.box(world, Vector3(0.42, 0.18, 0.14), Vector3(-0.23, FRONT_TOP + 0.09, FRONT_Z - 0.15), Props.BLACK)
	# pastry display case
	var case_at := Vector3(0.85, FRONT_TOP, FRONT_Z)
	IsoKit.box(world, Vector3(0.6, 0.05, 0.45), case_at + Vector3(0, 0.025, 0), Props.STEEL, true)
	IsoKit.box(world, Vector3(0.6, 0.35, 0.45), case_at + Vector3(0, 0.22, 0), DOOR_GLASS, false, true)
	for i in 4:
		var c: Color = [Color("#E8A0A8"), Color("#9FCF6A"), Color("#E8C04A"), Color("#B97F52")][i]
		IsoKit.cyl(world, 0.06, 0.05, case_at + Vector3(-0.2 + i * 0.13, 0.08, 0.05), c)
	# pass mat where served drinks are placed
	IsoKit.box(world, Vector3(0.3, 0.012, 0.3), SERVE_SPOT + Vector3(0, 0.006, 0), Color("#A7C77A"), false, false, false)


static func table_set(world: Node3D, at: Vector3) -> void:
	IsoKit.box(world, Vector3(0.7, 0.04, 0.7), at + Vector3(0, 0.74, 0), WOOD)
	IsoKit.cyl(world, 0.03, 0.72, at + Vector3(0, 0.36, 0), Props.BLACK)
	IsoKit.cyl(world, 0.22, 0.03, at + Vector3(0, 0.015, 0), Props.BLACK)
	for dx in [-0.6, 0.6]:
		var c := at + Vector3(dx, 0, 0)
		IsoKit.box(world, Vector3(0.4, 0.04, 0.4), c + Vector3(0, 0.45, 0), Color("#E8C04A"))
		IsoKit.box(world, Vector3(0.04, 0.45, 0.4), c + Vector3(signf(dx) * 0.2, 0.68, 0), Color("#E8C04A"))
		for lx in [-0.17, 0.17]:
			for lz in [-0.17, 0.17]:
				IsoKit.box(world, Vector3(0.03, 0.44, 0.03), c + Vector3(lx, 0.22, lz), WOOD)


static func seating(world: Node3D) -> void:
	table_set(world, Vector3(-1.6, 0, 2.9))
	table_set(world, Vector3(1.4, 0, 3.4))


static func decor(world: Node3D) -> void:
	for i in 2:  # delivery boxes
		IsoKit.box(world, Vector3(0.5, 0.36, 0.4), Vector3(3.0, 0.18 + i * 0.36, 0.9), Color("#C49A68"))
		IsoKit.box(world, Vector3(0.51, 0.05, 0.1), Vector3(3.0, 0.34 + i * 0.36, 0.9), Color("#E6D3B0"))
	IsoKit.cyl(world, 0.18, 0.3, Vector3(-2.3, 0.15, 0.3), Color("#B97F52"), false, false, 0.15)  # plant pot
	IsoKit.sphere(world, 0.32, Vector3(-2.3, 0.6, 0.3), Color("#5E8F5A"))
	IsoKit.sphere(world, 0.22, Vector3(-2.15, 0.85, 0.4), Color("#7AA86A"))
	var lamp := OmniLight3D.new()
	lamp.position = Vector3(0, 2.4, 1.4)
	lamp.omni_range = 4.5
	lamp.light_energy = 0.4
	lamp.light_color = Color("#FFD9A0")
	world.add_child(lamp)
