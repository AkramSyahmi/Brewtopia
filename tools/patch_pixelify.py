"""Makes assets/fonts/PixelifySansBrew.ttf from PixelifySans.ttf (SIL OFL 1.1, no Reserved
Font Name, see assets/fonts/PixelifySans-OFL.txt) with three readability fixes for the game:

1. C and c: their opening on the right is under one design pixel tall (C: y 270-350, c: y 179-260),
   and at the weights the game uses (600/700) the variation closes it further, so they read as
   O / o ("MAKOIK", "Reoipes", "60°O"). C's opening grows one design pixel each way (270 -> 179,
   350 -> 441); c loses its bottom hook (179 -> 88), keeping the top one. Only existing points
   move (same point count), so the weight variation (gvar) still applies.
2. 5: it's drawn like S (rounded top-left corner, the top bar curling down on the right), so
   "25 g" read as "2S g" wherever a label doesn't use the Silkscreen digits (Recipe Book, Shop,
   station labels). Its top becomes a 5's: a square top-left corner and a flat bar across the
   full width. The moved points get explicit weight deltas (the outer corner's / the bar's
   inner edge's), so the shape stays square at 600/700 instead of being interpolated.
3. Ligatures: the 'liga' feature turns "fi" / "fl" / "ff" into ligature glyphs that read badly
   at small sizes ("portafilter" -> "portaAlter"). The feature is removed; f and i are drawn
   as separate letters. (A FontVariation's opentype_features doesn't reach a fallback font, so
   this can't be switched off in code for numbers() labels.)

Everything else (other glyphs, metrics, the wght axis) is unchanged. The family is renamed
"Pixelify Sans Brew" so the modified font isn't mistaken for the original.

Needs Python 3 with fontTools (pip install fonttools). Run from the repo root:
    python tools/patch_pixelify.py
"""
from fontTools.ttLib import TTFont

SRC = "assets/fonts/PixelifySans.ttf"
DST = "assets/fonts/PixelifySansBrew.ttf"
GAPS = {  # glyph -> {the opening's edge (y) -> new y}; points on the right side only (x in GAP_X)
    "C": {270: 179, 350: 441},
    "c": {179: 88},
}
GAP_X = (423, 525)  # the inner and outer edge of the letter's right side
# 5's top: point index -> (new position, its wght delta at 700). Points 13-15 were the rounded
# top-left corner, 16-21 the top-right hook; duplicates keep the point count (gvar needs it).
FIVE_TOP = {
    13: ((60, 631), (-2, 12)), 14: ((60, 631), (-2, 12)), 15: ((60, 631), (-2, 12)),
    16: ((525, 631), (17, 12)), 17: ((525, 631), (17, 12)), 18: ((525, 631), (17, 12)),
    19: ((525, 530), (17, -29)), 20: ((525, 530), (17, -29)), 21: ((525, 530), (17, -29)),
}
FIVE_OLD = {13: (60, 540), 14: (151, 540), 15: (151, 631), 16: (433, 631), 17: (433, 540),
            18: (525, 540), 19: (525, 350), 20: (423, 350), 21: (423, 530)}


def widen_c(font: TTFont) -> None:
    glyf = font["glyf"]
    for name, gap in GAPS.items():
        glyph = glyf[name]
        coords = glyph.getCoordinates(glyf)[0]
        moved = 0
        for i, (x, y) in enumerate(coords):
            if x in GAP_X and y in gap:
                coords[i] = (x, gap[y])
                moved += 1
        assert moved == 2 * len(gap), "%s outline isn't the expected one (moved %d points)" % (name, moved)
        glyph.coordinates = coords
        glyph.recalcBounds(glyf)


def square_five(font: TTFont) -> None:
    glyf = font["glyf"]
    glyph = glyf["five"]
    coords = glyph.getCoordinates(glyf)[0]
    for i, old in FIVE_OLD.items():
        assert tuple(coords[i]) == old, "5 outline isn't the expected one (point %d is %s)" % (i, coords[i])
    for i, (pos, _delta) in FIVE_TOP.items():
        coords[i] = pos
    glyph.coordinates = coords
    glyph.recalcBounds(glyf)
    variations = font["gvar"].variations["five"]
    assert len(variations) == 1, "expected one weight variation for 5"
    deltas = variations[0].coordinates
    for i, (_pos, delta) in FIVE_TOP.items():
        deltas[i] = delta


def drop_liga(font: TTFont) -> None:
    table = font["GSUB"].table
    records = table.FeatureList.FeatureRecord
    keep = [r for r in records if r.FeatureTag != "liga"]
    assert len(keep) == len(records) - 1, "expected exactly one 'liga' feature"
    old_index = {id(r): i for i, r in enumerate(records)}
    new_index = {old_index[id(r)]: i for i, r in enumerate(keep)}
    table.FeatureList.FeatureRecord = keep
    table.FeatureList.FeatureCount = len(keep)
    for script in table.ScriptList.ScriptRecord:  # renumber every language system's feature list
        systems = [script.Script.DefaultLangSys] + [l.LangSys for l in script.Script.LangSysRecord]
        for lang in systems:
            if lang is None:
                continue
            lang.FeatureIndex = [new_index[i] for i in lang.FeatureIndex if i in new_index]
            lang.FeatureCount = len(lang.FeatureIndex)
            if lang.ReqFeatureIndex != 0xFFFF:
                lang.ReqFeatureIndex = new_index.get(lang.ReqFeatureIndex, 0xFFFF)


def rename(font: TTFont) -> None:
    for rec in font["name"].names:
        text = rec.toUnicode()
        if rec.nameID in (1, 3, 4, 16, 18):
            rec.string = text.replace("Pixelify Sans", "Pixelify Sans Brew")
        elif rec.nameID == 6:
            rec.string = text.replace("PixelifySans", "PixelifySansBrew")


def main() -> None:
    font = TTFont(SRC)
    widen_c(font)
    square_five(font)
    drop_liga(font)
    rename(font)
    font.save(DST)
    print("wrote %s (C and c openings widened, 5 squared, 'liga' removed)" % DST)


if __name__ == "__main__":
    main()
