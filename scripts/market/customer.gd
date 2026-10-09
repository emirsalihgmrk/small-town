class_name Customer
extends Node2D
## Pazara alışverişe gelen hayvan dost (tavşan, ayıcık ya da kirpi; görünüşü Looks altındaki çocuklardan
## biridir). Sağdan yürüyerek gelir, tezgâhın önünde durur ve başının üstünde isteğinin balonu açılır.
## Beklerken nefes alır, başını hafifçe sallar. Önden görünür, yürürken aynalanmaz; her adımda seker ve
## iki yana sallanır (bu hareket Hop düğümünde oynar).
## Her görünüşün BubbleAnchor işareti, balonun kuyruk ucunun duracağı yerdir. Kök noktası ayaklardır.

signal arrived

enum State { AWAY, WALKING_IN, WAITING }

const WALK_SPEED: float = 280.0
const STEP_TIME: float = 0.16
const STEP_HOP: float = 12.0
const WADDLE_DEGREES: float = 5.0
const SETTLE_TIME: float = 0.15
const BUBBLE_DELAY: float = 0.25
const BREATH_SCALE: float = 1.025
const BREATH_PERIOD: float = 2.6
const HEAD_SWAY_DEGREES: float = 3.0
const HEAD_SWAY_PERIOD: float = 3.2

var state: State = State.AWAY
## Görünüşün Looks altındaki sırası.
var kind: int = 0
var order: Array[StringName] = []

var _move_tween: Tween
var _waddle_tween: Tween
var _looks: Array[Node2D] = []

@onready var _hop: Node2D = $Hop
@onready var _bubble: RequestBubble = $Bubble


func _ready() -> void:
	_looks.assign($Hop/Looks.get_children())
	for look: Node2D in _looks:
		Oscillation.ping_pong(self, look, ^"scale:y", 1.0, BREATH_SCALE, BREATH_PERIOD, 0.1)
		Oscillation.ping_pong(self, look.get_node(^"Head"), ^"rotation", deg_to_rad(-HEAD_SWAY_DEGREES),
				deg_to_rad(HEAD_SWAY_DEGREES), HEAD_SWAY_PERIOD, 0.15)
	hide()


func look_count() -> int:
	return _looks.size()


## from'dan to'ya yürüyüp durur, sonra isteğinin balonunu açar ve arrived yayar.
func arrive(new_kind: int, new_order: Array[StringName], from: Vector2, to: Vector2) -> void:
	kind = clampi(new_kind, 0, _looks.size() - 1)
	order = new_order
	for i: int in _looks.size():
		_looks[i].visible = i == kind
	_bubble.hide()
	_bubble.position = (_looks[kind].get_node(^"BubbleAnchor") as Node2D).position
	global_position = from
	show()
	state = State.WALKING_IN
	_start_waddle()
	if _move_tween != null:
		_move_tween.kill()
	_move_tween = create_tween()
	_move_tween.tween_property(self, ^"global_position", to, from.distance_to(to) / WALK_SPEED)
	_move_tween.tween_callback(_stop_waddle)
	_move_tween.tween_interval(BUBBLE_DELAY)
	_move_tween.tween_callback(func() -> void:
		state = State.WAITING
		_bubble.open(order)
		arrived.emit())


func is_present() -> bool:
	return state != State.AWAY


func _start_waddle() -> void:
	if _waddle_tween != null:
		_waddle_tween.kill()
	_waddle_tween = create_tween().set_loops().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	for side: float in [1.0, -1.0]:
		_waddle_tween.tween_property(_hop, ^"rotation", deg_to_rad(WADDLE_DEGREES) * side, STEP_TIME)
		_waddle_tween.parallel().tween_property(_hop, ^"position:y", -STEP_HOP, STEP_TIME * 0.5)
		_waddle_tween.parallel().tween_property(_hop, ^"position:y", 0.0, STEP_TIME * 0.5) \
				.set_delay(STEP_TIME * 0.5)


func _stop_waddle() -> void:
	if _waddle_tween != null:
		_waddle_tween.kill()
		_waddle_tween = null
	var tween: Tween = create_tween().set_parallel().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(_hop, ^"rotation", 0.0, SETTLE_TIME)
	tween.tween_property(_hop, ^"position:y", 0.0, SETTLE_TIME)
