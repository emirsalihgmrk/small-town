class_name HintHand
extends CanvasLayer
## Parmak ipucu: ekranda bir işin nasıl yapılacağını gösteren el. Dokunuş yutmaz, yalnızca görünür.
## play verilen noktalar boyunca bir hareketi REPEATS kez oynatır: el ilk noktada belirir, bastırır (parmak
## ucunda halka açılır), noktadan noktaya kayar, son noktada hold kadar bekleyip bırakır ve kaybolur.
## Tek nokta dokunmadır: el o noktaya iki kez dokunur. Aynı nokta art arda verilirse el orada kısa bir an
## bekler. Noktalar ekran koordinatıdır. Hareketin hepsi bitince finished yayılır; stop hemen gizler.
## carry verilirse (raftaki araç, sepetten çıkan ürün gibi) kopyası parmağın ucunda, bastırınca belirip
## bırakınca kaybolur: el onu taşıyormuş gibi görünür.

signal finished

const DEFAULT_HOLD: float = 0.3
const REPEATS: int = 3
const TAP_COUNT: int = 2
const FADE_TIME: float = 0.25
const APPEAR_SCALE: float = 1.15
const PRESS_SCALE: float = 0.85
const PRESS_TIME: float = 0.15
const MOVE_SPEED: float = 650.0
## Kısa (ya da sıfır) yollar en az bu kadar sürer; aynı nokta art arda gelince bekleme olur.
const MIN_SEGMENT_TIME: float = 0.15
const TAP_GAP: float = 0.25
const REPEAT_GAP: float = 0.6
const RIPPLE_START_SCALE: float = 0.3
const RIPPLE_END_SCALE: float = 1.2
const RIPPLE_TIME: float = 0.45
## Taşınan kopyanın parmağa göre yeri (oyundaki araçlar da parmağın biraz üstünde durur), boyu ve saydamlığı.
const CARRY_OFFSET: Vector2 = Vector2(0.0, -40.0)
const CARRY_SCALE: float = 1.3
const CARRY_ALPHA: float = 0.85

var _tween: Tween
var _ripple_tween: Tween
var _carried: Node2D

@onready var _hand: Node2D = $Hand
@onready var _ripple: Node2D = $Ripple


func _ready() -> void:
	_hand.hide()
	_ripple.hide()


func is_playing() -> bool:
	return _tween != null and _tween.is_running()


func play(points: PackedVector2Array, hold: float = DEFAULT_HOLD, carry: Node2D = null) -> void:
	stop()
	if points.is_empty():
		return
	if carry != null:
		_carried = carry.duplicate() as Node2D
		_carried.position = CARRY_OFFSET
		_carried.scale = carry.global_scale * CARRY_SCALE
		_carried.rotation = 0.0
		_carried.modulate.a = CARRY_ALPHA
		_carried.hide()
		_hand.add_child(_carried)
		_hand.move_child(_carried, 0)
	_hand.show()
	_tween = create_tween()
	for i: int in REPEATS:
		_tween.tween_callback(_appear_at.bind(points[0]))
		_tween.tween_property(_hand, ^"modulate:a", 1.0, FADE_TIME)
		_tween.parallel().tween_property(_hand, ^"scale", Vector2.ONE, FADE_TIME).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		if points.size() == 1:
			for tap: int in TAP_COUNT:
				_press()
				_release()
				_tween.tween_interval(TAP_GAP)
		else:
			_press()
			for p: int in range(1, points.size()):
				var duration: float = maxf(points[p - 1].distance_to(points[p]) / MOVE_SPEED, MIN_SEGMENT_TIME)
				_tween.tween_property(_hand, ^"position", points[p], duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			_tween.tween_interval(hold)
			_release()
		_tween.tween_property(_hand, ^"modulate:a", 0.0, FADE_TIME)
		_tween.tween_interval(REPEAT_GAP)
	_tween.tween_callback(_finish)


func stop() -> void:
	if _tween != null:
		_tween.kill()
		_tween = null
	_hand.hide()
	_drop_carried()


func _appear_at(point: Vector2) -> void:
	_hand.position = point
	_hand.scale = Vector2.ONE * APPEAR_SCALE
	_hand.modulate.a = 0.0


func _press() -> void:
	_tween.tween_property(_hand, ^"scale", Vector2.ONE * PRESS_SCALE, PRESS_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_tween.tween_callback(_pulse_ripple)
	_tween.tween_callback(_set_carried_visible.bind(true))


func _release() -> void:
	_tween.tween_callback(_set_carried_visible.bind(false))
	_tween.tween_property(_hand, ^"scale", Vector2.ONE, PRESS_TIME).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _set_carried_visible(carried_visible: bool) -> void:
	if _carried != null:
		_carried.visible = carried_visible


func _drop_carried() -> void:
	if _carried != null:
		_carried.queue_free()
		_carried = null


## Parmak ucunda açılıp sönen halka (elin hareketinden bağımsız oynar).
func _pulse_ripple() -> void:
	if _ripple_tween != null:
		_ripple_tween.kill()
	_ripple.position = _hand.position
	_ripple.scale = Vector2.ONE * RIPPLE_START_SCALE
	_ripple.modulate.a = 1.0
	_ripple.show()
	_ripple_tween = create_tween().set_parallel()
	_ripple_tween.tween_property(_ripple, ^"scale", Vector2.ONE * RIPPLE_END_SCALE, RIPPLE_TIME).set_ease(Tween.EASE_OUT)
	_ripple_tween.tween_property(_ripple, ^"modulate:a", 0.0, RIPPLE_TIME)
	_ripple_tween.chain().tween_callback(_ripple.hide)


func _finish() -> void:
	_tween = null
	_hand.hide()
	_drop_carried()
	finished.emit()
