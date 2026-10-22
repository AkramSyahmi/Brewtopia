class_name LatteArtPanel
extends PanelContainer
## Latte art mini-game: the pitcher swings left and right over the cup; tap to pour when
## it is over the middle. The closer to the centre, the better the heart (score 0..1).

signal finished(score: float)

const R := 150.0  # cup radius on screen
const SWING := 2.4  # radians per second
const CREMA := Color("#C98B55")
const FOAM := Color("#FBF4EA")

var canvas: Control
var t := 0.0
var poured := false
var pour_x := 0.0


func _ready() -> void:
	var s := StyleBoxFlat.new()
	s.bg_color = Color("#F5ECE2")
	s.border_color = Color("#65422F")
	s.set_border_width_all(4)
	s.set_corner_radius_all(18)
	s.set_content_margin_all(18)
	add_theme_stylebox_override("panel", s)
	position = Vector2(380, 80)
	z_index = 10
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
	canvas.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			pour())
	canvas.draw.connect(draw_canvas)
	col.add_child(canvas)
	hide()


func start() -> void:
	t = 0.0
	poured = false
	show()


func swing_x() -> float:
	return sin(t * SWING) * R * 0.9


func _process(delta: float) -> void:
	if visible and not poured:
		t += delta
	if visible:
		canvas.queue_redraw()


func pour() -> void:
	if poured:
		return
	poured = true
	pour_x = swing_x()
	var score := clampf(1.0 - absf(pour_x) / (R * 0.8), 0.0, 1.0)
	await get_tree().create_timer(0.9).timeout
	finish(score)


func finish(score: float) -> void:
	hide()
	finished.emit(score)


func draw_canvas() -> void:
	var c := Vector2(240, 240)
	canvas.draw_circle(c + Vector2(0, 8), R + 18, Color("#D8CFC4"))  # saucer
	canvas.draw_circle(c, R, Color("#FFFFFF"))  # cup rim
	canvas.draw_circle(c, R - 14, CREMA)  # coffee
	canvas.draw_line(c - Vector2(0, R - 14), c + Vector2(0, R - 14), Color(1, 1, 1, 0.25), 2.0)  # centre guide
	if poured:  # milk heart where it was poured
		var at := c + Vector2(pour_x, 10)
		canvas.draw_circle(at + Vector2(-26, -20), 34, FOAM)
		canvas.draw_circle(at + Vector2(26, -20), 34, FOAM)
		canvas.draw_colored_polygon(PackedVector2Array([at + Vector2(-58, -12), at + Vector2(58, -12),
			at + Vector2(0, 60)]), FOAM)
	else:  # the pitcher spout swinging above the cup
		var x := c.x + swing_x()
		canvas.draw_colored_polygon(PackedVector2Array([Vector2(x - 26, 0), Vector2(x + 26, 0),
			Vector2(x, 44)]), Color("#B9BEC6"))
		canvas.draw_line(Vector2(x, 44), Vector2(x, c.y - 30), Color(FOAM, 0.6), 3.0)
