class_name SleepyCat
extends Node2D
## Kümesin yanında uyuyan kedi. Uyurken nefes alır, kuyruğu yavaşça sallanır, başının üstünden "z"ler
## süzülür. Dokununca kısa bir an uyanır: gerinir (uzayıp basılır), kuyruğunu oynatır, "z"ler kesilir;
## sonra yine uyur. Uyanınca woke yayılır (kız şaşırır). Ekonomiye karışmaz, süstür.
## Kök noktası kedinin karnının altının ortasıdır.

signal woke

const STRETCH: Vector2 = Vector2(1.18, 0.86)
const STRETCH_TIME: float = 0.35
const SETTLE_TIME: float = 0.6
const TAIL_FLICK_DEGREES: float = 35.0
const TAIL_FLICK_TIME: float = 0.12
const TAIL_FLICKS: int = 2
## Uyandıktan sonra "z"ler bu kadar süre çıkmaz.
const AWAKE_TIME: float = 3.0

var _awake_tween: Tween

@onready var _stretch: Node2D = $Stretch
@onready var _tail: Node2D = $Stretch/Tail/Sway/Flick
@onready var _zzz: CPUParticles2D = $Zzz
@onready var _tap_area: Tappable = $TapArea


func _ready() -> void:
	_tap_area.tapped.connect(func(_point: Vector2) -> void: _wake())


func _wake() -> void:
	if _awake_tween != null and _awake_tween.is_running():
		return
	woke.emit()
	_zzz.emitting = false
	_awake_tween = create_tween()
	_awake_tween.tween_property(_stretch, ^"scale", STRETCH, STRETCH_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_awake_tween.tween_property(_stretch, ^"scale", Vector2.ONE, SETTLE_TIME).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	for i: int in TAIL_FLICKS:
		_awake_tween.tween_property(_tail, ^"rotation", deg_to_rad(-TAIL_FLICK_DEGREES), TAIL_FLICK_TIME)
		_awake_tween.tween_property(_tail, ^"rotation", 0.0, TAIL_FLICK_TIME)
	_awake_tween.tween_interval(maxf(AWAKE_TIME - STRETCH_TIME - SETTLE_TIME - TAIL_FLICKS * 2 * TAIL_FLICK_TIME, 0.0))
	_awake_tween.tween_callback(func() -> void: _zzz.emitting = true)
