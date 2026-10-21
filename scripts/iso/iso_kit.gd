class_name IsoKit
extends RefCounted
## Builders for the isometric pixel-art look: simple 3D shapes with toon shading and
## an inverted-hull outline, rendered by IsoView at low resolution with nearest filtering.

const OUTLINE := Color("#1E1410")
const OUTLINE_SHADER := preload("res://scripts/iso/outline.gdshader")

static var _cache := {}


## Toon-lit material with a dark outline pass. `glass` makes it see-through.
static func mat(color: Color, metal := false, glass := false, outline := true) -> StandardMaterial3D:
	var key := "%s|%s|%s|%s" % [color.to_html(), metal, glass, outline]
	if _cache.has(key):
		return _cache[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
	m.specular_mode = BaseMaterial3D.SPECULAR_TOON
	m.roughness = 0.35 if metal else 0.85
	m.metallic = 0.5 if metal else 0.0
	m.metallic_specular = 0.7 if metal else 0.3
	if glass:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.albedo_color.a = 0.35
		m.roughness = 0.1
	if outline and not glass:
		var o := ShaderMaterial.new()
		o.shader = OUTLINE_SHADER
		o.set_shader_parameter("color", OUTLINE)
		m.next_pass = o
	_cache[key] = m
	return m


static func box(parent: Node3D, size: Vector3, pos: Vector3, color: Color, metal := false,
		glass := false, outline := true) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	return _add(parent, mesh, pos, mat(color, metal, glass, outline))


static func cyl(parent: Node3D, radius: float, height: float, pos: Vector3, color: Color,
		metal := false, glass := false, top_radius := -1.0) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.bottom_radius = radius
	mesh.top_radius = radius if top_radius < 0.0 else top_radius
	mesh.height = height
	mesh.radial_segments = 20
	mesh.rings = 1
	return _add(parent, mesh, pos, mat(color, metal, glass))


static func sphere(parent: Node3D, radius: float, pos: Vector3, color: Color) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 16
	mesh.rings = 8
	return _add(parent, mesh, pos, mat(color))


static func _add(parent: Node3D, mesh: Mesh, pos: Vector3, material: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = material
	mi.position = pos
	parent.add_child(mi)
	return mi


## Small checker texture for floor tiles.
static func checker(a: Color, b: Color, cells := 2) -> ImageTexture:
	var img := Image.create_empty(cells * 8, cells * 8, false, Image.FORMAT_RGBA8)
	for y in img.get_height():
		for x in img.get_width():
			img.set_pixel(x, y, a if ((x / 8) + (y / 8)) % 2 == 0 else b)
	return ImageTexture.create_from_image(img)
