class_name HouseBird
extends Node2D
## Kuş evinde yaşayan kuş. Nereye uçacağına kuş evi (PlayBirdhouse) karar verir: delikten küçükten büyüyerek
## çıkar, tanelere uçar, gagalar, taneler bitince küçülerek deliğe girer. Kendi başına yalnızca dokunmaya
## tepki verir: yerdeyken zıplar ve cıvıldar.
## Kök noktası ayaklarıdır; görsel Body altında sağa bakar, sola giderken kök aynalanır.

const FLAP_DEGREES: float = 50.0
const FLAP_TIME: float = 0.08
const PECK_DEGREES: float = 28.0
const PECK_TIME: float = 0.12
const HOP_HEIGHT: float = 16.0
const HOP_UP_TIME: float = 0.14
const HOP_DOWN_TIME: float = 0.22
## Gaga ucunun ayaklara göre yatay uzaklığı (tam boyda, ölçeksiz).
const BEAK_X: float = 26.0
const SCREEN_WIDTH: float = 1920.0
const MAX_SOUND_PAN: float = 0.7

## Yerdeki tam boyu.
@export var full_scale: float = 1.1
@export var chirp_paths: Array[String] = [
	"res://assets/audio/ambience/bird_chirp_1.ogg",
	"res://assets/audio/ambience/bird_chirp_3.ogg",
	"res://assets/audio/ambience/bird_chirp_5.ogg",
]

var _facing: float = 1.0
var _size: float = 1.0
var _chirps: Array[AudioStream] = []
var _flap_tween: Tween
var _move_tween: Tween
var _hop_tween: Tween

@onready var _body: Node2D = $Body
@onready var _wing: Node2D = $Body/Wing
@onready var _tap_area: Tappable = $TapArea


func _ready() -> void:
	hide()
	_tap_area.enabled = false
	_tap_area.tapped.connect(_on_tapped)
	for path: String in chirp_paths:
		if ResourceLoader.exists(path):
			_chirps.append(load(path) as AudioStream)


## from'dan to'ya arc kadar yukarı kavis çizerek uçar; boyu size_from'dan size_to'ya gider (tam boyun katı).
## Uçarken dokunulmaz. Varınca on_arrived çağrılır.
func fly(from: Vector2, to: Vector2, size_from: float, size_to: float, time: float, arc: float,
		on_arrived: Callable) -> void:
	show()
	_tap_area.enabled = false
	if absf(to.x - from.x) > 1.0:
		_facing = signf(to.x - from.x)
	_body.rotation = 0.0
	position = from
	scale = Vector2(_facing, 1.0) * size_from * full_scale
	_set_flapping(true)
	if _move_tween != null:
		_move_tween.kill()
	_move_tween = create_tween()
	_move_tween.tween_method(func(t: float) -> void:
		var control: Vector2 = (from + to) * 0.5 + Vector2(0.0, -arc)
		position = from.lerp(control, t).lerp(control.lerp(to, t), t)
		_size = lerpf(size_from, size_to, t)
		scale = Vector2(_facing, 1.0) * _size * full_scale, 0.0, 1.0, time) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_move_tween.tween_callback(func() -> void:
		_set_flapping(false)
		_tap_area.enabled = true
		on_arrived.call())


## Başını eğip bir kez gagalar; bitince on_done çağrılır.
func peck(on_done: Callable) -> void:
	var tween: Tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(_body, ^"rotation", deg_to_rad(PECK_DEGREES), PECK_TIME)
	tween.tween_property(_body, ^"rotation", 0.0, PECK_TIME)
	tween.tween_callback(on_done)


## Gaga ucunun yerdeki yeri (ebeveyne göre).
func beak() -> Vector2:
	return position + Vector2(beak_reach() * _facing, 0.0)


## Gaga ucunun ayaklara uzaklığı (tam boyda).
func beak_reach() -> float:
	return BEAK_X * full_scale


func _on_tapped(_point: Vector2) -> void:
	if _hop_tween != null and _hop_tween.is_running():
		return
	if not _chirps.is_empty():
		var pan: float = clampf((global_position.x / SCREEN_WIDTH) * 2.0 - 1.0, -1.0, 1.0) * MAX_SOUND_PAN
		AudioManager.play_sfx(_chirps.pick_random(), AudioManager.BUS_SFX, 0.0, randf_range(0.95, 1.1), pan)
	var rest_y: float = _body.position.y
	_hop_tween = create_tween()
	_hop_tween.tween_property(_body, ^"position:y", rest_y - HOP_HEIGHT, HOP_UP_TIME).set_trans(Tween.TRANS_QUAD) \
			.set_ease(Tween.EASE_OUT)
	_hop_tween.tween_property(_body, ^"position:y", rest_y, HOP_DOWN_TIME).set_trans(Tween.TRANS_BOUNCE) \
			.set_ease(Tween.EASE_OUT)


func _set_flapping(flapping: bool) -> void:
	if _flap_tween != null:
		_flap_tween.kill()
		_flap_tween = null
	_wing.rotation = 0.0
	if flapping:
		_flap_tween = create_tween().set_loops().set_trans(Tween.TRANS_SINE)
		_flap_tween.tween_property(_wing, ^"rotation", deg_to_rad(FLAP_DEGREES), FLAP_TIME)
		_flap_tween.tween_property(_wing, ^"rotation", deg_to_rad(-FLAP_DEGREES * 0.3), FLAP_TIME)
