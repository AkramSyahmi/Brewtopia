class_name CafeRoom
extends RefCounted
## Builds the café, laid out like reference brewtopia 2: one long service counter along X
## (top at y 0.95, barista side at +Z, customer side at -Z). Under the counter on the
## barista side: a steel fridge, an ice machine and open shelves. On the customer side:
## a café table with a stool, delivery boxes, and the back wall (z -2.6) with a window
## and a glass entrance door. Coordinates in metres.

const FLOOR_A := Color("#E0D3BF")  # warm stone tiles (palette shared with the 2D station art)
const FLOOR_LINE := Color("#CBBBA2")
const WALL := Color("#D9CEBF")  # warm plaster, as behind the espresso machine
const COUNTER_TOP := Color("#E8D7BA")
const CABINET := Color("#C99A62")
const CABINET_DARK := Color("#A87444")
const STEEL := Color("#9EA3AA")
const WOOD := Color("#8A5634")
const FRAME := Color("#8C5A3A")
const GLASS := Color("#A9D6EA")
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
## Customers arrive and leave off-screen to the right (the dollhouse view has no front wall):
## a whole person standing at ENTRANCE is outside the iso view (checked by camera projection),
## yet on the floor. Queuers go round behind the one at the counter via QUEUE_WAY.
const ENTRANCE := Vector3(4.9, 0, -0.5)
const QUEUE_WAY := Vector3(3.6, 0, -2.0)
const MENTOR_SPOT := Vector3(1.0, 0, 0.62)  # barista side, in front of the open shelves, in view
const CHALKBOARD_AT := Vector3(-0.9, 1.17, WALL_Z)  # menu board centre: on screen just under the speech bubble (y 224-285 at 1280x720), above the wainscot rail
## Customer table and its chair (chair behind it, facing it), both at FURNITURE_SCALE. The chair
## back ends at z -2.27, 27 cm in front of the dado rail (WALL_Z + 0.06); the table edge (x -1.02)
## is 47 cm from the queue spot.
const TABLE_AT := Vector3(-1.3, 0, -1.68)
const CHAIR_OFFSET := Vector3(0, 0, -0.44)  # seat front 1 cm behind the table edge
const FURNITURE_SCALE := 0.8  # table and chair, uniform: cosy, not miniature


static func build(world: Node3D) -> void:
	floor_and_walls(world)
	counter(world)
	counter_items(world)
	customer_side(world)
	staff_mat(world)
	contact_shadows(world)
	sunlight(world)
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
	# wood wainscot with plank seams and a dark dado rail (as on the topping page), wood skirting
	IsoKit.box(world, Vector3(12, 0.7, 0.03), Vector3(0, 0.35, WALL_Z + 0.015), Color("#8E5E3A"), false, false, false)
	for i in 30:
		IsoKit.box(world, Vector3(0.012, 0.66, 0.005), Vector3(-6.0 + i * 0.4, 0.37, WALL_Z + 0.032), Color("#6E4428"), false, false, false)
	IsoKit.box(world, Vector3(12, 0.05, 0.06), Vector3(0, 0.72, WALL_Z + 0.03), Color("#7A4A2A"))
	IsoKit.box(world, Vector3(12, 0.1, 0.04), Vector3(0, 0.05, WALL_Z + 0.04), Color("#5A341C"))  # skirting

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
	chalkboard(world, CHALKBOARD_AT)  # menu board on the back wall, under the speech bubble


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
	# two cakes under a glass dome, mid-counter, and two iced drinks to its left (outside it)
	pastry_dome(world, Vector3(1.72, y, -0.22))
	for i in 2:
		var at := Vector3(1.05 + i * 0.22, y, -0.18 + i * 0.04)
		IsoKit.cyl(world, 0.045, 0.13, at + Vector3(0, 0.065, 0), Color("#5A2E1A"), false, false, 0.05)
		IsoKit.cyl(world, 0.052, 0.015, at + Vector3(0, 0.135, 0), Props.GLASS, false, true)


static func table_set(world: Node3D, at: Vector3, chairs := true, size := 1.0) -> void:
	# `size` scales the table uniformly from the floor up (every height and width)
	IsoKit.box(world, Vector3(0.7, 0.04, 0.7) * size, at + Vector3(0, 0.74, 0) * size, WOOD)
	IsoKit.cyl(world, 0.03 * size, 0.72 * size, at + Vector3(0, 0.36, 0) * size, Props.BLACK)
	IsoKit.cyl(world, 0.22 * size, 0.03 * size, at + Vector3(0, 0.015, 0) * size, Props.BLACK)
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
	# wooden table on a black pedestal (like the reference) and a Kenney (CC0) chair pulled out
	# on the far side (no stool: the next customer queues next to the table)
	table_set(world, TABLE_AT, false, FURNITURE_SCALE)
	succulent(world, TABLE_AT + Vector3(0, 0.76 * FURNITURE_SCALE, 0))  # centred on the table top
	Props.model(world, "furniture/chair", TABLE_AT + CHAIR_OFFSET, 0.0, 1.9 * FURNITURE_SCALE)
	sack(world, Vector3(-0.1, 0, -2.3))  # burlap coffee sack where the plain box was
	var lemons := box(world, Vector3(0.55, 0.42, 0.45), Vector3(-3.3, 0, -1.0), "")
	for i in 6:  # printed lemons on the side of the box
		IsoKit.sphere(lemons, 0.045, Vector3(-0.17 + (i % 3) * 0.17, 0.12 + (i / 3) * 0.15, 0.226), Color("#E8B83A"))


## Decorations bought in the shop (SaveGame.DECOR ids), on the customer side and walls.
static func decor(world: Node3D, ids: Array) -> void:
	if "plants" in ids:
		Props.model(world, "furniture/pottedPlant", Vector3(0.4, 0, -2.3), 0.0, 2.6)
	if "lamps" in ids:
		for at in [TABLE_AT, Vector3(0.0, 0, -1.6)]:  # over the table and the queue
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
		var at := Vector3(-2.1, 0, WALL_Z + 0.3)  # left of the chair (x -2.5..-1.7), not through it
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
# ---------- atmosphere and props ----------

## Unshaded see-through colour for light and shade overlays (no outline, casts no shadow).
static func overlay(world: Node3D, size: Vector3, pos: Vector3, c: Color, add := false) -> MeshInstance3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD if add else BaseMaterial3D.BLEND_MODE_MIX
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.albedo_color = c
	var mesh := BoxMesh.new()
	mesh.size = size
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = pos
	world.add_child(mi)
	return mi


## 8 AM sun through the window: three soft slanted shafts and a warm patch where they land.
static func sunlight(world: Node3D) -> void:
	var sun := Color(1.0, 0.82, 0.5, 0.07)
	for i in 3:
		var shaft := overlay(world, Vector3(0.32, 2.1, 0.02), Vector3(0.45 + i * 0.45, 0.85, -1.95), sun, true)
		shaft.rotation_degrees.x = -40.0  # from the glass down towards the counter
	overlay(world, Vector3(1.5, 0.002, 0.9), Vector3(0.9, 0.003, -2.05), Color(1.0, 0.85, 0.55, 0.13), true)  # in view between the wall and the counter


## Soft contact shade where the wall and the counter meet the floor (two layers: darker at the seam).
static func contact_shadows(world: Node3D) -> void:
	var shade := Color(0.24, 0.14, 0.06, 0.16)
	for depth in [0.22, 0.09]:
		overlay(world, Vector3(12, 0.002, depth), Vector3(0, 0.002, WALL_Z + 0.03 + depth / 2.0), shade)  # wall base
		overlay(world, Vector3(COUNTER_X.y - COUNTER_X.x, 0.002, depth), Vector3((COUNTER_X.x + COUNTER_X.y) / 2.0, 0.002,
			COUNTER_Z.x - depth / 2.0), shade)  # customer side of the counter
		overlay(world, Vector3(COUNTER_X.y - COUNTER_X.x, 0.002, depth), Vector3((COUNTER_X.x + COUNTER_X.y) / 2.0, 0.002,
			0.08 + depth / 2.0), shade)  # barista side


## Ribbed charcoal anti-fatigue mat on the barista side, under the machine and the mentor.
static func staff_mat(world: Node3D) -> void:
	var at := Vector3(0.25, 0.004, 0.52)
	IsoKit.box(world, Vector3(2.2, 0.008, 0.5), at, Color("#2E2A2C"))
	for k in 9:  # ribs
		IsoKit.box(world, Vector3(2.1, 0.004, 0.012), at + Vector3(0, 0.005, -0.2 + k * 0.05), Color("#3E393C"), false, false, false)


## Small succulent in a terracotta pot, centred on a table top at `top` (the surface).
static func succulent(world: Node3D, top: Vector3) -> void:
	IsoKit.cyl(world, 0.05, 0.07, top + Vector3(0, 0.035, 0), Color("#C0643A"), false, false, 0.06)
	IsoKit.cyl(world, 0.063, 0.015, top + Vector3(0, 0.072, 0), Color("#D27A4A"))  # rim
	for k in 6:  # rosette of fleshy leaves
		var a := k * TAU / 6.0
		var leaf := IsoKit.box(world, Vector3(0.035, 0.025, 0.07), top + Vector3(sin(a) * 0.035, 0.095, cos(a) * 0.035), Color("#5FA04A"))
		leaf.rotation = Vector3(-0.5, a, 0)
	IsoKit.sphere(world, 0.028, top + Vector3(0, 0.11, 0), Color("#7CC05A"))


## Burlap coffee sack, tied at the neck, open with beans showing.
static func sack(world: Node3D, at: Vector3) -> void:
	var burlap := Color("#B48C5C")
	IsoKit.cyl(world, 0.24, 0.34, at + Vector3(0, 0.17, 0), burlap, false, false, 0.2)
	IsoKit.cyl(world, 0.205, 0.04, at + Vector3(0, 0.15, 0), Color("#9C7646"))  # woven band
	IsoKit.cyl(world, 0.11, 0.07, at + Vector3(0, 0.37, 0), burlap)  # neck
	IsoKit.cyl(world, 0.12, 0.025, at + Vector3(0, 0.37, 0), Color("#6A4A2A"))  # rope tie
	IsoKit.cyl(world, 0.17, 0.05, at + Vector3(0, 0.425, 0), burlap, false, false, 0.19)  # folded-out mouth
	IsoKit.cyl(world, 0.15, 0.012, at + Vector3(0, 0.452, 0), Color("#4A2614"))  # beans
	for k in 7:
		var a := k * TAU / 7.0
		IsoKit.sphere(world, 0.022, at + Vector3(sin(a) * 0.08, 0.465, cos(a) * 0.08), Color("#5A3018"))
	var l := Label3D.new()
	l.text = "KOPI"
	l.font_size = 36
	l.pixel_size = 0.004
	l.modulate = Color("#4A2E16")
	l.position = at + Vector3(-0.17, 0.2, 0.17)
	l.rotation_degrees.y = -45.0  # on the side facing the camera
	world.add_child(l)


## Chalkboard menu: wood frame, slate board, chalk lines with prices and a cup sketch.
static func chalkboard(world: Node3D, at: Vector3) -> void:
	IsoKit.box(world, Vector3(0.78, 0.6, 0.04), at + Vector3(0, 0, 0.02), WOOD)
	IsoKit.box(world, Vector3(0.68, 0.5, 0.01), at + Vector3(0, 0, 0.045), Color("#2E3430"), false, false, false)
	var chalk := Color("#D8DCD4")
	for i in 5:  # menu lines: an item and its price
		var y := 0.17 - i * 0.075
		IsoKit.box(world, Vector3(0.24 - (i % 2) * 0.06, 0.018, 0.004), at + Vector3(-0.17, y, 0.052), chalk, false, false, false)
		IsoKit.box(world, Vector3(0.05, 0.018, 0.004), at + Vector3(0.01, y, 0.052), chalk.darkened(0.2), false, false, false)
	var cup := at + Vector3(0.19, -0.06, 0.052)  # cup sketch: body, handle, saucer, steam
	IsoKit.box(world, Vector3(0.12, 0.012, 0.004), cup + Vector3(0, -0.06, 0), chalk, false, false, false)
	IsoKit.box(world, Vector3(0.012, 0.09, 0.004), cup + Vector3(-0.05, 0, 0), chalk, false, false, false)
	IsoKit.box(world, Vector3(0.012, 0.09, 0.004), cup + Vector3(0.05, 0, 0), chalk, false, false, false)
	IsoKit.box(world, Vector3(0.1, 0.012, 0.004), cup + Vector3(0, 0.045, 0), chalk, false, false, false)
	IsoKit.box(world, Vector3(0.03, 0.04, 0.004), cup + Vector3(0.07, 0.005, 0), chalk, false, false, false)
	IsoKit.box(world, Vector3(0.16, 0.012, 0.004), cup + Vector3(0, -0.075, 0), chalk, false, false, false)
	for s in 2:
		IsoKit.box(world, Vector3(0.012, 0.06, 0.004), cup + Vector3(-0.02 + s * 0.04, 0.1, 0), chalk.darkened(0.15), false, false, false)


## Cake display: a wooden board with two cakes on small plates under one glass hemisphere
## (radius DOME_R, inside the counter top with a 10 cm margin). The cakes are opaque, so they
## draw in the opaque pass; the dome is the only see-through part and draws after them, so it
## always lies over everything inside it.
static func pastry_dome(world: Node3D, at: Vector3) -> void:
	const DOME_R := 0.27
	var base := at + Vector3(0, 0.012, 0)  # top of the board
	IsoKit.cyl(world, DOME_R + 0.03, 0.012, at + Vector3(0, 0.006, 0), Color("#8A5634"))
	for dx in [-0.11, 0.11]:
		var c := base + Vector3(dx, 0, 0)
		IsoKit.cyl(world, 0.1, 0.012, c + Vector3(0, 0.006, 0), Color("#C9A27C"))  # plate
		IsoKit.cyl(world, 0.065, 0.07, c + Vector3(0, 0.047, 0), Color("#E8A0B4"))  # cake
		IsoKit.sphere(world, 0.02, c + Vector3(0.015, 0.09, 0), Color("#C8323C"))  # cherry
	var glass := IsoKit.mat(Props.GLASS, false, true).duplicate() as StandardMaterial3D
	glass.albedo_color.a = 0.28  # a light glossy tint: the cakes read clearly through it
	glass.roughness = 0.05
	glass.rim_enabled = true  # brighter silhouette (Fresnel): the dome reads as glass, clear in the middle
	glass.rim = 1.0
	glass.rim_tint = 0.2
	var dome := SphereMesh.new()
	dome.radius = DOME_R
	dome.height = DOME_R
	dome.is_hemisphere = true
	dome.radial_segments = 20
	dome.rings = 6
	IsoKit._add(world, dome, base, glass)
	IsoKit.cyl(world, DOME_R + 0.005, 0.01, base + Vector3(0, 0.005, 0), Color("#D8E4E8"))  # glass foot ring
	IsoKit.sphere(world, 0.025, base + Vector3(0, DOME_R + 0.015, 0), Color("#5A3A26"))  # knob


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
