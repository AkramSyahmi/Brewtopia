class_name CafeRoom
extends RefCounted
## Builds the café, laid out like reference brewtopia 2: one long service counter along X
## (top at y 0.95, barista side at +Z, customer side at -Z). Under the counter on the
## barista side: a steel fridge, an ice machine and open shelves. On the customer side:
## a café table with a stool, delivery boxes, and the back wall (z -2.6) with a window
## and a glass entrance door. Coordinates in metres.

const FLOOR_A := Color("#DED6C8")
const FLOOR_LINE := Color("#CFC6B6")
const WALL := Color("#CDCDCB")
const COUNTER_TOP := Color("#D8CFC1")
const CABINET := Color("#D7B77E")
const CABINET_DARK := Color("#B8955E")
const STEEL := Color("#9EA3AA")
const WOOD := Color("#8A5634")
const FRAME := Color("#8C5A3A")
const GLASS := Color("#BFDCE3")
const FILM := Color("#EEF3F7")
const BOX := Color("#C9A06E")
const BOX_TAPE := Color("#DCC29A")

const TOP_Y := 0.95
const COUNTER_X := Vector2(-3.0, 2.8)  # left and right ends
const COUNTER_Z := Vector2(-0.62, 0.18)  # customer edge and barista edge
const WALL_Z := -2.6
const SERVE_SPOT := Vector3(2.25, TOP_Y, -0.45)  # finished drink waits here, in front of the customer
const CUSTOMER_SPOT := Vector3(2.5, 0, -1.1)  # at the counter, right of the POS (nothing in front of their face)
const CUSTOMER_FACING := 0.0  # rotation_degrees.y: facing +Z, towards the counter
const QUEUE_SPOT := Vector3(-0.55, 0, -1.6)  # next customer waits here
const DOOR_SPOT := Vector3(2.7, 0, -2.4)
const MENTOR_SPOT := Vector3(2.45, 0, 0.45)


static func build(world: Node3D) -> void:
	floor_and_walls(world)
	counter(world)
	counter_items(world)
	customer_side(world)
	var lamp := OmniLight3D.new()
	lamp.position = Vector3(0, 2.4, -0.6)
	lamp.omni_range = 4.5
	lamp.light_energy = 0.2
	lamp.light_color = Color("#FFD9A0")
	world.add_child(lamp)


static func floor_and_walls(world: Node3D) -> void:
	var tile := Image.create_empty(16, 16, false, Image.FORMAT_RGBA8)
	tile.fill(FLOOR_A)
	for i in 16:  # thin grout line on two edges = a grid of large square tiles
		tile.set_pixel(i, 0, FLOOR_LINE)
		tile.set_pixel(0, i, FLOOR_LINE)
	var m := StandardMaterial3D.new()
	m.albedo_texture = ImageTexture.create_from_image(tile)
	m.uv1_scale = Vector3(20, 20, 1)  # 12 m / 20 = 0.6 m tiles
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	m.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
	var f := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(12, 12)
	f.mesh = pm
	f.material_override = m
	f.position = Vector3(0, 0, 3.4)
	world.add_child(f)
	IsoKit.box(world, Vector3(12, 3.0, 0.1), Vector3(0, 1.5, WALL_Z - 0.05), WALL, false, false, false)
	IsoKit.box(world, Vector3(12, 0.1, 0.04), Vector3(0, 0.05, WALL_Z + 0.02), Color("#B9B9B6"))  # skirting

	# window with a patterned privacy film on its lower half
	var wx := 0.9
	IsoKit.box(world, Vector3(1.7, 1.75, 0.08), Vector3(wx, 1.6, WALL_Z + 0.04), FRAME)
	IsoKit.box(world, Vector3(1.5, 1.55, 0.06), Vector3(wx, 1.6, WALL_Z + 0.07), GLASS, false, true)
	IsoKit.box(world, Vector3(1.5, 0.75, 0.02), Vector3(wx, 1.2, WALL_Z + 0.1), FILM, false, false, false)
	for i in 9:  # blue "%" marks on the film
		var mark := IsoKit.box(world, Vector3(0.06, 0.012, 0.005), Vector3(wx - 0.6 + (i % 5) * 0.3,
			0.95 + (i / 5) * 0.3 + (i % 2) * 0.12, WALL_Z + 0.115), Color("#4E6FC4"), false, false, false)
		mark.rotation_degrees.z = 45
	IsoKit.box(world, Vector3(1.7, 0.08, 0.2), Vector3(wx, 0.76, WALL_Z + 0.1), FRAME)  # sill
	# glass entrance door with a hanging OPEN sign
	var dx := 2.7
	IsoKit.box(world, Vector3(1.2, 2.3, 0.08), Vector3(dx, 1.15, WALL_Z + 0.04), FRAME)
	IsoKit.box(world, Vector3(1.0, 2.15, 0.06), Vector3(dx, 1.1, WALL_Z + 0.07), GLASS, false, true)
	IsoKit.box(world, Vector3(0.12, 0.42, 0.02), Vector3(dx - 0.62, 1.9, WALL_Z + 0.11), FRAME)
	var sign := Label3D.new()
	sign.text = "O\nP\nE\nN"
	sign.font_size = 28
	sign.pixel_size = 0.0035
	sign.line_spacing = -8
	sign.modulate = Color("#F5E7CA")
	sign.position = Vector3(dx - 0.62, 1.9, WALL_Z + 0.125)
	world.add_child(sign)
	# poster and a power outlet on the wall
	IsoKit.box(world, Vector3(0.6, 0.8, 0.02), Vector3(-2.4, 1.9, WALL_Z + 0.01), Color("#2F3A30"))
	IsoKit.box(world, Vector3(0.3, 0.3, 0.005), Vector3(-2.4, 2.0, WALL_Z + 0.025), Color("#8C6A3E"), false, false, false)
	IsoKit.box(world, Vector3(0.22, 0.1, 0.02), Vector3(-0.35, 0.55, WALL_Z + 0.01), Color("#F2F2F0"))


## The long service counter. Barista side (+Z): fridge, ice machine, open shelves.
static func counter(world: Node3D) -> void:
	var w := COUNTER_X.y - COUNTER_X.x
	var cx := (COUNTER_X.x + COUNTER_X.y) / 2.0
	var d := COUNTER_Z.y - COUNTER_Z.x
	var cz := (COUNTER_Z.x + COUNTER_Z.y) / 2.0
	var front := COUNTER_Z.y
	IsoKit.box(world, Vector3(w, 0.05, d), Vector3(cx, TOP_Y - 0.025, cz), COUNTER_TOP)
	IsoKit.box(world, Vector3(w - 0.04, TOP_Y - 0.05, d - 0.1), Vector3(cx, (TOP_Y - 0.05) / 2.0, cz - 0.05), CABINET)
	# stainless two-door fridge
	IsoKit.box(world, Vector3(1.3, 0.82, 0.04), Vector3(-2.2, 0.45, front - 0.08), STEEL, true)
	IsoKit.box(world, Vector3(0.01, 0.78, 0.045), Vector3(-2.2, 0.45, front - 0.07), Color("#7D828A"), false, false, false)
	# ice machine
	IsoKit.box(world, Vector3(0.75, 0.86, 0.06), Vector3(-1.05, 0.44, front - 0.06), Props.BLACK)
	IsoKit.box(world, Vector3(0.55, 0.3, 0.01), Vector3(-1.05, 0.62, front - 0.025), Color("#6E7A86"), false, true)
	IsoKit.box(world, Vector3(0.2, 0.05, 0.01), Vector3(-1.05, 0.2, front - 0.025), Color("#1A1A1A"), false, false, false)
	# open shelves: two bays with cans and a box of cups
	for bay in 2:
		var bx := 0.0 + bay * 0.95
		IsoKit.box(world, Vector3(0.85, 0.82, 0.02), Vector3(bx + 0.45, 0.47, front - 0.62), CABINET_DARK, false, false, false)
		IsoKit.box(world, Vector3(0.85, 0.03, 0.6), Vector3(bx + 0.45, 0.45, front - 0.32), CABINET)
		IsoKit.box(world, Vector3(0.03, 0.85, 0.62), Vector3(bx, 0.46, front - 0.31), CABINET)
	IsoKit.box(world, Vector3(0.03, 0.85, 0.62), Vector3(1.9, 0.46, front - 0.31), CABINET)
	for i in 5:  # soda cans on the shelf
		IsoKit.cyl(world, 0.035, 0.12, Vector3(0.2 + i * 0.1, 0.53, front - 0.3 + (i % 2) * 0.08),
			Color("#2D5BB8") if i == 4 else Color("#7A3A9A"))
	IsoKit.box(world, Vector3(0.5, 0.3, 0.4), Vector3(1.4, 0.18, front - 0.3), BOX)  # box of cups
	IsoKit.box(world, Vector3(0.51, 0.04, 0.1), Vector3(1.4, 0.33, front - 0.3), BOX_TAPE)
	for k in 4:
		IsoKit.cyl(world, 0.06, 0.04, Vector3(1.4, 0.35 + k * 0.03, front - 0.3), Props.GLASS, false, true, 0.07)
	# kitchen unit with an oven at the right end
	IsoKit.box(world, Vector3(0.7, TOP_Y, 0.8), Vector3(3.25, TOP_Y / 2.0, front + 0.3), Color("#5A5E64"), true)
	IsoKit.box(world, Vector3(0.6, 0.06, 0.6), Vector3(3.25, TOP_Y + 0.03, front + 0.3), Color("#3A3D42"))
	IsoKit.box(world, Vector3(0.02, 0.5, 0.6), Vector3(2.89, 0.5, front + 0.3), Color("#2A2C30"))


## Things on the counter top besides the brewing gear Bar3D places. Keep tall things off
## the right end: the customer stands there (CUSTOMER_SPOT) and must stay visible.
static func counter_items(world: Node3D) -> void:
	var y := TOP_Y
	Props.grinder(world, Vector3(0.38, y, -0.42))  # second grinder
	IsoKit.cyl(world, 0.11, 0.012, Vector3(0.38, y + 0.006, -0.25), Color("#9AA3AD"), true)  # dosing mats
	IsoKit.cyl(world, 0.11, 0.012, Vector3(0.0, y + 0.006, -0.18), Color("#9AA3AD"), true)
	# cup dispenser with two stacks of plastic cups
	IsoKit.box(world, Vector3(0.36, 0.22, 0.16), Vector3(0.82, y + 0.11, -0.42), Props.BLACK)
	for i in 2:
		IsoKit.cyl(world, 0.06, 0.4, Vector3(0.74 + i * 0.16, y + 0.32, -0.42), Props.GLASS, false, true, 0.07)
	# receipt printer and POS screen facing the barista, at the left end so they never hide
	# the customer (who stands at the right end)
	IsoKit.box(world, Vector3(0.16, 0.1, 0.16), Vector3(-2.45, y + 0.05, -0.12), Color("#F2F2F0"))
	var pos := Vector3(-2.15, y, -0.32)
	IsoKit.box(world, Vector3(0.2, 0.02, 0.16), pos + Vector3(0, 0.01, 0), Props.STEEL_DARK, true)
	IsoKit.box(world, Vector3(0.04, 0.16, 0.04), pos + Vector3(0, 0.09, 0), Props.STEEL, true)
	var screen := IsoKit.box(world, Vector3(0.42, 0.28, 0.03), pos + Vector3(0, 0.3, 0.02), Props.BLACK)
	screen.rotation_degrees = Vector3(-15, 0, 0)
	# cakes on plates and two iced drinks at the ends
	for at in [Vector3(1.95, y, -0.05), Vector3(1.5, y, 0.0)]:
		IsoKit.cyl(world, 0.14, 0.015, at + Vector3(0, 0.008, 0), Color("#A06A3E"))
		IsoKit.cyl(world, 0.08, 0.08, at + Vector3(0, 0.055, 0), Color("#E8A0B4"))
		IsoKit.sphere(world, 0.025, at + Vector3(0.02, 0.11, 0), Color("#C8323C"))
	for i in 2:
		var at := Vector3(1.25 + i * 0.3, y, -0.3 + i * 0.05)
		IsoKit.cyl(world, 0.045, 0.13, at + Vector3(0, 0.065, 0), Color("#5A2E1A"), false, false, 0.05)
		IsoKit.cyl(world, 0.052, 0.015, at + Vector3(0, 0.135, 0), Props.GLASS, false, true)


static func table_set(world: Node3D, at: Vector3, chairs := true) -> void:
	IsoKit.box(world, Vector3(0.7, 0.04, 0.7), at + Vector3(0, 0.74, 0), WOOD)
	IsoKit.cyl(world, 0.03, 0.72, at + Vector3(0, 0.36, 0), Props.BLACK)
	IsoKit.cyl(world, 0.22, 0.03, at + Vector3(0, 0.015, 0), Props.BLACK)
	if not chairs:
		return
	for dx in [-0.6, 0.6]:
		var c := at + Vector3(dx, 0, 0)
		IsoKit.box(world, Vector3(0.4, 0.04, 0.4), c + Vector3(0, 0.45, 0), Color("#E8C04A"))
		IsoKit.box(world, Vector3(0.04, 0.45, 0.4), c + Vector3(signf(dx) * 0.2, 0.68, 0), Color("#E8C04A"))
		for lx in [-0.17, 0.17]:
			for lz in [-0.17, 0.17]:
				IsoKit.box(world, Vector3(0.03, 0.44, 0.03), c + Vector3(lx, 0.22, lz), WOOD)


## Customer side: a table and stool, and delivery boxes.
static func customer_side(world: Node3D) -> void:
	# Kenney Furniture Kit (CC0) table, chairs and stool
	Props.model(world, "furniture/tableRound", Vector3(-1.3, 0, -1.9), 0.0, 1.4)
	Props.model(world, "furniture/chairCushion", Vector3(-1.3, 0, -1.35), 180.0, 1.6)
	Props.model(world, "furniture/chairCushion", Vector3(-1.85, 0, -1.9), 90.0, 1.6)
	Props.model(world, "furniture/stoolBar", Vector3(-2.3, 0, -1.0))
	box(world, Vector3(0.6, 0.45, 0.45), Vector3(-0.1, 0, -2.3), "Beans")
	var lemons := box(world, Vector3(0.55, 0.42, 0.45), Vector3(-3.3, 0, -1.0), "")
	for i in 6:  # printed lemons on the side of the box
		IsoKit.sphere(lemons, 0.045, Vector3(-0.17 + (i % 3) * 0.17, 0.12 + (i / 3) * 0.15, 0.226), Color("#E8B83A"))


## Decorations bought in the shop (SaveGame.DECOR ids), on the customer side and walls.
static func decor(world: Node3D, ids: Array) -> void:
	if "plants" in ids:
		Props.model(world, "furniture/pottedPlant", Vector3(0.4, 0, -2.3), 0.0, 2.6)
	if "lamps" in ids:
		for at in [Vector3(-1.3, 0, -1.9), Vector3(0.0, 0, -1.6)]:  # over the customer area
			IsoKit.cyl(world, 0.008, 0.4, at + Vector3(0, 2.85, 0), Props.BLACK)
			Props.model(world, "furniture/lampSquareCeiling", at + Vector3(0, 2.3, 0), 0.0, 1.6)
			var glow := OmniLight3D.new()
			glow.position = at + Vector3(0, 2.1, 0)
			glow.omni_range = 1.4
			glow.light_energy = 0.35
			glow.light_color = Color("#FFD9A0")
			world.add_child(glow)
	if "batik" in ids:  # framed batik panel: coloured bands with dots
		IsoKit.box(world, Vector3(0.7, 0.62, 0.03), Vector3(-0.75, 1.45, WALL_Z + 0.02), WOOD)
		var bands := [Color("#C0504D"), Color("#E8B83A"), Color("#3A7D8C"), Color("#7A3A6A")]
		for i in 4:
			IsoKit.box(world, Vector3(0.62, 0.13, 0.01), Vector3(-0.75, 1.65 - i * 0.13, WALL_Z + 0.04), bands[i], false, false, false)
			for k in 4:
				IsoKit.box(world, Vector3(0.04, 0.04, 0.01), Vector3(-0.96 + k * 0.14, 1.65 - i * 0.13, WALL_Z + 0.05),
					Color("#F5E7CA"), false, false, false)
	if "bookshelf" in ids:
		var at := Vector3(-1.6, 0, WALL_Z + 0.3)
		Props.model(world, "furniture/bookcaseOpen", at)
		for h in [0.05, 0.62, 1.2]:  # books on the shelves
			Props.model(world, "furniture/books", at + Vector3(-0.1, h, 0.02))
	if "neon" in ids:
		var sign := Label3D.new()
		sign.text = "BREWTOPIA"
		sign.font_size = 64
		sign.pixel_size = 0.0035
		sign.modulate = Color("#FF7AC8")
		sign.outline_size = 14
		sign.outline_modulate = Color("#8A2A6A")
		sign.shaded = false
		sign.position = Vector3(0.9, 1.3, WALL_Z + 0.13)  # hung inside the window
		world.add_child(sign)


## Cardboard box with packing tape; `label` is printed on its front (+Z) face.
static func box(world: Node3D, size: Vector3, at: Vector3, label: String) -> Node3D:
	var b := Props.node(world, at)
	IsoKit.box(b, size, Vector3(0, size.y / 2.0, 0), BOX)
	IsoKit.box(b, Vector3(size.x + 0.01, 0.01, 0.12), Vector3(0, size.y, 0), BOX_TAPE, false, false, false)
	if label != "":
		var l := Label3D.new()
		l.text = label
		l.font_size = 40
		l.pixel_size = 0.004
		l.modulate = Color("#2A2018")
		l.position = Vector3(0.05, size.y * 0.4, size.z / 2.0 + 0.005)
		b.add_child(l)
	return b
