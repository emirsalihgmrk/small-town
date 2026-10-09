class_name Butterfly
extends Node2D
## Bir alanın içinde gezinen kelebek. Rastgele bir noktaya hafifçe dalgalanarak uçar, arada havada biraz
## oyalanır, sonra yeni bir noktaya geçer; kanatları hep çırpar (oyalanırken daha yavaş). Dokununca
## kanatlarını hızla çırpıp alanın uzak bir köşesine kaçar.
## Görsel yukarıdan görünür; kanatlar gövdenin iki yanında, birbirinin aynasıdır (LeftWing, RightWing).

const WOBBLE: float = 14.0
const WOBBLE_SPEED: float = 7.0
const ARRIVE_DISTANCE: float = 12.0
const FLAP_TIME: float = 0.09
const SLOW_FLAP_TIME: float = 0.35
## Kanadın kapanınca kaldığı en dar genişlik oranı.
const FLAP_CLOSED: float = 0.25
const TILT_DEGREES: float = 12.0
const FLEE_SPEED_FACTOR: float = 3.5
## Kaçarken dokunulan yerden en az bu kadar uzağa gider.
const FLEE_MIN_DISTANCE: float = 250.0

## Kelebeğin gezindiği dünya alanı.
@export var area: Rect2 = Rect2(400.0, 560.0, 1400.0, 240.0)
@export_range(10.0, 400.0, 5.0, "suffix:px/s") var speed: float = 90.0
@export_range(0.0, 10.0, 0.1, "suffix:s") var hover_min: float = 0.8
@export_range(0.0, 10.0, 0.1, "suffix:s") var hover_max: float = 2.5

var _target: Vector2
var _hover_left: float = 0.0
var _fleeing: bool = false
var _time: float = 0.0
var _flap_tween: Tween
var _flap_time: float = 0.0

@onready var _left_wing: Node2D = $LeftWing
@onready var _right_wing: Node2D = $RightWing


func _ready() -> void:
	($TapArea as Tappable).tapped.connect(func(_point: Vector2) -> void: _flee())
	_time = randf() * TAU
	_pick_target()
	_set_flap(FLAP_TIME)


func _process(delta: float) -> void:
	_time += delta
	if _hover_left > 0.0:
		_hover_left -= delta
		position.y += sin(_time * WOBBLE_SPEED * 0.5) * WOBBLE * 0.3 * delta
		if _hover_left <= 0.0:
			_pick_target()
			_set_flap(FLAP_TIME)
		return
	var to_target: Vector2 = _target - position
	if to_target.length() <= ARRIVE_DISTANCE:
		if _fleeing:
			_fleeing = false
		_hover_left = randf_range(hover_min, hover_max)
		_set_flap(SLOW_FLAP_TIME)
		rotation = 0.0
		return
	var direction: Vector2 = to_target.normalized()
	var current_speed: float = speed * (FLEE_SPEED_FACTOR if _fleeing else 1.0)
	var side: Vector2 = Vector2(-direction.y, direction.x)
	position += direction * minf(current_speed * delta, to_target.length())
	position += side * cos(_time * WOBBLE_SPEED) * WOBBLE * WOBBLE_SPEED * delta * 0.5
	rotation = deg_to_rad(TILT_DEGREES) * clampf(direction.x, -1.0, 1.0)


func _pick_target() -> void:
	_target = Vector2(randf_range(area.position.x, area.end.x), randf_range(area.position.y, area.end.y))


func _flee() -> void:
	_fleeing = true
	_hover_left = 0.0
	_set_flap(FLAP_TIME * 0.6)
	for i: int in 8:
		_pick_target()
		if _target.distance_to(position) >= FLEE_MIN_DISTANCE:
			break


func _set_flap(half_time: float) -> void:
	if is_equal_approx(half_time, _flap_time) and _flap_tween != null:
		return
	_flap_time = half_time
	if _flap_tween != null:
		_flap_tween.kill()
	_flap_tween = create_tween().set_loops().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_flap_tween.tween_property(_left_wing, ^"scale:x", FLAP_CLOSED, half_time)
	_flap_tween.parallel().tween_property(_right_wing, ^"scale:x", -FLAP_CLOSED, half_time)
	_flap_tween.tween_property(_left_wing, ^"scale:x", 1.0, half_time)
	_flap_tween.parallel().tween_property(_right_wing, ^"scale:x", -1.0, half_time)
