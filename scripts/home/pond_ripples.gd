class_name PondRipples
extends Node2D
## Havuz suyunda genişleyip sönen halkalar (yandan bakıldığı için basık elips). Dokunuş, ördeğin dümen suyu
## ve balığın dalışı için ortak.

const LIFETIME: float = 1.0
## Aynı sıçramadaki ardışık halkalar arasındaki gecikme.
const RING_GAP: float = 0.18
const START_RADIUS: float = 4.0
const MAX_RADIUS: float = 40.0
const Y_SQUASH: float = 0.3
const WIDTH: float = 3.0
const POINTS: int = 28
const COLOR: Color = Color(1.0, 1.0, 1.0, 0.85)

## Her halka: {pos: Vector2, age: float, size: float}. Yaşı eksi olan halka henüz çizilmez.
var _rings: Array[Dictionary] = []


## pos (yerel) noktasında count halka açar; size, MAX_RADIUS'un çarpanıdır.
func splash(pos: Vector2, size: float = 1.0, count: int = 3) -> void:
	for i: int in count:
		_rings.append({pos = pos, age = -i * RING_GAP, size = size})


func _process(delta: float) -> void:
	if _rings.is_empty():
		return
	for ring: Dictionary in _rings:
		ring.age += delta
	_rings = _rings.filter(func(ring: Dictionary) -> bool: return ring.age < LIFETIME)
	queue_redraw()


func _draw() -> void:
	for ring: Dictionary in _rings:
		if ring.age < 0.0:
			continue
		var t: float = ring.age / LIFETIME
		var radius: float = lerpf(START_RADIUS, MAX_RADIUS * ring.size, ease(t, 0.4))
		var color: Color = COLOR
		color.a *= 1.0 - t
		var points: PackedVector2Array = PackedVector2Array()
		for i: int in POINTS + 1:
			var angle: float = TAU * i / POINTS
			points.append(ring.pos + Vector2(cos(angle) * radius, sin(angle) * radius * Y_SQUASH))
		draw_polyline(points, color, WIDTH * (1.0 - t * 0.5), true)
