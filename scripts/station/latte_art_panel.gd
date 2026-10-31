class_name LatteArtPanel
extends PanelContainer
## Latte art mini-game: the pitcher swings left and right over the cup; tap to pour when
## it is over the middle. The closer to the centre, the better the art (score 0..1).
## Drawn as pixel art: an 80x70-cell image scaled x6 (nearest), cup seen from above on its
## saucer. The pour builds the pattern where it landed: a full rosetta with a heart for a
## great pour, a smaller lopsided one for a good pour, an uneven blob for a poor one.

signal finished(score: float)

const R := 150.0  # cup radius on screen (the swing and the score use this)
const SWING := 2.4  # radians per second
const P := 6  # screen px per art pixel
const GRID := Vector2i(80, 70)
const C := Vector2(40.0, 39.0)  # cup centre, in cells
const CUP_R := 25.0  # = R / P
const COFFEE_R := 20.0
const REVEAL_S := 0.8  # the pattern forms while pouring
const HOLD_S := 1.4  # then it stays a moment before the panel closes

const OUT := Color("#5A3F30")
const SAUCER := Color("#EFE6DB")
const SAUCER_SH := Color("#DCCFC1")
const SAUCER_HI := Color("#FAF5EE")
const RIM := Color("#FBF7F1")
const RIM_SH := Color("#E3D8CB")
const RIM_HI := Color("#FFFFFF")
const INNER_SH := Color("#C9BBAB")
const CREMA_D := Color("#8E4F25")
const CREMA := Color("#A8622F")
const LATTE := Color("#B97A45")
const LATTE2 := Color("#C0844E")
const SPECK := Color("#D9A066")
const HALO := Color("#CF9A66")
const FOAM := Color("#F7EDDF")
const FOAM_SH := Color("#E9D3B6")
const METAL := Color("#B9BEC6")

var canvas: Control
var t := 0.0
var poured := false
var pour_x := 0.0
var score := 0.0
var since_pour := 0.0
var tex: ImageTexture
var img: Image


func _ready() -> void:
	add_theme_stylebox_override("panel", PixelUI.cream_panel())  # pixel cream sign, gold rim
	position = Vector2(380, 80)
	var col := VBoxContainer.new()
	add_child(col)
	var title := Label.new()
	title.text = "Latte art! Tap when the pitcher is over the middle."
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color("#36251D"))
	col.add_child(title)
	canvas = Control.new()
	canvas.custom_minimum_size = Vector2(480, 420)
	canvas.mouse_filter = MOUSE_FILTER_STOP
	canvas.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	canvas.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			pour())
	canvas.draw.connect(draw_canvas)
	col.add_child(canvas)
	img = Image.create(GRID.x, GRID.y, false, Image.FORMAT_RGBA8)
	hide()


func start() -> void:
	t = 0.0
	poured = false
	since_pour = 0.0
	paint(0.0)
	show()


func swing_x() -> float:
	return sin(t * SWING) * R * 0.9


func _process(delta: float) -> void:
	if not visible:
		return
	if not poured:
		t += delta
	elif since_pour < REVEAL_S:
		since_pour += delta
		paint(minf(since_pour / REVEAL_S, 1.0))
	canvas.queue_redraw()


func pour() -> void:
	if poured:
		return
	poured = true
	pour_x = swing_x()
	score = clampf(1.0 - absf(pour_x) / (R * 0.8), 0.0, 1.0)
	await get_tree().create_timer(HOLD_S).timeout
	if poured and visible:
		finish(score)


func finish(final_score: float) -> void:
	score = final_score
	hide()
	finished.emit(final_score)


# ---------- the picture ----------

## Rebuilds the cup image; `stage` 0..1 = how far the pour's pattern has formed.
func paint(stage: float) -> void:
	var foam := {}  # cell -> true where milk foam shows
	if poured:
		var origin := C + Vector2(roundf(pour_x / P) + 0.5, 1.0)  # on a cell centre, so the stem is 1 px
		for y in GRID.y:
			for x in GRID.x:
				var cell := Vector2(x, y) + Vector2(0.5, 0.5)
				if cell.distance_to(C) <= COFFEE_R and is_foam(cell - origin, stage):
					foam[Vector2i(x, y)] = true
	for y in GRID.y:
		for x in GRID.x:
			img.set_pixel(x, y, pixel(Vector2i(x, y), foam))
	if tex == null:
		tex = ImageTexture.create_from_image(img)
	else:
		tex.update(img)


## Small fixed noise so the coffee surface isn't flat.
func noise(x: int, y: int) -> int:
	return (x * 73 + y * 151 + x * y * 7) % 23


func pixel(c: Vector2i, foam: Dictionary) -> Color:
	var cell := Vector2(c) + Vector2(0.5, 0.5)
	var d := cell.distance_to(C)
	var lit := (cell - C).normalized().dot(Vector2(-0.7, -0.7))  # light from the top left
	# handle, to the right of the cup
	if c.x >= 64 and c.x <= 71 and c.y >= 36 and c.y <= 42 and d > CUP_R:
		if c.x == 71 or c.y == 36 or c.y == 42:
			return OUT
		return RIM_SH if c.y >= 40 else RIM
	if d <= CUP_R:
		if d > CUP_R - 1.0:
			return OUT
		if d > COFFEE_R + 1.0:  # ceramic rim
			if lit > 0.55 and d > CUP_R - 2.5:
				return RIM_HI
			return RIM_SH if lit < -0.35 else RIM
		if d > COFFEE_R:  # inner wall in the rim's shadow
			return INNER_SH if lit > -0.3 else RIM_SH
		if foam.has(c):
			for o in [Vector2i(0, 1), Vector2i(1, 0), Vector2i(0, -1), Vector2i(-1, 0)]:
				if not foam.has(c + o):
					return FOAM_SH  # soft edge of the foam
			return FOAM
		for o in [Vector2i(0, 1), Vector2i(1, 0), Vector2i(0, -1), Vector2i(-1, 0)]:
			if foam.has(c + o):
				return HALO  # milk blending into the coffee
		if d > COFFEE_R - 1.0 or (d > COFFEE_R - 2.0 and lit > 0.3):
			return CREMA_D  # crema ring, darker under the rim's shadow
		if d > COFFEE_R - 3.0:
			return CREMA if (c.x + c.y) % 2 == 0 else LATTE
		var n := noise(c.x, c.y)
		if n == 0 and lit > 0.0:
			return SPECK
		return LATTE2 if n < 7 else LATTE
	var ds := cell.distance_to(C + Vector2(0, 1))  # saucer
	if ds <= 29.0:
		if ds > 28.0:
			return OUT
		if cell.distance_to(C + Vector2(1.5, 2.5)) <= CUP_R + 0.5:
			return SAUCER_SH  # the cup's shadow
		if ds > 26.0 and lit > 0.45:
			return SAUCER_HI
		return SAUCER_SH if ds > 27.0 and lit < -0.3 else SAUCER
	return Color.TRANSPARENT


## Foam pattern in cells around where the milk landed (p = cell - origin).
func is_foam(p: Vector2, stage: float) -> bool:
	if score < 0.5:  # poor pour: an uneven blob that spreads out
		var g := 0.4 + 0.6 * stage
		var ragged := float(noise(int(p.x + 40.0), int(p.y + 40.0)) % 5) * 0.3
		return p.distance_to(Vector2(0, 2)) < 6.5 * g - ragged \
			or p.distance_to(Vector2(3, -2)) < 4.0 * g - ragged \
			or p.distance_to(Vector2(-4, 5)) < 3.0 * g
	var great := score >= 0.8
	var n := 5 if great else 3
	var lean := 0.0 if great else signf(pour_x) * 0.6  # a good pour leans to one side
	var shown := ceili(stage * n)
	var top := 0.0
	var leaf := false
	for k in n:  # leaves (U-shaped wings, thick at the bottom, thin up the sides), big one first
		var yk := 10.0 - k * 3.0
		var w := 10.0 - k * 1.5
		var q := Vector2(p.x - lean * k, p.y)
		top = yk - 4.0
		if k >= shown:
			continue
		var outer := pow(q.x / w, 2) + pow((q.y - yk) / 6.0, 2) <= 1.0
		var inner := pow(q.x / (w - 1.5), 2) + pow((q.y - yk + 1.8) / 6.0, 2) <= 1.0
		if outer and not inner and q.y > yk - 2.2:
			leaf = true
	if leaf:
		# the pull-through: a coffee line down the middle splits each leaf into two wings
		return not (stage >= 1.0 and great and absf(p.x) < 0.5)
	if stage > 0.75:  # heart above the leaves
		var hs := 3.6 if great else 2.8
		var hv := Vector2(p.x - lean * n, -(p.y - (top - 1.5))) / hs
		if pow(hv.x * hv.x + hv.y * hv.y - 1.0, 3) - hv.x * hv.x * pow(hv.y, 3) <= 0.0:
			return true
	return false


func draw_canvas() -> void:
	if tex:
		canvas.draw_texture_rect(tex, Rect2(Vector2.ZERO, Vector2(GRID * P)), false)
	var ticks := Color(OUT, 0.55)  # the middle, marked on the saucer above and below the cup
	canvas.draw_rect(Rect2(C.x * P - P / 2.0, (C.y - 28) * P, P, P * 2), ticks)
	if poured:
		return
	var x := C.x * P + swing_x()  # the pitcher spout swinging above the cup, in art pixels
	var cx := roundf(x / P) * P
	for r in 5:
		var half := (4 - r) * P
		canvas.draw_rect(Rect2(cx - half - P / 2.0, r * P, half * 2 + P, P), OUT if r == 0 else METAL)
	canvas.draw_rect(Rect2(cx - P / 2.0, 5 * P, P, (C.y - 12) * P - 5 * P), FOAM_SH)  # the milk stream
