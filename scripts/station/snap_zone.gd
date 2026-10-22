class_name SnapZone
extends Area2D
## A drop/tap target on the espresso station: an Area2D with a rectangle shape, plus a
## Marker2D ("Snap") where an item dropped here comes to rest. Coordinates are base
## pixels in the station world. EspressoStation finds zones with a physics point query.


static func make(zone_name: String, area: Rect2, snap: Vector2) -> SnapZone:
	var z := SnapZone.new()
	z.name = zone_name
	z.position = area.position
	z.monitoring = false  # only queried, never scans for overlaps itself
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = area.size
	shape.shape = rect
	shape.position = area.size / 2.0
	z.add_child(shape)
	var marker := Marker2D.new()
	marker.name = "Snap"
	marker.position = snap - area.position
	z.add_child(marker)
	return z


## Where a dropped item's anchor goes, in station world base pixels.
func snap_point() -> Vector2:
	return position + ($Snap as Marker2D).position
