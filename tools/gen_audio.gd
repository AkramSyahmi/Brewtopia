extends SceneTree
## Synthesises the game's placeholder sounds and music into res://assets/audio/*.wav
## (original, made in code, so no licence issues). Run:
##   Godot_console.exe --headless --path . --script res://tools/gen_audio.gd
## then `--import`. Sounds listed in assets/audio/KEEP.txt are skipped (real recordings).
## Loops (grind, pour, steam, music) are saved with loop points set.

const OUT := "res://assets/audio/%s.wav"
const RATE := 22050

var rng := RandomNumberGenerator.new()
var keep: Array = []


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://assets/audio"))
	var kf := ProjectSettings.globalize_path("res://assets/audio/KEEP.txt")
	if FileAccess.file_exists(kf):
		keep = Array(FileAccess.get_file_as_string(kf).split("\n")).map(func(l): return l.strip_edges())
	rng.seed = 42
	save("grind", grind(), true)
	save("pour", pour(), true)
	save("steam", steam(), true)
	save("bell", bell())
	save("click", blip(900.0, 0.06, 0.35))
	save("clink", clink(0.8))
	save("thud", thud(0.9))
	save("knock", concat([thud(1.0), silence(0.08), thud(0.8)]))
	save("ice", concat([clink(0.5, 1.4), silence(0.05), clink(0.4, 1.7), silence(0.04), clink(0.35, 1.2)]))
	save("pump", pump())
	save("shake", concat([pump(0.08, 0.25), silence(0.04), pump(0.08, 0.25), silence(0.04), pump(0.08, 0.25)]))
	save("serve", swoosh())
	save("perfect", arpeggio([72, 76, 79, 84], 0.09, 0.5))
	save("good", arpeggio([72, 79], 0.12, 0.45))
	save("fail", arpeggio([64, 60], 0.18, 0.4, true))
	save("coins", coins())
	save("levelup", arpeggio([67, 72, 76, 79, 84, 88], 0.08, 0.5))
	save("music", music(), true)
	print("audio generated")
	quit()


# ---------- output ----------

func save(sound_name: String, samples: PackedFloat32Array, loop := false) -> void:
	if sound_name in keep:
		return
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i in samples.size():
		bytes.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32000.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.stereo = false
	wav.data = bytes
	if loop:
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		wav.loop_end = samples.size()
	wav.save_to_wav(ProjectSettings.globalize_path(OUT % sound_name))


func buffer(seconds: float) -> PackedFloat32Array:
	var b := PackedFloat32Array()
	b.resize(int(seconds * RATE))
	return b


func silence(seconds: float) -> PackedFloat32Array:
	return buffer(seconds)


func concat(parts: Array) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	for p in parts:
		out.append_array(p)
	return out


func midi(note: float) -> float:
	return 440.0 * pow(2.0, (note - 69.0) / 12.0)


## Crossfades the end into the start so a loop has no click.
func seamless(b: PackedFloat32Array, fade := 0.05) -> PackedFloat32Array:
	var n := int(fade * RATE)
	for i in n:
		var t := float(i) / n
		b[i] = b[i] * t + b[b.size() - n + i] * (1.0 - t)
	b.resize(b.size() - n)
	return b


# ---------- sound effects ----------

## Burr grinder: motor hum plus crunchy bean noise, wobbling.
func grind() -> PackedFloat32Array:
	var b := buffer(1.25)
	var lp := 0.0
	for i in b.size():
		var t := float(i) / RATE
		var hum := sin(TAU * 118.0 * t) * 0.25 + sin(TAU * 236.0 * t) * 0.12 + sin(TAU * 354.0 * t) * 0.06
		lp += (rng.randf_range(-1, 1) - lp) * 0.35
		var crunch := lp * (0.5 + 0.5 * sin(TAU * 21.0 * t)) * 0.55
		b[i] = (hum + crunch) * 0.6
	return seamless(b)


## Espresso stream: soft low trickle with gentle gurgle.
func pour() -> PackedFloat32Array:
	var b := buffer(1.2)
	var lp := 0.0
	var lp2 := 0.0
	for i in b.size():
		var t := float(i) / RATE
		lp += (rng.randf_range(-1, 1) - lp) * 0.08
		lp2 += (lp - lp2) * 0.15
		var gurgle := 0.7 + 0.3 * sin(TAU * (6.0 + 3.0 * sin(TAU * 0.7 * t)) * t)
		b[i] = lp2 * gurgle * 2.2
	return seamless(b)


## Steam wand: bright hiss (white noise minus its low part), slightly fluttering.
func steam() -> PackedFloat32Array:
	var b := buffer(1.2)
	var lp := 0.0
	for i in b.size():
		var t := float(i) / RATE
		var w := rng.randf_range(-1, 1)
		lp += (w - lp) * 0.2
		b[i] = (w - lp) * (0.32 + 0.06 * sin(TAU * 13.0 * t))
	return seamless(b)


## Shop door bell: two bright chimes (ding-dong).
func bell() -> PackedFloat32Array:
	var b := buffer(1.3)
	for note in [[88.0, 0.0], [84.0, 0.22]]:
		var f := midi(note[0])
		var start := int(note[1] * RATE)
		for i in range(start, b.size()):
			var t := float(i - start) / RATE
			var env := exp(-t * 4.0)
			b[i] += (sin(TAU * f * t) + 0.4 * sin(TAU * f * 2.76 * t) * exp(-t * 9.0)) * env * 0.35
	return b


func blip(freq: float, length: float, vol: float) -> PackedFloat32Array:
	var b := buffer(length)
	for i in b.size():
		var t := float(i) / RATE
		b[i] = sin(TAU * freq * t) * exp(-t * 60.0) * vol
	return b


## Glass/ceramic clink: inharmonic partials, fast decay.
func clink(vol: float, pitch := 1.0) -> PackedFloat32Array:
	var b := buffer(0.3)
	for i in b.size():
		var t := float(i) / RATE
		var env := exp(-t * 22.0)
		b[i] = (sin(TAU * 2900.0 * pitch * t) + 0.6 * sin(TAU * 4170.0 * pitch * t) + 0.3 * sin(TAU * 6020.0 * pitch * t)) * env * 0.22 * vol
	return b


## Tamp / knock: a low thump with a pitch drop.
func thud(vol: float) -> PackedFloat32Array:
	var b := buffer(0.18)
	var phase := 0.0
	for i in b.size():
		var t := float(i) / RATE
		phase += TAU * (140.0 - 300.0 * t) / RATE
		b[i] = (sin(phase) * exp(-t * 25.0) + rng.randf_range(-1, 1) * exp(-t * 80.0) * 0.3) * 0.7 * vol
	return b


## Syrup pump / topping shake: a short soft noise puff.
func pump(length := 0.16, vol := 0.4) -> PackedFloat32Array:
	var b := buffer(length)
	var lp := 0.0
	for i in b.size():
		var t := float(i) / RATE
		lp += (rng.randf_range(-1, 1) - lp) * 0.25
		b[i] = lp * sin(PI * t / length) * vol * 2.0
	return b


## Serving the cup: an airy swoosh rising in brightness.
func swoosh() -> PackedFloat32Array:
	var b := buffer(0.35)
	var lp := 0.0
	for i in b.size():
		var t := float(i) / RATE
		var k := 0.03 + 0.4 * t / 0.35
		lp += (rng.randf_range(-1, 1) - lp) * k
		b[i] = lp * sin(PI * t / 0.35) * 0.7
	return b


## Short jingle: soft bell-ish notes one after another.
func arpeggio(notes: Array, step: float, vol: float, soft := false) -> PackedFloat32Array:
	var b := buffer(step * notes.size() + 0.6)
	for k in notes.size():
		var f := midi(notes[k])
		var start := int(k * step * RATE)
		for i in range(start, b.size()):
			var t := float(i - start) / RATE
			var env := exp(-t * (5.0 if soft else 6.5))
			var tone := sin(TAU * f * t) + (0.15 if soft else 0.3) * sin(TAU * f * 2.0 * t)
			b[i] += tone * env * vol * 0.4
	return b


## Coins into the till: quick bright clinks.
func coins() -> PackedFloat32Array:
	var parts := []
	for k in 6:
		parts.append(clink(0.5, rng.randf_range(1.3, 1.9)).slice(0, int(0.09 * RATE)))
	parts.append(clink(0.6, 2.0))
	return concat(parts)


# ---------- music ----------

## Original chill café loop, 84 BPM, 8 bars: Fmaj7 Em7 Dm7 Cmaj7 (2 bars each) on a soft
## electric-piano tone, walking bass, brushed hats, and a sparse pentatonic melody.
func music() -> PackedFloat32Array:
	var bpm := 84.0
	var beat := 60.0 / bpm
	var bars := 8
	var b := buffer(bars * 4 * beat)
	var chords := [[53, 57, 60, 64], [52, 55, 59, 62], [50, 53, 57, 60], [48, 52, 55, 59]]
	var bass := [41, 40, 38, 36]
	for bar in bars:
		var chord: Array = chords[bar / 2]
		var bar_t := bar * 4 * beat
		for hit in [0.0, 1.5, 2.5]:  # syncopated chord stabs
			for n in chord:
				note(b, bar_t + hit * beat, midi(n + 12), 1.4 * beat, 0.07, 2.2)
		var root: int = bass[bar / 2]
		for k in 4:  # walking-ish bass: root, fifth, octave, fifth
			note(b, bar_t + k * beat, midi(root + [0, 7, 12, 7][k]), 0.9 * beat, 0.16, 5.0, true)
		for k in 8:  # brushed hats on the off-beats, swung
			hat(b, bar_t + (k + (0.12 if k % 2 == 1 else 0.0)) * beat * 0.5, 0.05 if k % 2 == 1 else 0.025)
	var melody := [[0.0, 76], [1.0, 79], [2.5, 81], [6.0, 79], [7.0, 76], [8.5, 74], [12.0, 72], [13.0, 74],
		[14.5, 76], [18.0, 77], [19.0, 76], [20.5, 74], [24.0, 72], [25.5, 74], [27.0, 76], [28.5, 72]]
	for m in melody:
		note(b, m[0] * beat, midi(m[1]), 1.2 * beat, 0.09, 3.0)
	for i in b.size():  # gentle limiter
		b[i] = tanh(b[i] * 1.3) * 0.8
	return b


## Electric-piano-ish note (sine + soft 2nd harmonic, tremolo) or a round bass note.
func note(b: PackedFloat32Array, start: float, freq: float, length: float, vol: float, decay: float, is_bass := false) -> void:
	var s := int(start * RATE)
	var n := int((length + 0.4) * RATE)
	for i in n:
		var idx := (s + i) % b.size()  # wraps, so the loop tail flows into the start
		var t := float(i) / RATE
		var env := minf(t / 0.01, 1.0) * exp(-t * decay) * (1.0 if t < length else exp(-(t - length) * 12.0))
		var tone := sin(TAU * freq * t)
		if not is_bass:
			tone += 0.25 * sin(TAU * freq * 2.0 * t) * exp(-t * 6.0)
			tone *= 1.0 + 0.08 * sin(TAU * 5.0 * t)
		b[idx] += tone * env * vol


func hat(b: PackedFloat32Array, start: float, vol: float) -> void:
	var s := int(start * RATE)
	var prev := 0.0
	for i in int(0.06 * RATE):
		var w := rng.randf_range(-1, 1)
		var hp := w - prev  # crude high-pass
		prev = w
		b[(s + i) % b.size()] += hp * exp(-float(i) / RATE * 70.0) * vol
