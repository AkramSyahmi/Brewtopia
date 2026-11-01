extends SceneTree
## Makes assets/fonts/BrewtopiaDigits.ttf: Silkscreen Bold (SIL OFL 1.1, no Reserved Font
## Name) with its character map cut down to the number characters below. Used as a font
## whose fallback is Pixelify Sans (PixelUI.numbers), so in "RM 12" or "36.0 g · 27 s" the
## digits come from Silkscreen (5 is not an S, 0 is not an O) and the letters stay Pixelify.
## Only the 'cmap' table changes; glyphs and everything else are copied as they are.
## Run: Godot_console.exe --headless --path . --script res://tools/make_digit_font.gd

const SRC := "res://assets/fonts/Silkscreen-Bold.ttf"
const DST := "res://assets/fonts/BrewtopiaDigits.ttf"
## Not mapped (they stay Pixelify): % (reads like a Z), . and : (Silkscreen Bold's full stop is a
## 2x1 bar, so sentences read "please_"), and 4 (a solid block: "ORDER 4/4" looked like "¥/¥").
const CHARS := "012356789/"


func _initialize() -> void:
	var src := FileAccess.get_file_as_bytes(SRC)
	var font: FontFile = load(SRC)
	var map := {}  # char code -> glyph id
	for ch in CHARS:
		var gid := font.get_glyph_index(16, ch.unicode_at(0), 0)
		if gid > 0:
			map[ch.unicode_at(0)] = gid
	var tables := {}  # tag -> bytes
	var order: Array[String] = []
	var count := u16(src, 4)
	for i in count:
		var rec := 12 + i * 16
		var tag := src.slice(rec, rec + 4).get_string_from_ascii()
		order.append(tag)
		tables[tag] = src.slice(u32(src, rec + 8), u32(src, rec + 8) + u32(src, rec + 12))
	tables["cmap"] = cmap(map)
	var out := PackedByteArray()
	out.append_array(src.slice(0, 12))  # same sfnt version and table count
	var offset := 12 + count * 16
	var body := PackedByteArray()
	for tag in order:
		var data: PackedByteArray = tables[tag]
		out.append_array(tag.to_ascii_buffer())
		out.append_array(be32(checksum(data)))
		out.append_array(be32(offset + body.size()))
		out.append_array(be32(data.size()))
		body.append_array(data)
		while body.size() % 4 != 0:
			body.append(0)
	out.append_array(body)
	var f := FileAccess.open(DST, FileAccess.WRITE)
	f.store_buffer(out)
	f.close()
	print("wrote %s with %d characters: %s" % [DST, map.size(), CHARS])
	quit()


## cmap with one Windows Unicode (3,1) format-4 subtable: one segment per character.
func cmap(map: Dictionary) -> PackedByteArray:
	var codes := map.keys()
	codes.sort()
	var seg := codes.size() + 1  # + the closing 0xFFFF segment
	var pow2 := 1
	var sel := 0
	while pow2 * 2 <= seg:
		pow2 *= 2
		sel += 1
	var sub := PackedByteArray()
	var length := 16 + seg * 8
	for v in [4, length, 0, seg * 2, pow2 * 2, sel, seg * 2 - pow2 * 2]:
		sub.append_array(be16(v))
	for c in codes:
		sub.append_array(be16(c))  # endCode
	sub.append_array(be16(0xFFFF))
	sub.append_array(be16(0))  # reservedPad
	for c in codes:
		sub.append_array(be16(c))  # startCode
	sub.append_array(be16(0xFFFF))
	for c in codes:
		sub.append_array(be16((int(map[c]) - int(c)) & 0xFFFF))  # idDelta
	sub.append_array(be16(1))
	for i in seg:
		sub.append_array(be16(0))  # idRangeOffset
	var t := PackedByteArray()
	for v in [0, 1, 3, 1]:  # version, numTables, platform 3 (Windows), encoding 1 (Unicode BMP)
		t.append_array(be16(v))
	t.append_array(be32(12))
	t.append_array(sub)
	return t


func checksum(data: PackedByteArray) -> int:
	var padded := data.duplicate()
	while padded.size() % 4 != 0:
		padded.append(0)
	var sum := 0
	for i in range(0, padded.size(), 4):
		sum = (sum + u32(padded, i)) & 0xFFFFFFFF
	return sum


func u16(b: PackedByteArray, at: int) -> int:
	return (b[at] << 8) | b[at + 1]


func u32(b: PackedByteArray, at: int) -> int:
	return (b[at] << 24) | (b[at + 1] << 16) | (b[at + 2] << 8) | b[at + 3]


func be16(v: int) -> PackedByteArray:
	return PackedByteArray([(v >> 8) & 0xFF, v & 0xFF])


func be32(v: int) -> PackedByteArray:
	return PackedByteArray([(v >> 24) & 0xFF, (v >> 16) & 0xFF, (v >> 8) & 0xFF, v & 0xFF])
