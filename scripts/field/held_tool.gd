class_name HeldTool
extends Node2D
## Parmakla taşınan araç. Kök noktası aracın çalışan ucudur (çapanın ağzı, torbanın ağzı); görsel
## Visual altındadır, böylece kullanma animasyonu taşınan konumu bozmaz. Varsa Pour parçacıkları
## aracın döktüğü şeydir (serpilen tohum gibi).

const POP_START_SCALE: float = 0.5
const POP_TIME: float = 0.18
const USE_LIFT_TIME: float = 0.07
const USE_STRIKE_TIME: float = 0.09
const RETURN_TIME: float = 0.28
const RETURN_END_SCALE: float = 0.45
const POUR_TILT_TIME: float = 0.15

## Görselin kök noktasına göre ortası; rafa dönerken aracın ortası rafın ortasına otursun diye.
@export var visual_center: Vector2 = Vector2.ZERO
## Kullanırken araç bu kadar kalkıp yatar, sonra hızla yerine iner (çapa vurur, torba silkelenir).
@export var use_lift: Vector2 = Vector2(14.0, -34.0)
@export_range(-45.0, 45.0, 1.0, "suffix:°") var use_tilt_degrees: float = 12.0
## Dökerken araç kök noktası (ağzı) etrafında bu kadar eğilir (kova öne yatar); 0 ise eğilmez.
@export_range(-90.0, 90.0, 1.0, "suffix:°") var pour_tilt_degrees: float = 0.0

var _use_tween: Tween
var _move_tween: Tween
var _tilt_tween: Tween

@onready var _visual: Node2D = $Visual
@onready var _pour: CPUParticles2D = get_node_or_null(^"Pour") as CPUParticles2D


func pop_in() -> void:
	scale = Vector2.ONE * POP_START_SCALE
	_move_tween = create_tween()
	_move_tween.tween_property(self, ^"scale", Vector2.ONE, POP_TIME).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Bir kullanım (çapa için bir vuruş). Önceki vuruş bitmeden gelirse baştan başlar.
func play_use() -> void:
	if _use_tween != null:
		_use_tween.kill()
	_visual.position = Vector2.ZERO
	_visual.rotation = 0.0
	_use_tween = create_tween()
	_use_tween.tween_property(_visual, ^"position", use_lift, USE_LIFT_TIME).set_ease(Tween.EASE_OUT)
	_use_tween.parallel().tween_property(_visual, ^"rotation", deg_to_rad(use_tilt_degrees), USE_LIFT_TIME)
	_use_tween.tween_property(_visual, ^"position", Vector2.ZERO, USE_STRIKE_TIME) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_use_tween.parallel().tween_property(_visual, ^"rotation", 0.0, USE_STRIKE_TIME)


## Pour parçacığı olmayan araçlarda bir şey yapmaz.
func set_pouring(pouring: bool) -> void:
	if _pour == null or _pour.emitting == pouring:
		return
	_pour.emitting = pouring
	if pour_tilt_degrees != 0.0:
		if _tilt_tween != null:
			_tilt_tween.kill()
		_tilt_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		_tilt_tween.tween_property(_visual, ^"rotation", deg_to_rad(pour_tilt_degrees) if pouring else 0.0, POUR_TILT_TIME)


## Görsel ortası target'a gelecek şekilde rafa geri uçar, küçülüp kaybolur;
## varınca on_arrived çağrılır ve araç kendini siler.
func return_to(target: Vector2, on_arrived: Callable) -> void:
	set_pouring(false)
	if _move_tween != null:
		_move_tween.kill()
	_move_tween = create_tween().set_parallel().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_move_tween.tween_property(self, ^"position", target - visual_center * RETURN_END_SCALE, RETURN_TIME)
	_move_tween.tween_property(self, ^"scale", Vector2.ONE * RETURN_END_SCALE, RETURN_TIME)
	_move_tween.tween_property(self, ^"modulate:a", 0.0, RETURN_TIME * 0.4).set_delay(RETURN_TIME * 0.6)
	_move_tween.chain().tween_callback(func() -> void:
		on_arrived.call()
		queue_free())
