class_name Props
extends RefCounted
## Detailed bar props built from simple 3D shapes (IsoKit). Units are metres.
## Every prop's origin is its bottom centre on the counter, front facing +Z (towards
## the barista) unless noted.

const STEEL := Color("#B9BEC6")
const STEEL_DARK := Color("#6E737C")
const BLACK := Color("#2B2729")
const CREAM := Color("#EFE6D8")
const PORCELAIN := Color("#F7F3EE")
const SAGE := Color("#8FAE6A")
const WOOD := Color("#8A5634")
const COFFEE := Color("#4A2614")
const CREMA := Color("#C98B55")
const RUBBER := Color("#38302F")
const LCD := Color("#9FD39A")
const RED := Color("#C8463C")
const GLASS := Color("#DCE8EC")

const FACE_Z := Vector3(90, 0, 0)  # rotates a cylinder so its flat face points +Z


static func node(parent: Node3D, pos := Vector3.ZERO) -> Node3D:
	var n := Node3D.new()
	n.position = pos
	parent.add_child(n)
	return n


static func lcd_label(parent: Node3D, pos: Vector3, size := 0.0009) -> Label3D:
	var l := Label3D.new()
	l.position = pos
	l.pixel_size = size
	l.font_size = 32
	l.modulate = Color("#1F3B22")
	l.outline_size = 0
	l.text = "0.0g"
	l.no_depth_test = false
	l.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	parent.add_child(l)
	return l


## Single-group espresso machine, 0.6 wide. Returns the root; useful children are
## named: "BrewButton", "Gauge", "ShotStream". Group head basket sits at (0, 0.22, 0.13).
static func espresso_machine(parent: Node3D, pos: Vector3) -> Node3D:
	var m := node(parent, pos)
	for fx in [-0.26, 0.26]:
		for fz in [-0.16, 0.16]:
			IsoKit.cyl(m, 0.02, 0.02, Vector3(fx, 0.01, fz), BLACK)
	IsoKit.box(m, Vector3(0.6, 0.04, 0.42), Vector3(0, 0.04, 0), BLACK)  # plinth
	IsoKit.box(m, Vector3(0.52, 0.4, 0.36), Vector3(0, 0.26, -0.03), STEEL, true)  # body
	IsoKit.box(m, Vector3(0.05, 0.42, 0.4), Vector3(-0.285, 0.27, -0.02), SAGE)  # side panels
	IsoKit.box(m, Vector3(0.05, 0.42, 0.4), Vector3(0.285, 0.27, -0.02), SAGE)
	IsoKit.box(m, Vector3(0.48, 0.12, 0.012), Vector3(0, 0.39, 0.155), CREAM)  # front control strip
	IsoKit.box(m, Vector3(0.16, 0.035, 0.006), Vector3(0, 0.425, 0.163), BLACK)  # name plate
	var plate := Label3D.new()
	plate.text = "BREWTOPIA"
	plate.font_size = 32
	plate.pixel_size = 0.0011
	plate.modulate = CREAM
	plate.position = Vector3(0, 0.425, 0.167)
	m.add_child(plate)
	for gx in [-0.16, 0.16]:  # pressure gauges
		var g := IsoKit.cyl(m, 0.034, 0.012, Vector3(gx, 0.385, 0.162), STEEL_DARK, true)
		g.rotation_degrees = FACE_Z
		var face := IsoKit.cyl(m, 0.027, 0.004, Vector3(gx, 0.385, 0.17), PORCELAIN)
		face.rotation_degrees = FACE_Z
		var needle := IsoKit.box(m, Vector3(0.004, 0.022, 0.002), Vector3(gx + 0.006, 0.39, 0.173), BLACK, false, false, false)
		needle.rotation_degrees = Vector3(0, 0, -35)
	var brew := IsoKit.cyl(m, 0.026, 0.02, Vector3(0.0, 0.36, 0.168), SAGE)  # brew button
	brew.rotation_degrees = FACE_Z
	brew.name = "BrewButton"
	IsoKit.box(m, Vector3(0.14, 0.07, 0.1), Vector3(0, 0.3, 0.14), STEEL, true)  # brew head block
	IsoKit.cyl(m, 0.052, 0.012, Vector3(0, 0.262, 0.13), STEEL_DARK, true)  # collar
	IsoKit.cyl(m, 0.046, 0.03, Vector3(0, 0.245, 0.13), STEEL, true)  # group head
	# drip tray with grate and a small scale on it
	IsoKit.box(m, Vector3(0.48, 0.035, 0.16), Vector3(0, 0.0775, 0.13), STEEL, true)
	for i in 9:
		IsoKit.box(m, Vector3(0.008, 0.003, 0.13), Vector3(-0.2 + i * 0.05, 0.096, 0.13), STEEL_DARK, true, false, false)
	IsoKit.box(m, Vector3(0.11, 0.018, 0.11), Vector3(0, 0.104, 0.13), BLACK)
	IsoKit.box(m, Vector3(0.07, 0.012, 0.004), Vector3(0, 0.104, 0.187), LCD, false, false, false)
	var scale_lcd := lcd_label(m, Vector3(0, 0.104, 0.19), 0.0006)
	scale_lcd.name = "ScaleLCD"
	# steam wand
	var wand := IsoKit.cyl(m, 0.007, 0.2, Vector3(0.22, 0.24, 0.17), STEEL, true)
	wand.rotation_degrees = Vector3(18, 0, 0)
	IsoKit.cyl(m, 0.016, 0.03, Vector3(0.22, 0.345, 0.16), STEEL_DARK, true)
	# cups warming on top
	IsoKit.box(m, Vector3(0.5, 0.012, 0.32), Vector3(0, 0.466, -0.03), STEEL_DARK, true)
	for i in 3:
		IsoKit.cyl(m, 0.038, 0.05, Vector3(-0.14 + i * 0.14, 0.497, -0.04), PORCELAIN, false, false, 0.03)
	# coffee streams from the portafilter spouts into the cup
	var streams := node(m, Vector3.ZERO)
	streams.name = "ShotStream"
	for sx in [-0.012, 0.012]:
		IsoKit.cyl(streams, 0.003, 0.07, Vector3(sx, 0.16, 0.13), COFFEE, false, false, -1.0)
	streams.hide()
	return m


## Grinder with built-in scale. Children: "GrindButton", "Dial", "GroundsStream", "LCD".
## Portafilter rests under the chute with its basket at (0, 0.115, 0.1).
static func grinder(parent: Node3D, pos: Vector3) -> Node3D:
	var g := node(parent, pos)
	IsoKit.box(g, Vector3(0.17, 0.045, 0.24), Vector3(0, 0.0225, 0.01), BLACK)  # base
	IsoKit.box(g, Vector3(0.07, 0.024, 0.004), Vector3(0, 0.024, 0.132), LCD, false, false, false)
	var lcd := lcd_label(g, Vector3(0, 0.024, 0.135), 0.0007)
	lcd.name = "LCD"
	IsoKit.box(g, Vector3(0.012, 0.01, 0.07), Vector3(-0.038, 0.135, 0.075), STEEL_DARK, true)  # fork
	IsoKit.box(g, Vector3(0.012, 0.01, 0.07), Vector3(0.038, 0.135, 0.075), STEEL_DARK, true)
	IsoKit.cyl(g, 0.068, 0.3, Vector3(0, 0.195, -0.03), CREAM)  # body
	IsoKit.cyl(g, 0.072, 0.02, Vector3(0, 0.35, -0.03), STEEL_DARK, true)  # collar
	var chute := IsoKit.box(g, Vector3(0.034, 0.024, 0.06), Vector3(0, 0.205, 0.05), STEEL, true)
	chute.rotation_degrees = Vector3(-20, 0, 0)
	var dial := IsoKit.cyl(g, 0.03, 0.014, Vector3(-0.025, 0.29, 0.04), WOOD)
	dial.rotation_degrees = FACE_Z
	dial.name = "Dial"
	IsoKit.box(dial, Vector3(0.006, 0.006, 0.022), Vector3(0, 0.008, 0.0), CREAM, false, false, false)  # notch
	var btn := IsoKit.cyl(g, 0.014, 0.014, Vector3(0.035, 0.29, 0.038), RED)
	btn.rotation_degrees = FACE_Z
	btn.name = "GrindButton"
	IsoKit.cyl(g, 0.05, 0.17, Vector3(0, 0.445, -0.03), GLASS, false, true, 0.085)  # hopper
	IsoKit.cyl(g, 0.045, 0.1, Vector3(0, 0.41, -0.03), COFFEE, false, false, 0.07)  # beans
	for i in 10:
		var a := TAU * i / 10.0
		IsoKit.sphere(g, 0.008, Vector3(cos(a) * 0.05, 0.46, -0.03 + sin(a) * 0.05), Color("#6B3A20"))
	IsoKit.cyl(g, 0.09, 0.022, Vector3(0, 0.54, -0.03), BLACK)  # lid
	IsoKit.cyl(g, 0.018, 0.02, Vector3(0, 0.56, -0.03), STEEL_DARK, true)
	var stream := IsoKit.cyl(g, 0.006, 0.06, Vector3(0, 0.165, 0.1), Color("#5C351F"))
	stream.name = "GroundsStream"
	stream.hide()
	return g


## Portafilter, origin at the basket centre; handle points +Z. Child "Content" holds
## the coffee: shown/scaled per state by set_portafilter_state().
static func portafilter(parent: Node3D) -> Node3D:
	var p := node(parent)
	IsoKit.cyl(p, 0.045, 0.03, Vector3.ZERO, STEEL, true)  # basket
	IsoKit.cyl(p, 0.049, 0.008, Vector3(0, 0.015, 0), STEEL_DARK, true)  # rim
	for sx in [-0.012, 0.012]:
		IsoKit.cyl(p, 0.006, 0.02, Vector3(sx, -0.022, 0), STEEL_DARK, true)  # spouts
	var neck := IsoKit.box(p, Vector3(0.02, 0.018, 0.04), Vector3(0, 0.0, 0.06), STEEL, true)
	neck.rotation_degrees = Vector3(-10, 0, 0)
	var handle := IsoKit.cyl(p, 0.014, 0.12, Vector3(0, -0.012, 0.135), WOOD, false, false, 0.016)
	handle.rotation_degrees = Vector3(80, 0, 0)
	var content := IsoKit.cyl(p, 0.038, 0.01, Vector3(0, 0.014, 0), COFFEE)
	content.name = "Content"
	content.hide()
	return p


## state: "empty", "dosed" (loose mound), "tamped" (flat), "used" (dark puck).
static func set_portafilter_state(p: Node3D, state: String) -> void:
	var content: MeshInstance3D = p.get_node("Content")
	content.visible = state != "empty"
	match state:
		"dosed":
			content.scale = Vector3(1, 2.2, 1)
			content.position.y = 0.022
			content.material_override = IsoKit.mat(Color("#6B3A20"))
		"tamped":
			content.scale = Vector3.ONE
			content.position.y = 0.014
			content.material_override = IsoKit.mat(COFFEE)
		"used":
			content.scale = Vector3.ONE
			content.position.y = 0.012
			content.material_override = IsoKit.mat(Color("#24140C"))


static func tamper(parent: Node3D) -> Node3D:
	var t := node(parent)
	IsoKit.cyl(t, 0.029, 0.02, Vector3(0, 0.01, 0), STEEL, true)
	IsoKit.cyl(t, 0.012, 0.05, Vector3(0, 0.045, 0), STEEL_DARK, true)
	IsoKit.cyl(t, 0.016, 0.05, Vector3(0, 0.085, 0), WOOD, false, false, 0.012)
	IsoKit.sphere(t, 0.02, Vector3(0, 0.115, 0), WOOD)
	return t


## Cup with saucer; child "Coffee" is a disc moved by set_cup_level().
static func cup(parent: Node3D) -> Node3D:
	var c := node(parent)
	IsoKit.cyl(c, 0.06, 0.008, Vector3(0, 0.004, 0), PORCELAIN)  # saucer
	IsoKit.cyl(c, 0.032, 0.06, Vector3(0, 0.038, 0), PORCELAIN, false, false, 0.042)
	var handle := IsoKit.box(c, Vector3(0.008, 0.03, 0.02), Vector3(0.048, 0.04, 0), PORCELAIN)
	handle.rotation_degrees = Vector3(0, 0, 10)
	var coffee := IsoKit.cyl(c, 0.036, 0.004, Vector3(0, 0.02, 0), COFFEE)
	coffee.name = "Coffee"
	coffee.hide()
	return c


## level 0..1 of the cup filled with coffee (crema on top when nearly full).
static func set_cup_level(c: Node3D, level: float) -> void:
	var coffee: MeshInstance3D = c.get_node("Coffee")
	coffee.visible = level > 0.02
	var l := clampf(level, 0.0, 1.0)
	coffee.position.y = 0.012 + 0.052 * l
	var radius := 0.033 + 0.008 * l
	coffee.scale = Vector3(radius / 0.036, 1, radius / 0.036)
	coffee.material_override = IsoKit.mat(CREMA if l > 0.7 else COFFEE)


static func cup_stack(parent: Node3D, pos: Vector3) -> Node3D:
	var s := node(parent, pos)
	IsoKit.box(s, Vector3(0.2, 0.015, 0.16), Vector3(0, 0.0075, 0), WOOD)
	for i in 2:
		for k in 3:
			IsoKit.cyl(s, 0.036, 0.05, Vector3(-0.045 + i * 0.09, 0.04 + k * 0.035, 0), PORCELAIN, false, false, 0.03)
	return s


static func tamp_mat(parent: Node3D, pos: Vector3) -> Node3D:
	var t := node(parent, pos)
	IsoKit.box(t, Vector3(0.24, 0.015, 0.16), Vector3(0, 0.0075, 0), RUBBER)
	return t


static func knock_box(parent: Node3D, pos: Vector3) -> Node3D:
	var k := node(parent, pos)
	IsoKit.box(k, Vector3(0.15, 0.12, 0.16), Vector3(0, 0.06, 0), BLACK)
	IsoKit.box(k, Vector3(0.13, 0.01, 0.14), Vector3(0, 0.116, 0), Color("#24140C"), false, false, false)
	var bar := IsoKit.cyl(k, 0.01, 0.15, Vector3(0, 0.125, 0), RUBBER)
	bar.rotation_degrees = Vector3(0, 0, 90)
	return k


static func serve_tray(parent: Node3D, pos: Vector3) -> Node3D:
	var s := node(parent, pos)
	IsoKit.box(s, Vector3(0.22, 0.012, 0.18), Vector3(0, 0.006, 0), WOOD)
	IsoKit.box(s, Vector3(0.2, 0.004, 0.16), Vector3(0, 0.013, 0), Color("#A7C77A"), false, false, false)
	var l := Label3D.new()
	l.text = "SERVE"
	l.font_size = 32
	l.pixel_size = 0.0022
	l.modulate = Color("#2E4A1E")
	l.rotation_degrees = Vector3(-90, 0, 0)
	l.position = Vector3(0, 0.017, 0.02)
	s.add_child(l)
	return s


static func milk(parent: Node3D, pos: Vector3) -> void:
	IsoKit.box(parent, Vector3(0.07, 0.17, 0.07), pos + Vector3(0, 0.085, 0), Color("#F3F6FA"))
	IsoKit.box(parent, Vector3(0.072, 0.05, 0.072), pos + Vector3(0, 0.08, 0), Color("#3B6FD1"))
	var top := IsoKit.box(parent, Vector3(0.07, 0.03, 0.05), pos + Vector3(0, 0.18, 0), Color("#F3F6FA"))
	top.rotation_degrees = Vector3(0, 0, 0)


## Blocky low-poly person, origin at the feet, facing +Z. `look` keys:
## skin, hair, shirt, pants, hair_style ("short", "bun", "long", "cap"), cap, apron, glasses, beard.
static func person(parent: Node3D, look: Dictionary) -> Node3D:
	var p := node(parent)
	var body := node(p)  # bobbed while walking
	body.name = "Body"
	var skin: Color = look.get("skin", Color("#D9A57A"))
	var hair: Color = look.get("hair", Color("#2A1B14"))
	var shirt: Color = look.get("shirt", Color("#5B7DB1"))
	var pants: Color = look.get("pants", Color("#3A3F4E"))
	for sx in [-0.07, 0.07]:
		IsoKit.box(body, Vector3(0.12, 0.74, 0.13), Vector3(sx, 0.42, 0), pants)
		IsoKit.box(body, Vector3(0.13, 0.06, 0.19), Vector3(sx, 0.03, 0.025), BLACK)
	IsoKit.box(body, Vector3(0.36, 0.56, 0.22), Vector3(0, 1.06, 0), shirt)
	for sx in [-0.235, 0.235]:
		IsoKit.box(body, Vector3(0.1, 0.5, 0.11), Vector3(sx, 1.04, 0), shirt)
		IsoKit.box(body, Vector3(0.09, 0.09, 0.09), Vector3(sx, 0.75, 0), skin)
	if look.has("apron"):
		IsoKit.box(body, Vector3(0.3, 0.66, 0.02), Vector3(0, 0.92, 0.12), look.apron)
	IsoKit.box(body, Vector3(0.12, 0.08, 0.12), Vector3(0, 1.37, 0), skin)  # neck
	IsoKit.box(body, Vector3(0.27, 0.28, 0.25), Vector3(0, 1.54, 0), skin)  # head
	for ex in [-0.06, 0.06]:
		IsoKit.box(body, Vector3(0.04, 0.05, 0.01), Vector3(ex, 1.55, 0.128), BLACK, false, false, false)
	IsoKit.box(body, Vector3(0.08, 0.015, 0.01), Vector3(0, 1.47, 0.128), Color("#8A4A3A"), false, false, false)
	if look.get("glasses", false):
		IsoKit.box(body, Vector3(0.2, 0.06, 0.012), Vector3(0, 1.555, 0.132), Color("#1E1410"), false, false, false)
	if look.get("beard", false):
		IsoKit.box(body, Vector3(0.25, 0.1, 0.03), Vector3(0, 1.45, 0.12), hair, false, false, false)
	match look.get("hair_style", "short"):
		"cap":
			var cap: Color = look.get("cap", Color("#C0504D"))
			IsoKit.box(body, Vector3(0.29, 0.1, 0.27), Vector3(0, 1.71, 0), cap)
			IsoKit.box(body, Vector3(0.24, 0.025, 0.12), Vector3(0, 1.67, 0.18), cap)
		_:
			IsoKit.box(body, Vector3(0.29, 0.09, 0.27), Vector3(0, 1.71, 0), hair)
			IsoKit.box(body, Vector3(0.29, 0.2, 0.06), Vector3(0, 1.6, -0.11), hair)
			if look.get("hair_style", "short") == "bun":
				IsoKit.box(body, Vector3(0.13, 0.12, 0.12), Vector3(0, 1.8, -0.06), hair)
			elif look.get("hair_style", "short") == "long":
				IsoKit.box(body, Vector3(0.3, 0.42, 0.08), Vector3(0, 1.42, -0.1), hair)
	var emote := Label3D.new()
	emote.name = "Emote"
	emote.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	emote.font_size = 64
	emote.pixel_size = 0.004
	emote.outline_size = 12
	emote.modulate = Color("#FFE066")
	emote.position = Vector3(0, 2.05, 0)
	emote.no_depth_test = true
	p.add_child(emote)
	return p


static func pitcher(parent: Node3D, pos: Vector3) -> void:
	IsoKit.cyl(parent, 0.04, 0.1, pos + Vector3(0, 0.05, 0), STEEL, true, false, 0.035)
	var h := IsoKit.box(parent, Vector3(0.008, 0.05, 0.03), pos + Vector3(0.048, 0.06, 0), STEEL_DARK, true)
	h.rotation_degrees = Vector3(0, 0, -10)
