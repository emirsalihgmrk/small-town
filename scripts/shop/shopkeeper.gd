class_name Shopkeeper
extends Node2D
## Tezgâhın arkasındaki tilki satıcı. Bir ürün satılınca sevinçle zıplar, başını yana eğer ve paketi
## uzatır (cheer); paket hand_point'ten çıkar. Sesi yoktur.
## Kök noktası ayaklarının ortasıdır (tezgâhın arkasında kalır).

## Paketin çıktığı yer (kök noktasına göre): tezgâhın hemen üstü, sağ elinin önü.
const HAND: Vector2 = Vector2(-40.0, -150.0)
const HOP_HEIGHT: float = 24.0
const HOP_UP_TIME: float = 0.16
const HOP_DOWN_TIME: float = 0.3
const TILT_DEGREES: float = 10.0
const TILT_TIME: float = 0.2
const TILT_HOLD: float = 0.5

var _tween: Tween
var _rest_y: float

@onready var _head: Node2D = $Head


func _ready() -> void:
	_rest_y = position.y


func hand_point() -> Vector2:
	return to_global(HAND)


func cheer() -> void:
	if _tween != null:
		_tween.kill()
	position.y = _rest_y
	_tween = create_tween()
	_tween.tween_property(self, ^"position:y", _rest_y - HOP_HEIGHT, HOP_UP_TIME).set_trans(Tween.TRANS_QUAD) \
			.set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, ^"position:y", _rest_y, HOP_DOWN_TIME).set_trans(Tween.TRANS_BOUNCE) \
			.set_ease(Tween.EASE_OUT)
	var tilt: Tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tilt.tween_property(_head, ^"rotation", deg_to_rad(-TILT_DEGREES), TILT_TIME)
	tilt.tween_interval(TILT_HOLD)
	tilt.tween_property(_head, ^"rotation", 0.0, TILT_TIME)

