class_name PitcherMilk
extends Node2D
## The milk in the pitcher's mouth, drawn in the pitcher sprite's own pixels (so the same
## node works on the counter pitcher and, scaled up, in the steam popup). It fills the
## oval opening inside the metal rim: the back wall shows as a darker band, the front lip
## stays light metal. Empty = dark inside; cold = pale milk with a glint; heating warms it
## to cream; foam adds fine microfoam flecks and lifts the surface up to the back wall.
## Visual only: it just reads the station's milk temperature and foam.

const CENTRE := Vector2(25.5, 5.5)  # the opening in pitcher.png (re-measure if the art changes)
const RADII := Vector2(16.0, 3.4)
const BACK_WALL := Color("#6E737B")
const LIP := Color("#C7CACF")
const INSIDE := Color("#3E434B")  # empty: looking down into the steel
const COLD := Color("#F2F4F1")  # pale, slightly cool white
const WARM := Color("#F3E3CA")  # steamed: creamy
const FLECK := Color("#FFFAF0")  # microfoam

var has_milk := false
var temp := 5.0
var foam := 0.0


func set_milk(full: bool, temp_c: float, foam_amount: float) -> void:
	has_milk = full
	temp = temp_c
	foam = foam_amount
	queue_redraw()


func inside(x: int, y: int) -> bool:
	var d := (Vector2(x, y) + Vector2(0.5, 0.5) - CENTRE) / RADII
	return d.length_squared() <= 1.0


func _draw() -> void:
	var base := COLD.lerp(WARM, clampf((temp - 20.0) / 45.0, 0.0, 1.0))
	var lifted := has_milk and foam >= 0.35  # a foamy jug's surface rises to the back wall
	for y in range(int(CENTRE.y - RADII.y) - 1, int(CENTRE.y + RADII.y) + 1):
		for x in range(int(CENTRE.x - RADII.x) - 1, int(CENTRE.x + RADII.x) + 1):
			if not inside(x, y):
				continue
			var col: Color
			if not inside(x, y + 1):
				col = LIP  # front lip of the rim, in front of the milk
			elif not inside(x, y - 1) and not lifted:
				col = BACK_WALL  # the inside of the back wall above the surface
			elif not has_milk:
				col = INSIDE.lightened(0.08) if y <= CENTRE.y else INSIDE
			else:
				col = base
				if not inside(x - 1, y) or not inside(x + 2, y):
					col = base.darkened(0.08)  # where the milk meets the side walls
				if foam > 0.05 and (x * 3 + y * 5) % 7 == 0 and float((x * 7 + y * 11) % 10) < foam * 10.0:
					col = FLECK if temp > 20.0 else base.lightened(0.5)  # fine microfoam
			draw_rect(Rect2(x, y, 1, 1), col)
	if has_milk:  # a small glint on the surface
		draw_rect(Rect2(CENTRE.x - 9, CENTRE.y - 1, 3, 1), Color(1, 1, 1, 0.9 if foam < 0.35 else 0.6))
