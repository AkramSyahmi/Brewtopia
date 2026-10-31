class_name CupLiquid
extends Node2D
## The drink inside a cup, drawn row by row in whole pixels and clipped to the cup's inner
## shape (read from the sprite: each row's opaque width minus the wall, so it follows the
## taper and never crosses the rim). Clear cups (glass, iced: side view) show the layers
## rising from the bottom: espresso with crema, milk, then foam on top (thicker for a
## cappuccino). The ceramic latte cup (top view) shows the drink's surface in its opening.
## Levels ease to their targets; this is visual only, the station keeps the real amounts.

const COFFEE := Color("#4A2A18")
const CHOC := Color("#3A1C14")  # mocha: chocolate syrup darkens the coffee
const CREMA := Color("#B9783E")
const MILK := Color("#F3E6D2")
const FOAM := Color("#FBF4EA")
const SYRUP_TINT := {"caramel": Color("#C98A45"), "gula_melaka": Color("#9C5A2C"),
	"condensed_milk": Color("#F1D9A6"), "chocolate": Color("#6B3A20")}
const FILL_SPEED := 24.0  # px per second the shown level moves
const CAPPUCCINO_FOAM := 0.45  # milk at least this foamy looks like a cappuccino cap

var inside: Rect2
var top_view := false
var spans := {}  # row y -> Vector2i(left, right), inclusive
var coffee := 0.0  # shown heights in px, easing toward want_*
var milk := 0.0
var want_coffee := 0.0
var want_milk := 0.0
var foam := 0.0
var cold := false
var base := COFFEE
var milk_col := MILK
var art := false  # a poured heart is the foam on a latte


func _init(tex: Texture2D, inside_rect: Rect2, top: bool) -> void:
	inside = inside_rect
	top_view = top
	var im := tex.get_image()
	if im.is_compressed():
		im.decompress()
	for y in range(int(inside.position.y), int(inside.end.y)):
		var l := -1
		var r := -1
		for x in im.get_width():
			if im.get_pixel(x, y).a > 0.5:
				if l < 0:
					l = x
				r = x
		if r - l > 6:
			spans[y] = Vector2i(l + 2, r - 2)  # 2 px of wall/rim stay visible
	set_process(false)


## New target levels (px of the inside rect) and the look of the drink.
func set_drink(coffee_h: float, milk_h: float, drink: Dictionary) -> void:
	want_coffee = coffee_h
	want_milk = milk_h
	foam = drink.get("milk_foam", 0.0)
	art = drink.has("art")
	cold = drink.get("milk_temp", 99.0) < 20.0
	var syrups: Dictionary = drink.get("syrups", {})
	base = CHOC if syrups.has("chocolate") else COFFEE
	milk_col = MILK if cold else MILK.lerp(CREMA, 0.3)  # steamed milk takes on warm coffee colour
	for s in syrups:
		milk_col = milk_col.lerp(SYRUP_TINT.get(s, milk_col), 0.35)
	set_process(true)
	queue_redraw()


func _process(delta: float) -> void:
	coffee = move_toward(coffee, want_coffee, FILL_SPEED * delta)
	milk = move_toward(milk, want_milk, FILL_SPEED * delta)
	queue_redraw()
	if coffee == want_coffee and milk == want_milk:
		set_process(false)


func _draw() -> void:
	if top_view:
		draw_top()
	else:
		draw_side()


## One shaded row: darker at the edges (right side most), a highlight near the left wall.
func row(y: int, col: Color, inset := 0) -> Vector2i:
	var s: Vector2i = spans.get(y, Vector2i(0, -1))
	s = Vector2i(s.x + inset, s.y - inset)
	if s.y - s.x < 0:
		return s
	draw_rect(Rect2(s.x, y, s.y - s.x + 1, 1), col)
	if s.y - s.x >= 4:
		draw_rect(Rect2(s.x, y, 1, 1), col.darkened(0.15))
		draw_rect(Rect2(s.y - 1, y, 2, 1), col.darkened(0.25))
		draw_rect(Rect2(s.x + 2, y, 1, 1), col.lightened(0.15))
	return s


## Glass and iced cup: layers from the bottom up.
func draw_side() -> void:
	var nc := roundi(coffee)
	var nm := roundi(milk)
	var n := nc + nm
	var nf := 0 if cold or nm == 0 else clampi(roundi(nm * foam * 0.7), 1, nm)
	var ncr := 0 if nm > 0 else (2 if nc >= 5 else 1)  # crema only shows on a bare shot
	var bottom := int(inside.end.y) - 1
	for k in n:
		var y := bottom - k
		var col := base
		if k >= nc - ncr and k < nc:
			col = CREMA
		elif k >= nc and k < n - nf:
			col = base.lerp(milk_col, minf(0.45 + 0.3 * (k - nc), 1.0))  # coffee clouds into the milk
		elif k >= n - nf:
			col = FOAM
		if k == n - 1:
			col = col.lightened(0.12)  # the surface catches the light
		var s := row(y, col)
		if k >= n - nf:  # foam bubbles
			for x in range(s.x + 1 + (y % 2) * 2, s.y - 1, 4):
				draw_rect(Rect2(x, y, 1, 1), FOAM.darkened(0.08))


## Latte cup seen from above: the surface fills the opening, smaller and lower when low.
## Bare shot = crema with a dark edge; milk = latte brown; foamy milk = a wide white cap.
## (The heart itself is drawn by the station on top.)
func draw_top() -> void:
	var f := clampf((coffee + milk) / inside.size.y, 0.0, 1.0)
	if f <= 0.0:
		return
	var k := roundi((1.0 - f) * 3.0)
	var y0 := int(inside.position.y) + k
	var y1 := int(inside.end.y) - 1
	var latte := base.lerp(milk_col, 0.5).lerp(CREMA, 0.4)  # warm caramel-brown
	for y in range(y0, y1 + 1):
		var edge := y == y0 or y == y1
		if milk <= 0.0:
			var s := row(y, COFFEE if edge else CREMA, k)
			for x in range(s.x + 2 + (y % 2) * 2, s.y - 1, 5):  # crema flecks
				draw_rect(Rect2(x, y, 1, 1), CREMA.lightened(0.2))
		else:
			row(y, latte, k)
			if not edge:  # foam in the middle: a wide cap for a cappuccino, a small one for a latte
				var cap := 2 if foam >= CAPPUCCINO_FOAM else 6
				if not cold and (cap == 2 or not art):
					row(y, FOAM, k + cap)
